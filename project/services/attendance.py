"""Attendance policy and the daily status derived from taps.

The tap state machine in `database.record_tap()` decides IN/OUT. This module
only *reads* the logs it produced and classifies each school day as
present, late, absent, excused, and so on. Nothing here runs on the ESP32's
request path except `late_minutes()`, which is pure arithmetic.
"""
from datetime import date, datetime, time, timedelta

import database as db

FMT = db.FMT

DEFAULTS = {
    "school_start": "07:30",
    "late_after_minutes": "15",
    "cutoff": "18:00",
    "school_days": "1,2,3,4,5",
    "visitor_limit_hours": "4",
    "notify_absences": "1",
    "sms_events": "in,out,absent",
}

# The day statuses the API reports, in display order.
DAY_STATUSES = ("present", "late", "absent", "excused", "not_yet", "upcoming", "holiday", "no_class", "no_school")


# ------------------------------------------------------------------ settings
def get_setting(c, key):
    row = c.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else DEFAULTS.get(key)


def set_setting(c, key, value):
    c.execute("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
              (key, str(value)))


def _parse_hhmm(text, fallback):
    try:
        return datetime.strptime(text, "%H:%M").time()
    except (TypeError, ValueError):
        return datetime.strptime(fallback, "%H:%M").time()


def policy(c):
    """The attendance policy as typed values."""
    def num(key, cast):
        try:
            return cast(get_setting(c, key))
        except (TypeError, ValueError):
            return cast(DEFAULTS[key])

    days = set()
    for part in (get_setting(c, "school_days") or "").split(","):
        if part.strip().isdigit() and 1 <= int(part) <= 7:
            days.add(int(part))
    return {
        "school_start": _parse_hhmm(get_setting(c, "school_start"), DEFAULTS["school_start"]),
        "late_after_minutes": max(0, num("late_after_minutes", int)),
        "cutoff": _parse_hhmm(get_setting(c, "cutoff"), DEFAULTS["cutoff"]),
        "school_days": days or {1, 2, 3, 4, 5},
        "visitor_limit_hours": max(0.25, num("visitor_limit_hours", float)),
        "notify_absences": get_setting(c, "notify_absences") == "1",
        "sms_events": {e.strip() for e in (get_setting(c, "sms_events") or "").split(",") if e.strip()},
    }


def policy_json(pol):
    return {
        "school_start": pol["school_start"].strftime("%H:%M"),
        "late_after_minutes": pol["late_after_minutes"],
        "cutoff": pol["cutoff"].strftime("%H:%M"),
        "school_days": sorted(pol["school_days"]),
        "visitor_limit_hours": pol["visitor_limit_hours"],
    }


