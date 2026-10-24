"""Admin routes (X-Admin-Key header). Block /api/v1/admin/* at any public proxy or tunnel."""
import sqlite3
from datetime import timedelta

from flask import g, jsonify, request

from . import notifier
from .auth import code_hash, new_claim_code
from .common import (ApiError, PHONE, STUDENT_NO, audit, bp, connect, json_body, later, now_dt, now_text,
                     require_admin, require_staff, text_field, to_iso)


def _active_student(c, user_id):
    r = c.execute("SELECT id, name FROM users WHERE id = ? AND role = 'student' AND archived = 0",
                  (user_id,)).fetchone()
    if r is None:
        raise ApiError(404, "not_found", "No such active student.")
    return r


@bp.get("/admin/students")
@require_staff("registrar", "teacher", "guard")
def admin_students():
    q = (request.args.get("q") or "").strip()[:50]
    section = request.args.get("section_id")
    sql = """SELECT u.id, u.name, u.rfid_uid, u.registered_at, p.student_number, p.course_section, p.phone,
                    p.section_id, s.name AS section_name, a.user_id IS NOT NULL AS claimed,
                    (SELECT COUNT(*) FROM guardians gd WHERE gd.user_id = u.id) AS guardians
             FROM users u LEFT JOIN student_profiles p ON p.user_id = u.id
             LEFT JOIN sections s ON s.id = p.section_id
             LEFT JOIN student_accounts a ON a.user_id = u.id
             WHERE u.role = 'student' AND u.archived = 0
               AND (? = '' OR u.name LIKE '%' || ? || '%' OR p.student_number LIKE '%' || ? || '%')"""
    args = [q, q, q]
    if section:
        sql += " AND p.section_id = ?"
        args.append(section)
    with connect() as c:
        rows = c.execute(sql + " ORDER BY u.name LIMIT 1000", args).fetchall()
    return jsonify(items=[{"id": r["id"], "user_id": r["id"], "name": r["name"], "rfid_uid": r["rfid_uid"],
                           "registered_at": r["registered_at"], "student_number": r["student_number"],
                           "course_section": r["course_section"], "phone": r["phone"],
                           "section_id": r["section_id"], "section_name": r["section_name"],
                           "has_profile": r["student_number"] is not None, "claimed": bool(r["claimed"]),
                           "guardians": r["guardians"]}
                          for r in rows])


def save_profile(c, user_id, sn, section, phone, section_id=None):
    """Creates or updates a student's profile. Raises ApiError on a duplicate number."""
    if section_id is not None:
        row = c.execute("SELECT name FROM sections WHERE id = ?", (section_id,)).fetchone()
        if row is None:
            raise ApiError(400, "invalid_field", "No such section.")
        section = section or row["name"]
    try:
        c.execute("""INSERT INTO student_profiles (user_id, student_number, course_section, phone, section_id,
                     updated_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(user_id) DO UPDATE SET
                     student_number = excluded.student_number, course_section = excluded.course_section,
                     phone = excluded.phone, section_id = excluded.section_id, updated_at = excluded.updated_at""",
                  (user_id, sn, section, phone, section_id, now_text()))
    except sqlite3.IntegrityError:
        raise ApiError(409, "duplicate_student_number", "That student number is already assigned.")


@bp.put("/admin/students/<int:user_id>/profile")
@require_admin
def admin_set_profile(user_id):
    d = json_body()
    sn = text_field(d, "student_number", min_len=2, max_len=32, pattern=STUDENT_NO)
    section = text_field(d, "course_section", max_len=60, required=False)
    phone = text_field(d, "phone", max_len=25, required=False, pattern=PHONE)
    section_id = d.get("section_id")
    if section_id is not None and (not isinstance(section_id, int) or isinstance(section_id, bool)):
        raise ApiError(400, "invalid_field", "'section_id' must be a section id.")
    with connect(write=True) as c:
        _active_student(c, user_id)
        save_profile(c, user_id, sn, section, phone, section_id)
        audit(c, "student.profile", f"#{user_id} {sn}")
    return jsonify(success=True)


