"""Background worker: creates inbox rows after confirmed taps and delivers FCM pushes.

Nothing here runs on the /tap request thread except a non-blocking queue append, so a slow
database, a slow Firebase call or an exception can never delay or change the ESP32 response.

Set FIREBASE_SERVICE_ACCOUNT_PATH to the service-account JSON file. It must
remain outside this repository and must never be put in the Flutter app.
"""
import logging
import os
import threading
import time
from datetime import timedelta

from .common import connect, now_text

log = logging.getLogger("api.push")

RETRY_DELAYS = [5, 30, 120, 600]          # seconds between delivery attempts
# FCM reports invalid registration tokens synchronously during send.  Keep the
# old worker cadence only because the queue loop still wakes to run the
# no-op receipt hook below, preserving its established lifecycle.
RECEIPT_INTERVAL = 300

_jobs = []
_cv = threading.Condition()
_pending = 0
_thread = None
_start_lock = threading.Lock()
_firebase_lock = threading.Lock()
_firebase_app = None
_firebase_messaging = None


class Transient(Exception):
    """Network/5xx/429 problem: worth retrying later."""


def push_enabled():
    return os.environ.get("PUSH_ENABLED", "1") != "0"


def _firebase():
    """Initialise the Firebase Admin SDK once, using the private key path."""
    global _firebase_app, _firebase_messaging
    with _firebase_lock:
        if _firebase_messaging is not None:
            return _firebase_messaging, _firebase_app
        path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
        if not path or not os.path.isfile(path):
            raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_PATH is not configured")
        try:
            import firebase_admin
            from firebase_admin import credentials, messaging
        except ImportError as exc:
            raise RuntimeError("firebase-admin is not installed; run pip install -r requirements.txt") from exc
        _firebase_app = firebase_admin.initialize_app(credentials.Certificate(path))
        _firebase_messaging = messaging
        return _firebase_messaging, _firebase_app


def send_messages(messages):
    """Send one FCM notification per device and return Expo-compatible results.

    Keeping the small result shape lets the existing queue, retry and device
    invalidation behaviour remain unchanged while the transport becomes FCM.
    """
    messaging, app = _firebase()
    results = []
    for item in messages:
        try:
            android = messaging.AndroidConfig(
                priority="high" if item["priority"] == "high" else "normal",
                ttl=timedelta(seconds=int(item["ttl"])),
                notification=messaging.AndroidNotification(
                    channel_id="pulse_updates",
                    sound="default" if item.get("sound") else None,
                ),
            )
            message = messaging.Message(
                token=item["to"],
                notification=messaging.Notification(title=item["title"], body=item["body"]),
                data={str(key): str(value) for key, value in item["data"].items()},
                android=android,
            )
            messaging.send(message, app=app)
            results.append({"status": "ok"})
        except Exception as exc:
            name = type(exc).__name__
            if name == "UnregisteredError":
                results.append({"status": "error", "details": {"error": "DeviceNotRegistered"}})
            elif name in ("UnavailableError", "QuotaExceededError", "InternalError"):
                results.append({"status": "error", "details": {"error": "MessageRateExceeded"}})
            else:
                results.append({"status": "error", "message": str(exc)})
    return results


def get_receipts(ids):
    """FCM returns invalid-device errors during send; it has no Expo receipts."""
    return {}


# ------------------------------------------------------------------ queue
def submit(kind, delay=0.0, attempt=0, **payload):
    ensure_started()
    global _pending
    with _cv:
        _jobs.append({"run_at": time.time() + delay, "kind": kind, "attempt": attempt, **payload})
        _pending += 1
        _cv.notify_all()


def drain(timeout=10.0):
    """Block until every queued job (including delayed retries) has run. Used by tests."""
    end = time.time() + timeout
    with _cv:
        while _pending > 0:
            left = end - time.time()
            if left <= 0:
                return False
            _cv.wait(left)
    return True


def ensure_started():
    global _thread
    with _start_lock:
        if _thread is not None and _thread.is_alive():
            return
        _thread = threading.Thread(target=_loop, name="api-push-worker", daemon=True)
        _thread.start()
    _requeue_pending()


def _requeue_pending():
    """After a restart, retry pushes that were created but never delivered (last 2 hours)."""
    try:
        from .common import later
        with connect() as c:
            rows = c.execute("SELECT id FROM notifications WHERE push_status = 'pending' AND created_at >= ?",
                             (later(hours=-2),)).fetchall()
        for r in rows:
            submit("push", nid=r["id"])
    except Exception:
        log.exception("could not requeue pending pushes")


def _loop():
    global _pending
    next_receipts = time.time() + RECEIPT_INTERVAL
    while True:
        job = None
        with _cv:
            now = time.time()
            due = [j for j in _jobs if j["run_at"] <= now]
            if due:
                job = min(due, key=lambda j: j["run_at"])
                _jobs.remove(job)
            else:
                nxt = min([j["run_at"] for j in _jobs] + [next_receipts])
                _cv.wait(timeout=max(0.05, min(nxt - now, 30)))
        if job:
            try:
                _handle(job)
            except Exception:
                log.exception("push job %s failed", job.get("kind"))
            finally:
                with _cv:
                    _pending -= 1
                    _cv.notify_all()
        if time.time() >= next_receipts:
            next_receipts = time.time() + RECEIPT_INTERVAL
            try:
                check_receipts()
            except Exception:
                log.exception("receipt check failed")