# ------------------------------------------------------------------ classification
def late_minutes(time_in, pol):
    """Minutes after the school start, or 0 when inside the grace period."""
    start = datetime.combine(time_in.date(), pol["school_start"])
    minutes = int((time_in.replace(tzinfo=None) - start).total_seconds() // 60)
    return minutes if minutes > pol["late_after_minutes"] else 0


def day_kind(c, day, pol):
    """`school`, `holiday`, `no_class` or `no_school` (a weekend)."""
    row = c.execute("SELECT kind FROM school_calendar WHERE date = ?", (day.isoformat(),)).fetchone()
    if row and row["kind"] in ("holiday", "no_class"):
        return row["kind"]
    if row and row["kind"] == "special":
        return "school"
    return "school" if day.isoweekday() in pol["school_days"] else "no_school"


def classify(day, kind, first_in, excused, pol, now):
    """Returns (day_status, late_minutes) for one student-day."""
    if first_in is not None:
        late = late_minutes(first_in, pol)
        return ("late" if late else "present"), late
    if kind != "school":
        return kind, 0
    if excused:
        return "excused", 0
    today = now.date()
    if day > today:
        return "upcoming", 0
    if day == today and now.time() < pol["cutoff"]:
        return "not_yet", 0
    return "absent", 0


def _parse(text):
    return datetime.strptime(text, FMT) if text else None


def student_calendar(c, user_id, start, end, now=None):
    """Every day in [start, end] for one student, with its status."""
    now = (now or db.school_now()).replace(tzinfo=None)
    pol = policy(c)
    lo, hi = f"{start} 00:00:00", f"{end + timedelta(days=1)} 00:00:00"
    logs = c.execute("""SELECT time_in, time_out, flag FROM logs WHERE user_id = ? AND time_in >= ? AND time_in < ?
                        ORDER BY time_in""", (user_id, lo, hi)).fetchall()
    by_day = {}
    for r in logs:
        by_day.setdefault(r["time_in"][:10], []).append(r)
    excused = {r["date"] for r in c.execute(
        "SELECT date FROM excuse_requests WHERE user_id = ? AND status = 'approved' AND date BETWEEN ? AND ?",
        (user_id, start.isoformat(), end.isoformat()))}
    out = []
    day = start
    while day <= end:
        key = day.isoformat()
        rows = by_day.get(key, [])
        first_in = _parse(rows[0]["time_in"]) if rows else None
        status, late = classify(day, day_kind(c, day, pol), first_in, key in excused, pol, now)
        out.append({"date": key, "day_status": status, "late_minutes": late,
                    "time_in": rows[0]["time_in"] if rows else None,
                    "time_out": rows[-1]["time_out"] if rows else None,
                    "missing_time_out": any(r["flag"] == "MISSING_TIME_OUT" for r in rows)})
        day += timedelta(days=1)
    return out


def summarize(days):
    counts = {s: 0 for s in ("present", "late", "absent", "excused")}
    for d in days:
        if d["day_status"] in counts:
            counts[d["day_status"]] += 1
    school_days = sum(counts.values())
    attended = counts["present"] + counts["late"]
    counts["school_days"] = school_days
    counts["rate"] = round(100.0 * attended / school_days, 1) if school_days else None
    return counts


# ------------------------------------------------------------------ reports
def _students(c, section_id=None):
    sql = """SELECT u.id, u.name, p.student_number, p.section_id, s.name AS section
             FROM users u LEFT JOIN student_profiles p ON p.user_id = u.id
             LEFT JOIN sections s ON s.id = p.section_id
             WHERE u.role = 'student' AND u.archived = 0"""
    args = []
    if section_id:
        sql += " AND p.section_id = ?"
        args.append(section_id)
    return c.execute(sql + " ORDER BY u.name", args).fetchall()


def daily_report(c, day, section_id=None, now=None):
    """One row per student for [day], plus totals."""
    rows = []
    for s in _students(c, section_id):
        d = student_calendar(c, s["id"], day, day, now)[0]
        rows.append({"user_id": s["id"], "name": s["name"], "student_number": s["student_number"],
                     "section": s["section"], **d})
    totals = {k: sum(1 for r in rows if r["day_status"] == k) for k in DAY_STATUSES}
    totals["students"] = len(rows)
    return {"date": day.isoformat(), "section_id": section_id, "rows": rows, "totals": totals}


def monthly_report(c, month_start, section_id=None, now=None):
    nxt = (month_start.replace(day=28) + timedelta(days=4)).replace(day=1)
    end = nxt - timedelta(days=1)
    rows = []
    for s in _students(c, section_id):
        days = student_calendar(c, s["id"], month_start, end, now)
        rows.append({"user_id": s["id"], "name": s["name"], "student_number": s["student_number"],
                     "section": s["section"], **summarize(days),
                     "late_minutes_total": sum(d["late_minutes"] for d in days)})
    return {"month": month_start.strftime("%Y-%m"), "section_id": section_id, "rows": rows}


# ------------------------------------------------------------------ end of day
def close_day(c, day):
    """Flags every log of [day] still open as MISSING_TIME_OUT.

    Returns the affected (user_id, log_id) pairs. Run inside a write
    transaction. The tap state machine already does this lazily on the next
    tap; doing it at the cutoff makes reports correct the same evening.
    """
    lo, hi = f"{day} 00:00:00", f"{day + timedelta(days=1)} 00:00:00"
    rows = c.execute("""SELECT id, user_id FROM logs WHERE time_out IS NULL
                        AND (flag IS NULL OR flag = 'OVERSTAY') AND time_in >= ? AND time_in < ?""",
                     (lo, hi)).fetchall()
    for r in rows:
        c.execute("UPDATE logs SET flag = 'MISSING_TIME_OUT' WHERE id = ?", (r["id"],))
    return [(r["user_id"], r["id"]) for r in rows]


def absentees(c, day, now=None):
    """Active students who were absent on [day] (a school day after its cutoff)."""
    out = []
    for s in _students(c):
        d = student_calendar(c, s["id"], day, day, now)[0]
        if d["day_status"] == "absent":
            out.append(s["id"])
    return out


def is_school_day(c, day):
    return day_kind(c, day, policy(c)) == "school"


def to_date(text):
    return date.fromisoformat(text)


def combine(day, t):
    return datetime.combine(day, t if isinstance(t, time) else _parse_hhmm(t, "00:00"))
