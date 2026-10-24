-- Parents and guardians, and the SMS messages sent to them.
CREATE TABLE IF NOT EXISTS guardians (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    relation TEXT,
    phone TEXT NOT NULL,
    sms_enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_guardians_user ON guardians (user_id);

CREATE TABLE IF NOT EXISTS sms_outbox (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    guardian_id INTEGER,
    phone TEXT NOT NULL,
    body TEXT NOT NULL,
    dedupe_key TEXT UNIQUE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'skipped')),
    provider TEXT,
    error TEXT,
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    sent_at TEXT
);
