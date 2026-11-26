"""Background worker for Firebase Cloud Messaging delivery.

Nothing here runs on the RFID ``/tap`` request thread except a non-blocking
queue append. A slow Firebase call or delivery error cannot delay or change
the ESP32 response.

The Firebase service-account JSON file is never stored in this repository.
Set ``FIREBASE_SERVICE_ACCOUNT_PATH`` to its absolute local/server path.
"""
import logging
import os
import threading
import time
from datetime import timedelta

from .common import connect, now_text

log = logging.getLogger("api.push")

RETRY_DELAYS = [5, 30, 120, 600]  # seconds between delivery attempts

_jobs = []
_cv = threading.Condition()
_pending = 0
_thread = None
_start_lock = threading.Lock()
_firebase_lock = threading.Lock()
_firebase_app = None
_firebase_messaging = None


class Transient(Exception):
    """Network/rate-limit/server problem that is worth retrying later."""


def _service_account_path():
    value = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
    return os.path.abspath(value) if value else None


def push_enabled():
    """Whether an operator has deliberately disabled device push delivery."""
    return os.environ.get("PUSH_ENABLED", "1") != "0"


def _firebase():
    """Lazily initialise the Firebase Admin SDK once per server process."""
    global _firebase_app, _firebase_messaging
    with _firebase_lock:
        if _firebase_messaging is not None:
            return _firebase_messaging, _firebase_app

        path = _service_account_path()
        if not path or not os.path.isfile(path):
            raise RuntimeError(
                "FIREBASE_SERVICE_ACCOUNT_PATH is not configured; notifications "
                "remain in the inbox but cannot be sent to devices"
            )
        try:
            import firebase_admin
            from firebase_admin import credentials, messaging
        except ImportError as exc:
            raise RuntimeError(
                "firebase-admin is not installed; run pip install -r requirements.txt"
            ) from exc

        _firebase_app = firebase_admin.initialize_app(credentials.Certificate(path))
        _firebase_messaging = messaging
        return _firebase_messaging, _firebase_app


def send_messages(messages):
    """Send messages through FCM and return one result dictionary per target.

    The small result shape keeps retry and invalid-device handling explicit and
    easy to test without ever needing Firebase credentials in automated tests.
    """
    messaging, app = _firebase()
    results = []
    for item in messages:
        try:
            ttl = int(item.get("ttl", 86400))
            android = messaging.AndroidConfig(
                priority="high" if item.get("priority") == "high" else "normal",
                ttl=timedelta(seconds=ttl),
                notification=messaging.AndroidNotification(
                    channel_id=item.get("channel_id", "pulse_updates"),
                    sound="default" if item.get("sound") else None,
                ),
            )
            message = messaging.Message(
                token=item["token"],
                notification=messaging.Notification(
                    title=item["title"], body=item["body"],
                ),
                data={str(k): str(v) for k, v in item["data"].items()},
                android=android,
            )
            messaging.send(message, app=app)
            results.append({"status": "ok"})
        except Exception as exc:  # Firebase exposes transport errors by type.
            results.append({
                "status": "error",
                "kind": type(exc).__name__,
                "code": str(getattr(exc, "code", "")),
                "message": str(exc),
            })
    return results


# ------------------------------------------------------------------ queue
def submit(kind, delay=0.0, attempt=0, **payload):
    ensure_started()
    global _pending
    with _cv:
        _jobs.append({"run_at": time.time() + delay, "kind": kind, "attempt": attempt, **payload})
        _pending += 1
        _cv.notify_all()


def drain(timeout=10.0):
    """Block until every queued job (including delayed retries) has run."""
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
    """Retry notifications created in the two hours before a server restart."""
    try:
        from .common import later
        with connect() as c:
            rows = c.execute(
                "SELECT id FROM notifications WHERE push_status = 'pending' AND created_at >= ?",
                (later(hours=-2),),
            ).fetchall()
        for row in rows:
            submit("push", nid=row["id"])
    except Exception:
        log.exception("could not requeue pending pushes")


def _loop():
    global _pending
    while True:
        job = None
        with _cv:
            now = time.time()
            due = [job for job in _jobs if job["run_at"] <= now]
            if due:
                job = min(due, key=lambda value: value["run_at"])
                _jobs.remove(job)
            else:
                next_run = min(job["run_at"] for job in _jobs) if _jobs else None
                _cv.wait(timeout=30 if next_run is None else max(0.05, min(next_run - now, 30)))
        if job is None:
            continue
        try:
            _handle(job)
        except Exception:
            log.exception("push job %s failed", job.get("kind"))
        finally:
            with _cv:
                _pending -= 1
                _cv.notify_all()


