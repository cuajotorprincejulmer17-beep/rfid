"""Tests for readers, staff, school structure, policy, reports, jobs and the student school API."""
import os
from contextlib import closing
from datetime import datetime, timedelta
from unittest import mock

from test_api import ADMIN, Base  # sets up the temporary database and env

import config
import database as db
from api import push
from jobs import scheduler
from services import attendance, devices, sms

TZ = db.SCHOOL_TZ


def at(text):
    """A fixed school-time moment, e.g. at('2026-10-20 07:52')."""
    return datetime.strptime(text, "%Y-%m-%d %H:%M").replace(tzinfo=TZ)


class SchoolBase(Base):
    EXTRA = ("staff_accounts", "staff_sessions", "audit_log", "terms", "sections", "subjects",
             "rooms", "class_schedules", "school_calendar", "excuse_requests", "announcements", "tasks",
             "task_completions", "directory_entries", "map_places", "lost_found_items", "library_items",
             "library_reservations", "faq_items", "assistance_paths", "support_tickets", "guardians",
             "sms_outbox")

    def setUp(self):
        super().setUp()
        with closing(db.get_conn()) as c:
            for t in self.EXTRA:
                c.execute(f"DELETE FROM {t}")
            c.execute("DELETE FROM devices WHERE code != 'DEFAULT'")
            c.execute("UPDATE devices SET armed_until = 0")
            c.execute("DELETE FROM settings WHERE key NOT IN "
                      "('school_start','late_after_minutes','cutoff','school_days','visitor_limit_hours',"
                      "'notify_absences','sms_events')")
            for k, v in attendance.DEFAULTS.items():
                attendance.set_setting(c, k, v)

    # ---- helpers
    def reader(self, code="GATE-1", mode="KIOSK"):
        r = self.admin("post", "/admin/devices", json={"code": code, "name": code, "mode": mode})
        self.assertEqual(r.status_code, 201, r.json)
        return {"id": r.json["id"], "key": r.json["device_key"]}

    def dtap(self, dev, uid, **extra):
        return self.cl.post("/api/v1/device/tap", json={"uid": uid, **extra}, headers={"X-Device-Key": dev["key"]})

    def staff(self, username="reg1", role="registrar", pw="staff-pass-1"):
        r = self.admin("post", "/admin/staff", json={"username": username, "full_name": username.title(),
                                                     "role": role, "password": pw})
        self.assertEqual(r.status_code, 201, r.json)
        r = self.cl.post("/api/v1/admin/auth/login", json={"username": username, "password": pw})
        self.assertEqual(r.status_code, 200, r.json)
        return {"Authorization": "Bearer " + r.json["token"]}

    def section(self, name="BSIT - 2A"):
        return self.admin("post", "/admin/sections", json={"name": name}).json["id"]

    def place_in(self, s, section_id):
        self.admin("put", f"/admin/students/{s['user_id']}/profile",
                   json={"student_number": s["sn"], "section_id": section_id})


