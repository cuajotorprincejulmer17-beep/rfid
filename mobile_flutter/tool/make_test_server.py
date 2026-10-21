#!/usr/bin/env python3
"""Set up an ISOLATED copy of the PULSE server for testing the Flutter app.

Why this exists
---------------
`project/rfid_system.db` is the school's real database. The Flutter app is
read-only for attendance, but signing in and tapping still write rows
(users, sessions, attendance logs, notifications). To test safely, this
script:

  1. copies the server code to a temp folder (NO database file),
  2. starts it on port 5001 with a throwaway ADMIN_API_KEY,
  3. creates a test student and a one-time claim code,
  4. prints the student number, claim code and password to sign in with.

Your real database in `project/rfid_system.db` is never opened or modified.

Usage
-----
    python tools/make_test_server.py          # start + seed, print credentials
    python tools/make_test_server.py --stop   # stop the test server
    python tools/make_test_server.py --clean  # stop + delete everything
"""

import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(REPO, "project")
PORT = 5001
BASE = f"http://127.0.0.1:{PORT}/api/v1"
ADMIN_KEY = "test-only-admin-key-1234567890"

STUDENT_NUMBER = "2026-0001"
PASSWORD = "pulse-test-1234"

# Where the run state is kept, so --stop and --clean can find it again.
STATE_DIR = os.path.join(tempfile.gettempdir(), "pulse_test_server")
STATE_FILE = os.path.join(STATE_DIR, "test_server.json")


def say(msg):
    print(msg)


def api(method, path, body=None, admin=False, timeout=15, root=False):
    """Call the local server and return the parsed JSON body.

    [root] True targets the app root (e.g. /users) instead of /api/v1.
    """
    base = f"http://127.0.0.1:{PORT}" if root else BASE
    headers = {"Content-Type": "application/json"}
    if admin:
        headers["X-Admin-Key"] = ADMIN_KEY
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read().decode())
        except Exception:
            return {"http_error": e.code}


def is_up():
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{PORT}/api/v1/health", timeout=4)
        return True
    except Exception:
        return False


def copy_server():
    """Copy the server code into the temp folder, without any database.

    The test database is kept across restarts, so `--stop` then a fresh start
    still has the same student and the same attendance. `--clean` wipes it.
    """
    # The database lives in a sibling folder so that wiping the code folder
    # cannot take the data with it.
    data_dir = os.path.join(STATE_DIR, "data")
    db_path = os.path.join(data_dir, "rfid_system.db")
    os.makedirs(data_dir, exist_ok=True)
    if os.path.isfile(db_path):
        say("  keeping the existing test database")
    else:
        say("  starting with a fresh, empty test database")

    code_dir = os.path.join(STATE_DIR, "code")
    if os.path.isdir(code_dir):
        shutil.rmtree(code_dir, ignore_errors=True)
    os.makedirs(code_dir, exist_ok=True)

    for name in ("app.py", "database.py", "app_ui.py", "student_display.py"):
        src = os.path.join(SOURCE, name)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(code_dir, name))

    for folder in ("api", "tools"):
        src = os.path.join(SOURCE, folder)
        if os.path.isdir(src):
            shutil.copytree(
                src,
                os.path.join(code_dir, folder),
                ignore=shutil.ignore_patterns("__pycache__"),
            )

    say(f"  copied server code to {code_dir}")
    say(f"  the test database lives in {data_dir} (your project/ database is never touched)")


def start_server():
    env = dict(os.environ)
    env["ADMIN_API_KEY"] = ADMIN_KEY
    env["PYTHONUNBUFFERED"] = "1"

    code_dir = os.path.join(STATE_DIR, "code")
    data_dir = os.path.join(STATE_DIR, "data")

    # The server opens "rfid_system.db" relative to its working directory, so
    # the working directory is the data folder. The code is found through
    # PYTHONPATH instead.
    env["PYTHONPATH"] = code_dir + os.pathsep + env.get("PYTHONPATH", "")

    log = open(os.path.join(STATE_DIR, "server.log"), "w", encoding="utf-8")
    proc = subprocess.Popen(
        [sys.executable, os.path.join(code_dir, "app.py")],
        cwd=data_dir,
        env=env,
        stdout=log,
        stderr=subprocess.STDOUT,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    )

    for _ in range(40):
        time.sleep(0.5)
        if is_up():
            say(f"  server is up on port {PORT} (pid {proc.pid})")
            return proc
        if proc.poll() is not None:
            say("  the server exited. Log:")
            with open(os.path.join(STATE_DIR, "server.log"), encoding="utf-8") as f:
                say("  " + f.read()[-2000:])
            sys.exit(1)

    say("  the server did not start in time. Log:")
    with open(os.path.join(STATE_DIR, "server.log"), encoding="utf-8") as f:
        say("  " + f.read()[-2000:])
    sys.exit(1)


