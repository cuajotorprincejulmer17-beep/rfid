import sqlite3
from datetime import datetime, timedelta, timezone

import config

# Absolute, so the server finds the same database whatever folder it starts in.
DB_NAME = config.DB_PATH
SCHOOL_TZ = timezone(timedelta(hours=8))
FMT = "%Y-%m-%d %H:%M:%S"


def school_now():
    return datetime.now(SCHOOL_TZ)

def get_conn():
    conn = sqlite3.connect(DB_NAME, timeout=10, isolation_level=None)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_conn()
    # WAL lets the kiosk, admin and mobile readers run while a tap writes.
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rfid_uid TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('student', 'visitor')),
            is_temp INTEGER NOT NULL DEFAULT 0,
            time_limit_minutes INTEGER,
            is_expired INTEGER NOT NULL DEFAULT 0,
            archived INTEGER NOT NULL DEFAULT 0,
            registered_at TEXT NOT NULL DEFAULT (datetime('now', '+8 hours'))
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            time_in TEXT,
            time_out TEXT,
            expected_out TEXT,
            flag TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    """)
    existing = {row["name"] for row in conn.execute("PRAGMA table_info(logs)")}
    if "expected_out" not in existing:
        conn.execute("ALTER TABLE logs ADD COLUMN expected_out TEXT")
    if "flag" not in existing:
        conn.execute("ALTER TABLE logs ADD COLUMN flag TEXT")
    if "device_id" not in existing:
        conn.execute("ALTER TABLE logs ADD COLUMN device_id INTEGER")
    existing_cols = {row["name"] for row in conn.execute("PRAGMA table_info(users)")}
    if "time_limit_minutes" not in existing_cols:
        conn.execute("ALTER TABLE users ADD COLUMN time_limit_minutes INTEGER")
    if "is_expired" not in existing_cols:
        conn.execute("ALTER TABLE users ADD COLUMN is_expired INTEGER NOT NULL DEFAULT 0")
    if "archived" not in existing_cols:
        conn.execute("ALTER TABLE users ADD COLUMN archived INTEGER NOT NULL DEFAULT 0")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            event TEXT NOT NULL,
            at TEXT NOT NULL
        )
    """)
    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS one_open_record
        ON logs (user_id)
        WHERE time_out IS NULL AND (flag IS NULL OR flag = 'OVERSTAY')
    """)
    conn.close()

def uid_exists(uid):
    conn = get_conn()
    row = conn.execute("SELECT * FROM users WHERE rfid_uid = ?", (uid,)).fetchone()
    conn.close()
    return row

def add_user(uid, name, role, is_temp=0, time_limit_minutes=None):
    conn = get_conn()
    cur = conn.execute(
        "INSERT INTO users (rfid_uid, name, role, is_temp, time_limit_minutes, registered_at) VALUES (?, ?, ?, ?, ?, ?)",
        (uid, name, role, is_temp, time_limit_minutes, school_now().strftime(FMT)))
    conn.close()
    return cur.lastrowid

def upgrade_temp_user(uid, name, role, time_limit_minutes=None):
    conn = get_conn()
    if time_limit_minutes is None:
        conn.execute("UPDATE users SET name = ?, role = ?, is_temp = 0 WHERE rfid_uid = ?",
                     (name, role, uid))
    else:
        conn.execute("UPDATE users SET name = ?, role = ?, is_temp = 0, time_limit_minutes = ? WHERE rfid_uid = ?",
                     (name, role, time_limit_minutes, uid))
    conn.close()


def re_register_visitor_card(uid, name, role, time_limit_minutes=None):
    """Re-register any visitor card for a new visitor.

    The old user row is archived (uid rewritten, archived=1) so every past
    attendance record keeps the original visitor's name. Any open visit is
    flagged MISSING_TIME_OUT because that visitor never timed out. A brand new
    row is inserted under the real card UID so the card can be used again.
    """
    conn = get_conn()
    try:
        conn.execute("BEGIN IMMEDIATE")
        old = conn.execute("SELECT id FROM users WHERE rfid_uid = ? AND archived = 0", (uid,)).fetchone()
        if old is None:
            conn.execute("ROLLBACK")
            return False
        # Close any open visit: that visitor's card is being handed to someone new.
        conn.execute("""
            UPDATE logs SET flag = 'MISSING_TIME_OUT'
            WHERE user_id = ? AND time_out IS NULL AND (flag IS NULL OR flag = 'OVERSTAY')
        """, (old["id"],))
        # Archive the old row so history keeps the old name.
        conn.execute("UPDATE users SET rfid_uid = ?, archived = 1, is_expired = 1 WHERE id = ?",
                     (f"{uid}#USED{old['id']}", old["id"]))
        conn.execute(
            "INSERT INTO users (rfid_uid, name, role, is_temp, time_limit_minutes, is_expired, archived, registered_at) "
            "VALUES (?, ?, ?, 0, ?, 0, 0, ?)",
            (uid, name, role, time_limit_minutes, school_now().strftime(FMT)),
        )
        conn.execute("COMMIT")
        return True
    except Exception:
        conn.execute("ROLLBACK")
        raise
    finally:
        conn.close()

def delete_user(uid):
    conn = get_conn()
    try:
        conn.execute("BEGIN IMMEDIATE")
        user = conn.execute("SELECT id FROM users WHERE rfid_uid = ?", (uid,)).fetchone()
        if user:
            conn.execute("DELETE FROM logs WHERE user_id = ?", (user["id"],))
            conn.execute("DELETE FROM events WHERE user_id = ?", (user["id"],))
            conn.execute("DELETE FROM users WHERE id = ?", (user["id"],))
        conn.execute("COMMIT")
    except Exception:
        conn.execute("ROLLBACK")
        raise
    finally:
        conn.close()

def get_all_users():
    conn = get_conn()
    rows = conn.execute("SELECT * FROM users WHERE archived = 0 ORDER BY id DESC").fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_visitor_time_limit_minutes(uid):
    """Return the time_limit_minutes for a visitor card, or None."""
    conn = get_conn()
    row = conn.execute(
        "SELECT time_limit_minutes FROM users WHERE rfid_uid = ? AND role = 'visitor'", (uid,)
    ).fetchone()
    conn.close()
    if row and row["time_limit_minutes"] is not None:
        return row["time_limit_minutes"]
    return None

def record_tap(uid, mode, limit_hours=None, device_id=None, at=None):
    """Apply one tap atomically.

    Returns ``(result_code, user_row, log_id)`` after the transaction commits.
    ``log_id`` is the exact attendance log created or affected by the tap, or
    ``None`` when no attendance log was involved.  Callers can safely use it
    for post-commit work without guessing which log is newest.

    ``limit_hours`` may be None when the card has its own time_limit_minutes.
    ``device_id`` names the reader. ``at`` is the moment of the tap when it
    is replayed from a reader's offline queue; it defaults to now.
    """
    conn = get_conn()
    try:
        conn.execute("BEGIN IMMEDIATE")
        user = conn.execute("SELECT * FROM users WHERE rfid_uid = ?", (uid,)).fetchone()
        if user is None:
            conn.execute("COMMIT")
            return "DENY_UNKNOWN", None, None

        # Reject expired visitor cards from time in
        if user["is_expired"] and user["role"] == "visitor" and mode == "IN":
            conn.execute("COMMIT")
            return "REJECT_EXPIRED_VISITOR", user, None

        now = at or school_now()
        now_text = now.strftime(FMT)
        today = now.strftime("%Y-%m-%d")
        conn.execute("""
            UPDATE logs SET flag = 'MISSING_TIME_OUT'
            WHERE user_id = ? AND time_out IS NULL
              AND (flag IS NULL OR flag = 'OVERSTAY')
              AND substr(time_in, 1, 10) < ?
        """, (user["id"], today))

        open_record = conn.execute("""
            SELECT * FROM logs
            WHERE user_id = ? AND time_out IS NULL
              AND (flag IS NULL OR flag = 'OVERSTAY')
        """, (user["id"],)).fetchone()
        log_id = None

        if mode == "OUT":
            if open_record is None:
                conn.execute(
                    "INSERT INTO events (user_id, event, at) VALUES (?, 'NO_OPEN_RECORD', ?)",
                    (user["id"], now_text),
                )
                result = "REJECT_NO_OPEN_RECORD"
            else:
                log_id = open_record["id"]
                flag = open_record["flag"]
                if open_record["expected_out"] and now_text > open_record["expected_out"]:
                    flag = "OVERSTAY"
                # A checkout succeeds even when the completed visit is
                # flagged for overstay.  The flag remains available in logs.
                result = "TIME_OUT_OK"
                conn.execute("UPDATE logs SET time_out = ?, flag = ? WHERE id = ?",
                             (now_text, flag, open_record["id"]))
                # Expire visitor cards after a complete visit so they cannot time in again
                if user["role"] == "visitor":
                    conn.execute("UPDATE users SET is_expired = 1 WHERE id = ?", (user["id"],))
        elif open_record is None:
            expected_out = None
            if user["role"] == "visitor":
                # Use per-card time_limit_minutes if available, otherwise fall back to limit_hours
                if user["time_limit_minutes"] is not None:
                    expected_out = (now + timedelta(minutes=user["time_limit_minutes"])).strftime(FMT)
                elif limit_hours is not None:
                    expected_out = (now + timedelta(hours=limit_hours)).strftime(FMT)
            log_id = conn.execute(
                "INSERT INTO logs (user_id, time_in, expected_out, device_id) VALUES (?, ?, ?, ?)",
                (user["id"], now_text, expected_out, device_id),
            ).lastrowid
            result = "TIME_IN_OK"
        elif open_record["expected_out"] and now_text > open_record["expected_out"]:
            log_id = open_record["id"]
            conn.execute("UPDATE logs SET flag = 'OVERSTAY' WHERE id = ?",
                         (open_record["id"],))
            result = "VISIT_LIMIT_EXCEEDED"
        else:
            log_id = open_record["id"]
            result = "ALREADY_CHECKED_IN"

        conn.execute("COMMIT")
        return result, user, log_id
    except Exception:
        conn.execute("ROLLBACK")
        raise
    finally:
        conn.close()


def count_today():
    today = school_now().strftime("%Y-%m-%d")
    conn = get_conn()
    count = conn.execute(
        "SELECT COUNT(*) FROM logs WHERE substr(time_in, 1, 10) = ?", (today,)
    ).fetchone()[0]
    conn.close()
    return count

def get_recent_logs(limit=30):
    conn = get_conn()
    rows = conn.execute("""
        SELECT u.name, u.role, l.time_in, l.time_out, l.flag
        FROM logs l JOIN users u ON u.id = l.user_id
        ORDER BY l.id DESC LIMIT ?
    """, (limit,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]