class Readers(SchoolBase):
    def test_device_tap_needs_a_valid_key_and_returns_lcd_lines(self):
        dev = self.reader()
        self.student("AA11", claim=False)
        self.assertEqual(self.cl.post("/api/v1/device/tap", json={"uid": "AA11"}).status_code, 401)
        r = self.dtap(dev, "aa11")
        self.assertEqual(r.status_code, 200, r.json)
        self.assertEqual((r.json["result"], r.json["action"]), ("TIME_IN_OK", "IN"))
        self.assertEqual(r.json["lcd"][0], "Juan")
        self.assertTrue(r.json["lcd"][1].startswith(("TIME IN", "LATE IN")))
        self.assertTrue(all(len(line) <= 16 for line in r.json["lcd"]))
        r = self.dtap(dev, "FFFF")
        self.assertEqual((r.json["result"], r.json["lcd"]), ("DENY_UNKNOWN", ["ACCESS DENIED", "Not registered"]))

    def test_kiosk_arm_is_per_reader(self):
        gate, side = self.reader("GATE-1"), self.reader("SIDE-1")
        self.student("AA11", claim=False)
        self.student("BB22", name="Ana", sn="2023-0143", claim=False)
        self.dtap(gate, "AA11")
        self.dtap(side, "BB22")
        r = self.cl.post("/api/v1/device/arm-timeout", headers={"X-Device-Key": side["key"]})
        self.assertEqual(r.status_code, 200)
        # The arm on SIDE-1 must not turn a tap on GATE-1 into a time out.
        with mock.patch.object(devices, "DEBOUNCE_SECONDS", 0):
            self.assertEqual(self.dtap(gate, "AA11").json["result"], "ALREADY_CHECKED_IN")
            self.assertEqual(self.dtap(side, "BB22").json["result"], "TIME_OUT_OK")
            # The arm is used up by one tap.
            self.assertEqual(self.dtap(side, "BB22").json["result"], "TIME_IN_OK")

    def test_in_and_out_readers_need_no_button(self):
        entrance, exit_ = self.reader("IN-1", "IN"), self.reader("OUT-1", "OUT")
        self.student("AA11", claim=False)
        self.assertEqual(self.dtap(entrance, "AA11").json["result"], "TIME_IN_OK")
        self.assertEqual(self.dtap(exit_, "AA11").json["result"], "TIME_OUT_OK")
        r = self.cl.post("/api/v1/device/arm-timeout", headers={"X-Device-Key": entrance["key"]})
        self.assertEqual(r.status_code, 409)

    def test_debounce_and_offline_replay_are_recorded_once(self):
        dev = self.reader()
        self.student("AA11", claim=False)
        first = self.dtap(dev, "AA11", client_event_id="GATE-1-7").json
        held = self.dtap(dev, "AA11").json
        self.assertTrue(held["debounced"])
        self.assertEqual(held["result"], "TIME_IN_OK")
        replay = self.dtap(dev, "AA11", client_event_id="GATE-1-7").json
        self.assertTrue(replay["replayed"])
        self.assertEqual(replay["event_id"], first["event_id"])
        with closing(db.get_conn()) as c:
            self.assertEqual(c.execute("SELECT COUNT(*) FROM logs").fetchone()[0], 1)
            self.assertEqual(c.execute("SELECT COUNT(*) FROM tap_events").fetchone()[0], 1)

    def test_a_denied_card_is_checked_again_right_after_registration(self):
        dev = self.reader()
        self.assertEqual(self.dtap(dev, "AA11").json["result"], "DENY_UNKNOWN")
        self.student("AA11", claim=False)
        self.assertEqual(self.dtap(dev, "AA11").json["result"], "TIME_IN_OK")

    def test_replayed_tap_keeps_its_own_time(self):
        dev = self.reader("OUT-1", "IN")
        self.student("AA11", claim=False)
        when = (db.school_now() - timedelta(minutes=40)).replace(microsecond=0)
        self.dtap(dev, "AA11", client_event_id="x1", tapped_at=when.isoformat())
        with closing(db.get_conn()) as c:
            row = c.execute("SELECT time_in, device_id FROM logs").fetchone()
        self.assertEqual(row["time_in"], when.strftime(db.FMT))
        self.assertEqual(row["device_id"], dev["id"])
        # Implausible times are ignored rather than trusted.
        self.assertIsNone(devices._parse_tapped_at((db.school_now() + timedelta(hours=1)).isoformat()))
        self.assertIsNone(devices._parse_tapped_at("2001-01-01T00:00:00"))

    def test_heartbeat_display_event_and_admin_listing(self):
        dev = self.reader()
        self.student("AA11", claim=False)
        r = self.cl.post("/api/v1/device/heartbeat", json={"rssi": -60, "firmware": "2.0.0", "queue_len": 0},
                         headers={"X-Device-Key": dev["key"]})
        self.assertEqual(r.json["mode"], "KIOSK")
        self.dtap(dev, "AA11")
        ev = self.cl.get("/api/v1/device/display-event", headers={"X-Device-Key": dev["key"]}).json
        self.assertEqual((ev["result"], ev["name"]), ("TIME_IN_OK", "Juan"))
        listed = {d["code"]: d for d in self.admin("get", "/admin/devices").json["items"]}
        self.assertTrue(listed["GATE-1"]["online"])
        self.assertEqual(listed["GATE-1"]["firmware"], "2.0.0")
        self.assertNotIn("key_hash", listed["GATE-1"])
        self.assertIn("DEFAULT", listed)

    def test_rotated_key_replaces_the_old_one(self):
        dev = self.reader()
        new = self.admin("post", f"/admin/devices/{dev['id']}/rotate-key").json["device_key"]
        self.assertEqual(self.dtap(dev, "AA11").status_code, 401)
        self.assertEqual(self.dtap({"key": new}, "AA11").status_code, 200)

    def test_legacy_routes_use_the_default_reader_and_can_be_disabled(self):
        self.student("AA11", claim=False)
        self.tap("AA11")
        self.assertEqual(self.cl.get("/last-tap").json["uid"], "AA11")
        self.assertEqual(self.cl.get("/display-event").json["result"], "TIME_IN_OK")
        with mock.patch.object(config, "ALLOW_LEGACY_TAP", False):
            self.assertEqual(self.tap("AA11").status_code, 403)

    def test_keyless_card_routes_answer_only_the_server_pc(self):
        lan = {"REMOTE_ADDR": "192.168.1.77"}
        self.assertEqual(self.cl.get("/users", environ_base=lan).status_code, 403)
        self.assertEqual(self.cl.post("/users", json={"uid": "X1", "name": "X", "role": "student"},
                                      environ_base=lan).status_code, 403)
        self.assertEqual(self.cl.get("/users").status_code, 200)
        # Readers on the LAN can still tap.
        self.assertEqual(self.cl.post("/tap", json={"uid": "X1"}, environ_base=lan).status_code, 200)

    def test_unknown_cards_are_listed_for_registration(self):
        dev = self.reader()
        self.dtap(dev, "C0FFEE01")
        items = self.admin("get", "/admin/taps?unknown=1").json["items"]
        self.assertEqual(items[0]["uid"], "C0FFEE01")
        self.assertEqual(items[0]["device"], "GATE-1")


