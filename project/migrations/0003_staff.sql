-- Staff accounts for the admin console and the admin API.
CREATE TABLE IF NOT EXISTS staff_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'registrar', 'teacher', 'guard')),
    email TEXT,
    phone TEXT,
    password_hash TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    last_login TEXT
);

CREATE TABLE IF NOT EXISTS staff_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    staff_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_staff_sessions_staff ON staff_sessions (staff_id);

-- Who changed what in the admin console.
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    staff_id INTEGER,
    action TEXT NOT NULL,
    detail TEXT,
    at TEXT NOT NULL
);
