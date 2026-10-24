"""RFID readers: identity, per-reader state and the tap pipeline.

Every tap, from the original `/tap` route or from `/api/v1/device/tap`, goes
through `process_tap()`:

    reader + UID -> mode (IN / OUT / armed kiosk) -> database.record_tap()
                 -> notifier (queued, never blocks) -> tap_events row -> reply

Per-reader state (the kiosk TIME OUT arm, the latest result for the display)
lives in the database, so it survives restarts and two readers never share
one arm.
"""
import hashlib
import secrets
import time
from datetime import datetime, timedelta

import database as db
from services import attendance

TIMEOUT_ARM_SECONDS = 15
DEBOUNCE_SECONDS = 3
ONLINE_WINDOW_MINUTES = 3
MAX_REPLAY_AGE_HOURS = 24

FMT = db.FMT


def _now_text():
    return db.school_now().strftime(FMT)


def hash_key(key):
    return hashlib.sha256(key.encode()).hexdigest()


def new_key():
    return secrets.token_urlsafe(24)


# ------------------------------------------------------------------ lookup
def by_key(c, key):
    if not key or len(key) < 16:
        return None
    return c.execute("SELECT * FROM devices WHERE key_hash = ? AND active = 1", (hash_key(key),)).fetchone()


def default_device(c):
    row = c.execute("SELECT * FROM devices WHERE code = 'DEFAULT'").fetchone()
    if row is None:
        c.execute("""INSERT INTO devices (code, name, location, mode, created_at)
                     VALUES ('DEFAULT', 'Main gate (legacy /tap)', 'Main gate', 'KIOSK', ?)""", (_now_text(),))
        row = c.execute("SELECT * FROM devices WHERE code = 'DEFAULT'").fetchone()
    return row


def is_online(device):
    if not device["last_seen"]:
        return False
    seen = datetime.strptime(device["last_seen"], FMT)
    return db.school_now().replace(tzinfo=None) - seen <= timedelta(minutes=ONLINE_WINDOW_MINUTES)


def public(device):
    """A device as the admin API shows it. Never includes the key."""
    return {"id": device["id"], "code": device["code"], "name": device["name"], "location": device["location"],
            "mode": device["mode"], "active": bool(device["active"]), "has_key": device["key_hash"] is not None,
            "last_seen": device["last_seen"], "online": is_online(device), "ip": device["ip"],
            "rssi": device["rssi"], "firmware": device["firmware"], "queue_len": device["queue_len"],
            "armed": device["armed_until"] > time.time()}


# ------------------------------------------------------------------ state
def arm_timeout(c, device_id, seconds=TIMEOUT_ARM_SECONDS):
    c.execute("UPDATE devices SET armed_until = ? WHERE id = ?", (time.time() + seconds, device_id))
    return seconds


def heartbeat(c, device_id, ip=None, rssi=None, firmware=None, queue_len=None):
    c.execute("""UPDATE devices SET last_seen = ?, ip = COALESCE(?, ip), rssi = COALESCE(?, rssi),
                 firmware = COALESCE(?, firmware), queue_len = COALESCE(?, queue_len) WHERE id = ?""",
              (_now_text(), ip, rssi, firmware, queue_len, device_id))


# ------------------------------------------------------------------ messages
def _first_name(name):
    return (name or "").split(" ")[0][:16]


def describe(code, user, device_mode="KIOSK", at=None, late=0):
    """Maps a record_tap() result to the reply fields and the 16x2 LCD lines."""
    name = user["name"] if user else ""
    role = user["role"] if user else ""
    clock = (at or db.school_now()).strftime("%H:%M")
    if code == "TIME_IN_OK":
        status, action, message = "granted", "IN", f"Welcome, {name}!"
        lcd = [_first_name(name), f"LATE IN {clock}" if late else f"TIME IN {clock}"]
    elif code == "TIME_OUT_OK":
        status, action, message = "granted", "OUT", f"Goodbye, {name}!"
        lcd = [_first_name(name), f"TIME OUT {clock}"]
    elif code == "ALREADY_CHECKED_IN":
        if device_mode == "IN":
            status, action, message = "warning", "", "Already checked in. Tap at the exit reader."
            lcd = ["ALREADY IN", "Use exit reader"]
        else:
            status, action, message = "warning", "", "Already checked in. Use the TIME OUT button."
            lcd = ["ALREADY IN", "Press TIME OUT"]
    elif code == "VISIT_LIMIT_EXCEEDED":
        status, action, message = "denied", "", "Visit limit exceeded. Please see staff."
        lcd = ["VISIT LIMIT", "See staff"]
    elif code == "REJECT_NO_OPEN_RECORD":
        status, action, message = "denied", "", "No time in on record. Please see staff."
        lcd = ["NO TIME IN", "See staff"]
    elif code == "REJECT_EXPIRED_VISITOR":
        status, action, message = "denied", "", "Visitor card already used. Please register it for a new visitor."
        name, role = "", ""
        lcd = ["CARD EXPIRED", "See staff"]
    elif code == "OVERSTAY":
        status, action, message = "warning", "OUT", "Visitor card has overstayed. Please register a new card."
        lcd = ["OVERSTAY", "See staff"]
    else:
        status, action, message = "denied", "", "Card not registered. Please see staff."
        name, role = "", ""
        lcd = ["ACCESS DENIED", "Not registered"]
    return {"status": status, "result": code, "name": name, "role": role, "action": action,
            "message": message, "lcd": [line[:16] for line in lcd]}