class Staff(SchoolBase):
    def test_login_roles_and_logout(self):
        reg = self.staff("reg1", "registrar")
        teach = self.staff("teach1", "teacher")
        self.assertEqual(self.cl.get("/api/v1/admin/auth/me", headers=teach).json["staff"]["role"], "teacher")
        self.assertEqual(self.cl.get("/api/v1/admin/students", headers=teach).status_code, 200)
        self.assertEqual(self.cl.post("/api/v1/admin/devices", headers=teach,
                                      json={"code": "X1", "name": "X", "mode": "IN"}).status_code, 403)
        self.assertEqual(self.cl.post("/api/v1/admin/staff", headers=reg,
                                      json={"username": "zz", "full_name": "Z", "role": "admin",
                                            "password": "longenough"}).status_code, 403)
        self.cl.post("/api/v1/admin/auth/logout", headers=reg)
        self.assertEqual(self.cl.get("/api/v1/admin/auth/me", headers=reg).status_code, 401)

    def test_wrong_password_and_deactivation(self):
        self.staff("guard1", "guard", pw="guard-pass-1")
        r = self.cl.post("/api/v1/admin/auth/login", json={"username": "guard1", "password": "nope-nope"})
        self.assertEqual(r.status_code, 401)
        sid = self.admin("get", "/admin/staff").json["items"][0]["id"]
        hdr = self.staff("guard2", "guard")
        self.admin("patch", f"/admin/staff/{sid}", json={"active": False})
        r = self.cl.post("/api/v1/admin/auth/login", json={"username": "guard1", "password": "guard-pass-1"})
        self.assertEqual(r.status_code, 401)
        self.assertEqual(self.cl.get("/api/v1/admin/devices", headers=hdr).status_code, 200)

    def test_meta_lists_resources_and_audit_records_changes(self):
        hdr = self.staff("adm", "admin")
        meta = self.cl.get("/api/v1/admin/meta", headers=hdr).json
        self.assertIn("sections", meta["resources"])
        self.assertEqual(meta["policy"]["school_start"], "07:30")
        self.cl.post("/api/v1/admin/sections", headers=hdr, json={"name": "BSCS - 1A"})
        audit = self.cl.get("/api/v1/admin/audit", headers=hdr).json["items"]
        self.assertEqual(audit[0]["action"], "sections.create")
        self.assertEqual(audit[0]["username"], "adm")


