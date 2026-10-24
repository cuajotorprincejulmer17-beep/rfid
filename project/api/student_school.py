"""Student routes for school and campus content. Every query is scoped to the signed-in student."""
import json
import re
from datetime import date, datetime, timedelta

from flask import g, jsonify, request

from services import attendance
from .common import ApiError, bp, connect, json_body, limiter, now_dt, now_text, require_auth, text_field, to_iso

MAX_SCHEDULE_DAYS = 62


# ------------------------------------------------------------------ helpers
def _section_id(c, user_id):
    r = c.execute("SELECT section_id FROM student_profiles WHERE user_id = ?", (user_id,)).fetchone()
    return r["section_id"] if r else None


def _q():
    return (request.args.get("q") or "").strip()[:60]


def _date_arg(name, default=None):
    raw = request.args.get(name)
    if raw is None:
        return default
    try:
        return date.fromisoformat(raw)
    except ValueError:
        raise ApiError(400, "invalid_date", f"'{name}' must be YYYY-MM-DD.")


def _throttle(kind, limit=20, window=3600):
    key = f"{kind}:{g.user_id}"
    limiter.check(key, limit, window)
    limiter.add(key)


def _list(value):
    try:
        return json.loads(value) if value else []
    except ValueError:
        return []


# ------------------------------------------------------------------ schedule
def schedule_events(c, user_id, start, end):
    """Expands the section's weekly timetable into dated events in [start, end]."""
    section_id = _section_id(c, user_id)
    if section_id is None:
        return []
    rows = c.execute(
        """SELECT cs.*, sj.code AS subject_code, sj.title AS subject_title, r.name AS room_name,
                  r.building AS room_building, st.full_name AS teacher
           FROM class_schedules cs JOIN subjects sj ON sj.id = cs.subject_id
           LEFT JOIN rooms r ON r.id = cs.room_id LEFT JOIN staff_accounts st ON st.id = cs.teacher_staff_id
           WHERE cs.section_id = ? ORDER BY cs.start_time""", (section_id,)).fetchall()
    by_day = {}
    for r in rows:
        by_day.setdefault(r["weekday"], []).append(r)
    pol = attendance.policy(c)
    events = []
    day = start
    while day <= end:
        kind = attendance.day_kind(c, day, pol)
        if kind not in ("holiday", "no_class"):
            for r in by_day.get(day.isoweekday(), []):
                room = f"{r['room_name']}, {r['room_building']}" if r["room_name"] else "Room to be announced"
                events.append({
                    "id": f"{r['id']}-{day.isoformat()}", "schedule_id": r["id"],
                    "title": r["subject_title"], "subject_code": r["subject_code"],
                    "start": to_iso(f"{day} {r['start_time']}:00"), "end": to_iso(f"{day} {r['end_time']}:00"),
                    "room": room, "kind": r["kind"], "teacher": r["teacher"], "note": r["note"]})
        day += timedelta(days=1)
    return events


@bp.get("/schedule")
@require_auth
def schedule():
    today = now_dt().date()
    one = _date_arg("date")
    start, end = (one, one) if one else (_date_arg("from", today), _date_arg("to", today + timedelta(days=6)))
    if end < start or (end - start).days >= MAX_SCHEDULE_DAYS:
        raise ApiError(400, "invalid_range", f"The range must be 1-{MAX_SCHEDULE_DAYS} days.")
    with connect() as c:
        items = schedule_events(c, g.user_id, start, end)
        holidays = [dict(r) for r in c.execute(
            "SELECT date, kind, note FROM school_calendar WHERE date BETWEEN ? AND ? ORDER BY date",
            (start.isoformat(), end.isoformat()))]
    return jsonify(**{"from": start.isoformat(), "to": end.isoformat()}, items=items, calendar=holidays)


# ------------------------------------------------------------------ announcements
def _announcement(r):
    return {"id": r["id"], "category": r["category"], "title": r["title"], "body": r["body"],
            "audience": r["audience"], "pinned": bool(r["pinned"]), "published_at": to_iso(r["published_at"])}


