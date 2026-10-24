#!/usr/bin/env python3
"""End-to-end check against a RUNNING server, the way the hardware and the app use it.

  set ADMIN_API_KEY=...            (the server's key)
  python tools/e2e_check.py [http://127.0.0.1:5001]

It creates a temporary reader and student, taps the card in and out through
the reader API, signs in as the student, and checks attendance, the inbox
and the admin reports. Everything it creates is removed at the end. Exit
code 0 means every step passed.
"""
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.request

BASE = (sys.argv[1] if len(sys.argv) > 1 else os.environ.get("SCHOOL_API", "http://127.0.0.1:5001")).rstrip("/")
KEY = os.environ.get("ADMIN_API_KEY", "")
failures = 0


def call(method, path, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data, method=method,
                                 headers={"Content-Type": "application/json", **(headers or {})})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except ValueError:
            return e.code, None


def check(name, ok, detail=""):
    global failures
    print(f"  {'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        failures += 1
    return ok


def wait_for(fn, seconds=8):
    end = time.time() + seconds
    while time.time() < end:
        value = fn()
        if value:
            return value
        time.sleep(0.5)
    return fn()


def main():
    if len(KEY) < 16:
        sys.exit("Set ADMIN_API_KEY to the server's admin key first.")
    admin = {"X-Admin-Key": KEY}
    tag = secrets.token_hex(3).upper()
    uid, sn, code = f"E2E{tag}", f"E2E-{tag}", f"E2E-{tag}"
    print(f"Checking {BASE}")

    status, health = call("GET", "/api/v1/health")
    if not check("server answers /health", status == 200, status):
        sys.exit(1)

    status, dev = call("POST", "/api/v1/admin/devices", {"code": code, "name": "E2E reader", "mode": "KIOSK"}, admin)
    check("admin creates a reader and gets its key once", status == 201 and dev.get("device_key"), dev)
    reader = {"X-Device-Key": dev["device_key"]}
    student_id = None
    try:
        status, r = call("POST", "/api/v1/device/tap", {"uid": uid}, reader)
        check("unknown card is denied with LCD text", r.get("result") == "DENY_UNKNOWN" and r.get("lcd"), r)

        status, r = call("POST", "/api/v1/admin/students", {"uid": uid, "name": "E2E Student", "student_number": sn}, admin)
        check("admin registers the card as a student", status == 201, r)
        student_id = r.get("user_id")

        status, r = call("POST", f"/api/v1/admin/students/{student_id}/claim-code", {"expires_hours": 1}, admin)
        check("admin issues an app activation code", status == 201, r)
        status, s = call("POST", "/api/v1/auth/claim", {"student_number": sn, "claim_code": r["claim_code"],
                                                        "password": "e2e-password-1"})
        check("student activates the app account", status == 201, s)
        me = {"Authorization": "Bearer " + s["access_token"]}

        status, r = call("POST", "/api/v1/device/tap", {"uid": uid, "client_event_id": f"{code}-1"}, reader)
        check("reader tap records TIME IN", r.get("result") == "TIME_IN_OK", r)
        status, r2 = call("POST", "/api/v1/device/tap", {"uid": uid, "client_event_id": f"{code}-1"}, reader)
        check("replayed offline tap is not recorded twice", r2.get("replayed") is True, r2)

        status, today = call("GET", "/api/v1/attendance/today", headers=me)
        check("student app sees state 'in'", today.get("state") == "in", today)

        status, r = call("POST", "/api/v1/device/arm-timeout", {}, reader)
        check("TIME OUT button arms the reader", status == 200, r)
        status, r = call("POST", "/api/v1/device/tap", {"uid": uid}, reader)
        check("next tap records TIME OUT", r.get("result") == "TIME_OUT_OK", r)

        status, today = call("GET", "/api/v1/attendance/today", headers=me)
        check("student app sees status 'complete'", today.get("status") == "complete", today)

        def recorded():
            _, inbox = call("GET", "/api/v1/notifications?category=attendance", headers=me)
            n = sum(1 for i in inbox.get("items", []) if i["title"] in ("Attendance Recorded", "Late Arrival Recorded"))
            return n >= 2
        check("inbox has the time-in and time-out notices", wait_for(recorded))

        day = today.get("date")
        status, rep = call("GET", f"/api/v1/admin/reports/daily?date={day}", headers=admin)
        row = next((x for x in rep.get("rows", []) if x["user_id"] == student_id), None)
        check("daily report lists the student as present or late",
              row is not None and row["day_status"] in ("present", "late"), row)

        status, devs = call("GET", "/api/v1/admin/devices", headers=admin)
        mine = next((d for d in devs.get("items", []) if d["code"] == code), {})
        check("reader shows as online", mine.get("online") is True, mine)
    finally:
        if student_id:
            call("DELETE", f"/api/v1/admin/cards/{student_id}", headers=admin)
        call("PATCH", f"/api/v1/admin/devices/{dev['id']}", {"active": False}, admin)
        print("  cleanup: temporary student deleted, temporary reader deactivated")

    print("\nALL CHECKS PASSED" if failures == 0 else f"\n{failures} CHECK(S) FAILED")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
