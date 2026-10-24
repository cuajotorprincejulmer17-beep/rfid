#!/usr/bin/env python3
"""Local maintenance on the server PC. Works on the database directly (no key needed).

  python tools/manage.py create-staff                 # asks for username, name, role, password
  python tools/manage.py create-staff admin "School Admin" --role admin
  python tools/manage.py list-staff
  python tools/manage.py reset-password <username>
  python tools/manage.py add-reader GATE-1 "Main gate" --mode KIOSK     # prints the reader key once
  python tools/manage.py migrate                      # apply pending database migrations
  python tools/manage.py backup                       # copy the database to backups/
  python tools/manage.py close-day [YYYY-MM-DD]       # run the end-of-day close now
"""
import argparse
import getpass
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import config  # noqa: E402,F401
import database as db  # noqa: E402
import migrations  # noqa: E402
from api.schema import init_api_schema  # noqa: E402


def setup():
    db.init_db()
    init_api_schema()
    applied = migrations.migrate()
    if applied:
        print(f"Applied migrations: {applied}")


def ask(prompt, default=None):
    value = input(f"{prompt}{f' [{default}]' if default else ''}: ").strip()
    return value or default


def new_password(label="Password"):
    while True:
        pw = getpass.getpass(f"{label} (8+ characters): ")
        if len(pw) < 8:
            print("Too short.")
            continue
        if getpass.getpass("Repeat: ") != pw:
            print("They do not match.")
            continue
        return pw


def cmd_create_staff(a):
    from api.common import ApiError
    from api.staff_auth import create_staff
    username = a.username or ask("Username")
    full_name = a.full_name or ask("Full name")
    role = a.role or ask("Role (admin/registrar/teacher/guard)", "admin")
    password = a.password or new_password()
    conn = db.get_conn()
    try:
        conn.execute("BEGIN IMMEDIATE")
        create_staff(conn, username, full_name, role, password)
        conn.execute("COMMIT")
    except ApiError as e:
        conn.execute("ROLLBACK")
        sys.exit(f"Error: {e.message}")
    finally:
        conn.close()
    print(f"Created {role} '{username}'. Sign in at http://<this PC>:{config.PORT}/admin")


def cmd_list_staff(_a):
    conn = db.get_conn()
    rows = conn.execute("SELECT username, full_name, role, active, last_login FROM staff_accounts ORDER BY role, username")
    for r in rows:
        print(f"{r['username']:<16} {r['role']:<10} {'active' if r['active'] else 'disabled':<9} "
              f"{r['full_name']}  (last sign-in: {r['last_login'] or 'never'})")
    conn.close()


def cmd_reset_password(a):
    from werkzeug.security import generate_password_hash
    pw = new_password("New password")
    conn = db.get_conn()
    n = conn.execute("UPDATE staff_accounts SET password_hash = ?, active = 1 WHERE username = ?",
                     (generate_password_hash(pw), a.username)).rowcount
    conn.execute("UPDATE staff_sessions SET revoked = 1 WHERE staff_id = (SELECT id FROM staff_accounts WHERE username = ?)",
                 (a.username,))
    conn.close()
    print("Password changed." if n else f"No staff account '{a.username}'.")


def cmd_add_reader(a):
    from services import devices
    key = devices.new_key()
    conn = db.get_conn()
    try:
        conn.execute("""INSERT INTO devices (code, name, location, mode, key_hash, created_at)
                        VALUES (?, ?, ?, ?, ?, ?)""", (a.code.upper(), a.name, a.location, a.mode,
                                                      devices.hash_key(key), db.school_now().strftime(db.FMT)))
    except sqlite3.IntegrityError:
        sys.exit(f"A reader with code {a.code.upper()} already exists. Rotate its key in the admin console.")
    finally:
        conn.close()
    print("Reader created. Put these lines in rfid_reader/rfid_reader.ino (shown once):\n")
    print(f'const char* DEVICE_CODE = "{a.code.upper()}";')
    print(f'const char* DEVICE_KEY  = "{key}";')


def cmd_migrate(_a):
    print(f"Database: {db.DB_NAME}")
    print("Up to date." if not migrations.migrate() else "Done.")


def cmd_backup(_a):
    print(f"Backup written to {migrations.backup('manual')}")


def cmd_close_day(a):
    from datetime import date
    from jobs import scheduler
    day = date.fromisoformat(a.date) if a.date else db.school_now().date()
    result = scheduler.close_day(day)
    from api import push
    push.drain(20)
    print(f"{day}: {len(result['missing_time_out'])} missing time out, {len(result['absent'])} absent.")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("create-staff")
    s.add_argument("username", nargs="?")
    s.add_argument("full_name", nargs="?")
    s.add_argument("--role", choices=["admin", "registrar", "teacher", "guard"])
    s.add_argument("--password", help="Avoid on shared PCs: it stays in the shell history.")
    sub.add_parser("list-staff")
    s = sub.add_parser("reset-password")
    s.add_argument("username")
    s = sub.add_parser("add-reader")
    s.add_argument("code")
    s.add_argument("name")
    s.add_argument("--location")
    s.add_argument("--mode", choices=["KIOSK", "IN", "OUT"], default="KIOSK")
    sub.add_parser("migrate")
    sub.add_parser("backup")
    s = sub.add_parser("close-day")
    s.add_argument("date", nargs="?")
    a = p.parse_args()
    if a.cmd != "backup":
        setup()
    {"create-staff": cmd_create_staff, "list-staff": cmd_list_staff, "reset-password": cmd_reset_password,
     "add-reader": cmd_add_reader, "migrate": cmd_migrate, "backup": cmd_backup,
     "close-day": cmd_close_day}[a.cmd](a)


if __name__ == "__main__":
    main()
