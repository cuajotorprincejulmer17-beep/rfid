# PULSE / RFID Attendance — Gap Analysis and Backend Integration Plan

**Status:** all phases implemented and verified (2026-10-24) — see §0
**Scope:** one Python backend + one SQLite database shared by the ESP32 RFID reader(s), the desktop admin/kiosk apps, and the Flutter mobile app (`mobile_flutter/`).

---

## 0. Implementation status (2026-10-24)

All six phases are implemented on `feature/integrate-pulse-expo-mobile-stage1b` (not yet committed).

| Phase | Delivered | Verified by |
|---|---|---|
| 0 Stabilise | `config.py` + `.env`, absolute DB path, numbered migrations with automatic backup, WAL, `run_server.py` (waitress), key removed from `notes.md` | Migrated a copy of the real DB: 9 users / 22 logs intact, backup written |
| 1 App ↔ backend | Sign-in, activation, sign-out, route guard, server address, real Home/Attendance/Profile/ID/Contacts/Updates, polling | Simulator: ESP32-style tap appeared in the app within 30 s |
| 2 Device layer | `devices` + `tap_events`, per-reader keys, KIOSK/IN/OUT modes, per-reader TIME OUT arm, LCD text from the server, debounce, offline replay with `client_event_id`/`tapped_at`, heartbeat + clock sync; firmware v2 (LCD and no-LCD); kiosk display per reader; keyless desktop routes limited to the server PC | `arduino-cli` compiles both sketches with no warnings; reader tests; `e2e_check.py` |
| 3 School + staff | Staff accounts and roles, terms/sections/subjects/rooms/schedules/calendar, attendance policy (late, absent, excused), end-of-day job, reports + CSV, audit log, **browser admin console at `/admin`** | All 29 console pages load; register-unknown-card flow; reports |
| 4 Real features | Schedule, tasks + assignments, directory, rooms, map, lost and found, library, FAQ/assistance, support tickets, excuse letters, announcements feed; app repositories switch to the server when signed in | API + repository tests; simulator Home/Schedule/History on the demo school |
| 5 Notifications | Late arrival, missing time-out, absence, assignment, ticket reply, excuse decision, library notices; guardian SMS (none/log/Semaphore/HTTP) with outbox | `EndOfDay` and SMS tests; outbox in console |
| 6 QA + deploy | `seed_demo.py`, `e2e_check.py` (15 checks), `docs/DEPLOYMENT.md`, API reference, READMEs | `ALL CHECKS PASSED` against a running server |

**Decisions taken (defaults, all reversible):** 1) push = polling + inbox, no Firebase; 2) admin = browser console
served by Flask (the desktop `app_ui.py` keeps working on the server PC); 3) time-out = per-reader mode (KIOSK button,
or IN/OUT reader pair) plus an optional ESP32 button; 4) every sample feature made real; 5) 07:30 start, late after
15 min, 18:00 cutoff, Mon–Fri — all editable in the console; 6) guardian SMS built, off until `SMS_PROVIDER` is set.

**Test totals:** server 65 tests, app 116 tests, end-to-end 15/15, firmware compiles (ESP32 core 3.3.12).

**Not done / needs you:** generate a new `ADMIN_API_KEY` (the old one is in git history); flash the firmware to the
real ESP32 and set its WiFi/server/key; choose an SMS provider account if you want texts; FCM push (decision 1) is not
built.

## 1. Executive summary

The backend is in better shape than the mobile app. `project/` already runs one Flask server on port 5001 with one SQLite file (`rfid_system.db`) that serves **both** the ESP32 (`POST /tap`) and a token-secured mobile API (`/api/v1`). Its tap logic is atomic, and its 33 automated tests pass.

The Flutter app is **not connected to that backend**, though it has a correct API client, token storage, refresh logic and models that match the server's JSON exactly. None of it is wired into the UI:

- `pulseRepositoryProvider` is hard-coded to `null` (`lib/app/app_data.dart:13`), so Home, Attendance and Profile always show "could not be loaded".
- There is no sign-in or claim-account screen, so a student can never get a token.
- `InboxRepository` exists but no screen uses it. The Updates tab shows sample data instead of real notifications.
- 9 of the 13 feature areas (schedule, tasks, updates, directory, rooms, lost and found, library, map, FAQ, plus the Digital ID card) run on a built-in sample-data file. The backend has no endpoints for them.