def _handle(job):
    from . import notifier
    if job["kind"] == "tap":
        notification_id = notifier.process_tap(
            job["code"], job["user_id"], job.get("log_id")
        )
        if notification_id:
            _deliver(notification_id, None, 0)
    elif job["kind"] == "push":
        _deliver(job["nid"], job.get("tokens"), job["attempt"])


# ------------------------------------------------------------------ delivery
def _mark(notification_id, status, bump=False):
    with connect(write=True) as c:
        c.execute(
            "UPDATE notifications SET push_status = ?, push_attempts = push_attempts + ? WHERE id = ?",
            (status, 1 if bump else 0, notification_id),
        )


def _retry(notification_id, tokens, attempt, reason):
    if attempt >= len(RETRY_DELAYS):
        log.warning("giving up on notification %s: %s", notification_id, reason)
        _mark(notification_id, "failed", bump=True)
        return
    with connect(write=True) as c:
        c.execute("UPDATE notifications SET push_attempts = push_attempts + 1 WHERE id = ?", (notification_id,))
    submit(
        "push",
        delay=RETRY_DELAYS[attempt],
        attempt=attempt + 1,
        nid=notification_id,
        tokens=tokens,
    )


def _is_unregistered(result):
    kind = str(result.get("kind", "")).lower()
    code = str(result.get("code", "")).lower()
    # Also recognise the old shape so existing test doubles remain useful.
    details = result.get("details") or {}
    old_error = str(details.get("error", "")).lower()
    return (
        kind == "unregisterederror"
        or code in {"not_found", "registration-token-not-registered"}
        or old_error == "devicenotregistered"
    )


def _is_transient(result):
    kind = str(result.get("kind", "")).lower()
    code = str(result.get("code", "")).lower()
    return kind in {"unavailableerror", "quotaexceedederror", "internalerror"} or code in {
        "unavailable", "resource_exhausted", "internal", "deadline_exceeded",
    }


def _deliver(notification_id, only_tokens, attempt):
    with connect() as c:
        notification = c.execute(
            "SELECT * FROM notifications WHERE id = ?", (notification_id,)
        ).fetchone()
        if notification is None or notification["push_status"] in ("sent", "skipped", "failed"):
            return
        prefs = c.execute(
            "SELECT * FROM notification_prefs WHERE user_id = ?", (notification["user_id"],)
        ).fetchone()
        devices = [
            row["token"]
            for row in c.execute(
                "SELECT token FROM push_devices WHERE user_id = ? AND disabled_at IS NULL "
                "AND token NOT LIKE 'ExponentPushToken[%]%' AND token NOT LIKE 'ExpoPushToken[%]%'",
                (notification["user_id"],),
            )
        ]

    def preference(key):
        return True if prefs is None else bool(prefs[key])

    allowed = {
        "attendance": preference("attendance_alerts"),
        "system": preference("announcements"),
        "emergency": True,
    }[notification["category"]]
    tokens = [token for token in devices if only_tokens is None or token in only_tokens]
    if not push_enabled() or not allowed or not tokens:
        _mark(notification_id, "skipped")
        return

    messages = [
        {
            "token": token,
            "title": notification["title"],
            "body": notification["body"],
            "channel_id": "pulse_updates",
            "data": {"notificationId": notification_id, "category": notification["category"]},
            "priority": "high" if notification["category"] != "system" else "normal",
            "ttl": 3600 if notification["category"] == "attendance" else 86400,
            "sound": preference("sound"),
        }
        for token in tokens
    ]

    try:
        results = send_messages(messages)
    except Transient as exc:
        _retry(notification_id, tokens, attempt, str(exc))
        return
    except Exception:
        log.exception("push send failed permanently for notification %s", notification_id)
        _mark(notification_id, "failed", bump=True)
        return

    ok, retry_tokens = 0, []
    with connect(write=True) as c:
        for token, result in zip(tokens, results):
            if result.get("status") == "ok":
                ok += 1
            elif _is_unregistered(result):
                c.execute("UPDATE push_devices SET disabled_at = ? WHERE token = ?", (now_text(), token))
            elif _is_transient(result):
                retry_tokens.append(token)
            else:
                log.warning(
                    "FCM delivery error for notification %s: %s",
                    notification_id,
                    result.get("message") or result.get("code") or result.get("kind"),
                )
    if retry_tokens:
        _retry(notification_id, retry_tokens, attempt, "FCM temporarily unavailable")
    else:
        _mark(notification_id, "sent" if ok else "failed", bump=True)
