-- School structure, attendance policy and excuse letters.
CREATE TABLE IF NOT EXISTS terms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    term_id INTEGER,
    name TEXT NOT NULL,
    course TEXT,
    year_level INTEGER,
    adviser_staff_id INTEGER,
    created_at TEXT NOT NULL,
    UNIQUE (term_id, name)
);

CREATE TABLE IF NOT EXISTS subjects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE COLLATE NOCASE,
    title TEXT NOT NULL,
    units REAL
);

CREATE TABLE IF NOT EXISTS rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE COLLATE NOCASE,
    name TEXT NOT NULL,
    building TEXT NOT NULL,
    floor INTEGER NOT NULL DEFAULT 1,
    capacity INTEGER NOT NULL DEFAULT 0,
    services TEXT,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS class_schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    section_id INTEGER NOT NULL,
    subject_id INTEGER NOT NULL,
    teacher_staff_id INTEGER,
    room_id INTEGER,
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'class' CHECK (kind IN ('class', 'exam', 'event')),
    note TEXT
);
CREATE INDEX IF NOT EXISTS idx_schedules_section ON class_schedules (section_id, weekday);

-- Key/value settings: attendance policy, job bookkeeping.
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
INSERT OR IGNORE INTO settings (key, value) VALUES ('school_start', '07:30');
INSERT OR IGNORE INTO settings (key, value) VALUES ('late_after_minutes', '15');
INSERT OR IGNORE INTO settings (key, value) VALUES ('cutoff', '18:00');
INSERT OR IGNORE INTO settings (key, value) VALUES ('school_days', '1,2,3,4,5');
INSERT OR IGNORE INTO settings (key, value) VALUES ('visitor_limit_hours', '4');
INSERT OR IGNORE INTO settings (key, value) VALUES ('notify_absences', '1');
INSERT OR IGNORE INTO settings (key, value) VALUES ('sms_events', 'in,out,absent');

CREATE TABLE IF NOT EXISTS school_calendar (
    date TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('holiday', 'no_class', 'special')),
    note TEXT
);

ALTER TABLE student_profiles ADD COLUMN section_id INTEGER;

CREATE TABLE IF NOT EXISTS excuse_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    date TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    review_note TEXT,
    reviewed_by INTEGER,
    reviewed_at TEXT,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_excuses_user ON excuse_requests (user_id, date);