class Crud(SchoolBase):
    def test_validation_and_conflicts(self):
        self.assertEqual(self.admin("post", "/admin/subjects", json={"code": "IT101"}).status_code, 400)
        self.assertEqual(self.admin("post", "/admin/subjects", json={"code": "IT101", "title": "Intro"}).status_code, 201)
        self.assertEqual(self.admin("post", "/admin/subjects", json={"code": "it101", "title": "Dup"}).status_code, 409)
        sec = self.section()
        sub = self.admin("get", "/admin/subjects").json["items"][0]["id"]
        bad = {"section_id": sec, "subject_id": sub, "weekday": 1, "start_time": "10:00", "end_time": "09:00"}
        self.assertEqual(self.admin("post", "/admin/schedules", json=bad).status_code, 400)
        self.assertEqual(self.admin("post", "/admin/schedules", json={**bad, "weekday": 9}).status_code, 400)
        r = self.admin("post", "/admin/schedules", json={**bad, "end_time": "11:00"})
        self.assertEqual(r.status_code, 201, r.json)
        self.assertEqual(self.admin("patch", f"/admin/schedules/{r.json['id']}", json={"bogus": 1}).status_code, 400)

    def test_only_one_active_term_and_soft_delete(self):
        a = self.admin("post", "/admin/terms", json={"name": "T1", "start_date": "2026-06-01",
                                                    "end_date": "2026-10-31", "active": True}).json["id"]
        self.admin("post", "/admin/terms", json={"name": "T2", "start_date": "2026-11-01",
                                                "end_date": "2027-03-31", "active": True})
        terms = {t["name"]: t for t in self.admin("get", "/admin/terms").json["items"]}
        self.assertFalse(terms["T1"]["active"])
        self.assertTrue(terms["T2"]["active"])
        self.assertTrue(a)
        d = self.admin("post", "/admin/directory", json={"name": "Registrar", "role": "Office",
                                                        "department": "Admin"}).json["id"]
        self.admin("delete", f"/admin/directory/{d}")
        self.assertFalse(self.admin("get", "/admin/directory").json["items"][0]["active"])

    def test_csv_import_creates_good_rows_and_explains_bad_ones(self):
        self.section("BSIT - 2A")
        csv_text = ("uid,name,student_number,section,phone\n"
                    "A1A1,Ana Cruz,2026-0001,BSIT - 2A,09170000000\n"
                    "B2B2,Ben Diaz,2026-0002,NOPE,\n"
                    "C3C3,Cara Uy,2026-0001,,\n")
        r = self.cl.post("/api/v1/admin/students/import", data=csv_text, headers={**ADMIN, "Content-Type": "text/csv"})
        self.assertEqual(r.status_code, 200, r.json)
        self.assertEqual(len(r.json["created"]), 1)
        self.assertEqual(len(r.json["skipped"]), 2)
        students = self.admin("get", "/admin/students").json["items"]
        self.assertEqual(students[0]["section_name"], "BSIT - 2A")


class Policy(SchoolBase):
    def test_late_and_present(self):
        with closing(db.get_conn()) as c:
            pol = attendance.policy(c)
        self.assertEqual(attendance.late_minutes(at("2026-10-20 07:44").replace(tzinfo=None), pol), 0)
        self.assertEqual(attendance.late_minutes(at("2026-10-20 07:52").replace(tzinfo=None), pol), 22)

    def test_daily_report_and_calendar_classify_days(self):
        s = self.student("AA11", claim=False)
        self.student("BB22", name="Ana", sn="2023-0143", claim=False)
        with closing(db.get_conn()) as c:
            c.execute("INSERT INTO logs (user_id, time_in, time_out) VALUES (?, '2026-10-19 07:52:00', '2026-10-19 16:00:00')",
                      (s["user_id"],))
            c.execute("INSERT INTO school_calendar (date, kind) VALUES ('2026-10-21', 'holiday')")
            c.execute("INSERT INTO excuse_requests (user_id, date, reason, status, created_at) "
                      "VALUES (?, '2026-10-20', 'sick', 'approved', '2026-10-20 08:00:00')", (s["user_id"],))
        now = at("2026-10-22 12:00")
        with closing(db.get_conn()) as c:
            days = attendance.student_calendar(c, s["user_id"], at("2026-10-17 0:00").date(), at("2026-10-23 0:00").date(), now)
            report = attendance.daily_report(c, at("2026-10-19 0:00").date(), now=now)
        statuses = {d["date"]: d["day_status"] for d in days}
        self.assertEqual(statuses, {"2026-10-17": "no_school", "2026-10-18": "no_school", "2026-10-19": "late",
                                    "2026-10-20": "excused", "2026-10-21": "holiday", "2026-10-22": "not_yet",
                                    "2026-10-23": "upcoming"})
        self.assertEqual((report["totals"]["late"], report["totals"]["absent"]), (1, 1))
        self.assertEqual(attendance.summarize(days)["rate"], 50.0)

    def test_reports_and_csv(self):
        s = self.student("AA11", claim=False)
        self.tap("AA11")
        today = db.school_now().date().isoformat()
        r = self.admin("get", f"/admin/reports/daily?date={today}")
        self.assertEqual(r.json["rows"][0]["user_id"], s["user_id"])
        r = self.admin("get", f"/admin/reports/daily.csv?date={today}")
        self.assertEqual(r.mimetype, "text/csv")
        self.assertIn("Juan", r.get_data(as_text=True))
        r = self.admin("get", f"/admin/reports/monthly.csv?month={today[:7]}")
        self.assertIn("Attendance rate", r.get_data(as_text=True))
        self.assertEqual(self.admin("get", "/admin/reports/monthly?month=2026-13x").status_code, 400)

    def test_settings_validation(self):
        hdr = self.staff("adm", "admin")
        bad = self.cl.put("/api/v1/admin/settings", headers=hdr, json={"school_start": "7:30am"})
        self.assertEqual(bad.status_code, 400)
        ok = self.cl.put("/api/v1/admin/settings", headers=hdr, json={"school_start": "08:00", "school_days": "1,2,3,4,5,6"})
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(self.cl.get("/api/v1/admin/settings", headers=hdr).json["settings"]["school_start"], "08:00")


