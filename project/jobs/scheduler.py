"""End-of-day close.

Once a minute the scheduler checks whether today's cutoff has passed. For
every school day not yet closed (up to a week back, so a PC that was off
over the weekend catches up) it:

  * flags logs still open as MISSING_TIME_OUT and tells those students,
  * finds the students who never tapped and, when enabled, tells them and
    their guardians they were marked absent.

`settings.last_close_date` remembers the last day closed, so a restart never
closes a day twice.
"""
import logging
import threading
from datetime import date, timedelta

import config
import database as db
from api.common import connect
from services import attendance

log = logging.getLogger("jobs")
INTERVAL_SECONDS = 60
CATCH_UP_DAYS = 7

_thread = None
_lock = threading.Lock()


def close_day(day, now=None):
    """Closes [day]. Returns {"missing_time_out": [...], "absent": [...]}. Safe to repeat."""
    from api import notifier
    from services import sms

    with connect(write=True) as c:
        open_logs = attendance.close_day(c, day)
        pol = attendance.policy(c)
        school_day = attendance.day_kind(c, day, pol) == "school"
    for user_id, log_id in open_logs:
        notifier.notify_users(
            [user_id], "attendance", "Missing Time Out",
            f"You did not time out on {day.strftime('%b %d')}. Your attendance for that day is marked "
            "incomplete. Please see the school office if this is wrong.",
            f"log:{log_id}:MISSING")

    absent = []
    if school_day:
        with connect() as c:
            absent = attendance.absentees(c, day, now)
        if absent and pol["notify_absences"]:
            for uid in absent:
                notifier.notify_users(
                    [uid], "attendance", "Absence Recorded",
                    f"No time in was recorded for you on {day.strftime('%b %d')}. If you were excused, "
                    "submit an excuse letter in the app.",
                    f"absent:{day}")
            sms.on_absent(absent, day)
    return {"missing_time_out": [u for u, _ in open_logs], "absent": absent}


def run_due(now=None):
    """Closes every day whose cutoff has passed and that is not closed yet."""
    now = (now or db.school_now()).replace(tzinfo=None)
    with connect() as c:
        pol = attendance.policy(c)
        last = attendance.get_setting(c, "last_close_date")
    newest = now.date() if now.time() >= pol["cutoff"] else now.date() - timedelta(days=1)
    if not last:
        # First run on this database: start from here rather than sending
        # absence notices for days before the system was in use.
        with connect(write=True) as c:
            attendance.set_setting(c, "last_close_date", newest.isoformat())
        return []
    start = date.fromisoformat(last) + timedelta(days=1)
    start = max(start, newest - timedelta(days=CATCH_UP_DAYS - 1))
    closed = []
    day = start
    while day <= newest:
        close_day(day, now)
        with connect(write=True) as c:
            attendance.set_setting(c, "last_close_date", day.isoformat())
        closed.append(day.isoformat())
        day += timedelta(days=1)
    return closed


def _loop():
    stop = threading.Event()
    while not stop.wait(INTERVAL_SECONDS):
        try:
            done = run_due()
            if done:
                log.info("closed attendance for %s", ", ".join(done))
        except Exception:
            log.exception("end-of-day job failed")


def ensure_started():
    global _thread
    if not config.env_flag("JOBS_ENABLED", True):
        return
    with _lock:
        if _thread is not None and _thread.is_alive():
            return
        _thread = threading.Thread(target=_loop, name="attendance-jobs", daemon=True)
        _thread.start()