@bp.get("/announcements")
@require_auth
def announcements():
    limit = min(max(int(request.args.get("limit", 30) or 30), 1), 50)
    with connect() as c:
        section_id = _section_id(c, g.user_id)
        rows = c.execute("""SELECT * FROM announcements WHERE audience = 'all' OR section_id = ?
                            ORDER BY pinned DESC, id DESC LIMIT ?""", (section_id, limit)).fetchall()
    return jsonify(items=[_announcement(r) for r in rows])


@bp.get("/announcements/<int:ann_id>")
@require_auth
def announcement(ann_id):
    with connect() as c:
        section_id = _section_id(c, g.user_id)
        r = c.execute("""SELECT * FROM announcements WHERE id = ? AND (audience = 'all' OR section_id = ?)""",
                      (ann_id, section_id)).fetchone()
    if r is None:
        raise ApiError(404, "not_found", "Announcement not found.")
    return jsonify(_announcement(r))


# ------------------------------------------------------------------ tasks
def _task(r):
    return {"id": r["id"], "title": r["title"], "course": r["course"] or "", "due": to_iso(r["due_at"]),
            "priority": r["priority"], "completed": r["completed_at"] is not None,
            "completed_at": to_iso(r["completed_at"]),
            "kind": "personal" if r["user_id"] is not None else "assignment"}


def _task_rows(c, user_id, task_id=None):
    sql = """SELECT t.*, tc.completed_at FROM tasks t
             LEFT JOIN task_completions tc ON tc.task_id = t.id AND tc.user_id = ?
             WHERE (t.user_id = ? OR t.section_id = ?)"""
    args = [user_id, user_id, _section_id(c, user_id) or -1]
    if task_id is not None:
        sql += " AND t.id = ?"
        args.append(task_id)
    return c.execute(sql + " ORDER BY t.due_at", args).fetchall()


def _due(d, required):
    raw = d.get("due")
    if raw is None:
        if required:
            raise ApiError(400, "invalid_field", "'due' is required.")
        return None
    try:
        dt = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except ValueError:
        raise ApiError(400, "invalid_field", "'due' must be an ISO date-time.")
    if dt.tzinfo is not None:
        from database import SCHOOL_TZ
        dt = dt.astimezone(SCHOOL_TZ).replace(tzinfo=None)
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _priority(d, required):
    p = d.get("priority", "medium" if required else None)
    if p is not None and p not in ("high", "medium", "low"):
        raise ApiError(400, "invalid_field", "'priority' must be high, medium or low.")
    return p


@bp.get("/tasks")
@require_auth
def tasks():
    with connect() as c:
        return jsonify(items=[_task(r) for r in _task_rows(c, g.user_id)])


@bp.post("/tasks")
@require_auth
def task_create():
    _throttle("task", 60)
    d = json_body()
    title = text_field(d, "title", max_len=120)
    course = text_field(d, "course", max_len=60, required=False, min_len=0)
    due, priority = _due(d, True), _priority(d, True)
    with connect(write=True) as c:
        if c.execute("SELECT COUNT(*) FROM tasks WHERE user_id = ?", (g.user_id,)).fetchone()[0] >= 500:
            raise ApiError(400, "too_many", "You have too many tasks. Delete some first.")
        cur = c.execute("""INSERT INTO tasks (user_id, title, course, due_at, priority, created_at)
                           VALUES (?, ?, ?, ?, ?, ?)""", (g.user_id, title, course, due, priority, now_text()))
        row = _task_rows(c, g.user_id, cur.lastrowid)[0]
    return jsonify(_task(row)), 201


