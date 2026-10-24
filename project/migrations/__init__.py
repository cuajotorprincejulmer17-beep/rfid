"""Numbered, additive schema migrations.

Version 1 is the baseline that `database.init_db()` and
`api.schema.init_api_schema()` already create. Every later change is a file
`NNNN_name.sql` in this folder, applied once, in order, inside one
transaction, and recorded in `schema_version`.

Before an existing database (one with users) is upgraded, a copy is written
to BACKUP_DIR so a bad migration can never lose attendance data.
"""
import logging
import os
import re
import sqlite3
from datetime import datetime

import config
import database as db

log = logging.getLogger("migrations")
HERE = os.path.dirname(os.path.abspath(__file__))
BASELINE = 1


def _files():
    out = []
    for name in sorted(os.listdir(HERE)):
        m = re.fullmatch(r"(\d{4})_[a-z0-9_]+\.sql", name)
        if m:
            out.append((int(m.group(1)), os.path.join(HERE, name)))
    return out


def current_version(conn):
    conn.execute("""CREATE TABLE IF NOT EXISTS schema_version (
                        version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL)""")
    row = conn.execute("SELECT MAX(version) FROM schema_version").fetchone()
    if row[0] is None:
        conn.execute("INSERT INTO schema_version (version, name, applied_at) VALUES (?, 'baseline', ?)",
                     (BASELINE, db.school_now().strftime(db.FMT)))
        return BASELINE
    return row[0]


def pending(conn):
    version = current_version(conn)
    return [(v, path) for v, path in _files() if v > version]


def backup(reason="pre-migration"):
    """Copies the live database with SQLite's online backup API. Returns the path."""
    os.makedirs(config.BACKUP_DIR, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    target = os.path.join(config.BACKUP_DIR, f"rfid_system-{stamp}-{reason}.db")
    src = sqlite3.connect(db.DB_NAME)
    dst = sqlite3.connect(target)
    try:
        src.backup(dst)
    finally:
        dst.close()
        src.close()
    return target


def migrate():
    """Applies every pending migration. Returns the list of versions applied."""
    conn = db.get_conn()
    try:
        todo = pending(conn)
        if not todo:
            return []
        has_data = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] > 0
        if has_data:
            log.warning("backing up database before migration: %s", backup())
        applied = []
        for version, path in todo:
            with open(path, encoding="utf-8") as fh:
                sql = fh.read()
            name = os.path.basename(path)[5:-4]
            conn.execute("BEGIN IMMEDIATE")
            try:
                for stmt in _split(sql):
                    conn.execute(stmt)
                conn.execute("INSERT INTO schema_version (version, name, applied_at) VALUES (?, ?, ?)",
                             (version, name, db.school_now().strftime(db.FMT)))
                conn.execute("COMMIT")
            except Exception:
                conn.execute("ROLLBACK")
                raise
            applied.append(version)
            log.info("applied migration %04d_%s", version, name)
        return applied
    finally:
        conn.close()


def _split(sql):
    """Splits a migration into statements. Comments start with --."""
    lines = [ln for ln in sql.splitlines() if not ln.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]