@bp.post("/admin/students/<int:user_id>/claim-code")
@require_admin
def admin_claim_code(user_id):
    d = request.get_json(silent=True) or {}
    hours = d.get("expires_hours", 72) if isinstance(d, dict) else 72
    if not isinstance(hours, int) or isinstance(hours, bool) or not 1 <= hours <= 168:
        raise ApiError(400, "invalid_field", "'expires_hours' must be 1-168.")
    code = new_claim_code()
    with connect(write=True) as c:
        _active_student(c, user_id)
        prof = c.execute("SELECT student_number FROM student_profiles WHERE user_id = ?", (user_id,)).fetchone()
        if prof is None:
            raise ApiError(409, "profile_required", "Set the student's profile (student number) first.")
        if c.execute("SELECT 1 FROM student_accounts WHERE user_id = ?", (user_id,)).fetchone():
            raise ApiError(409, "already_claimed", "This student already has an account. Reset it first.")
        c.execute("UPDATE claim_codes SET used_at = ? WHERE user_id = ? AND used_at IS NULL", (now_text(), user_id))
        expires = (now_dt() + timedelta(hours=hours)).strftime("%Y-%m-%d %H:%M:%S")
        c.execute("INSERT INTO claim_codes (user_id, code_hash, expires_at, created_at) VALUES (?, ?, ?, ?)",
                  (user_id, code_hash(user_id, code), expires, now_text()))
    # The plaintext code is only ever returned here; only its hash is stored.
    return jsonify(claim_code=code, student_number=prof["student_number"], expires_at=to_iso(expires)), 201


@bp.post("/admin/students/<int:user_id>/reset-account")
@require_admin
def admin_reset_account(user_id):
    """Forgot-password path: removes the account and sessions so a new claim code can be issued."""
    with connect(write=True) as c:
        _active_student(c, user_id)
        for table in ("api_sessions", "push_devices", "student_accounts", "notification_prefs"):
            c.execute(f"DELETE FROM {table} WHERE user_id = ?", (user_id,))
        c.execute("UPDATE claim_codes SET used_at = ? WHERE user_id = ? AND used_at IS NULL", (now_text(), user_id))
    return jsonify(success=True)


# ------------------------------------------------------------------ faculty contacts
def _contact_fields(d, partial):
    out = {}
    rules = {"role": dict(max_len=60), "name": dict(max_len=100), "phone": dict(max_len=25, pattern=PHONE),
             "notes": dict(max_len=200, min_len=0)}
    for key, kw in rules.items():
        if key in d or (not partial and key != "notes"):
            out[key] = text_field(d, key, required=not (partial or key == "notes"), **kw)
    if "sort_order" in d:
        if not isinstance(d["sort_order"], int) or isinstance(d["sort_order"], bool):
            raise ApiError(400, "invalid_field", "'sort_order' must be a whole number.")
        out["sort_order"] = d["sort_order"]
    if "active" in d:
        if not isinstance(d["active"], bool):
            raise ApiError(400, "invalid_field", "'active' must be true or false.")
        out["active"] = int(d["active"])
    return out


@bp.get("/admin/contacts")
@require_admin
def admin_contacts():
    with connect() as c:
        rows = c.execute("SELECT * FROM faculty_contacts ORDER BY sort_order, id").fetchall()
    return jsonify(items=[dict(r) for r in rows])


@bp.post("/admin/contacts")
@require_admin
def admin_contact_create():
    f = _contact_fields(json_body(), partial=False)
    with connect(write=True) as c:
        cur = c.execute("""INSERT INTO faculty_contacts (role, name, phone, notes, sort_order, active, updated_at)
                           VALUES (?, ?, ?, ?, ?, ?, ?)""",
                        (f["role"], f["name"], f["phone"], f.get("notes"), f.get("sort_order", 0),
                         f.get("active", 1), now_text()))
    return jsonify(id=cur.lastrowid), 201