@bp.patch("/tasks/<int:task_id>")
@require_auth
def task_update(task_id):
    d = json_body()
    with connect(write=True) as c:
        rows = _task_rows(c, g.user_id, task_id)
        if not rows:
            raise ApiError(404, "not_found", "Task not found.")
        own = rows[0]["user_id"] == g.user_id
        if "completed" in d:
            if not isinstance(d["completed"], bool):
                raise ApiError(400, "invalid_field", "'completed' must be true or false.")
            if d["completed"]:
                c.execute("INSERT OR IGNORE INTO task_completions (task_id, user_id, completed_at) VALUES (?, ?, ?)",
                          (task_id, g.user_id, now_text()))
            else:
                c.execute("DELETE FROM task_completions WHERE task_id = ? AND user_id = ?", (task_id, g.user_id))
        edits = {k: d[k] for k in ("title", "course", "due", "priority") if k in d}
        if edits:
            if not own:
                raise ApiError(403, "forbidden", "Assignments are set by your teacher.")
            sets, args = [], []
            if "title" in edits:
                sets.append("title = ?")
                args.append(text_field(d, "title", max_len=120))
            if "course" in edits:
                sets.append("course = ?")
                args.append(text_field(d, "course", max_len=60, required=False, min_len=0))
            if "due" in edits:
                sets.append("due_at = ?")
                args.append(_due(d, True))
            if "priority" in edits:
                sets.append("priority = ?")
                args.append(_priority(d, True))
            c.execute(f"UPDATE tasks SET {', '.join(sets)} WHERE id = ?", [*args, task_id])
        row = _task_rows(c, g.user_id, task_id)[0]
    return jsonify(_task(row))


@bp.delete("/tasks/<int:task_id>")
@require_auth
def task_delete(task_id):
    with connect(write=True) as c:
        n = c.execute("DELETE FROM tasks WHERE id = ? AND user_id = ?", (task_id, g.user_id)).rowcount
        if n == 0:
            raise ApiError(404, "not_found", "Task not found, or it is an assignment.")
        c.execute("DELETE FROM task_completions WHERE task_id = ?", (task_id,))
    return jsonify(success=True)


# ------------------------------------------------------------------ campus
@bp.get("/directory")
@require_auth
def directory():
    q = _q()
    with connect() as c:
        rows = c.execute("""SELECT * FROM directory_entries WHERE active = 1
                            AND (? = '' OR name LIKE '%' || ? || '%' OR role LIKE '%' || ? || '%'
                                 OR department LIKE '%' || ? || '%')
                            ORDER BY sort_order, name""", (q, q, q, q)).fetchall()
    return jsonify(items=[{"id": r["id"], "name": r["name"], "role": r["role"], "department": r["department"],
                           "email": r["email"], "phone": r["phone"], "office": r["office"]} for r in rows])


def _room(r):
    return {"id": r["id"], "code": r["code"], "name": r["name"], "building": r["building"], "floor": r["floor"],
            "capacity": r["capacity"], "services": _list(r["services"]), "notes": r["notes"]}


@bp.get("/rooms")
@require_auth
def rooms():
    q = _q()
    with connect() as c:
        rows = c.execute("""SELECT * FROM rooms WHERE ? = '' OR code LIKE '%' || ? || '%'
                            OR name LIKE '%' || ? || '%' OR building LIKE '%' || ? || '%'
                            ORDER BY building, code""", (q, q, q, q)).fetchall()
    return jsonify(items=[_room(r) for r in rows])


@bp.get("/rooms/<int:room_id>")
@require_auth
def room(room_id):
    with connect() as c:
        r = c.execute("SELECT * FROM rooms WHERE id = ?", (room_id,)).fetchone()
        if r is None:
            raise ApiError(404, "not_found", "Room not found.")
        today = now_dt().date()
        weekday = today.isoweekday()
        busy = [dict(x) for x in c.execute(
            """SELECT cs.start_time, cs.end_time, sj.title, s.name AS section FROM class_schedules cs
               JOIN subjects sj ON sj.id = cs.subject_id JOIN sections s ON s.id = cs.section_id
               WHERE cs.room_id = ? AND cs.weekday = ? ORDER BY cs.start_time""", (room_id, weekday))]
    return jsonify({**_room(r), "today": busy})


