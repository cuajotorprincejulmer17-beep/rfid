#!/usr/bin/env python3
"""Fills an EMPTY database with a realistic demo school, for the defence or for testing.

  set RFID_DB=demo.db            (Windows; use export on macOS/Linux)
  python tools/seed_demo.py

It refuses to run on a database that already has cards, so it can never mix
demo data into the real attendance records. It prints the demo staff
passwords, the reader keys and one student's app activation code.
"""
import argparse
import os
import random
import secrets
import sys
from datetime import datetime, timedelta

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import config  # noqa: E402,F401
import database as db  # noqa: E402
import migrations  # noqa: E402
from api.schema import init_api_schema  # noqa: E402

FMT = db.FMT
rng = random.Random(2026)

FIRST = ["Juan", "Maria", "Jose", "Ana", "Mark", "Angel", "John", "Princess", "Carlo", "Kim", "Paolo", "Bea",
         "Miguel", "Sofia", "Rafael", "Camille", "Gabriel", "Nicole", "Daniel", "Patricia", "Joshua", "Andrea",
         "Kevin", "Trisha", "Christian", "Jasmine", "Ryan", "Erika", "Vincent", "Hannah"]
LAST = ["Dela Cruz", "Santos", "Reyes", "Garcia", "Mendoza", "Torres", "Flores", "Gonzales", "Bautista", "Villanueva",
        "Ramos", "Castillo", "Aquino", "Navarro", "Rivera", "Domingo", "Mercado", "Aguilar", "Pascual", "Salazar"]

STAFF = [("admin", "School Administrator", "admin"), ("registrar", "Liza Manalo", "registrar"),
         ("teacher", "Ramon Cruz", "teacher"), ("guard", "Pedro Bautista", "guard")]
SECTIONS = [("BSIT - 2A", "BS Information Technology", 2), ("BSCS - 1B", "BS Computer Science", 1),
            ("BSED - 3A", "BS Secondary Education", 3)]
SUBJECTS = [("IT201", "Data Structures", 3), ("IT202", "Web Development", 3), ("CS101", "Intro to Computing", 3),
            ("MATH1", "Discrete Mathematics", 3), ("GE5", "Purposive Communication", 3), ("PE3", "Physical Education", 2),
            ("ED301", "Assessment of Learning", 3)]
ROOMS = [("R101", "Room 101", "Main Building", 1, 40, ["Projector", "Whiteboard"]),
         ("R204", "Room 204", "Main Building", 2, 45, ["Projector", "Aircon"]),
         ("LAB1", "Computer Lab 1", "IT Building", 1, 35, ["Computers", "Aircon", "Projector"]),
         ("LAB2", "Computer Lab 2", "IT Building", 2, 35, ["Computers", "Aircon"]),
         ("GYM", "Gymnasium", "Sports Complex", 1, 400, ["Sound system"]),
         ("LIB", "Library Reading Hall", "Library", 1, 80, ["Wi-Fi", "Aircon"])]
# (section index, subject code, room code, weekdays, start, end)
TIMETABLE = [(0, "IT201", "LAB1", (1, 3), "08:00", "09:30"), (0, "IT202", "LAB2", (2, 4), "09:30", "11:00"),
             (0, "MATH1", "R204", (1, 3, 5), "13:00", "14:00"), (0, "GE5", "R101", (2, 4), "14:00", "15:30"),
             (0, "PE3", "GYM", (5,), "08:00", "10:00"),
             (1, "CS101", "LAB1", (2, 4), "08:00", "09:30"), (1, "MATH1", "R101", (1, 3, 5), "10:00", "11:00"),
             (1, "GE5", "R204", (1, 3), "13:00", "14:30"), (1, "PE3", "GYM", (2,), "15:00", "17:00"),
             (2, "ED301", "R204", (1, 3), "08:00", "09:30"), (2, "GE5", "R101", (2, 4), "10:00", "11:30"),
             (2, "MATH1", "R101", (5,), "13:00", "15:00")]
