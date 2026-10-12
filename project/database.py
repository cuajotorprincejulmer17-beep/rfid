import sqlite3
from datetime import datetime, timedelta, timezone

DB_NAME = "rfid_system.db"
SCHOOL_TZ = timezone(timedelta(hours=8))


def school_now():
    return datetime.now(SCHOOL_TZ)

def get_conn():
    conn = sqlite3.connect(DB_NAME, timeout=10, isolation_level=None)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            rfid_uid TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('student', 'visitor')),
            is_temp INTEGER NOT NULL DEFAULT 0,
            registered_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
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

def add_user(uid, name, role, is_temp=0):
    conn = get_conn()
    conn.execute("INSERT INTO users (rfid_uid, name, role, is_temp) VALUES (?, ?, ?, ?)",
                 (uid, name, role, is_temp))
    conn.close()

def upgrade_temp_user(uid, name, role):
    conn = get_conn()
    conn.execute("UPDATE users SET name = ?, role = ?, is_temp = 0 WHERE rfid_uid = ?",
                 (name, role, uid))
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
    rows = conn.execute("SELECT * FROM users ORDER BY id DESC").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def open_log_exists(user_id):
    conn = get_conn()
    row = conn.execute("SELECT id FROM logs WHERE user_id = ? AND time_out IS NULL",
                       (user_id,)).fetchone()
    conn.close()
    return row is not None


def record_tap(uid, mode, limit_hours):
    """Apply one tap atomically and return its result code and user row."""
    conn = get_conn()
    try:
        conn.execute("BEGIN IMMEDIATE")
        user = conn.execute("SELECT * FROM users WHERE rfid_uid = ?", (uid,)).fetchone()
        if user is None:
            conn.execute("COMMIT")
            return "DENY_UNKNOWN", None

        now = school_now()
        now_text = now.strftime("%Y-%m-%d %H:%M:%S")
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

        if mode == "OUT":
            if open_record is None:
                conn.execute(
                    "INSERT INTO events (user_id, event, at) VALUES (?, 'NO_OPEN_RECORD', ?)",
                    (user["id"], now_text),
                )
                result = "REJECT_NO_OPEN_RECORD"
            else:
                flag = open_record["flag"]
                if open_record["expected_out"] and now_text > open_record["expected_out"]:
                    flag = "OVERSTAY"
                conn.execute("UPDATE logs SET time_out = ?, flag = ? WHERE id = ?",
                             (now_text, flag, open_record["id"]))
                result = "TIME_OUT_OK"
        elif open_record is None:
            expected_out = None
            if user["role"] == "visitor":
                expected_out = (now + timedelta(hours=limit_hours)).strftime("%Y-%m-%d %H:%M:%S")
            conn.execute(
                "INSERT INTO logs (user_id, time_in, expected_out) VALUES (?, ?, ?)",
                (user["id"], now_text, expected_out),
            )
            result = "TIME_IN_OK"
        elif open_record["expected_out"] and now_text > open_record["expected_out"]:
            conn.execute("UPDATE logs SET flag = 'OVERSTAY' WHERE id = ?",
                         (open_record["id"],))
            result = "VISIT_LIMIT_EXCEEDED"
        else:
            result = "ALREADY_CHECKED_IN"

        conn.execute("COMMIT")
        return result, user
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

def log_time_in(user_id):
    conn = get_conn()
    conn.execute("INSERT INTO logs (user_id, time_in) VALUES (?, datetime('now','localtime'))",
                 (user_id,))
    conn.commit()
    conn.close()

def log_time_out(user_id):
    conn = get_conn()
    conn.execute("UPDATE logs SET time_out = datetime('now','localtime') "
                 "WHERE user_id = ? AND time_out IS NULL", (user_id,))
    conn.commit()
    conn.close()

def get_recent_logs(limit=30):
    conn = get_conn()
    rows = conn.execute("""
        SELECT u.name, u.role, l.time_in, l.time_out, l.flag
        FROM logs l JOIN users u ON u.id = l.user_id
        ORDER BY l.id DESC LIMIT ?
    """, (limit,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]