def _place(r):
    return {"id": r["id"], "name": r["name"], "kind": r["kind"], "x": r["x"], "y": r["y"], "width": r["width"],
            "height": r["height"], "room_id": r["room_id"], "description": r["description"]}


@bp.get("/map/places")
@require_auth
def map_places():
    with connect() as c:
        rows = c.execute("SELECT * FROM map_places ORDER BY name").fetchall()
    return jsonify(items=[_place(r) for r in rows])


@bp.get("/map/places/<int:place_id>")
@require_auth
def map_place(place_id):
    with connect() as c:
        r = c.execute("SELECT * FROM map_places WHERE id = ?", (place_id,)).fetchone()
    if r is None:
        raise ApiError(404, "not_found", "Place not found.")
    return jsonify(_place(r))


# ------------------------------------------------------------------ lost and found
LF_CATEGORIES = ("electronics", "id", "bags", "books", "clothing", "keys", "wallet", "other")


def _lf(r, user_id):
    return {"id": r["id"], "kind": r["kind"], "name": r["name"], "category": r["category"],
            "location": r["location"], "description": r["description"], "status": r["status"],
            "claimed": r["status"] in ("claimed", "closed"), "reported_at": to_iso(r["reported_at"]),
            "mine": r["reported_by_user"] == user_id, "claimed_by_me": r["claimed_by_user"] == user_id}


@bp.get("/lost-found")
@require_auth
def lost_found():
    sql, args = "SELECT * FROM lost_found_items WHERE status != 'closed'", []
    if request.args.get("category"):
        sql += " AND category = ?"
        args.append(request.args["category"])
    if request.args.get("kind") in ("lost", "found"):
        sql += " AND kind = ?"
        args.append(request.args["kind"])
    with connect() as c:
        rows = c.execute(sql + " ORDER BY reported_at DESC LIMIT 200", args).fetchall()
    return jsonify(items=[_lf(r, g.user_id) for r in rows], categories=list(LF_CATEGORIES))