**Recommendation:** keep the current Python/Flask + SQLite backend and **extend it in place. Do not rewrite it.** The ESP32 contract (`POST /tap` with `{"uid": ...}`) stays byte-for-byte compatible. All new work is additive: new tables, new `/api/v1/...` endpoints, and wiring in the Flutter app. That gives one backend and one database for every client.

---

## 2. What exists today

### 2.1 System map

```
                          ┌──────────────────────── project/app.py (Flask, :5001) ────────────────────────┐
[RC522]→[ESP32]──POST /tap──▶ legacy routes (no auth)                                                      │
  LCD ◀── JSON ─────────────   /tap  /timeout-arm  /last-tap  /display-event  /users  /logs  /today-count  │
                              │                                                                            │
[student_display.py] ─poll───▶ /display-event, /timeout-arm  (PySide6 kiosk, TIME OUT button)              │
[app_ui.py]          ─HTTP───▶ /users, /logs, /last-tap      (customtkinter admin)                         │
[tools/school_admin.py]──────▶ /api/v1/admin/*   (X-Admin-Key)                                             │
[Flutter app]  ✗ not wired ──▶ /api/v1/auth, /me, /home, /attendance, /notifications, /contacts            │
                              └──────────────── database.py + api/ ──▶ rfid_system.db (SQLite) ────────────┘
```

### 2.2 Backend inventory (`project/`)

