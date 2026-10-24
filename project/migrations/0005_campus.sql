-- Content the student app reads: announcements, tasks, campus and support.
CREATE TABLE IF NOT EXISTS announcements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category TEXT NOT NULL CHECK (category IN ('system', 'emergency')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    audience TEXT NOT NULL DEFAULT 'all' CHECK (audience IN ('all', 'section')),
    section_id INTEGER,
    pinned INTEGER NOT NULL DEFAULT 0,
    created_by INTEGER,
    published_at TEXT NOT NULL
);

-- A task with user_id is a student's own; one with section_id is an
-- assignment a teacher posted to a section.
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    section_id INTEGER,
    title TEXT NOT NULL,
    course TEXT,
    due_at TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('high', 'medium', 'low')),
    created_by_staff INTEGER,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks (user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_section ON tasks (section_id);

CREATE TABLE IF NOT EXISTS task_completions (
    task_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    completed_at TEXT NOT NULL,
    PRIMARY KEY (task_id, user_id)
);

CREATE TABLE IF NOT EXISTS directory_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    role TEXT NOT NULL,
    department TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    office TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS map_places (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'building',
    x REAL NOT NULL,
    y REAL NOT NULL,
    width REAL NOT NULL,
    height REAL NOT NULL,
    room_id INTEGER,
    description TEXT
);

CREATE TABLE IF NOT EXISTS lost_found_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kind TEXT NOT NULL DEFAULT 'found' CHECK (kind IN ('lost', 'found')),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    location TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'claim_requested', 'claimed', 'closed')),
    reported_by_user INTEGER,
    claimed_by_user INTEGER,
    reported_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS library_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    shelf TEXT NOT NULL,
    copies INTEGER NOT NULL DEFAULT 1,
    featured INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS library_reservations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'borrowed', 'returned', 'cancelled')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_reservations_item ON library_reservations (item_id, status);

CREATE TABLE IF NOT EXISTS faq_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS assistance_paths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT NOT NULL DEFAULT 'help',
    sort_order INTEGER NOT NULL DEFAULT 0,
    active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS support_tickets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'answered', 'closed')),
    reply TEXT,
    replied_by INTEGER,
    replied_at TEXT,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tickets_user ON support_tickets (user_id);