MAP = [("Main Gate", "gate", 40, 860, 120, 60, None), ("Main Building", "building", 80, 520, 360, 220, "R204"),
       ("IT Building", "building", 520, 520, 300, 200, "LAB1"), ("Library", "building", 520, 260, 220, 160, "LIB"),
       ("Gymnasium", "facility", 80, 160, 340, 240, "GYM"), ("Canteen", "facility", 800, 260, 160, 140, None),
       ("Football Field", "field", 460, 20, 500, 200, None), ("Parking", "parking", 820, 820, 160, 140, None)]
DIRECTORY = [("Liza Manalo", "Registrar", "Registrar's Office", "registrar@school.edu.ph", "(02) 8123 4501", "Main Bldg 101"),
             ("Dr. Elena Ramos", "Dean", "College of Computing", "dean.cc@school.edu.ph", "(02) 8123 4510", "IT Bldg 201"),
             ("Ramon Cruz", "Instructor", "College of Computing", "rcruz@school.edu.ph", None, "IT Bldg Faculty"),
             ("Grace Lim", "Guidance Counselor", "Guidance Office", "guidance@school.edu.ph", "(02) 8123 4520", "Main Bldg 105"),
             ("Nurse Joy Santos", "School Nurse", "Clinic", "clinic@school.edu.ph", "(02) 8123 4530", "Main Bldg 102"),
             ("Pedro Bautista", "Head Guard", "Security", None, "0917 000 1111", "Main Gate"),
             ("Library Desk", "Librarian", "Library", "library@school.edu.ph", "(02) 8123 4540", "Library"),
             ("IT Helpdesk", "Support", "MIS Office", "helpdesk@school.edu.ph", "(02) 8123 4550", "IT Bldg 105")]
BOOKS = [("Clean Code", "Robert C. Martin", "QA76 .M37", 2, 1), ("Introduction to Algorithms", "Cormen et al.", "QA76 .C67", 3, 1),
         ("Eloquent JavaScript", "Marijn Haverbeke", "QA76 .H38", 2, 0), ("Discrete Mathematics", "Kenneth Rosen", "QA39 .R67", 4, 0),
         ("The Pragmatic Programmer", "Hunt & Thomas", "QA76 .H86", 1, 1), ("Noli Me Tangere", "Jose Rizal", "PL6058 .R5", 5, 0),
         ("Assessment of Learning 1", "Navarro & Santos", "LB3051 .N38", 2, 0), ("Database System Concepts", "Silberschatz", "QA76 .S55", 2, 0),
         ("Python Crash Course", "Eric Matthes", "QA76 .M38", 2, 1), ("El Filibusterismo", "Jose Rizal", "PL6058 .R6", 4, 0)]
FAQ = [("How do I time in?", "Tap your RFID card on the reader at the gate. The LCD shows TIME IN with the time."),
       ("How do I time out?", "Press the TIME OUT button on the kiosk screen, then tap your card within 15 seconds. "
        "At gates with an exit reader, just tap the exit reader."),
       ("What if I forgot to time out?", "Your day is marked incomplete. Ask the registrar to correct the record."),
       ("I lost my RFID card.", "Report it at the Registrar's Office right away so the card can be blocked and replaced."),
       ("When am I marked late?", "When you time in more than 15 minutes after the 7:30 AM start."),
       ("How do I excuse an absence?", "Open Attendance in the app and send an excuse letter. Your adviser reviews it.")]
ASSIST = [("ID and RFID card", "Lost, damaged or unregistered cards.", "id"),
          ("Attendance records", "Missing time in or time out, wrong status.", "calendar"),
          ("Health and clinic", "Clinic visits and medical excuses.", "health"),
          ("Guidance", "Counselling and student concerns.", "help"),
          ("IT helpdesk", "App sign-in, Wi-Fi and lab computers.", "it")]