@bp.post("/lost-found")
@require_auth
def lost_found_report():
    _throttle("lostfound", 10)
    d = json_body()
    kind = d.get("kind", "lost")
    if kind not in ("lost", "found"):
        raise ApiError(400, "invalid_field", "'kind' must be lost or found.")
    name = text_field(d, "name", max_len=100)
    category = text_field(d, "category", max_len=40)
    location = text_field(d, "location", max_len=100)
    description = text_field(d, "description", max_len=300, required=False, min_len=0)
    with connect(write=True) as c:
        cur = c.execute("""INSERT INTO lost_found_items (kind, name, category, location, description,
                           reported_by_user, reported_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                        (kind, name, category.lower(), location, description, g.user_id, now_text(), now_text()))
        r = c.execute("SELECT * FROM lost_found_items WHERE id = ?", (cur.lastrowid,)).fetchone()
    return jsonify(_lf(r, g.user_id)), 201


@bp.post("/lost-found/<int:item_id>/claim")
@require_auth
def lost_found_claim(item_id):
    """Asks the office to release a found item. Staff confirm it in the console."""
    _throttle("lfclaim", 10)
    with connect(write=True) as c:
        r = c.execute("SELECT * FROM lost_found_items WHERE id = ?", (item_id,)).fetchone()
        if r is None:
            raise ApiError(404, "not_found", "Item not found.")
        if r["kind"] != "found" or r["status"] != "open":
            raise ApiError(409, "not_claimable", "This item cannot be claimed right now.")
        c.execute("""UPDATE lost_found_items SET status = 'claim_requested', claimed_by_user = ?, updated_at = ?
                     WHERE id = ?""", (g.user_id, now_text(), item_id))
        r = c.execute("SELECT * FROM lost_found_items WHERE id = ?", (item_id,)).fetchone()
    return jsonify(_lf(r, g.user_id))


@bp.post("/lost-found/<int:item_id>/resolve")
@require_auth
def lost_found_resolve(item_id):
    """The student who reported a lost item marks it recovered."""
    with connect(write=True) as c:
        n = c.execute("""UPDATE lost_found_items SET status = 'closed', updated_at = ?
                         WHERE id = ? AND reported_by_user = ? AND kind = 'lost'""",
                      (now_text(), item_id, g.user_id)).rowcount
        if n == 0:
            raise ApiError(404, "not_found", "Only your own lost-item reports can be closed.")
        r = c.execute("SELECT * FROM lost_found_items WHERE id = ?", (item_id,)).fetchone()
    return jsonify(_lf(r, g.user_id))


# ------------------------------------------------------------------ library
def _book(r, user_id):
    return {"id": r["id"], "title": r["title"], "author": r["author"], "shelf": r["shelf"],
            "copies": r["copies"], "available": r["copies"] - r["out"] > 0, "featured": bool(r["featured"]),
            "my_reservation": r["mine"]}


LIB_SQL = """SELECT i.*, (SELECT COUNT(*) FROM library_reservations r WHERE r.item_id = i.id
                          AND r.status IN ('reserved', 'borrowed')) AS out,
                         (SELECT r.status FROM library_reservations r WHERE r.item_id = i.id AND r.user_id = ?
                          AND r.status IN ('reserved', 'borrowed') ORDER BY r.id DESC LIMIT 1) AS mine
             FROM library_items i"""


@bp.get("/library")
@require_auth
def library():
    q = _q()
    with connect() as c:
        rows = c.execute(LIB_SQL + """ WHERE ? = '' OR i.title LIKE '%' || ? || '%' OR i.author LIKE '%' || ? || '%'
                                       ORDER BY i.featured DESC, i.title""", (g.user_id, q, q, q)).fetchall()
    return jsonify(items=[_book(r, g.user_id) for r in rows])


@bp.post("/library/<int:item_id>/reserve")
@require_auth
def library_reserve(item_id):
    _throttle("reserve", 20)
    with connect(write=True) as c:
        r = c.execute(LIB_SQL + " WHERE i.id = ?", (g.user_id, item_id)).fetchone()
        if r is None:
            raise ApiError(404, "not_found", "Book not found.")
        if r["mine"]:
            raise ApiError(409, "already_reserved", "You already reserved this book.")
        if r["copies"] - r["out"] <= 0:
            raise ApiError(409, "unavailable", "No copy is available right now.")
        active = c.execute("""SELECT COUNT(*) FROM library_reservations WHERE user_id = ?
                              AND status IN ('reserved', 'borrowed')""", (g.user_id,)).fetchone()[0]
        if active >= 5:
            raise ApiError(409, "limit_reached", "You can hold at most 5 books at a time.")
        c.execute("""INSERT INTO library_reservations (item_id, user_id, created_at, updated_at)
                     VALUES (?, ?, ?, ?)""", (item_id, g.user_id, now_text(), now_text()))
        r = c.execute(LIB_SQL + " WHERE i.id = ?", (g.user_id, item_id)).fetchone()
    return jsonify(_book(r, g.user_id)), 201


@bp.get("/library/reservations")
@require_auth
def library_reservations():
    with connect() as c:
        rows = c.execute("""SELECT r.id, r.status, r.created_at, i.id AS item_id, i.title, i.author, i.shelf
                            FROM library_reservations r JOIN library_items i ON i.id = r.item_id
                            WHERE r.user_id = ? ORDER BY r.id DESC LIMIT 100""", (g.user_id,)).fetchall()
    return jsonify(items=[{**dict(r), "created_at": to_iso(r["created_at"])} for r in rows])


@bp.delete("/library/reservations/<int:res_id>")
@require_auth
def library_cancel(res_id):
    with connect(write=True) as c:
        n = c.execute("""UPDATE library_reservations SET status = 'cancelled', updated_at = ?
                         WHERE id = ? AND user_id = ? AND status = 'reserved'""",
                      (now_text(), res_id, g.user_id)).rowcount
    if n == 0:
        raise ApiError(404, "not_found", "No reservation to cancel.")
    return jsonify(success=True)


# ------------------------------------------------------------------ support
@bp.get("/faq")
@require_auth
def faq():
    q = _q()
    with connect() as c:
        rows = c.execute("""SELECT * FROM faq_items WHERE active = 1 AND (? = '' OR question LIKE '%' || ? || '%'
                            OR answer LIKE '%' || ? || '%') ORDER BY sort_order, id""", (q, q, q)).fetchall()
    return jsonify(items=[{"id": r["id"], "question": r["question"], "answer": r["answer"]} for r in rows])


@bp.get("/support/assistance")
@require_auth
def assistance():
    with connect() as c:
        rows = c.execute("SELECT * FROM assistance_paths WHERE active = 1 ORDER BY sort_order, id").fetchall()
    return jsonify(items=[{"id": r["id"], "title": r["title"], "description": r["description"],
                           "icon": r["icon"]} for r in rows])


def _ticket(r):
    return {"id": r["id"], "subject": r["subject"], "body": r["body"], "status": r["status"], "reply": r["reply"],
            "created_at": to_iso(r["created_at"]), "replied_at": to_iso(r["replied_at"])}


@bp.get("/support/tickets")
@require_auth
def tickets():
    with connect() as c:
        rows = c.execute("SELECT * FROM support_tickets WHERE user_id = ? ORDER BY id DESC LIMIT 100",
                         (g.user_id,)).fetchall()
    return jsonify(items=[_ticket(r) for r in rows])


@bp.post("/support/tickets")
@require_auth
def ticket_create():
    _throttle("ticket", 10)
    d = json_body()
    subject = text_field(d, "subject", max_len=100)
    body = text_field(d, "body", max_len=2000, required=False, min_len=0) or ""
    with connect(write=True) as c:
        cur = c.execute("INSERT INTO support_tickets (user_id, subject, body, created_at) VALUES (?, ?, ?, ?)",
                        (g.user_id, subject, body, now_text()))
        r = c.execute("SELECT * FROM support_tickets WHERE id = ?", (cur.lastrowid,)).fetchone()
    return jsonify(_ticket(r)), 201


# ------------------------------------------------------------------ excuse letters
def _excuse(r):
    return {"id": r["id"], "date": r["date"], "reason": r["reason"], "status": r["status"],
            "review_note": r["review_note"], "created_at": to_iso(r["created_at"]),
            "reviewed_at": to_iso(r["reviewed_at"])}


@bp.get("/excuses")
@require_auth
def excuses():
    with connect() as c:
        rows = c.execute("SELECT * FROM excuse_requests WHERE user_id = ? ORDER BY date DESC, id DESC LIMIT 100",
                         (g.user_id,)).fetchall()
    return jsonify(items=[_excuse(r) for r in rows])


@bp.post("/excuses")
@require_auth
def excuse_create():
    _throttle("excuse", 10)
    d = json_body()
    raw = text_field(d, "date", max_len=10)
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", raw):
        raise ApiError(400, "invalid_date", "'date' must be YYYY-MM-DD.")
    try:
        day = date.fromisoformat(raw)
    except ValueError:
        raise ApiError(400, "invalid_date", "'date' must be a real date.")
    today = now_dt().date()
    if day > today + timedelta(days=30) or day < today - timedelta(days=60):
        raise ApiError(400, "invalid_date", "Excuse letters cover the last 60 or the next 30 days.")
    reason = text_field(d, "reason", min_len=5, max_len=500)
    with connect(write=True) as c:
        if c.execute("""SELECT 1 FROM excuse_requests WHERE user_id = ? AND date = ? AND status != 'rejected'""",
                     (g.user_id, raw)).fetchone():
            raise ApiError(409, "duplicate", "You already sent an excuse letter for that day.")
        cur = c.execute("""INSERT INTO excuse_requests (user_id, date, reason, created_at)
                           VALUES (?, ?, ?, ?)""", (g.user_id, raw, reason, now_text()))
        r = c.execute("SELECT * FROM excuse_requests WHERE id = ?", (cur.lastrowid,)).fetchone()
    return jsonify(_excuse(r)), 201