| Area | What it does | Quality |
|---|---|---|
| `database.py` | `users`, `logs`, `events` tables; `record_tap()` state machine (IN / OUT / ALREADY_CHECKED_IN / VISIT_LIMIT_EXCEEDED / REJECT_*), visitor time limits, visitor card reuse with archiving | Good: atomic `BEGIN IMMEDIATE`, unique index prevents two open records |
| `app.py` | ESP32 `/tap`, kiosk `/timeout-arm` (arms one OUT tap for 15 s), `/display-event`, user CRUD, logs | Works, but has **no auth** and keeps state in process globals |
| `api/auth.py` | Student claim codes → account, login, rotating refresh tokens with replay detection, logout | Good |
| `api/student.py` | `/me`, `/home`, `/attendance/today`, `/attendance?month=`, `/attendance/<date>`, preferences, push devices, contacts | Good, read-only by design |
| `api/inbox.py`, `notifier.py`, `push.py` | Notification inbox, tap → notification, announcements, Expo push worker with retries | Good, but push is **Expo-only** (Flutter can't use it) |
| `api/admin.py` | Student profiles, claim codes, account reset, contacts, announcements | Single shared admin key; no staff accounts |
| `app_ui.py`, `student_display.py` | Desktop admin + kiosk display | Talk to the unauthenticated legacy routes |
| `tests/test_api.py` | 33 tests | **All pass** (verified 2026-10-24) |

### 2.3 ESP32 firmware (`project/rfid_reader/rfid_reader.ino`)

- Reads the UID, then sends `POST {SERVER_URL}` with `{"uid":"..."}` and shows the result on a 16×2 LCD. It then waits 2 s as a cooldown.
- WiFi SSID, password and server IP are hard-coded. There is no device identity and no auth header.
- It does not handle `REJECT_EXPIRED_VISITOR`, which falls through to "ACCESS DENIED / Not registered", and the WiFi reconnect loop blocks.
- It has no physical TIME OUT button. Time-out depends on the PC kiosk arming the next tap.

### 2.4 Flutter app (`mobile_flutter/`)

| Feature | Route | Data source today | Backend endpoint exists? |
|---|---|---|---|
| Sign in / claim account | — | **no screen** | ✅ `/auth/login`, `/auth/claim` |
| Home (today + recent) | `/home` | real repo, but provider is `null` | ✅ `/home` |
| Attendance + history + insights | `/academic/*` | real repo, but provider is `null` | ✅ `/attendance*` |
| Profile | `/personal/profile` | real repo, but provider is `null` | ✅ `/me` |
| Notification inbox | — | `InboxRepository` **unused** | ✅ `/notifications*` |
| Updates | `/updates` | sample | ⚠️ inbox exists; no announcements feed |
| Contact support | `/support/contact` | real (`/contacts`) but not wired | ✅ `/contacts` |
| Schedule | `/schedule` | sample | ❌ |
| Tasks | `/tasks` | sample | ❌ |
| Digital ID | `/campus/digital-id` | sample ("Sample programme") | ⚠️ partially (`/me`) |
| Directory | `/campus/directory` | sample | ⚠️ `faculty_contacts` only |
| Room finder | `/campus/rooms` | sample | ❌ |
| Map | `/campus/map` | sample | ❌ |
| Lost and found | `/campus/lost-found` | sample | ❌ |
| Library | `/campus/library` | sample | ❌ |
| FAQ / assistance | `/support/*` | sample | ❌ |
| Push notifications | — | not implemented | ⚠️ Expo-only on server |
| Server address | build-time `--dart-define` only | default `10.0.2.2` (Android emulator) | — |

The repository interfaces in `lib/shared/repositories/repositories.dart` are well designed. Each sample repository can be swapped for an API-backed one without touching any screen.

---

## 3. Gap analysis

Severity: **P0** blocks a working demo · **P1** required for a "complete" school system · **P2** quality and robustness · **P3** nice to have.

### 3.1 Integration gaps (mobile ↔ backend)

| # | Gap | Sev | Fix |
|---|---|---|---|
| G1 | `pulseRepositoryProvider` never overridden, so no real data reaches the UI | P0 | Provide `ApiClient`, `AuthController`, `PulseRepository`, and `InboxRepository` through Riverpod in `main.dart` |
| G2 | No sign-in, claim-account, or sign-out screens; no route guard | P0 | Add `/sign-in` and `/claim` routes, plus a `go_router` `redirect` driven by `AuthController.status` |
| G3 | Server URL fixed at build time; the Android-emulator default fails on real phones | P0 | "Server address" field + "Test connection" in Settings, persisted in `shared_preferences` |
| G4 | Updates tab uses sample data; the real inbox is unused | P0 | Updates = `/notifications` (attendance, emergency, system) + new `/announcements` feed |
| G5 | Push is Expo-only; the Flutter app has no push | P1 | Phase 1: poll `/notifications/unread-count` on resume and every 60 s in the foreground. Phase 5 (optional): add FCM |
| G6 | Digital ID, Schedule, Directory and the other features above have no endpoints | P1 | New `/api/v1` resources (section 5.3) |

**Observed when running the app (iPhone 16 Pro simulator, 2026-10-24, backend live on :5001):**

| # | Finding | Sev | Status / fix |
|---|---|---|---|
| R1 | App crashed on every cold start ("No Directionality widget found"): the splash `Stack` in `main.dart` sits above `MaterialApp` | P0 | **Fixed:** wrapped it in `Directionality(ltr)` |
| R2 | The app made **zero** requests to the backend. The server log shows only manual `/health` checks | P0 | **Fixed in Phase 1** |
| R3 | Attendance shows "No status yet" when it is not connected, which reads as a real server answer | P1 | **Fixed:** shows "Not connected to the school server" |
| R4 | Dock "Home" pill overflows by 19 px (`lib/navigation/pulse_dock.dart:148`) on a 402-pt-wide phone | P2 | **Fixed:** label shows only when it fits; icon-only pill otherwise |
| R5 | Home hero card stack shows text bleeding through behind the top card ("Room 204…" over "4 due today") | P2 | **Fixed:** opaque backing, content in the visible strip; "due today" now counts only tasks due today |

### 3.2 Hardware / device gaps (ESP32 ↔ backend)

| # | Gap | Sev | Fix |
|---|---|---|---|
| H1 | `/tap` is unauthenticated, so anyone on the LAN can fake attendance | P1 | Per-device key (`X-Device-Key`), stored hashed in a `devices` table. The legacy no-key path stays behind `ALLOW_LEGACY_TAP=1` for the transition |
| H2 | `timeout_armed`, `last_tap`, and `latest_display_event` are process globals. They assume a single reader and are lost on restart | P1 | Store them per device in the DB (`devices.armed_until`, `tap_events`). The kiosk reads `/display-event?device=GATE-1` |
| H3 | No audit trail of raw taps (unknown cards and denied taps are lost) | P1 | `tap_events` table: every tap with device, UID, result, and timestamps. It also replaces `/last-tap` for card registration |
| H4 | No server-side debounce: a card held on the reader produces repeated taps | P2 | Ignore the same UID on the same device within 3 s and return the previous result |
| H5 | Taps are lost when WiFi or the server is down | P2 | Firmware ring buffer (SPIFFS/NVS) that replays with `client_event_id` + `tapped_at`. The server deduplicates on `client_event_id` |
| H6 | LCD text is decided in firmware; new result codes show wrong text | P2 | Server returns `lcd: ["line1", "line2"]` (≤16 chars). Firmware prints it and falls back to its current mapping |
| H7 | Hard-coded IP, blocking WiFi loop, no HTTP timeout | P2 | `http.setTimeout(4000)`, non-blocking reconnect, optional WiFiManager captive portal for SSID/server |
| H8 | No physical TIME OUT control at the reader | P2 | Optional push button on a free GPIO that calls `/api/v1/device/arm-timeout`, **or** a device `mode` of `IN`/`OUT`/`KIOSK` so separate entrance and exit readers need no button |
| H9 | No device health visibility | P3 | `POST /api/v1/device/heartbeat` every 60 s (IP, RSSI, firmware). Admin sees online/offline |

### 3.3 Backend domain gaps (school management logic)

| # | Gap | Sev | Fix |
|---|---|---|---|
| D1 | No staff, teacher, or admin accounts: one shared admin key, and the desktop UI has no auth | P1 | `staff_accounts` with roles `admin`, `registrar`, `teacher`, `guard`, plus staff login → bearer token |
| D2 | No school structure: `course_section` is free text; no terms, sections, subjects, or schedules | P1 | `terms`, `sections`, `subjects`, `class_schedules`; `student_profiles.section_id` |
| D3 | Attendance only knows complete/pending/incomplete. There is no **late**, no **absent**, and no school-day calendar | P1 | `attendance_policy` (start time, late after N min, cutoff) + `school_calendar` (holidays). Daily status = present / late / absent / incomplete / excused |
| D4 | Open records are only flagged `MISSING_TIME_OUT` lazily, on the student's *next* tap | P1 | End-of-day job at cutoff closes open logs, flags them, and notifies |
| D5 | No reports | P1 | Daily and monthly attendance per section, CSV export, absentee list |
| D6 | Announcements are fire-and-forget notifications, not a browsable feed | P1 | `announcements` table (audience: all / section), with fan-out to the inbox kept |
| D7 | Excuse or absence requests | P3 | `excuse_requests`: student submits in the app, staff approves, and the day becomes `excused` |
| D8 | Guardian alerts | P3 | `guardians` table + SMS gateway adapter, behind a feature flag |

### 3.4 Engineering / security gaps

| # | Gap | Sev | Fix |
|---|---|---|---|
| E1 | **A live `ADMIN_API_KEY` is committed in `notes.md`** | P0 | Rotate the key, delete it from `notes.md`, and load it from an untracked `.env` |
| E2 | Schema changes are ad-hoc `ALTER TABLE`s inside `init_db()` | P2 | Numbered SQL migrations + a `schema_version` table |
| E3 | SQLite runs in the default journal mode (readers block the writer) | P2 | `PRAGMA journal_mode=WAL; busy_timeout=5000` |
| E4 | Flask dev server (`app.run`) | P2 | `waitress` (works on Windows) for the school PC. Keep `app.run` for development |
| E5 | Dead code: `log_time_in`, `log_time_out`, `open_log_exists` | P3 | Remove |
| E6 | `registered_at` uses SQLite `localtime`, everything else uses school time (+08:00) | P3 | Write all timestamps through `school_now()` |
| E7 | Flutter `pubspec.yaml` requires Dart ^3.13.5 (Riverpod 3.4 needs ≥3.12). The project only had `android/` | P2 | Requires **Flutter 3.47.7+** (installed). `ios/` platform added so the app runs on the iOS simulator |

---

## 4. Target architecture

**Principle:** one process, one database, many clients. Every client talks HTTP/JSON to the same Flask app, and only the Flask app touches `rfid_system.db`.

```
 ESP32 reader(s) ──X-Device-Key──▶ /tap (legacy, kept)            ┐
                                   /api/v1/device/{tap,heartbeat,arm-timeout}
 Kiosk display  ──X-Device-Key──▶ /api/v1/device/display-event   │
 Desktop admin  ──staff token───▶ /api/v1/admin/*                ├─▶ services/ ─▶ rfid_system.db (SQLite, WAL)
 Admin CLI      ──staff token───▶ /api/v1/admin/*                │      ▲
 Flutter app    ──student token─▶ /api/v1/{auth,me,attendance,…} ┘      │
                                                                  jobs/ (end-of-day close, push retries)
```

### 4.1 Proposed backend layout (additive refactor of `project/`)

```
project/
├── app.py                  # create_app(); `python app.py` still works; legacy routes stay here
├── config.py               # NEW: reads .env (DB path, ADMIN key, TZ, policy defaults, feature flags)
├── database.py             # KEEP: get_conn(), school_now(), record_tap() (moved logic stays importable)
├── migrations/             # NEW
│   ├── 0001_baseline.sql   #   the current users/logs/events + api tables (no-op on existing DBs)
│   ├── 0002_devices.sql
│   ├── 0003_staff.sql
│   ├── 0004_school.sql
│   ├── 0005_campus.sql
│   └── migrate.py          #   applies pending files, records schema_version
├── services/               # NEW: business logic, no Flask imports (easy to unit test)
│   ├── attendance.py       #   daily status (present/late/absent/…), policy, end-of-day close
│   ├── devices.py          #   device auth, per-device arm state, debounce, tap_events
│   ├── reports.py          #   section/day/month aggregates, CSV
│   └── notifications.py    #   (moves notifier.py logic here; push providers: expo, fcm, none)
├── api/                    # existing blueprint, grows by module
│   ├── common.py auth.py student.py inbox.py admin.py push.py schema.py   (existing)
│   ├── device.py           # NEW  /device/*
│   ├── staff_auth.py       # NEW  /admin/auth/login, refresh, logout; require_staff(role=…)
│   ├── school.py           # NEW  /schedule, /announcements, /sections (student read)
│   ├── campus.py           # NEW  /directory, /rooms, /map, /lost-found, /library
│   ├── support.py          # NEW  /faq, /support/tickets
│   ├── tasks.py            # NEW  /tasks (per-student CRUD)
│   └── admin_school.py     # NEW  admin CRUD for all of the above + reports
├── jobs/scheduler.py       # NEW: one daemon thread; end-of-day close at policy cutoff
├── tools/school_admin.py   # extended with new commands; seed_demo.py for a demo dataset
├── rfid_reader/…ino        # updated firmware (device key, lcd lines, timeout, optional button)
└── tests/                  # existing 33 + new per module
```

Why not FastAPI, Django or MySQL? The existing code, tests, desktop apps and ESP32 already work against Flask + SQLite. A school deployment with one PC and a few hundred students is well within SQLite's limits in WAL mode. A rewrite would add risk without adding features. A later move to MySQL/PostgreSQL stays possible because all SQL goes through `get_conn()`.

### 4.2 Database: new tables

All tables are additive. `users`, `logs`, and `events` are not changed (except a nullable `device_id` on `logs`).

| Table | Key columns | Purpose |
|---|---|---|
| `schema_version` | version, applied_at | migrations |
| `devices` | id, code (`GATE-1`), name, location, key_hash, mode (`IN`/`OUT`/`KIOSK`), armed_until, last_seen, ip, firmware, active | reader identity + per-device state |
| `tap_events` | id, device_id, uid, user_id?, result_code, log_id?, client_event_id UNIQUE, tapped_at, received_at | full tap audit trail, debounce, unknown-card capture |
| `staff_accounts` | id, username UNIQUE, full_name, role, password_hash, active | admin / registrar / teacher / guard |
| `staff_sessions` | same shape as `api_sessions` | staff tokens |
| `terms` | id, name (`2026-2027 1st Sem`), start_date, end_date, active | school year |
| `sections` | id, term_id, name (`BSIT 2A`), course, year_level, adviser_staff_id | class grouping |
| `subjects` | id, code, title, units | |
| `class_schedules` | id, section_id, subject_id, teacher_staff_id, room_id, weekday, start_time, end_time | Schedule tab |
| `settings` | key, value | attendance policy: `school_start=07:30`, `late_after_min=15`, `cutoff=18:00`, `visitor_limit_hours=4` |
| `school_calendar` | date, kind (`holiday`/`no_class`/`special`), note | absent ≠ holiday |
| `announcements` | id, category, title, body, audience (`all`/`section`), section_id?, created_by, published_at, pinned | Updates feed (inbox fan-out kept) |
| `rooms` | id, code, name, building, floor, capacity, services_json | Room finder |
| `map_places` | id, name, kind, x, y, w, h, room_id? | Map |
| `directory_entries` | id, staff_id?, name, role, department, email, phone, office_room_id?, active | Directory (merges `faculty_contacts`) |
| `lost_found_items` | id, kind (`lost`/`found`), name, category, location, reported_by_user_id, reported_at, status (`open`/`claimed`/`closed`) | Lost and found |
| `library_items` / `library_reservations` | title, author, shelf, copies / item_id, user_id, status, created_at | Library |
| `faq_items`, `support_tickets` | question, answer, sort / user_id, subject, body, status, reply | Support |
| `student_tasks` | id, user_id, title, course, due_at, priority, completed_at | Tasks (synced per student) |
| `excuse_requests` *(P3)* | user_id, date, reason, status, reviewed_by | Excused absences |
| `guardians` *(P3)* | user_id, name, phone, relation, sms_enabled | Parent SMS |

`student_profiles` gains `section_id` (nullable FK) and `photo_path`. The free-text `course_section` is kept and auto-filled for older clients.

### 4.3 Attendance logic (single source of truth: `services/attendance.py`)

The tap state machine in `database.record_tap()` stays as it is. It is correct and tested. The new **daily status** is derived on read and never stored on the tap path, so the ESP32 response time is unchanged.

```
for student S on school day D (not in school_calendar as holiday/no_class):
  no log on D                         → absent   (excused if an approved excuse exists)
  first time_in > school_start + late → late
  else                                → present
  any session flagged MISSING_TIME_OUT
    or open after cutoff              → incomplete (shown alongside present/late)
```

The end-of-day job runs at `cutoff`. For every open log from today it sets `flag='MISSING_TIME_OUT'` and queues an "Attendance Issue" notification. Today that flag is set only when the student taps again.

The existing mobile `status` values (`complete` / `pending` / `incomplete` / `unavailable`) stay. A new `day_status` field (`present` / `late` / `absent` / `excused` / `holiday`) is added, so the current app keeps working before it is updated.

### 4.4 Device protocol (ESP32), backward compatible

```
POST /tap                                   (unchanged; accepted while ALLOW_LEGACY_TAP=1)
POST /api/v1/device/tap
  headers: X-Device-Key: <secret>
  body:    {"uid":"04A1B2C3", "client_event_id":"GATE-1-000123", "tapped_at":"2026-10-24T07:31:05+08:00"}
  200:     {"status":"granted","result":"TIME_IN_OK","name":"Juan D.","role":"student",
            "action":"IN","message":"Welcome, Juan D.!","lcd":["Juan D.","TIME IN 07:31"]}
POST /api/v1/device/arm-timeout             (kiosk button or GPIO button; arms THIS device only)
POST /api/v1/device/heartbeat               {"ip","rssi","firmware","queue_len"}
GET  /api/v1/device/display-event           (kiosk; returns this device's latest event)
```

The `/tap` response gains only new keys (`lcd`). Old firmware ignores them. Mode logic: an `IN` device always times in, an `OUT` device always times out, and a `KIOSK` device uses the existing arm-for-15-s behaviour.

### 4.5 Mobile API additions (student token)

| Method & path | Returns |
|---|---|
| `GET /me` *(extended)* | + `section`, `photo_url`, `rfid: {registered, masked_uid}`, `term` |
| `GET /attendance*` *(extended)* | + `day_status`, `late_minutes`, monthly `rate` |
| `GET /schedule?date=` / `?from=&to=` | class sessions for the student's section |
| `GET /announcements?before=&limit=` · `GET /announcements/<id>` | feed (Updates tab) |
| `GET/POST/PATCH/DELETE /tasks` | personal tasks |
| `GET /directory?q=` | staff directory |
| `GET /rooms?q=` · `/rooms/<id>` · `GET /map/places` | campus |
| `GET /lost-found?category=` · `POST /lost-found` · `POST /lost-found/<id>/claim` | lost and found |
| `GET /library?q=` · `POST /library/<id>/reserve` | library |
| `GET /faq?q=` · `POST /support/tickets` · `GET /support/tickets` | support |
| `POST /excuses` · `GET /excuses` *(P3)* | excuse letters |
| `POST /devices` *(extended)* | accepts `provider: "fcm"` tokens |

Admin endpoints (`/api/v1/admin/...`, staff token + role check) mirror these with full CRUD, plus `/admin/devices`, `/admin/reports/daily?date=&section=`, `/admin/reports/monthly.csv`, `/admin/taps?unknown=1`.

---

## 5. Implementation plan

Each phase ends with something that can be demonstrated, and with tests. Estimates assume one developer familiar with the code.

### Phase 0 — Stabilise and secure (0.5 day) ✅ done 2026-10-24
1. Rotate `ADMIN_API_KEY`, remove it from `notes.md`, and add `project/.env.example` with `config.py` loading `.env`.
2. Add a migration runner and `0001_baseline.sql` that reproduces today's schema, with no data changes. Enable WAL.
3. Add `waitress` to `requirements.txt` and a `run_server.bat` / `run_server.sh`.
4. Remove dead DB functions. Pin the Flutter version in `mobile_flutter/README.md`.

**Done when:** the existing 33 tests pass and the server starts on a copy of the real DB with no schema diff.

### Phase 1 — Connect the Flutter app to the existing backend ✅ done 2026-10-24

**Delivered:** sign-in, claim-account and sign-out flows with a route guard; a runtime server address with Test connection; real Home, Attendance, Attendance History (month), Profile, Digital ID and Contact Support; Updates backed by the real inbox (filters, mark read, mark all read); an unread badge on the dock; 30 s polling plus refresh on resume; Android `INTERNET` + cleartext and iOS ATS local-network settings. Covered by 7 new widget tests (109 total pass).

**Verified on the iPhone 16 Pro simulator** against a copy of `rfid_system.db`: the admin CLI issued a claim code, the app activated the account, a simulated ESP32 `POST /tap` showed "Timed in at 2:24 AM" on Home within one poll with no user action, a kiosk `/timeout-arm` + tap showed "Timed out … Recorded", and both "Attendance Recorded" notifications appeared in Updates.

**Known gaps left for later phases:** the Contact Support *form* still only simulates sending (needs `POST /support/tickets`, Phase 4); Schedule, Tasks, Directory, Rooms, Map, Lost and Found, Library and FAQ remain sample data (Phase 4); no OS push notifications (Phase 5).

Original scope:
1. Riverpod providers for `ApiClient`, `AuthController`, `PulseRepository`, and `InboxRepository`, overridden in `main.dart`.
2. `SignInPage` (student number + password), `ClaimAccountPage` (student number + claim code + new password), and sign-out in Settings.
3. `go_router` `redirect`: signed-out users go to `/sign-in`. `onSessionExpired` sends the user back to sign-in.
4. Runtime **Server address** setting with Test connection (`/health`).
5. Updates tab reads `/notifications` (filter chips: attendance / announcements / emergency) with mark-read and mark-all-read. The unread badge on the dock comes from `/notifications/unread-count`.
6. Contact Support reads `/contacts`. The Digital ID card uses the real name, student number, and section from `/me`.
7. Unread-count polling on app resume and every 60 s in the foreground.

**Done when:** a card tapped on the ESP32 shows the student as **In** on Home within one refresh, and the Updates tab shows "Attendance Recorded" with the server's time. Widget tests use the existing `test/fake_server.dart`.

### Phase 2 — Device layer (1.5 days) ✅ done 2026-10-24
1. Migration `0002_devices.sql`. Add `services/devices.py` and `api/device.py`.
2. Move the arm-timeout, last-tap, and display-event state from globals into `devices` and `tap_events`. Keep the legacy routes as thin wrappers that use the default device.
3. Add a 3 s debounce, `client_event_id` deduplication, and `lcd` lines in the response.
4. Firmware v2: device key header, `/api/v1/device/tap`, `http.setTimeout`, non-blocking WiFi, LCD from the server, heartbeat, optional TIME OUT button (GPIO 27 → `arm-timeout`), optional offline queue (≤50 taps in NVS).
5. `student_display.py` is told its device code. `app_ui.py` registration reads unknown taps from `tap_events`.

**Done when:** two readers (or one reader plus a curl "fake reader") arm and time out independently. Unplugging the server does not lose taps (if the offline queue is enabled). Firmware v1 still works.

### Phase 3 — School structure, staff, attendance policy, reports (2.5–3 days) ✅ done 2026-10-24
1. Migrations `0003_staff.sql` and `0004_school.sql`. Add staff login and `require_staff(roles)`. The shared admin key stays valid for the CLI only.
2. Admin CRUD for terms, sections, subjects, schedules, settings, and the school calendar. Assign students to sections in bulk (CSV import).
3. `services/attendance.py`: daily status (present / late / absent / excused / holiday) and the end-of-day close job.
4. Reports: daily per section, monthly per student, CSV export, absentee list.
5. Admin UI: add a staff login and pages for Students (profile, section, claim code), Sections & Schedules, Announcements, Devices, and Reports to `app_ui.py` (or a web admin, see Decision 2).

**Done when:** a teacher signs in, picks a section and today's date, and sees present/late/absent counts that match the taps. A CSV opens in Excel.

### Phase 4 — Replace sample features with real data (2–3 days) ✅ done 2026-10-24
Implement API-backed repositories behind the **existing** Flutter interfaces in this order: Schedule → Announcements (Updates) → Tasks → Directory → Rooms + Map → Lost and Found → Library → FAQ/Support tickets. Each feature needs a backend endpoint, tests, and an admin CRUD command (CLI/UI), then an `Api…Repository` in Flutter and a provider switch. The sample repositories stay available only when the app is built with `--dart-define=DEMO=true`, and the "Sample data" chips disappear in real mode.

**Done when:** a normal build contains no sample data, and every screen shows the loading, empty, and error states against the real server.

### Phase 5 — Notifications (1–1.5 days, optional pieces) ✅ done 2026-10-24
1. Push provider abstraction in `push.py` (`expo` | `fcm` | `none`). Add FCM HTTP v1 sending with a service-account file, and `firebase_messaging` + `flutter_local_notifications` in the app. *(Requires a Firebase project; skip if Decision 1 = polling only.)*
2. Notification triggers for late arrival, end-of-day missing time-out, new announcement, ticket reply, and excuse decision.
3. *(P3)* Guardian SMS adapter behind `SMS_PROVIDER`.

### Phase 6 — QA, demo data, deployment (1 day) ✅ done 2026-10-24
1. `tools/seed_demo.py`: one term, 3 sections, 30 students with cards, a week of taps, announcements, and schedules.
2. An end-to-end test script that simulates ESP32 taps via HTTP and checks the student API and reports.
3. Deployment guide for the school PC: reserved DHCP/static IP, Windows firewall rule for port 5001, waitress as a startup task, nightly `rfid_system.db` backup (SQLite `.backup`), and an ESP32 flashing checklist.
4. Update `API_README.md` and `PROJECT_GUIDE.md`, and add an architecture diagram for the defence.

**Total:** about 10–12 working days for P0+P1. P2/P3 items are marked optional and can be cut.

---

## 6. Decisions needed from you

1. **Push notifications.** Choose between (a) **polling only** (no Firebase, works offline on the LAN; recommended for a school demo) and (b) real push via Firebase Cloud Messaging (needs a Firebase project, and the phones need internet access).
2. **Admin interface.** Choose between (a) **extending the existing desktop `app_ui.py`** (recommended, since it is already built and familiar) and (b) a new browser-based admin served by Flask (usable from any PC, but more work).
3. **Time-out method at the gate.** Choose between (a) keeping the kiosk TIME OUT button, (b) adding a physical button on the ESP32, and (c) **separate IN and OUT readers** (simplest for students; needs a second ESP32 + RC522).
4. **Feature scope.** Which sample features must be real for the defence? Suggested must-haves: Schedule, Updates/Announcements, Digital ID, Directory, Tasks. Could be cut: Library, Map, Lost and Found.
5. **Late/absent rules.** School start time, late threshold, and daily cutoff (proposed: 07:30, 15 min, 18:00).
6. **Guardian SMS.** In scope or not? It requires a paid SMS gateway.

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| Changing `/tap` breaks the deployed ESP32 | Legacy route kept unchanged; contract test pins the response keys |
| Phone can't reach the server (different WiFi, client isolation, firewall) | Runtime server-address setting, `/health` test button, firewall step in the deploy guide |
| SQLite "database is locked" under load | WAL + `busy_timeout`; all writes already use short `BEGIN IMMEDIATE` transactions |
| Existing DB data lost during migrations | Migrations are additive only; `migrate.py` takes a `.backup` copy first |
| Scope creep for the defence | Phase 1 alone gives a working end-to-end demo; later phases are independent |