def ts(dt):
    return dt.strftime(FMT)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--force", action="store_true", help="Seed even though cards already exist (never on real data).")
    p.add_argument("--students", type=int, default=30)
    a = p.parse_args()

    db.init_db()
    init_api_schema()
    migrations.migrate()
    from werkzeug.security import generate_password_hash
    from services import devices
    from api.auth import code_hash, new_claim_code

    c = db.get_conn()
    if c.execute("SELECT COUNT(*) FROM users").fetchone()[0] and not a.force:
        sys.exit(f"{db.DB_NAME} already has cards. Seed an empty database (set RFID_DB) or pass --force.")
    now = db.school_now().replace(tzinfo=None, microsecond=0)
    today = now.date()
    c.execute("BEGIN IMMEDIATE")

    out = {"staff": [], "readers": []}
    staff_ids = {}
    for username, name, role in STAFF:
        pw = f"demo-{username}-{secrets.token_hex(2)}"
        cur = c.execute("""INSERT OR IGNORE INTO staff_accounts (username, full_name, role, password_hash, created_at)
                           VALUES (?, ?, ?, ?, ?)""", (username, name, role, generate_password_hash(pw), ts(now)))
        if cur.rowcount:
            out["staff"].append((username, role, pw))
        staff_ids[role] = c.execute("SELECT id FROM staff_accounts WHERE username = ?", (username,)).fetchone()[0]

    for code, name, mode in (("GATE-1", "Main gate kiosk", "KIOSK"), ("EXIT-1", "Main gate exit", "OUT")):
        key = devices.new_key()
        cur = c.execute("""INSERT OR IGNORE INTO devices (code, name, location, mode, key_hash, created_at)
                           VALUES (?, ?, 'Main gate', ?, ?, ?)""", (code, name, mode, devices.hash_key(key), ts(now)))
        if cur.rowcount:
            out["readers"].append((code, mode, key))
    gate = c.execute("SELECT id FROM devices WHERE code = 'GATE-1'").fetchone()[0]


    start = today - timedelta(days=today.weekday() + 21)
    term = c.execute("INSERT INTO terms (name, start_date, end_date, active) VALUES (?, ?, ?, 1)",
                     (f"{today.year}-{today.year + 1} 1st Semester", start.isoformat(),
                      (start + timedelta(days=140)).isoformat())).lastrowid
    sec_ids = [c.execute("""INSERT INTO sections (term_id, name, course, year_level, adviser_staff_id, created_at)
                            VALUES (?, ?, ?, ?, ?, ?)""", (term, n, course, yl, staff_ids["teacher"], ts(now))).lastrowid
               for n, course, yl in SECTIONS]
    subj = {code: c.execute("INSERT INTO subjects (code, title, units) VALUES (?, ?, ?)", (code, t, u)).lastrowid
            for code, t, u in SUBJECTS}
    import json
    rooms = {code: c.execute("""INSERT INTO rooms (code, name, building, floor, capacity, services)
                                VALUES (?, ?, ?, ?, ?, ?)""", (code, n, b, f, cap, json.dumps(sv))).lastrowid
             for code, n, b, f, cap, sv in ROOMS}
    for si, code, room, days, t0, t1 in TIMETABLE:
        for wd in days:
            c.execute("""INSERT INTO class_schedules (section_id, subject_id, teacher_staff_id, room_id, weekday,
                         start_time, end_time) VALUES (?, ?, ?, ?, ?, ?, ?)""",
                      (sec_ids[si], subj[code], staff_ids["teacher"], rooms[room], wd, t0, t1))
    for n, kind, x, y, w, hgt, room in MAP:
        c.execute("""INSERT INTO map_places (name, kind, x, y, width, height, room_id) VALUES (?, ?, ?, ?, ?, ?, ?)""",
                  (n, kind, x, y, w, hgt, rooms.get(room)))
    for i, (n, role, dept, email, phone, office) in enumerate(DIRECTORY):
        c.execute("""INSERT INTO directory_entries (name, role, department, email, phone, office, sort_order)
                     VALUES (?, ?, ?, ?, ?, ?, ?)""", (n, role, dept, email, phone, office, i))
    for t, au, shelf, copies, featured in BOOKS:
        c.execute("INSERT INTO library_items (title, author, shelf, copies, featured) VALUES (?, ?, ?, ?, ?)",
                  (t, au, shelf, copies, featured))
    for i, (q, ans) in enumerate(FAQ):
        c.execute("INSERT INTO faq_items (question, answer, sort_order) VALUES (?, ?, ?)", (q, ans, i))
    for i, (t, d, icon) in enumerate(ASSIST):
        c.execute("INSERT INTO assistance_paths (title, description, icon, sort_order) VALUES (?, ?, ?, ?)", (t, d, icon, i))
    for i, (role, name, phone, notes) in enumerate([("Registrar", "Liza Manalo", "(02) 8123 4501", "Mon-Fri 8:00-17:00"),
                                                    ("Clinic", "Nurse Joy Santos", "(02) 8123 4530", "Open during classes"),
                                                    ("Security", "Main Gate Guard House", "0917 000 1111", "24 hours")]):
        c.execute("""INSERT INTO faculty_contacts (role, name, phone, notes, sort_order, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?)""", (role, name, phone, notes, i, ts(now)))
    for d_off, kind, note in ((7, "holiday", "Founding anniversary"), (12, "no_class", "Faculty development day")):
        c.execute("INSERT OR IGNORE INTO school_calendar (date, kind, note) VALUES (?, ?, ?)",
                  ((today + timedelta(days=d_off)).isoformat(), kind, note))

    # Students, cards, profiles and guardians.
    students = []
    for i in range(a.students):
        name = f"{FIRST[i % len(FIRST)]} {LAST[(i * 7) % len(LAST)]}"
        uid = secrets.token_hex(4).upper()
        sec = sec_ids[i % len(sec_ids)]
        user_id = c.execute("INSERT INTO users (rfid_uid, name, role, registered_at) VALUES (?, ?, 'student', ?)",
                            (uid, name, ts(now - timedelta(days=30)))).lastrowid
        sn = f"{today.year}-{i + 1:04d}"
        c.execute("""INSERT INTO student_profiles (user_id, student_number, course_section, phone, section_id, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?)""", (user_id, sn, SECTIONS[i % 3][0], f"0917{rng.randint(1000000, 9999999)}",
                                                   sec, ts(now)))
        if i % 3 == 0:
            c.execute("""INSERT INTO guardians (user_id, name, relation, phone, created_at) VALUES (?, ?, ?, ?, ?)""",
                      (user_id, f"Parent of {name.split()[0]}", rng.choice(["Mother", "Father", "Guardian"]),
                       f"+63917{rng.randint(1000000, 9999999)}", ts(now)))
        students.append((user_id, name, uid, sn, sec))
    visitor = c.execute("""INSERT INTO users (rfid_uid, name, role, time_limit_minutes, registered_at)
                           VALUES (?, 'Visitor Card 1', 'visitor', 240, ?)""", (secrets.token_hex(4).upper(), ts(now))).lastrowid

    # Three weeks of attendance on school days, ending yesterday.
    day = start
    while day < today:
        if day.isoweekday() <= 5:
            for idx, (user_id, *_rest) in enumerate(students):
                roll = rng.random()
                if roll < 0.06:
                    continue  # absent
                t_in = datetime.combine(day, datetime.min.time()) + timedelta(hours=7, minutes=rng.randint(0, 25))
                if roll > 0.88:
                    t_in += timedelta(minutes=rng.randint(20, 55))  # late
                t_out = datetime.combine(day, datetime.min.time()) + timedelta(hours=16, minutes=rng.randint(0, 80))
                missing = roll > 0.985
                c.execute("""INSERT INTO logs (user_id, time_in, time_out, flag, device_id) VALUES (?, ?, ?, ?, ?)""",
                          (user_id, ts(t_in), None if missing else ts(t_out), "MISSING_TIME_OUT" if missing else None,
                           gate))
        day += timedelta(days=1)
    c.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('last_close_date', ?)",
              ((today - timedelta(days=1)).isoformat(),))

    # Today: most of the first section is already in (only when the school day has started).
    if now.hour >= 7 and today.isoweekday() <= 5:
        for user_id, *_rest in students[:12]:
            t_in = datetime.combine(today, datetime.min.time()) + timedelta(hours=7, minutes=rng.randint(0, 40))
            if t_in < now:
                c.execute("INSERT INTO logs (user_id, time_in, device_id) VALUES (?, ?, ?)", (user_id, ts(t_in), gate))

    # Announcements, assignments, campus activity.
    for cat, title, body, sec in (("system", "Welcome to PULSE", "Attendance, schedules and school news are now in the app.", None),
                                  ("system", "Foundation Week", "Classes end at 12 NN on Friday for the opening program.", None),
                                  ("system", "Lab 3 moved", "IT202 lab on Thursday moves to Computer Lab 1.", sec_ids[0])):
        c.execute("""INSERT INTO announcements (category, title, body, audience, section_id, created_by, published_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?)""", (cat, title, body, "section" if sec else "all", sec,
                                                      staff_ids["registrar"], ts(now - timedelta(days=2))))
    for sec, title, course, days in ((sec_ids[0], "Linked list exercise", "IT201", 3), (sec_ids[0], "Portfolio site", "IT202", 9),
                                     (sec_ids[1], "Problem set 4", "MATH1", 2), (sec_ids[2], "Test blueprint", "ED301", 6)):
        c.execute("""INSERT INTO tasks (section_id, title, course, due_at, priority, created_by_staff, created_at)
                     VALUES (?, ?, ?, ?, 'high', ?, ?)""", (sec, title, course, ts(now + timedelta(days=days)),
                                                           staff_ids["teacher"], ts(now)))
    for kind, n, cat, loc, status in (("found", "Black umbrella", "other", "Gymnasium", "open"),
                                      ("found", "Student ID lace", "id", "Canteen", "open"),
                                      ("found", "Calculator (Casio fx-991)", "electronics", "Room 204", "open"),
                                      ("lost", "Blue water bottle", "other", "Library", "open")):
        c.execute("""INSERT INTO lost_found_items (kind, name, category, location, status, reported_by_user, reported_at,
                     updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                  (kind, n, cat, loc, status, students[1][0] if kind == "lost" else None,
                   ts(now - timedelta(days=1)), ts(now)))
    c.execute("""INSERT INTO excuse_requests (user_id, date, reason, created_at) VALUES (?, ?, ?, ?)""",
              (students[2][0], (today - timedelta(days=3)).isoformat(), "Fever; clinic slip attached at the registrar.", ts(now)))
    c.execute("""INSERT INTO support_tickets (user_id, subject, body, created_at) VALUES (?, ?, ?, ?)""",
              (students[3][0], "Card not reading", "My card sometimes shows ACCESS DENIED at the gate.", ts(now)))

    # One activation code so the app can be demonstrated immediately.
    demo = students[0]
    code = new_claim_code()
    c.execute("INSERT INTO claim_codes (user_id, code_hash, expires_at, created_at) VALUES (?, ?, ?, ?)",
              (demo[0], code_hash(demo[0], code), ts(now + timedelta(days=7)), ts(now)))
    c.execute("COMMIT")
    c.close()

    print(f"Demo school written to {db.DB_NAME}")
    print(f"  {len(students)} students in {len(SECTIONS)} sections, 1 visitor card (#{visitor}), 3 weeks of attendance.\n")
    print("Admin console staff (demo passwords):")
    for username, role, pw in out["staff"]:
        print(f"  {username:<10} {role:<10} {pw}")
    print("\nReader keys (put one in rfid_reader.ino; shown once):")
    for code_, mode, key in out["readers"]:
        print(f"  {code_:<7} {mode:<6} {key}")
    print("\nDemo student for the app:")
    print(f"  {demo[1]}  student number {demo[3]}  card {demo[2]}  activation code {code}")
    print("\nOther cards to tap (POST /tap):  " + ", ".join(s[2] for s in students[1:6]))



if __name__ == "__main__":
    main()