def _from_row(row):
    return {"status": row["status"], "result": row["result_code"], "name": row["name"] or "",
            "role": row["role"] or "", "action": row["action"] or "", "message": row["message"] or "",
            "event_id": row["id"]}


def _parse_tapped_at(text):
    """A replayed tap's own time, or None when it is missing or implausible."""
    if not text:
        return None
    try:
        at = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if at.tzinfo is None:
        at = at.replace(tzinfo=db.SCHOOL_TZ)
    at = at.astimezone(db.SCHOOL_TZ)
    now = db.school_now()
    if at > now + timedelta(minutes=2) or at < now - timedelta(hours=MAX_REPLAY_AGE_HOURS):
        return None
    return at


# ------------------------------------------------------------------ the tap
def process_tap(device, uid, *, client_event_id=None, tapped_at=None, debounce=False):
    """Records one tap from [device]. Returns the reply dict (with lcd and event_id)."""
    from api.notifier import notify_after_tap

    uid = str(uid or "").strip().upper()
    cid = str(client_event_id).strip()[:64] if client_event_id else None
    conn = db.get_conn()
    try:
        if cid:
            # A reader replaying its offline queue: answer the same as the first time.
            row = conn.execute("SELECT * FROM tap_events WHERE device_id = ? AND client_event_id = ?",
                               (device["id"], cid)).fetchone()
            if row:
                return {**_from_row(row), "lcd": ["Already sent", ""], "replayed": True}

        now_epoch = time.time()
        fresh = conn.execute("SELECT * FROM devices WHERE id = ?", (device["id"],)).fetchone() or device
        armed = fresh["mode"] == "KIOSK" and fresh["armed_until"] > now_epoch

        if debounce and not armed:
            last = conn.execute("SELECT * FROM tap_events WHERE device_id = ? ORDER BY id DESC LIMIT 1",
                                (device["id"],)).fetchone()
            # Only a recorded time in/out is repeated: a denial is checked
            # again, because staff may have just registered the card.
            if last and last["uid"] == uid and last["result_code"] in ("TIME_IN_OK", "TIME_OUT_OK"):
                age = db.school_now().replace(tzinfo=None) - datetime.strptime(last["received_at"], FMT)
                if age.total_seconds() < DEBOUNCE_SECONDS:
                    # The card is still on the reader: repeat the answer, record nothing.
                    lcd = [_first_name(last["name"]) or "CARD READ", "Remove card"]
                    return {**_from_row(last), "lcd": lcd, "debounced": True}

        mode = {"IN": "IN", "OUT": "OUT"}.get(fresh["mode"], "OUT" if armed else "IN")
        if fresh["mode"] == "KIOSK" and fresh["armed_until"]:
            conn.execute("UPDATE devices SET armed_until = 0 WHERE id = ?", (device["id"],))
        pol = attendance.policy(conn)
    finally:
        conn.close()

    at = _parse_tapped_at(tapped_at)
    card_limit = db.get_visitor_time_limit_minutes(uid)
    limit_hours = card_limit / 60.0 if card_limit is not None else pol["visitor_limit_hours"]
    code, user, log_id = db.record_tap(uid, mode, limit_hours, device_id=device["id"], at=at)
    notify_after_tap(code, user, log_id)

    when = at or db.school_now()
    late = 0
    if code == "TIME_IN_OK" and user is not None and user["role"] == "student":
        late = attendance.late_minutes(when, pol)
    reply = describe(code, user, fresh["mode"], when, late)

    conn = db.get_conn()
    try:
        cur = conn.execute(
            """INSERT OR IGNORE INTO tap_events (device_id, uid, user_id, result_code, status, action, message,
                   name, role, log_id, client_event_id, tapped_at, received_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (device["id"], uid, user["id"] if user else None, code, reply["status"], reply["action"],
             reply["message"], reply["name"], reply["role"], log_id, cid, when.strftime(FMT), _now_text()))
        conn.execute("UPDATE devices SET last_seen = ? WHERE id = ?", (_now_text(), device["id"]))
        reply["event_id"] = cur.lastrowid
    finally:
        conn.close()
    reply["uid"] = uid
    if late:
        reply["late_minutes"] = late
    return reply


# ------------------------------------------------------------------ reads
def display_event(c, device_id):
    """The latest result on [device_id], for the kiosk display."""
    row = c.execute("SELECT * FROM tap_events WHERE device_id = ? ORDER BY id DESC LIMIT 1",
                    (device_id,)).fetchone()
    if row is None:
        return {"event_id": 0, "status": "idle", "message": "Ready to scan", "name": "", "role": "",
                "action": "", "result": "", "uid": ""}
    return {**_from_row(row), "uid": row["uid"]}


def last_tap(c):
    """The newest tap on any reader, for capturing a UID while registering a card."""
    row = c.execute("SELECT id, uid FROM tap_events ORDER BY id DESC LIMIT 1").fetchone()
    return {"uid": row["uid"], "count": row["id"]} if row else {"uid": None, "count": 0}