def seed():
    """Create a student and a claim code, using the real admin endpoints.

    Safe to run twice: if the student already exists, the existing account is
    reused instead of failing.
    """
    say("  seeding a test student...")

    # 1. Register the RFID card as a student. This is the app-root
    #    POST /users endpoint, which takes the card uid.
    card_uid = "000000000001"
    created = api(
        "POST",
        "/users",
        {"uid": card_uid, "name": "Test Student", "role": "student"},
        root=True,
    )
    if created.get("success"):
        say(f"    registered card {card_uid} as a student")
    else:
        say(f"    card {card_uid} already registered")

    # 2. Find the user id from the admin students list.
    students = api("GET", "/admin/students", admin=True)
    user_id = None
    for row in students.get("items", []):
        if row.get("student_number") == STUDENT_NUMBER:
            user_id = row.get("user_id")
            break
    if user_id is None:
        for row in students.get("items", []):
            if row.get("student_number") is None:
                user_id = row.get("user_id")
                break
    if user_id is None:
        say(f"    could not find the new student: {students}")
        sys.exit(1)
    say(f"    user_id = {user_id}")

    # 3. Give it a student number.
    profile = api(
        "PUT",
        f"/admin/students/{user_id}/profile",
        {"student_number": STUDENT_NUMBER, "course_section": "BSCS-1A"},
        admin=True,
    )
    if "error" in profile:
        say(f"    set-profile failed: {profile}")
        sys.exit(1)

    # 4. If the account is already claimed, the password still works, so
    #    there is nothing more to do.
    for row in students.get("items", []):
        if row.get("user_id") == user_id and row.get("claimed"):
            say("    account already exists and is claimed")
            return {
                "student_number": STUDENT_NUMBER,
                "claim_code": "(already claimed)",
                "password": PASSWORD,
                "user_id": user_id,
                "card_uid": card_uid,
            }

    # 5. Issue a one-time claim code.
    code_resp = api(
        "POST",
        f"/admin/students/{user_id}/claim-code",
        {"expires_hours": 72},
        admin=True,
    )
    claim_code = code_resp.get("claim_code")
    if not claim_code:
        say(f"    claim-code failed: {code_resp}")
        sys.exit(1)
    say(f"    claim code = {claim_code}")

    # 6. Claim the account so it can sign in with a password.
    claim = api(
        "POST",
        "/auth/claim",
        {
            "student_number": STUDENT_NUMBER,
            "claim_code": claim_code,
            "password": PASSWORD,
        },
    )
    if "error" in claim:
        say(f"    claim failed: {claim}")
        sys.exit(1)
    say("    account claimed")

    return {
        "student_number": STUDENT_NUMBER,
        "claim_code": claim_code,
        "password": PASSWORD,
        "user_id": user_id,
        "card_uid": card_uid,
    }


def simulate_tap(card="000000000001"):
    """Post a fake RFID tap, exactly like the reader does."""
    say("  simulating an RFID tap...")
    res = api("POST", "/tap", {"uid": card}, root=True)
    say(f"    tap response: {json.dumps(res)[:300]}")
    return res


def write_state(creds, proc):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(
            {
                "pid": proc.pid,
                "port": PORT,
                "student_number": creds["student_number"],
                "password": creds["password"],
                "admin_key": ADMIN_KEY,
                "dir": STATE_DIR,
            },
            f,
            indent=2,
        )


def read_state():
    if not os.path.isfile(STATE_FILE):
        return None
    with open(STATE_FILE, encoding="utf-8") as f:
        return json.load(f)


def kill_port_owner(port=PORT):
    """Kill whatever process is listening on [port].

    The server writes its pid to the state file, but a crash or a hard kill
    can leave an orphan behind. This finds it by port instead.
    """
    if os.name != "nt":
        return
    try:
        import subprocess as sp

        out = sp.run(
            ["netstat", "-ano", "-p", "TCP"],
            capture_output=True,
            text=True,
            timeout=15,
        ).stdout
    except Exception:
        return

    pids = set()
    for line in out.splitlines():
        if f":{port}" not in line or "LISTENING" not in line.upper():
            continue
        parts = line.split()
        if len(parts) >= 5 and parts[-1].isdigit():
            pids.add(int(parts[-1]))

    for pid in pids:
        try:
            os.kill(pid, 15)
            say(f"  stopped the process on port {port} (pid {pid})")
        except OSError:
            pass


def stop_server():
    state = read_state()
    if state:
        pid = state.get("pid")
        if pid:
            try:
                os.kill(pid, 15)
                say(f"  stopped pid {pid}")
            except OSError:
                say(f"  pid {pid} was not running")
        if os.path.isfile(STATE_FILE):
            os.remove(STATE_FILE)
    kill_port_owner()


def clean():
    stop_server()
    shutil.rmtree(STATE_DIR, ignore_errors=True)
    say(f"  deleted {STATE_DIR}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stop", action="store_true", help="stop the test server")
    parser.add_argument("--clean", action="store_true", help="stop and delete everything")
    parser.add_argument("--no-tap", action="store_true", help="skip the sample RFID tap")
    args = parser.parse_args()

    if args.clean:
        say("Cleaning up...")
        clean()
        return

    if args.stop:
        say("Stopping the test server...")
        stop_server()
        return

    if is_up():
        say(f"A server is already listening on port {PORT}.")
        say("Stop it first with:  python tools/make_test_server.py --stop")
        return

    say("Setting up an ISOLATED PULSE test server")
    say("  your real project/rfid_system.db is NOT touched")
    say("")
    copy_server()
    proc = start_server()
    creds = seed()
    if not args.no_tap:
        simulate_tap()
    write_state(creds, proc)

    say("")
    say("=" * 62)
    say("  TEST SERVER READY")
    say("=" * 62)
    say(f"  API URL (from the emulator) : http://10.0.2.2:{PORT}")
    say(f"  API URL (from this PC)       : http://127.0.0.1:{PORT}")
    say("")
    say(f"  Student number : {creds['student_number']}")
    say(f"  Password       : {creds['password']}")
    say("")
    say("  Sign in with those, then the app will show a 'Time in recorded'")
    say("  attendance card and an inbox row.")
    say("")
    say("  Stop the server : python tools/make_test_server.py --stop")
    say("  Delete it all   : python tools/make_test_server.py --clean")
    say("=" * 62)


if __name__ == "__main__":
    main()