class EndOfDay(SchoolBase):
    def test_close_day_flags_open_records_notifies_and_texts_guardians(self):
        s = self.student("AA11")
        absent = self.student("BB22", name="Ana", sn="2023-0143")
        self.admin("post", "/admin/guardians", json={"user_id": absent["user_id"], "name": "Mom", "phone": "+639170000000"})
        day = at("2026-10-19 0:00").date()  # a Monday
        with closing(db.get_conn()) as c:
            c.execute("INSERT INTO logs (user_id, time_in) VALUES (?, '2026-10-19 07:20:00')", (s["user_id"],))
        with mock.patch.dict(os.environ, {"SMS_PROVIDER": "log"}):
            result = scheduler.close_day(day, now=at("2026-10-19 19:00").replace(tzinfo=None))
            self.settle()
        self.assertEqual(result["missing_time_out"], [s["user_id"]])
        self.assertEqual(result["absent"], [absent["user_id"]])
        with closing(db.get_conn()) as c:
            self.assertEqual(c.execute("SELECT flag FROM logs").fetchone()[0], "MISSING_TIME_OUT")
            titles = {r[0] for r in c.execute("SELECT title FROM notifications WHERE category = 'attendance'")}
            self.assertEqual(titles, {"Missing Time Out", "Absence Recorded"})
            row = c.execute("SELECT status, body FROM sms_outbox").fetchone()
        self.assertEqual(row["status"], "sent")
        self.assertIn("absent", row["body"])

    def test_scheduler_first_run_only_records_the_start(self):
        self.assertEqual(scheduler.run_due(now=at("2026-10-19 19:00")), [])
        self.assertEqual(scheduler.run_due(now=at("2026-10-21 19:00")), ["2026-10-20", "2026-10-21"])
        self.assertEqual(scheduler.run_due(now=at("2026-10-21 20:00")), [])

    def test_guardian_text_on_tap_and_none_provider_skips(self):
        s = self.student("AA11", claim=False)
        self.admin("post", "/admin/guardians", json={"user_id": s["user_id"], "name": "Dad", "phone": "+639171111111"})
        self.tap("AA11")
        self.settle()
        with closing(db.get_conn()) as c:
            row = c.execute("SELECT status, body FROM sms_outbox").fetchone()
        self.assertEqual(row["status"], "skipped")  # SMS_PROVIDER defaults to none
        self.assertIn("arrived at school", row["body"])
        self.assertEqual(sms.provider(), "none")


