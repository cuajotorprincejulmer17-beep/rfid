-- RFID readers and the raw tap audit trail.
CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE COLLATE NOCASE,
    name TEXT NOT NULL,
    location TEXT,
    key_hash TEXT UNIQUE,
    mode TEXT NOT NULL DEFAULT 'KIOSK' CHECK (mode IN ('IN', 'OUT', 'KIOSK')),
    armed_until REAL NOT NULL DEFAULT 0,
    last_seen TEXT,
    ip TEXT,
    rssi INTEGER,
    firmware TEXT,
    queue_len INTEGER,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
);

-- Taps posted to the original /tap route (no key) belong to this reader.
INSERT OR IGNORE INTO devices (code, name, location, mode, created_at)
VALUES ('DEFAULT', 'Main gate (legacy /tap)', 'Main gate', 'KIOSK', datetime('now', '+8 hours'));

CREATE TABLE IF NOT EXISTS tap_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    uid TEXT NOT NULL,
    user_id INTEGER,
    result_code TEXT NOT NULL,
    status TEXT NOT NULL,
    action TEXT,
    message TEXT,
    name TEXT,
    role TEXT,
    log_id INTEGER,
    client_event_id TEXT,
    tapped_at TEXT NOT NULL,
    received_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_tap_client_event
    ON tap_events (device_id, client_event_id) WHERE client_event_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tap_events_device ON tap_events (device_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_tap_events_uid ON tap_events (uid, id DESC);
CREATE INDEX IF NOT EXISTS idx_logs_device ON logs (device_id);
