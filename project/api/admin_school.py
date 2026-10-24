"""Admin API for the school: structure, campus content, readers, reports and reviews."""
import csv
import io
import re
import sqlite3
from datetime import date, datetime, timedelta

from flask import Response, g, jsonify, request

import database as db
from services import attendance, cards, devices
from . import notifier
from .admin import save_profile
from .common import (ApiError, PHONE, STAFF_ROLES, STUDENT_NO, audit, bp, connect, json_body, now_dt, now_text,
                     require_staff, text_field)
from .crud import RESOURCES, Field as F, now_stamp, resource
from .schema import purge_user_data

TEACH = ("registrar", "teacher")
WEEKDAYS = {1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday", 7: "Sunday"}


def _staff_id():
    return (getattr(g, "staff", None) or {}).get("id")


# ================================================================== table resources
def _one_active_term(c, action, item_id, values):
    if values.get("active") == 1:
        c.execute("UPDATE terms SET active = 0 WHERE id != ?", (item_id,))


def _check_dates(values, _id):
    if values.get("start_date") and values.get("end_date") and values["end_date"] < values["start_date"]:
        raise ApiError(400, "invalid_field", "'end_date' must be after 'start_date'.")


def _check_times(values, _id):
    if values.get("start_time") and values.get("end_time") and values["end_time"] <= values["start_time"]:
        raise ApiError(400, "invalid_field", "'end_time' must be after 'start_time'.")


def _touch(values, _id):
    values["updated_at"] = now_text()


def _notify_assignment(c, action, item_id, values):
    if action != "create" or not values.get("section_id"):
        return
    students = notifier.section_students(c, values["section_id"])
    due = values.get("due_at", "")[:16]
    title, course = values.get("title", ""), values.get("course") or "your class"
    # Delivered after this transaction commits, by the worker thread.
    from . import push
    push.submit("notify", user_ids=students, category="system", title="New Assignment",
                body=f"{title} for {course}, due {due}.", dedupe_key=f"task:{item_id}")


resource("terms", "terms", [
    F("name", required=True, max_len=60),
    F("start_date", "date", required=True),
    F("end_date", "date", required=True),
    F("active", "bool", default=False, help="Only one term is active."),
], label="Terms", read_roles=STAFF_ROLES, order_by="start_date DESC", before_save=_check_dates,
    after_change=_one_active_term)

resource("sections", "sections", [
    F("name", required=True, max_len=60, help="For example BSIT - 2A"),
    F("course", max_len=60),
    F("year_level", "int", min=1, max=6),
    F("term_id", "ref", ref="terms", label="Term"),
    F("adviser_staff_id", "ref", ref="staff", label="Adviser"),
], label="Sections", read_roles=STAFF_ROLES, order_by="name", search=("name", "course"), filters=("term_id",),
    defaults={"created_at": now_stamp})

resource("subjects", "subjects", [
    F("code", required=True, max_len=20),
    F("title", required=True, max_len=100),
    F("units", "float", min=0, max=10),
], label="Subjects", read_roles=STAFF_ROLES, order_by="code", search=("code", "title"))

resource("schedules", "class_schedules", [
    F("section_id", "ref", ref="sections", required=True, label="Section"),
    F("subject_id", "ref", ref="subjects", required=True, label="Subject"),
    F("teacher_staff_id", "ref", ref="staff", label="Teacher"),
    F("room_id", "ref", ref="rooms", label="Room"),
    F("weekday", "choice", required=True, choices=[1, 2, 3, 4, 5, 6, 7], help="1 = Monday … 7 = Sunday"),
    F("start_time", "time", required=True),
    F("end_time", "time", required=True),
    F("kind", "choice", choices=["class", "exam", "event"], default="class"),
    F("note", max_len=200, list_column=False),
], label="Class schedules", read_roles=STAFF_ROLES, order_by="section_id, weekday, start_time",
    filters=("section_id", "teacher_staff_id", "weekday"), before_save=_check_times)

resource("calendar", "school_calendar", [
    F("date", "date", required=True),
    F("kind", "choice", required=True, choices=["holiday", "no_class", "special"],
      help="special = a school day on a weekend"),
    F("note", max_len=120),
], label="School calendar", read_roles=STAFF_ROLES, pk="rowid", order_by="date DESC")

resource("rooms", "rooms", [
    F("code", required=True, max_len=20),
    F("name", required=True, max_len=80),
    F("building", required=True, max_len=80),
    F("floor", "int", min=0, max=50, default=1),
    F("capacity", "int", min=0, max=5000, default=0),
    F("services", "list", help="Comma-separated, e.g. Projector, Aircon"),
    F("notes", max_len=200, list_column=False),
], label="Rooms", read_roles=STAFF_ROLES, order_by="building, code", search=("code", "name", "building"),
    group="Campus")

resource("map_places", "map_places", [
    F("name", required=True, max_len=80),
    F("kind", "choice", choices=["building", "facility", "gate", "field", "parking"], default="building"),
    F("x", "float", required=True, min=0, max=1000, help="Map units, 0–1000"),
    F("y", "float", required=True, min=0, max=1000),
    F("width", "float", required=True, min=1, max=1000),
    F("height", "float", required=True, min=1, max=1000),
    F("room_id", "ref", ref="rooms", label="Room"),
    F("description", max_len=200, list_column=False),
], label="Map places", read_roles=STAFF_ROLES, order_by="name", group="Campus")

resource("directory", "directory_entries", [
    F("name", required=True, max_len=100),
    F("role", required=True, max_len=80),
    F("department", required=True, max_len=80),
    F("email", max_len=120),
    F("phone", max_len=25),
    F("office", max_len=80),
    F("sort_order", "int", default=0),
    F("active", "bool", default=True),
], label="Directory", read_roles=STAFF_ROLES, order_by="sort_order, name", search=("name", "role", "department"),
    soft_delete=True, group="Campus")

resource("library_items", "library_items", [
    F("title", required=True, max_len=150),
    F("author", required=True, max_len=100),
    F("shelf", required=True, max_len=40),
    F("copies", "int", min=0, max=500, default=1),
    F("featured", "bool", default=False),
], label="Library", read_roles=STAFF_ROLES, order_by="title", search=("title", "author"), group="Campus")

resource("lost_found", "lost_found_items", [
    F("kind", "choice", choices=["lost", "found"], default="found"),
    F("name", required=True, max_len=100),
    F("category", required=True, max_len=40),
    F("location", required=True, max_len=100),
    F("description", max_len=300, list_column=False),
    F("status", "choice", choices=["open", "claim_requested", "claimed", "closed"], default="open"),
], label="Lost and found", read_roles=STAFF_ROLES, write_roles=("registrar", "guard"),
    order_by="reported_at DESC", search=("name", "location"), filters=("status", "kind"),
    defaults={"reported_at": now_stamp, "updated_at": now_stamp}, before_save=_touch, group="Campus")

resource("faq", "faq_items", [
    F("question", required=True, max_len=200),
    F("answer", required=True, max_len=1000, list_column=False),
    F("sort_order", "int", default=0),
    F("active", "bool", default=True),
], label="FAQ", read_roles=STAFF_ROLES, order_by="sort_order, id", search=("question", "answer"),
    soft_delete=True, group="Support")

resource("assistance", "assistance_paths", [
    F("title", required=True, max_len=80),
    F("description", required=True, max_len=300),
    F("icon", "choice", choices=["help", "id", "calendar", "money", "health", "security", "library", "it"],
      default="help"),
    F("sort_order", "int", default=0),
    F("active", "bool", default=True),
], label="Assistance paths", read_roles=STAFF_ROLES, order_by="sort_order, id", soft_delete=True, group="Support")

resource("guardians", "guardians", [
    F("user_id", "ref", ref="students", required=True, label="Student"),
    F("name", required=True, max_len=100),
    F("relation", max_len=40),
    F("phone", required=True, max_len=25),
    F("sms_enabled", "bool", default=True, label="SMS alerts"),
], label="Guardians", order_by="user_id, id", filters=("user_id",), search=("name", "phone"),
    defaults={"created_at": now_stamp}, group="People")

resource("assignments", "tasks", [
    F("section_id", "ref", ref="sections", required=True, label="Section"),
    F("title", required=True, max_len=120),
    F("course", max_len=60),
    F("due_at", "datetime", required=True, help="YYYY-MM-DD HH:MM"),
    F("priority", "choice", choices=["high", "medium", "low"], default="medium"),
], label="Assignments", read_roles=TEACH, write_roles=TEACH, where="section_id IS NOT NULL",
    order_by="due_at DESC", filters=("section_id",),
    defaults={"created_at": now_stamp, "created_by_staff": _staff_id}, after_change=_notify_assignment,
    group="School")


# ================================================================== meta + dashboard
@bp.get("/admin/meta")
@require_staff(*STAFF_ROLES)
def admin_meta():
    with connect() as c:
        pol = attendance.policy_json(attendance.policy(c))
    return jsonify(staff=g.staff, roles=list(STAFF_ROLES), resources=RESOURCES, policy=pol,
                   weekdays=WEEKDAYS)


@bp.get("/admin/dashboard")
@require_staff(*STAFF_ROLES)
def admin_dashboard():
    today = now_dt().date()
    with connect() as c:
        report = attendance.daily_report(c, today)
        devs = [devices.public(d) for d in c.execute("SELECT * FROM devices WHERE active = 1 ORDER BY code")]
        recent = [dict(r) for r in c.execute(
            """SELECT t.id, t.uid, t.name, t.role, t.result_code, t.status, t.action, t.received_at, d.code AS device
               FROM tap_events t LEFT JOIN devices d ON d.id = t.device_id ORDER BY t.id DESC LIMIT 15""")]
        inside = c.execute("""SELECT COUNT(*) FROM logs l JOIN users u ON u.id = l.user_id
                              WHERE l.time_out IS NULL AND (l.flag IS NULL OR l.flag = 'OVERSTAY')
                              AND substr(l.time_in, 1, 10) = ?""", (today.isoformat(),)).fetchone()[0]
        visitors = c.execute("""SELECT COUNT(*) FROM logs l JOIN users u ON u.id = l.user_id
                                WHERE u.role = 'visitor' AND substr(l.time_in, 1, 10) = ?""",
                             (today.isoformat(),)).fetchone()[0]
        pending = {
            "excuses": c.execute("SELECT COUNT(*) FROM excuse_requests WHERE status = 'pending'").fetchone()[0],
            "tickets": c.execute("SELECT COUNT(*) FROM support_tickets WHERE status = 'open'").fetchone()[0],
            "claims": c.execute("SELECT COUNT(*) FROM lost_found_items WHERE status = 'claim_requested'")
                       .fetchone()[0],
            "reservations": c.execute("SELECT COUNT(*) FROM library_reservations WHERE status = 'reserved'")
                             .fetchone()[0],
        }
        flags = c.execute("""SELECT COUNT(*) FROM logs WHERE flag IS NOT NULL
                             AND substr(time_in, 1, 10) >= ?""", ((today - timedelta(days=7)).isoformat(),)
                          ).fetchone()[0]
    return jsonify(date=today.isoformat(), totals=report["totals"], inside_now=inside, visitors_today=visitors,
                   devices=devs, recent_taps=recent, pending=pending, flags_last_7_days=flags)


# ================================================================== readers
@bp.get("/admin/devices")
@require_staff("registrar", "guard")
def admin_devices():
    with connect() as c:
        rows = c.execute("SELECT * FROM devices ORDER BY active DESC, code").fetchall()
    return jsonify(items=[devices.public(r) for r in rows])


def _device_fields(d, partial):
    out = {}
    if "code" in d or not partial:
        code = text_field(d, "code", min_len=2, max_len=20)
        if not re.fullmatch(r"[A-Za-z0-9_-]+", code):
            raise ApiError(400, "invalid_field", "'code' may use letters, digits, - and _ only.")
        out["code"] = code.upper()
    for key, max_len in (("name", 80), ("location", 80)):
        if key in d or (key == "name" and not partial):
            out[key] = text_field(d, key, max_len=max_len, required=key == "name")
    if "mode" in d or not partial:
        mode = d.get("mode", "KIOSK")
        if mode not in ("IN", "OUT", "KIOSK"):
            raise ApiError(400, "invalid_field", "'mode' must be IN, OUT or KIOSK.")
        out["mode"] = mode
    if "active" in d:
        if not isinstance(d["active"], bool):
            raise ApiError(400, "invalid_field", "'active' must be true or false.")
        out["active"] = int(d["active"])
    return out


@bp.post("/admin/devices")
@require_staff("registrar")
def admin_device_create():
    f = _device_fields(json_body(), partial=False)
    key = devices.new_key()
    try:
        with connect(write=True) as c:
            cur = c.execute("""INSERT INTO devices (code, name, location, mode, key_hash, created_at)
                               VALUES (?, ?, ?, ?, ?, ?)""",
                            (f["code"], f["name"], f.get("location"), f["mode"], devices.hash_key(key), now_text()))
            audit(c, "device.create", f["code"])
    except sqlite3.IntegrityError:
        raise ApiError(409, "duplicate_code", "A reader with that code already exists.")
    # The key is shown once. Only its hash is stored.
    return jsonify(id=cur.lastrowid, code=f["code"], device_key=key), 201


@bp.patch("/admin/devices/<int:dev_id>")
@require_staff("registrar")
def admin_device_update(dev_id):
    f = _device_fields(json_body(), partial=True)
    if not f:
        raise ApiError(400, "invalid_body", "Nothing to update.")
    try:
        with connect(write=True) as c:
            n = c.execute(f"UPDATE devices SET {', '.join(k + ' = ?' for k in f)} WHERE id = ?",
                          [*f.values(), dev_id]).rowcount
            if n == 0:
                raise ApiError(404, "not_found", "No such reader.")
            audit(c, "device.update", f"#{dev_id} {sorted(f)}")
    except sqlite3.IntegrityError:
        raise ApiError(409, "duplicate_code", "A reader with that code already exists.")
    return jsonify(success=True)


@bp.post("/admin/devices/<int:dev_id>/rotate-key")
@require_staff("registrar")
def admin_device_rotate(dev_id):
    key = devices.new_key()
    with connect(write=True) as c:
        n = c.execute("UPDATE devices SET key_hash = ? WHERE id = ?", (devices.hash_key(key), dev_id)).rowcount
        if n == 0:
            raise ApiError(404, "not_found", "No such reader.")
        audit(c, "device.rotate_key", f"#{dev_id}")
    return jsonify(device_key=key)


@bp.post("/admin/devices/<int:dev_id>/arm-timeout")
@require_staff("registrar", "guard")
def admin_device_arm(dev_id):
    with connect(write=True) as c:
        if c.execute("SELECT 1 FROM devices WHERE id = ?", (dev_id,)).fetchone() is None:
            raise ApiError(404, "not_found", "No such reader.")
        seconds = devices.arm_timeout(c, dev_id)
    return jsonify(success=True, seconds=seconds)


@bp.get("/admin/taps")
@require_staff("registrar", "guard")
def admin_taps():
    sql = """SELECT t.*, d.code AS device FROM tap_events t LEFT JOIN devices d ON d.id = t.device_id WHERE 1=1"""
    args = []
    if request.args.get("unknown") == "1":
        sql += " AND t.result_code = 'DENY_UNKNOWN'"
    if request.args.get("device_id"):
        sql += " AND t.device_id = ?"
        args.append(request.args["device_id"])
    if request.args.get("date"):
        sql += " AND substr(t.received_at, 1, 10) = ?"
        args.append(request.args["date"])
    limit = min(max(int(request.args.get("limit", 100) or 100), 1), 500)
    with connect() as c:
        rows = c.execute(sql + " ORDER BY t.id DESC LIMIT ?", [*args, limit]).fetchall()
    return jsonify(items=[dict(r) for r in rows])


# ================================================================== cards and students
@bp.get("/admin/cards")
@require_staff("registrar", "guard")
def admin_cards():
    role = request.args.get("role")
    q = (request.args.get("q") or "").strip()[:50]
    sql = """SELECT u.*, p.student_number FROM users u LEFT JOIN student_profiles p ON p.user_id = u.id
             WHERE u.archived = 0"""
    args = []
    if role in ("student", "visitor"):
        sql += " AND u.role = ?"
        args.append(role)
    if q:
        sql += " AND (u.name LIKE ? OR u.rfid_uid LIKE ? OR p.student_number LIKE ?)"
        args += [f"%{q}%"] * 3
    with connect() as c:
        rows = c.execute(sql + " ORDER BY u.id DESC LIMIT 1000", args).fetchall()
    return jsonify(items=[{"id": r["id"], "rfid_uid": r["rfid_uid"], "name": r["name"], "role": r["role"],
                           "student_number": r["student_number"], "time_limit_minutes": r["time_limit_minutes"],
                           "is_expired": bool(r["is_expired"]), "registered_at": r["registered_at"]}
                          for r in rows])


@bp.post("/admin/cards")
@require_staff("registrar", "guard")
def admin_card_create():
    """Registers a card (visitor or student), with the same rules as the desktop admin."""
    d = json_body()
    role = d.get("role")
    if g.staff["role"] == "guard" and role != "visitor":
        raise ApiError(403, "forbidden", "Guards can register visitor cards only.")
    ok, message, user_id = cards.register_card(d.get("uid"), d.get("name"), role, d.get("time_limit_minutes"))
    if not ok:
        raise ApiError(400 if "Missing" in message or "limit" in message else 409, "card_rejected", message)
    with connect(write=True) as c:
        audit(c, "card.register", f"{str(d.get('uid')).upper()} {role}")
    return jsonify(id=user_id, message=message), 201


@bp.delete("/admin/cards/<int:user_id>")
@require_staff("registrar")
def admin_card_delete(user_id):
    with connect() as c:
        row = c.execute("SELECT rfid_uid FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise ApiError(404, "not_found", "No such card.")
    db.delete_user(row["rfid_uid"])
    purge_user_data(user_id)
    with connect(write=True) as c:
        audit(c, "card.delete", f"#{user_id} {row['rfid_uid']}")
    return jsonify(success=True)


@bp.post("/admin/students")
@require_staff("registrar")
def admin_student_create():
    """Registers a student's card and profile in one step."""
    d = json_body()
    uid = text_field(d, "uid", max_len=32)
    name = text_field(d, "name", max_len=100)
    sn = text_field(d, "student_number", min_len=2, max_len=32, pattern=STUDENT_NO)
    phone = text_field(d, "phone", max_len=25, required=False, pattern=PHONE)
    section_id = d.get("section_id")
    with connect() as c:
        if c.execute("SELECT 1 FROM student_profiles WHERE student_number = ?", (sn,)).fetchone():
            raise ApiError(409, "duplicate_student_number", "That student number is already assigned.")
    ok, message, user_id = cards.register_card(uid, name, "student")
    if not ok:
        raise ApiError(409, "card_rejected", message)
    with connect(write=True) as c:
        save_profile(c, user_id, sn, None, phone, section_id if isinstance(section_id, int) else None)
        audit(c, "student.create", f"#{user_id} {sn}")
    return jsonify(id=user_id, user_id=user_id, message=message), 201


@bp.post("/admin/students/import")
@require_staff("registrar")
def admin_students_import():
    """CSV with a header row: uid,name,student_number,section,phone (section and phone optional).

    Each row is applied on its own; the reply lists what was created and why
    any row was skipped, so a partly bad file still imports the good rows.
    """
    text = request.get_data(as_text=True)
    if not text.strip():
        raise ApiError(400, "invalid_body", "Send the CSV text as the request body.")
    reader = csv.DictReader(io.StringIO(text.lstrip("﻿")))
    needed = {"uid", "name", "student_number"}
    if not reader.fieldnames or not needed <= {h.strip().lower() for h in reader.fieldnames}:
        raise ApiError(400, "invalid_csv", "The header must include uid,name,student_number.")
    with connect() as c:
        sections = {r["name"].lower(): r["id"] for r in c.execute("SELECT id, name FROM sections")}
    created, skipped = [], []
    for i, raw in enumerate(reader, start=2):
        row = {(k or "").strip().lower(): (v or "").strip() for k, v in raw.items()}
        try:
            sn = row["student_number"]
            if not re.fullmatch(STUDENT_NO, sn or ""):
                raise ApiError(400, "invalid_field", "bad student number")
            section_id = sections.get(row.get("section", "").lower()) if row.get("section") else None
            if row.get("section") and section_id is None:
                raise ApiError(400, "invalid_field", f"unknown section {row['section']!r}")
            with connect() as c:
                if c.execute("SELECT 1 FROM student_profiles WHERE student_number = ?", (sn,)).fetchone():
                    raise ApiError(409, "duplicate", "student number already assigned")
            ok, message, user_id = cards.register_card(row.get("uid"), row.get("name"), "student")
            if not ok:
                raise ApiError(409, "card_rejected", message)
            with connect(write=True) as c:
                save_profile(c, user_id, sn, row.get("section") or None, row.get("phone") or None, section_id)
            created.append({"line": i, "user_id": user_id, "name": row.get("name")})
        except ApiError as e:
            skipped.append({"line": i, "reason": e.message})
    with connect(write=True) as c:
        audit(c, "student.import", f"{len(created)} created, {len(skipped)} skipped")
    return jsonify(created=created, skipped=skipped)


# ================================================================== attendance logs
@bp.get("/admin/logs")
@require_staff(*STAFF_ROLES)
def admin_logs():
    day = request.args.get("date") or now_dt().date().isoformat()
    q = (request.args.get("q") or "").strip()[:50]
    sql = """SELECT l.id, l.time_in, l.time_out, l.flag, l.expected_out, u.id AS user_id, u.name, u.role,
                    p.student_number, s.name AS section, d.code AS device
             FROM logs l JOIN users u ON u.id = l.user_id
             LEFT JOIN student_profiles p ON p.user_id = u.id LEFT JOIN sections s ON s.id = p.section_id
             LEFT JOIN devices d ON d.id = l.device_id
             WHERE substr(l.time_in, 1, 10) = ?"""
    args = [day]
    if q:
        sql += " AND (u.name LIKE ? OR p.student_number LIKE ?)"
        args += [f"%{q}%"] * 2
    if request.args.get("flag"):
        sql += " AND l.flag = ?"
        args.append(request.args["flag"])
    with connect() as c:
        rows = c.execute(sql + " ORDER BY l.time_in DESC LIMIT 2000", args).fetchall()
    return jsonify(date=day, items=[dict(r) for r in rows])


@bp.patch("/admin/logs/<int:log_id>")
@require_staff("registrar")
def admin_log_correct(log_id):
    """Manual correction: set a missing time out and/or clear a flag. Audited."""
    d = json_body()
    with connect(write=True) as c:
        row = c.execute("SELECT * FROM logs WHERE id = ?", (log_id,)).fetchone()
        if row is None:
            raise ApiError(404, "not_found", "No such attendance record.")
        sets, args = [], []
        if "time_out" in d:
            t = str(d["time_out"] or "")
            if not re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", t):
                raise ApiError(400, "invalid_field", "'time_out' must be HH:MM.")
            out = f"{row['time_in'][:10]} {t}:00"
            if out <= row["time_in"]:
                raise ApiError(400, "invalid_field", "The time out must be after the time in.")
            sets.append("time_out = ?")
            args.append(out)
        if d.get("clear_flag") is True:
            sets.append("flag = NULL")
        if not sets:
            raise ApiError(400, "invalid_body", "Nothing to change.")
        c.execute(f"UPDATE logs SET {', '.join(sets)} WHERE id = ?", [*args, log_id])
        audit(c, "log.correct", f"#{log_id} {d}")
    return jsonify(success=True)


# ================================================================== settings
SETTING_KEYS = {
    "school_start": "time", "cutoff": "time", "late_after_minutes": "int", "visitor_limit_hours": "float",
    "school_days": "days", "notify_absences": "bool", "sms_events": "events",
}


@bp.get("/admin/settings")
@require_staff(*STAFF_ROLES)
def admin_settings():
    with connect() as c:
        out = {k: attendance.get_setting(c, k) for k in SETTING_KEYS}
        out["last_close_date"] = attendance.get_setting(c, "last_close_date")
    return jsonify(settings=out)


@bp.put("/admin/settings")
@require_staff()
def admin_settings_update():
    d = json_body()
    clean = {}
    for key, value in d.items():
        kind = SETTING_KEYS.get(key)
        if kind is None:
            raise ApiError(400, "invalid_field", f"Unknown setting '{key}'.")
        v = str(value).strip()
        ok = {
            "time": lambda: re.fullmatch(r"([01]\d|2[0-3]):[0-5]\d", v),
            "int": lambda: v.isdigit() and int(v) <= 240,
            "float": lambda: re.fullmatch(r"\d+(\.\d+)?", v) and 0.25 <= float(v) <= 24,
            "days": lambda: re.fullmatch(r"[1-7](,[1-7])*", v),
            "bool": lambda: v in ("0", "1", "True", "False", "true", "false"),
            "events": lambda: v == "" or re.fullmatch(r"(in|out|absent)(,(in|out|absent))*", v),
        }[kind]()
        if not ok:
            raise ApiError(400, "invalid_field", f"'{key}' has an invalid value.")
        clean[key] = {"True": "1", "true": "1", "False": "0", "false": "0"}.get(v, v)
    if not clean:
        raise ApiError(400, "invalid_body", "Nothing to update.")
    with connect(write=True) as c:
        for k, v in clean.items():
            attendance.set_setting(c, k, v)
        audit(c, "settings.update", clean)
    return jsonify(success=True)


@bp.post("/admin/jobs/close-day")
@require_staff()
def admin_close_day():
    """Runs the end-of-day close for one date now (it is safe to repeat)."""
    from jobs import scheduler
    d = request.get_json(silent=True) or {}
    try:
        day = date.fromisoformat(d.get("date") or now_dt().date().isoformat())
    except ValueError:
        raise ApiError(400, "invalid_date", "'date' must be YYYY-MM-DD.")
    if day > now_dt().date():
        raise ApiError(400, "invalid_date", "That day has not happened yet.")
    result = scheduler.close_day(day)
    with connect(write=True) as c:
        audit(c, "jobs.close_day", day.isoformat())
    return jsonify(date=day.isoformat(), **result)


# ================================================================== reports
def _report_args():
    section = request.args.get("section_id")
    try:
        section_id = int(section) if section else None
    except ValueError:
        raise ApiError(400, "invalid_argument", "'section_id' must be a number.")
    return section_id


def _csv(filename, header, rows):
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(header)
    w.writerows(rows)
    return Response("﻿" + buf.getvalue(), mimetype="text/csv",
                    headers={"Content-Disposition": f'attachment; filename="{filename}"'})


def _daily():
    try:
        day = date.fromisoformat(request.args.get("date") or now_dt().date().isoformat())
    except ValueError:
        raise ApiError(400, "invalid_date", "'date' must be YYYY-MM-DD.")
    with connect() as c:
        return attendance.daily_report(c, day, _report_args())


def _monthly():
    month = request.args.get("month") or now_dt().strftime("%Y-%m")
    if not re.fullmatch(r"\d{4}-\d{2}", month):
        raise ApiError(400, "invalid_month", "'month' must be YYYY-MM.")
    with connect() as c:
        return attendance.monthly_report(c, date.fromisoformat(month + "-01"), _report_args())


@bp.get("/admin/reports/daily")
@require_staff(*STAFF_ROLES)
def admin_report_daily():
    return jsonify(_daily())


@bp.get("/admin/reports/daily.csv")
@require_staff(*STAFF_ROLES)
def admin_report_daily_csv():
    r = _daily()
    return _csv(f"attendance-{r['date']}.csv",
                ["Student number", "Name", "Section", "Status", "Late (min)", "Time in", "Time out",
                 "Missing time out"],
                [[x["student_number"] or "", x["name"], x["section"] or "", x["day_status"], x["late_minutes"],
                  x["time_in"] or "", x["time_out"] or "", "yes" if x["missing_time_out"] else ""]
                 for x in r["rows"]])


@bp.get("/admin/reports/monthly")
@require_staff(*STAFF_ROLES)
def admin_report_monthly():
    return jsonify(_monthly())


@bp.get("/admin/reports/monthly.csv")
@require_staff(*STAFF_ROLES)
def admin_report_monthly_csv():
    r = _monthly()
    return _csv(f"attendance-{r['month']}.csv",
                ["Student number", "Name", "Section", "School days", "Present", "Late", "Absent", "Excused",
                 "Attendance rate %", "Total late minutes"],
                [[x["student_number"] or "", x["name"], x["section"] or "", x["school_days"], x["present"],
                  x["late"], x["absent"], x["excused"], "" if x["rate"] is None else x["rate"],
                  x["late_minutes_total"]] for x in r["rows"]])


@bp.get("/admin/reports/student/<int:user_id>")
@require_staff(*STAFF_ROLES)
def admin_report_student(user_id):
    month = request.args.get("month") or now_dt().strftime("%Y-%m")
    if not re.fullmatch(r"\d{4}-\d{2}", month):
        raise ApiError(400, "invalid_month", "'month' must be YYYY-MM.")
    start = date.fromisoformat(month + "-01")
    end = (start.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
    with connect() as c:
        u = c.execute("SELECT id, name FROM users WHERE id = ? AND role = 'student'", (user_id,)).fetchone()
        if u is None:
            raise ApiError(404, "not_found", "No such student.")
        days = attendance.student_calendar(c, user_id, start, end)
    return jsonify(user_id=user_id, name=u["name"], month=month, days=days, summary=attendance.summarize(days))


# ================================================================== reviews
@bp.get("/admin/excuses")
@require_staff(*TEACH)
def admin_excuses():
    status = request.args.get("status")
    sql = """SELECT e.*, u.name, p.student_number, s.name AS section, st.full_name AS reviewer
             FROM excuse_requests e JOIN users u ON u.id = e.user_id
             LEFT JOIN student_profiles p ON p.user_id = e.user_id LEFT JOIN sections s ON s.id = p.section_id
             LEFT JOIN staff_accounts st ON st.id = e.reviewed_by"""
    args = []
    if status in ("pending", "approved", "rejected"):
        sql += " WHERE e.status = ?"
        args.append(status)
    with connect() as c:
        rows = c.execute(sql + " ORDER BY e.id DESC LIMIT 500", args).fetchall()
    return jsonify(items=[dict(r) for r in rows])


@bp.post("/admin/excuses/<int:ex_id>/review")
@require_staff(*TEACH)
def admin_excuse_review(ex_id):
    d = json_body()
    status = d.get("status")
    if status not in ("approved", "rejected"):
        raise ApiError(400, "invalid_field", "'status' must be approved or rejected.")
    note = text_field(d, "note", max_len=300, required=False, min_len=0)
    with connect(write=True) as c:
        row = c.execute("SELECT * FROM excuse_requests WHERE id = ?", (ex_id,)).fetchone()
        if row is None:
            raise ApiError(404, "not_found", "No such excuse letter.")
        c.execute("""UPDATE excuse_requests SET status = ?, review_note = ?, reviewed_by = ?, reviewed_at = ?
                     WHERE id = ?""", (status, note, _staff_id(), now_text(), ex_id))
        audit(c, "excuse.review", f"#{ex_id} {status}")
    day = datetime.strptime(row["date"], "%Y-%m-%d").strftime("%b %d")
    notifier.notify_users([row["user_id"]], "system", f"Excuse Letter {status.capitalize()}",
                          f"Your excuse letter for {day} was {status}." + (f" Note: {note}" if note else ""),
                          f"excuse:{ex_id}:{status}")
    return jsonify(success=True)


@bp.get("/admin/tickets")
@require_staff(*TEACH)
def admin_tickets():
    status = request.args.get("status")
    sql = """SELECT t.*, u.name, p.student_number, st.full_name AS replier FROM support_tickets t
             JOIN users u ON u.id = t.user_id LEFT JOIN student_profiles p ON p.user_id = t.user_id
             LEFT JOIN staff_accounts st ON st.id = t.replied_by"""
    args = []
    if status in ("open", "answered", "closed"):
        sql += " WHERE t.status = ?"
        args.append(status)
    with connect() as c:
        rows = c.execute(sql + " ORDER BY t.id DESC LIMIT 500", args).fetchall()
    return jsonify(items=[dict(r) for r in rows])


@bp.post("/admin/tickets/<int:t_id>/reply")
@require_staff(*TEACH)
def admin_ticket_reply(t_id):
    d = json_body()
    reply = text_field(d, "reply", max_len=1000)
    status = "closed" if d.get("close") is True else "answered"
    with connect(write=True) as c:
        row = c.execute("SELECT * FROM support_tickets WHERE id = ?", (t_id,)).fetchone()
        if row is None:
            raise ApiError(404, "not_found", "No such ticket.")
        c.execute("""UPDATE support_tickets SET reply = ?, status = ?, replied_by = ?, replied_at = ?
                     WHERE id = ?""", (reply, status, _staff_id(), now_text(), t_id))
        audit(c, "ticket.reply", f"#{t_id}")
    notifier.notify_users([row["user_id"]], "system", "Support Reply",
                          f"Re: {row['subject']} — {reply[:200]}", f"ticket:{t_id}:{now_text()}")
    return jsonify(success=True)


@bp.get("/admin/library/reservations")
@require_staff("registrar")
def admin_reservations():
    with connect() as c:
        rows = c.execute("""SELECT r.*, i.title, u.name, p.student_number FROM library_reservations r
                            JOIN library_items i ON i.id = r.item_id JOIN users u ON u.id = r.user_id
                            LEFT JOIN student_profiles p ON p.user_id = r.user_id
                            ORDER BY r.id DESC LIMIT 500""").fetchall()
    return jsonify(items=[dict(r) for r in rows])


@bp.patch("/admin/library/reservations/<int:r_id>")
@require_staff("registrar")
def admin_reservation_update(r_id):
    status = json_body().get("status")
    if status not in ("reserved", "borrowed", "returned", "cancelled"):
        raise ApiError(400, "invalid_field", "'status' must be reserved, borrowed, returned or cancelled.")
    with connect(write=True) as c:
        row = c.execute("""SELECT r.*, i.title FROM library_reservations r JOIN library_items i ON i.id = r.item_id
                           WHERE r.id = ?""", (r_id,)).fetchone()
        if row is None:
            raise ApiError(404, "not_found", "No such reservation.")
        c.execute("UPDATE library_reservations SET status = ?, updated_at = ? WHERE id = ?",
                  (status, now_text(), r_id))
        audit(c, "library.reservation", f"#{r_id} {status}")
    if status in ("borrowed", "cancelled"):
        notifier.notify_users([row["user_id"]], "system", "Library",
                              f"Your reservation for “{row['title']}” is now {status}.",
                              f"lib:{r_id}:{status}")
    return jsonify(success=True)


@bp.get("/admin/sms")
@require_staff("registrar")
def admin_sms():
    with connect() as c:
        rows = c.execute("""SELECT o.*, gd.name AS guardian, u.name AS student FROM sms_outbox o
                            LEFT JOIN guardians gd ON gd.id = o.guardian_id LEFT JOIN users u ON u.id = gd.user_id
                            ORDER BY o.id DESC LIMIT 300""").fetchall()
    from services import sms
    return jsonify(provider=sms.provider(), items=[dict(r) for r in rows])


@bp.get("/admin/audit")
@require_staff()
def admin_audit():
    with connect() as c:
        rows = c.execute("""SELECT a.*, s.username FROM audit_log a LEFT JOIN staff_accounts s ON s.id = a.staff_id
                            ORDER BY a.id DESC LIMIT 500""").fetchall()
    return jsonify(items=[dict(r) for r in rows])
