"""Text messages to parents and guardians.

Messages are written to `sms_outbox` first (deduplicated per event), then
sent by the background worker, so a slow gateway never delays a tap. The
provider comes from SMS_PROVIDER:

    none       nothing is sent; rows are marked skipped (default)
    log        written to the server log, for demos and testing
    semaphore  Semaphore (https://semaphore.co), SEMAPHORE_API_KEY / SEMAPHORE_SENDER
    http       POST {"to": ..., "message": ...} to SMS_HTTP_URL with SMS_HTTP_TOKEN
"""
import json
import logging
import os
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

import database as db
from api.common import clock, connect, now_text
from services import attendance

log = logging.getLogger("sms")
MAX_ATTEMPTS = 3


def provider():
    return os.environ.get("SMS_PROVIDER", "none").strip().lower() or "none"


def _guardians(c, user_id):
    return c.execute("SELECT * FROM guardians WHERE user_id = ? AND sms_enabled = 1", (user_id,)).fetchall()


def queue(c, user_id, body, dedupe_key):
    """Adds one message per guardian of [user_id]. Returns how many were queued."""
    n = 0
    for g in _guardians(c, user_id):
        cur = c.execute("""INSERT OR IGNORE INTO sms_outbox (guardian_id, phone, body, dedupe_key, created_at)
                           VALUES (?, ?, ?, ?, ?)""", (g["id"], g["phone"], body[:300], f"{dedupe_key}:g{g['id']}",
                                                      now_text()))
        n += cur.rowcount
    return n


def _kick():
    from api import push
    push.submit("sms")


def on_tap(code, user_id, log_id):
    """Queues the guardian texts for a confirmed time in or time out."""
    if log_id is None or code not in ("TIME_IN_OK", "TIME_OUT_OK"):
        return 0
    with connect(write=True) as c:
        pol = attendance.policy(c)
        event = "in" if code == "TIME_IN_OK" else "out"
        if event not in pol["sms_events"]:
            return 0
        r = c.execute("""SELECT u.name, l.time_in, l.time_out FROM logs l JOIN users u ON u.id = l.user_id
                         WHERE l.id = ? AND l.user_id = ?""", (log_id, user_id)).fetchone()
        if r is None:
            return 0
        if event == "in":
            late = attendance.late_minutes(datetime.strptime(r["time_in"], db.FMT), pol)
            body = f"{r['name']} arrived at school at {clock(r['time_in'])}" + (f" ({late} min late)." if late else ".")
        else:
            if not r["time_out"]:
                return 0
            body = f"{r['name']} left school at {clock(r['time_out'])}."
        n = queue(c, user_id, body, f"log:{log_id}:{event}")
    if n:
        _kick()
    return n


def on_absent(user_ids, day):
    """Queues absence texts for [day]."""
    n = 0
    with connect(write=True) as c:
        if "absent" not in attendance.policy(c)["sms_events"]:
            return 0
        for uid in user_ids:
            r = c.execute("SELECT name FROM users WHERE id = ?", (uid,)).fetchone()
            if r:
                n += queue(c, uid, f"{r['name']} was marked absent on {day.strftime('%b %d, %Y')}.",
                           f"absent:{day}:{uid}")
    if n:
        _kick()
    return n


# ------------------------------------------------------------------ delivery
def send(phone, body):
    """Sends one message. Returns the provider name; raises on failure."""
    name = provider()
    if name == "log":
        log.info("SMS to %s: %s", phone, body)
        return name
    if name == "semaphore":
        data = urllib.parse.urlencode({"apikey": os.environ.get("SEMAPHORE_API_KEY", ""), "number": phone,
                                       "message": body,
                                       "sendername": os.environ.get("SEMAPHORE_SENDER", "SEMAPHORE")}).encode()
        req = urllib.request.Request("https://api.semaphore.co/api/v4/messages", data, method="POST")
    elif name == "http":
        url = os.environ.get("SMS_HTTP_URL", "")
        if not url:
            raise RuntimeError("SMS_HTTP_URL is not set")
        headers = {"Content-Type": "application/json"}
        if os.environ.get("SMS_HTTP_TOKEN"):
            headers["Authorization"] = "Bearer " + os.environ["SMS_HTTP_TOKEN"]
        req = urllib.request.Request(url, json.dumps({"to": phone, "message": body}).encode(), headers, method="POST")
    else:
        raise RuntimeError(f"unknown SMS provider {name!r}")
    with urllib.request.urlopen(req, timeout=15) as resp:
        if resp.status >= 300:
            raise RuntimeError(f"HTTP {resp.status}")
    return name


def deliver_pending(limit=50):
    """Sends queued messages. Returns (sent, failed, skipped)."""
    with connect() as c:
        rows = c.execute("SELECT * FROM sms_outbox WHERE status = 'pending' ORDER BY id LIMIT ?", (limit,)).fetchall()
    sent = failed = skipped = 0
    for r in rows:
        if provider() == "none":
            status, error, used = "skipped", None, "none"
            skipped += 1
        else:
            try:
                used = send(r["phone"], r["body"])
                status, error = "sent", None
                sent += 1
            except (urllib.error.URLError, OSError, RuntimeError) as e:
                used, error = provider(), str(e)[:200]
                status = "failed" if r["attempts"] + 1 >= MAX_ATTEMPTS else "pending"
                failed += 1
        with connect(write=True) as c:
            c.execute("""UPDATE sms_outbox SET status = ?, provider = ?, error = ?, attempts = attempts + 1,
                         sent_at = CASE WHEN ? = 'sent' THEN ? ELSE sent_at END WHERE id = ?""",
                      (status, used, error, status, now_text(), r["id"]))
    return sent, failed, skipped
