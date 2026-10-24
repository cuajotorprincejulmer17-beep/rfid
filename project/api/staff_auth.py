"""Staff sign-in for the admin console, and staff account management."""
import os
import secrets
import sqlite3

from flask import g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

from .common import (ApiError, STAFF_ROLES, audit, bp, client_ip, connect, json_body, later, limiter,
                     now_text, require_staff, sha, text_field)

SESSION_HOURS = int(os.environ.get("STAFF_SESSION_HOURS", "12"))
DUMMY_HASH = generate_password_hash(secrets.token_hex(8))
USERNAME = r"[A-Za-z0-9._-]{3,32}"


def create_staff(c, username, full_name, role, password, email=None, phone=None):
    """Inserts a staff account. Raises ApiError on a duplicate or bad role."""
    if role not in STAFF_ROLES:
        raise ApiError(400, "invalid_field", f"'role' must be one of {', '.join(STAFF_ROLES)}.")
    if len(password) < 8:
        raise ApiError(400, "weak_password", "Password must be at least 8 characters.")
    try:
        cur = c.execute("""INSERT INTO staff_accounts (username, full_name, role, email, phone, password_hash,
                           created_at) VALUES (?, ?, ?, ?, ?, ?, ?)""",
                        (username, full_name, role, email, phone, generate_password_hash(password), now_text()))
    except sqlite3.IntegrityError:
        raise ApiError(409, "duplicate_username", "That username is taken.")
    return cur.lastrowid


def _public(r):
    return {"id": r["id"], "username": r["username"], "full_name": r["full_name"], "role": r["role"],
            "email": r["email"], "phone": r["phone"], "active": bool(r["active"]), "last_login": r["last_login"]}


@bp.post("/admin/auth/login")
def staff_login():
    d = json_body()
    username = text_field(d, "username", min_len=3, max_len=32)
    password = text_field(d, "password", max_len=128, strip=False)
    ip = client_ip()
    limiter.check(f"staff-login:{ip}", 20, 600)
    with connect() as c:
        row = c.execute("SELECT * FROM staff_accounts WHERE username = ? AND active = 1", (username,)).fetchone()
    if not (check_password_hash(row["password_hash"] if row else DUMMY_HASH, password) and row):
        limiter.add(f"staff-login:{ip}")
        raise ApiError(401, "invalid_credentials", "Incorrect username or password.")
    token = secrets.token_urlsafe(32)
    expires = later(hours=SESSION_HOURS)
    with connect(write=True) as c:
        c.execute("DELETE FROM staff_sessions WHERE staff_id = ? AND (revoked = 1 OR expires_at < ?)",
                  (row["id"], now_text()))
        c.execute("INSERT INTO staff_sessions (staff_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?)",
                  (row["id"], sha(token), expires, now_text()))
        c.execute("UPDATE staff_accounts SET last_login = ? WHERE id = ?", (now_text(), row["id"]))
    return jsonify(token=token, expires_at=expires, staff=_public(row))


@bp.post("/admin/auth/logout")
@require_staff(*STAFF_ROLES)
def staff_logout():
    header = request.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        with connect(write=True) as c:
            c.execute("UPDATE staff_sessions SET revoked = 1 WHERE token_hash = ?", (sha(header[7:].strip()),))
    return jsonify(success=True)


@bp.get("/admin/auth/me")
@require_staff(*STAFF_ROLES)
def staff_me():
    return jsonify(staff=g.staff)


@bp.post("/admin/auth/password")
@require_staff(*STAFF_ROLES)
def staff_change_password():
    if g.staff["id"] is None:
        raise ApiError(400, "not_a_staff_account", "The admin key has no password.")
    d = json_body()
    current = text_field(d, "current_password", max_len=128, strip=False)
    new = text_field(d, "new_password", max_len=128, strip=False)
    if len(new) < 8:
        raise ApiError(400, "weak_password", "Password must be at least 8 characters.")
    with connect(write=True) as c:
        row = c.execute("SELECT password_hash FROM staff_accounts WHERE id = ?", (g.staff["id"],)).fetchone()
        if not check_password_hash(row["password_hash"], current):
            raise ApiError(400, "invalid_credentials", "The current password is wrong.")
        c.execute("UPDATE staff_accounts SET password_hash = ? WHERE id = ?",
                  (generate_password_hash(new), g.staff["id"]))
    return jsonify(success=True)


# ------------------------------------------------------------------ staff management (admin only)
@bp.get("/admin/staff")
@require_staff("registrar", "teacher", "guard")
def staff_list():
    with connect() as c:
        rows = c.execute("SELECT * FROM staff_accounts ORDER BY active DESC, full_name").fetchall()
    return jsonify(items=[_public(r) for r in rows])


@bp.post("/admin/staff")
@require_staff()
def staff_create():
    d = json_body()
    username = text_field(d, "username", pattern=USERNAME, min_len=3, max_len=32)
    full_name = text_field(d, "full_name", max_len=100)
    role = text_field(d, "role", max_len=12)
    password = text_field(d, "password", max_len=128, strip=False)
    email = text_field(d, "email", max_len=120, required=False)
    phone = text_field(d, "phone", max_len=25, required=False)
    with connect(write=True) as c:
        sid = create_staff(c, username, full_name, role, password, email, phone)
        audit(c, "staff.create", f"{username} ({role})")
    return jsonify(id=sid), 201


@bp.patch("/admin/staff/<int:sid>")
@require_staff()
def staff_update(sid):
    d = json_body()
    sets, args = [], []
    for key in ("full_name", "email", "phone"):
        if key in d:
            sets.append(f"{key} = ?")
            args.append(text_field(d, key, max_len=120, required=False, min_len=0))
    if "role" in d:
        if d["role"] not in STAFF_ROLES:
            raise ApiError(400, "invalid_field", f"'role' must be one of {', '.join(STAFF_ROLES)}.")
        sets.append("role = ?")
        args.append(d["role"])
    if "active" in d:
        if not isinstance(d["active"], bool):
            raise ApiError(400, "invalid_field", "'active' must be true or false.")
        if not d["active"] and sid == g.staff["id"]:
            raise ApiError(400, "invalid_field", "You cannot deactivate your own account.")
        sets.append("active = ?")
        args.append(int(d["active"]))
    if "password" in d:
        pw = text_field(d, "password", max_len=128, strip=False)
        if len(pw) < 8:
            raise ApiError(400, "weak_password", "Password must be at least 8 characters.")
        sets.append("password_hash = ?")
        args.append(generate_password_hash(pw))
    if not sets:
        raise ApiError(400, "invalid_body", "Nothing to update.")
    with connect(write=True) as c:
        n = c.execute(f"UPDATE staff_accounts SET {', '.join(sets)} WHERE id = ?", [*args, sid]).rowcount
        if n == 0:
            raise ApiError(404, "not_found", "No such staff account.")
        if "password" in d or d.get("active") is False:
            c.execute("UPDATE staff_sessions SET revoked = 1 WHERE staff_id = ?", (sid,))
        audit(c, "staff.update", f"#{sid} {sorted(k for k in d if k != 'password')}")
    return jsonify(success=True)