@bp.patch("/admin/contacts/<int:cid>")
@require_admin
def admin_contact_update(cid):
    f = _contact_fields(json_body(), partial=True)
    if not f:
        raise ApiError(400, "invalid_body", "Nothing to update.")
    with connect(write=True) as c:
        sets = ", ".join(f"{k} = ?" for k in f)
        n = c.execute(f"UPDATE faculty_contacts SET {sets}, updated_at = ? WHERE id = ?",
                      [*f.values(), now_text(), cid]).rowcount
    if n == 0:
        raise ApiError(404, "not_found", "No such contact.")
    return jsonify(success=True)


@bp.delete("/admin/contacts/<int:cid>")
@require_admin
def admin_contact_delete(cid):
    with connect(write=True) as c:
        n = c.execute("UPDATE faculty_contacts SET active = 0, updated_at = ? WHERE id = ?",
                      (now_text(), cid)).rowcount
    if n == 0:
        raise ApiError(404, "not_found", "No such contact.")
    return jsonify(success=True)


# ------------------------------------------------------------------ announcements
def publish_announcement(category, title, body, section_id=None, pinned=False):
    """Stores the announcement for the feed and puts it in every recipient's inbox.

    Returns (announcement_id, recipients).
    """
    with connect(write=True) as c:
        if section_id is not None and not c.execute("SELECT 1 FROM sections WHERE id = ?",
                                                    (section_id,)).fetchone():
            raise ApiError(400, "invalid_field", "No such section.")
        staff = getattr(g, "staff", None) or {}
        cur = c.execute("""INSERT INTO announcements (category, title, body, audience, section_id, pinned,
                           created_by, published_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                        (category, title, body, "section" if section_id else "all", section_id, int(pinned),
                         staff.get("id"), now_text()))
        ann_id = cur.lastrowid
        audit(c, "announcement.create", f"#{ann_id} {title}")
    recipients = notifier.create_announcement(category, title, body, section_id, key=f"ann:{ann_id}")
    return ann_id, recipients


@bp.post("/admin/announcements")
@require_staff("registrar", "teacher")
def admin_announce():
    d = json_body()
    category = text_field(d, "category", min_len=6, max_len=9)
    if category not in ("emergency", "system"):
        raise ApiError(400, "invalid_field", "'category' must be emergency or system.")
    title = text_field(d, "title", max_len=80)
    body = text_field(d, "body", max_len=500)
    section_id = d.get("section_id")
    if section_id is not None and (not isinstance(section_id, int) or isinstance(section_id, bool)):
        raise ApiError(400, "invalid_field", "'section_id' must be a section id.")
    if g.staff["role"] == "teacher" and (section_id is None or category == "emergency"):
        raise ApiError(403, "forbidden", "Teachers can post announcements to a section only.")
    ann_id, recipients = publish_announcement(category, title, body, section_id, bool(d.get("pinned")))
    return jsonify(id=ann_id, recipients=recipients), 201


@bp.get("/admin/announcements")
@require_staff("registrar", "teacher")
def admin_announcements():
    with connect() as c:
        rows = c.execute("""SELECT a.*, s.name AS section_name, st.full_name AS author FROM announcements a
                            LEFT JOIN sections s ON s.id = a.section_id
                            LEFT JOIN staff_accounts st ON st.id = a.created_by
                            ORDER BY a.id DESC LIMIT 200""").fetchall()
    return jsonify(items=[dict(r) for r in rows])


@bp.delete("/admin/announcements/<int:ann_id>")
@require_admin
def admin_announcement_delete(ann_id):
    """Removes it from the feed. Inbox copies already delivered stay with the students."""
    with connect(write=True) as c:
        if c.execute("DELETE FROM announcements WHERE id = ?", (ann_id,)).rowcount == 0:
            raise ApiError(404, "not_found", "No such announcement.")
        audit(c, "announcement.delete", f"#{ann_id}")
    return jsonify(success=True)