def _handle(job):
    from . import notifier
    if job["kind"] == "tap":
        nid = notifier.process_tap(job["code"], job["user_id"], job.get("log_id"))
        if nid:
            _deliver(nid, None, 0)
        from services import sms
        sms.on_tap(job["code"], job["user_id"], job.get("log_id"))
    elif job["kind"] == "notify":
        notifier.notify_users(job["user_ids"], job["category"], job["title"], job["body"], job.get("dedupe_key"))
    elif job["kind"] == "sms":
        from services import sms
        sms.deliver_pending()
    elif job["kind"] == "push":
        _deliver(job["nid"], job.get("tokens"), job["attempt"])


# ------------------------------------------------------------------ delivery
def _mark(nid, status, bump=False):
    with connect(write=True) as c:
        c.execute("UPDATE notifications SET push_status = ?, push_attempts = push_attempts + ? WHERE id = ?",
                  (status, 1 if bump else 0, nid))


def _retry(nid, tokens, attempt, reason):
    if attempt >= len(RETRY_DELAYS):
        log.warning("giving up on notification %s: %s", nid, reason)
        _mark(nid, "failed", bump=True)
        return
    with connect(write=True) as c:
        c.execute("UPDATE notifications SET push_attempts = push_attempts + 1 WHERE id = ?", (nid,))
    submit("push", delay=RETRY_DELAYS[attempt], attempt=attempt + 1, nid=nid, tokens=tokens)


def _deliver(nid, only_tokens, attempt):
    with connect() as c:
        n = c.execute("SELECT * FROM notifications WHERE id = ?", (nid,)).fetchone()
        if n is None or n["push_status"] in ("sent", "skipped", "failed"):
            return
        prefs = c.execute("SELECT * FROM notification_prefs WHERE user_id = ?", (n["user_id"],)).fetchone()
        devices = [r["token"] for r in c.execute(
            "SELECT token FROM push_devices WHERE user_id = ? AND disabled_at IS NULL", (n["user_id"],))]

    def pref(key):
        return True if prefs is None else bool(prefs[key])

    allowed = {"attendance": pref("attendance_alerts"), "system": pref("announcements"),
               "emergency": True}[n["category"]]  # safety notices ignore optional preferences
    tokens = [t for t in devices if only_tokens is None or t in only_tokens]
    if not push_enabled() or not allowed or not tokens:
        _mark(nid, "skipped")
        return

    messages = []
    for tok in tokens:
        m = {"to": tok, "title": n["title"], "body": n["body"], "channelId": n["category"],
             "data": {"notificationId": nid, "category": n["category"]},
             "priority": "high" if n["category"] != "system" else "default",
             "ttl": 3600 if n["category"] == "attendance" else 86400}
        if pref("sound"):
            m["sound"] = "default"
        messages.append(m)

    try:
        tickets = send_messages(messages)
    except Transient as e:
        _retry(nid, tokens, attempt, str(e))
        return
    except Exception:
        log.exception("push send failed permanently for notification %s", nid)
        _mark(nid, "failed", bump=True)
        return

    ok, retry_tokens = 0, []
    with connect(write=True) as c:
        for tok, t in zip(tokens, tickets):
            if t.get("status") == "ok":
                ok += 1
                if t.get("id"):
                    c.execute("INSERT OR IGNORE INTO push_tickets (ticket_id, token, notification_id, created_at)"
                              " VALUES (?, ?, ?, ?)", (t["id"], tok, nid, now_text()))
                continue
            err = (t.get("details") or {}).get("error")
            if err == "DeviceNotRegistered":
                c.execute("UPDATE push_devices SET disabled_at = ? WHERE token = ?", (now_text(), tok))
            elif err == "MessageRateExceeded":
                retry_tokens.append(tok)
            else:
                log.warning("push ticket error for notification %s: %s", nid, t.get("message") or err)
    if retry_tokens:
        _retry(nid, retry_tokens, attempt, "MessageRateExceeded")
    else:
        _mark(nid, "sent" if ok else "failed", bump=True)


def check_receipts():
    """Second chance to catch DeviceNotRegistered, which Expo reports in receipts."""
    from .common import later
    with connect() as c:
        rows = c.execute("SELECT ticket_id, token FROM push_tickets WHERE checked_at IS NULL AND created_at <= ?"
                         " LIMIT 500", (later(minutes=-RECEIPT_DELAY_MIN),)).fetchall()
    if not rows:
        return
    receipts = get_receipts([r["ticket_id"] for r in rows])
    with connect(write=True) as c:
        for r in rows:
            rec = receipts.get(r["ticket_id"])
            if rec is None:
                continue
            if rec.get("status") == "error" and (rec.get("details") or {}).get("error") == "DeviceNotRegistered":
                c.execute("UPDATE push_devices SET disabled_at = ? WHERE token = ?", (now_text(), r["token"]))
            c.execute("UPDATE push_tickets SET checked_at = ? WHERE ticket_id = ?", (now_text(), r["ticket_id"]))
        c.execute("DELETE FROM push_tickets WHERE created_at < ?", (later(days=-2),))