class StudentSchool(SchoolBase):
    def setup_school(self):
        s = self.student()
        sec = self.section()
        self.place_in(s, sec)
        sub = self.admin("post", "/admin/subjects", json={"code": "IT101", "title": "Programming"}).json["id"]
        room = self.admin("post", "/admin/rooms", json={"code": "R204", "name": "Room 204", "building": "Main",
                                                       "services": "Projector, Aircon"}).json["id"]
        for wd in range(1, 8):
            self.admin("post", "/admin/schedules", json={"section_id": sec, "subject_id": sub, "room_id": room,
                                                        "weekday": wd, "start_time": "23:00", "end_time": "23:30"})
        return s, sec, room

    def test_schedule_me_and_home(self):
        s, sec, room = self.setup_school()
        today = db.school_now().date()
        self.admin("post", "/admin/calendar", json={"date": (today + timedelta(days=1)).isoformat(), "kind": "holiday"})
        r = self.auth("get", f"/schedule?from={today}&to={today + timedelta(days=2)}", s["access"]).json
        self.assertEqual(len(r["items"]), 2)  # the holiday has no classes
        self.assertEqual(r["items"][0]["room"], "Room 204, Main")
        me = self.auth("get", "/me", s["access"]).json
        self.assertEqual(me["section"]["name"], "BSIT - 2A")
        self.assertEqual(me["policy"]["cutoff"], "18:00")
        home = self.auth("get", "/home", s["access"]).json
        self.assertEqual(home["next_class"]["title"], "Programming")
        self.assertIn("day_status", home["today"])
        room_detail = self.auth("get", f"/rooms/{room}", s["access"]).json
        self.assertEqual(room_detail["services"], ["Projector", "Aircon"])
        self.assertEqual(len(room_detail["today"]), 1)

    def test_tasks_personal_and_assignments(self):
        s, sec, _ = self.setup_school()
        other = self.student("CC33", name="Bo", sn="2023-0199")
        r = self.auth("post", "/tasks", s["access"], json={"title": "Read ch. 7", "due": "2026-10-30T17:00:00+08:00",
                                                          "priority": "high"})
        self.assertEqual(r.status_code, 201, r.json)
        own = r.json["id"]
        teach = self.staff("teach1", "teacher")
        r = self.cl.post("/api/v1/admin/assignments", headers=teach,
                         json={"section_id": sec, "title": "Lab 3", "course": "IT101", "due_at": "2026-10-31 17:00"})
        self.assertEqual(r.status_code, 201, r.json)
        self.settle()
        items = {t["title"]: t for t in self.auth("get", "/tasks", s["access"]).json["items"]}
        self.assertEqual(items["Lab 3"]["kind"], "assignment")
        self.assertEqual(self.auth("get", "/tasks", other["access"]).json["items"], [])
        lab = items["Lab 3"]["id"]
        self.assertTrue(self.auth("patch", f"/tasks/{lab}", s["access"], json={"completed": True}).json["completed"])
        self.assertEqual(self.auth("patch", f"/tasks/{lab}", s["access"], json={"title": "x"}).status_code, 403)
        self.assertEqual(self.auth("delete", f"/tasks/{lab}", s["access"]).status_code, 404)
        self.assertEqual(self.auth("delete", f"/tasks/{own}", other["access"]).status_code, 404)
        self.assertEqual(self.auth("delete", f"/tasks/{own}", s["access"]).status_code, 200)
        inbox = self.auth("get", "/notifications", s["access"]).json["items"]
        self.assertEqual(inbox[0]["title"], "New Assignment")

    def test_lost_found_library_support_and_excuses(self):
        s, _, _ = self.setup_school()
        found = self.admin("post", "/admin/lost_found", json={"kind": "found", "name": "Blue umbrella",
                                                             "category": "other", "location": "Gym"}).json["id"]
        r = self.auth("post", f"/lost-found/{found}/claim", s["access"])
        self.assertEqual(r.json["status"], "claim_requested")
        self.assertEqual(self.auth("post", f"/lost-found/{found}/claim", s["access"]).status_code, 409)
        mine = self.auth("post", "/lost-found", s["access"], json={"kind": "lost", "name": "ID lace",
                                                                  "category": "id", "location": "Canteen"}).json
        self.assertTrue(mine["mine"])
        self.assertEqual(self.auth("post", f"/lost-found/{mine['id']}/resolve", s["access"]).json["status"], "closed")

        book = self.admin("post", "/admin/library_items", json={"title": "Clean Code", "author": "Martin",
                                                               "shelf": "A1", "copies": 1}).json["id"]
        r = self.auth("post", f"/library/{book}/reserve", s["access"])
        self.assertEqual((r.status_code, r.json["available"], r.json["my_reservation"]), (201, False, "reserved"))
        other = self.student("CC33", name="Bo", sn="2023-0199")
        self.assertEqual(self.auth("post", f"/library/{book}/reserve", other["access"]).status_code, 409)

        t = self.auth("post", "/support/tickets", s["access"], json={"subject": "Card lost", "body": "Help"}).json
        self.admin("post", f"/admin/tickets/{t['id']}/reply", json={"reply": "Visit the registrar."})
        self.settle()
        self.assertEqual(self.auth("get", "/support/tickets", s["access"]).json["items"][0]["status"], "answered")

        day = db.school_now().date().isoformat()
        ex = self.auth("post", "/excuses", s["access"], json={"date": day, "reason": "Fever, clinic slip."})
        self.assertEqual(ex.status_code, 201, ex.json)
        self.assertEqual(self.auth("post", "/excuses", s["access"], json={"date": day, "reason": "Again please"}).status_code, 409)
        self.admin("post", f"/admin/excuses/{ex.json['id']}/review", json={"status": "approved"})
        self.settle()
        titles = [n["title"] for n in self.auth("get", "/notifications", s["access"]).json["items"]]
        self.assertIn("Excuse Letter Approved", titles)
        self.assertIn("Support Reply", titles)

    def test_section_announcements_reach_only_that_section(self):
        s, sec, _ = self.setup_school()
        other = self.student("CC33", name="Bo", sn="2023-0199")
        teach = self.staff("teach1", "teacher")
        self.assertEqual(self.cl.post("/api/v1/admin/announcements", headers=teach,
                                      json={"category": "system", "title": "All", "body": "x"}).status_code, 403)
        r = self.cl.post("/api/v1/admin/announcements", headers=teach,
                         json={"category": "system", "title": "Quiz moved", "body": "Friday", "section_id": sec})
        self.assertEqual(r.json["recipients"], 1)
        self.assertEqual(self.auth("get", "/announcements", s["access"]).json["items"][0]["title"], "Quiz moved")
        self.assertEqual(self.auth("get", "/announcements", other["access"]).json["items"], [])
        # The original CLI call (no section) still reaches everyone.
        self.assertEqual(self.admin("post", "/admin/announcements",
                                    json={"category": "system", "title": "Hi", "body": "All"}).json["recipients"], 2)

    def test_attendance_calendar_and_rate(self):
        s, _, _ = self.setup_school()
        self.tap("AA11")
        r = self.auth("get", "/attendance", s["access"]).json
        self.assertIn("calendar", r)
        self.assertIn("rate", r["summary"])
        today = db.school_now().date().isoformat()
        day = next(d for d in r["days"] if d["date"] == today)
        self.assertIn(day["day_status"], ("present", "late"))

    def test_directory_faq_assistance_map(self):
        s = self.student()
        self.admin("post", "/admin/directory", json={"name": "Ms. Reyes", "role": "Registrar", "department": "Admin"})
        self.admin("post", "/admin/faq", json={"question": "How do I time out?", "answer": "Press TIME OUT."})
        self.admin("post", "/admin/assistance", json={"title": "ID problems", "description": "Lost card"})
        self.admin("post", "/admin/map_places", json={"name": "Gym", "x": 10, "y": 20, "width": 100, "height": 50})
        self.assertEqual(self.auth("get", "/directory?q=reyes", s["access"]).json["items"][0]["role"], "Registrar")
        self.assertEqual(len(self.auth("get", "/faq?q=time", s["access"]).json["items"]), 1)
        self.assertEqual(self.auth("get", "/support/assistance", s["access"]).json["items"][0]["icon"], "help")
        self.assertEqual(self.auth("get", "/map/places", s["access"]).json["items"][0]["name"], "Gym")


class LateNotification(SchoolBase):
    def test_late_time_in_is_announced_as_late(self):
        s = self.student("AA11")
        with mock.patch("database.school_now", return_value=at("2026-10-19 07:58")):
            self.tap("AA11")
            self.settle()
        items = self.auth("get", "/notifications", s["access"]).json["items"]
        self.assertEqual(items[0]["title"], "Late Arrival Recorded")
        self.assertIn("28 minutes", items[0]["body"])


class Migrations(SchoolBase):
    def test_migrations_are_recorded_and_idempotent(self):
        import migrations
        self.assertEqual(migrations.migrate(), [])
        with closing(db.get_conn()) as c:
            versions = [r[0] for r in c.execute("SELECT version FROM schema_version ORDER BY version")]
        self.assertEqual(versions[0], 1)
        self.assertGreaterEqual(versions[-1], 6)


def tearDownModule():
    push.drain(5)
