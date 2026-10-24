# PULSE server API — reference

One Flask server, one SQLite database (`rfid_system.db`), four kinds of client:

| Client | Talks to | Auth |
|---|---|---|
| ESP32 reader, firmware v2 (`rfid_reader/`) | `/api/v1/device/*` | `X-Device-Key` (one key per reader) |
| ESP32 reader, original sketch | `POST /tap` (unchanged) | none — trusted LAN, `ALLOW_LEGACY_TAP=1` |
| Kiosk display (`student_display.py`) | `/api/v1/device/display-event`, `/arm-timeout` (or the legacy routes) | `RFID_DEVICE_KEY` env, optional |
| Student app (`mobile_flutter/`) | `/api/v1/*` | `Authorization: Bearer <access token>` |
| Admin console (`/admin`) and `tools/school_admin.py` | `/api/v1/admin/*` | staff token (Bearer) or `X-Admin-Key` |
| Desktop admin (`app_ui.py`) | `/users`, `/logs`, `/last-tap`, `/today-count` | none — **server PC only** (`LEGACY_ADMIN_LOCAL_ONLY=1`) |

Errors are always `{"error": {"code": "...", "message": "..."}}`; branch on `code`. Times are ISO 8601 with `+08:00`.

## Configuration (`project/.env`, see `.env.example`)

| Variable | Default | Purpose |
|---|---|---|
| `ADMIN_API_KEY` | — | 16+ characters, for `tools/school_admin.py`. Staff use the console with their own accounts |
| `RFID_DB` | `rfid_system.db` next to `app.py` | Database file |
| `HOST` / `PORT` | `0.0.0.0` / `5001` | Bind address |
| `ALLOW_LEGACY_TAP` | `1` | Accept the original keyless `/tap`. Set `0` once every reader runs v2 |
| `LEGACY_ADMIN_LOCAL_ONLY` | `1` | Keyless `/users` and `/logs` answer only the server PC |
| `JOBS_ENABLED` | `1` | End-of-day close (missing time-outs, absences) |
| `SMS_PROVIDER` | `none` | `none`, `log`, `semaphore` (`SEMAPHORE_API_KEY`, `SEMAPHORE_SENDER`), `http` (`SMS_HTTP_URL`, `SMS_HTTP_TOKEN`) |
| `PUSH_ENABLED` | `1` | Expo push for the old Expo app; the Flutter app polls instead |
| `ACCESS_TOKEN_MINUTES` / `REFRESH_TOKEN_DAYS` / `STAFF_SESSION_HOURS` | 60 / 30 / 12 | Session lifetimes |

Start: `python run_server.py` (waitress). Schema changes are numbered files in `migrations/`, applied on start-up after a
backup to `backups/`.

## Readers — `/api/v1/device/*` (header `X-Device-Key`)

| Method & path | Body | Reply |
|---|---|---|
| `POST /device/tap` | `{"uid", "client_event_id"?, "tapped_at"?}` | `status`, `result`, `name`, `role`, `action`, `message`, **`lcd: [line1, line2]`**, `event_id` (+ `late_minutes`, `debounced`, `replayed`) |
| `POST /device/arm-timeout` | `{}` | KIOSK readers only: the next tap on **this** reader is a time out (15 s) |
| `POST /device/heartbeat` | `{"firmware", "rssi", "queue_len"}` | `mode`, `name`, `epoch` (the reader sets its clock from it) |
| `GET /device/display-event` | — | latest result on this reader, for the kiosk screen |

Reader modes: `KIOSK` (tap = time in; TIME OUT button arms one time out), `IN` (entrance), `OUT` (exit).
`client_event_id` makes offline replays idempotent; `tapped_at` (within 24 h) keeps a replayed tap's real time.
The same card on the same reader within 3 s after a recorded time in/out is answered, not recorded again.
`POST /tap` keeps its exact original reply and belongs to the `DEFAULT` reader.

## Students — `/api/v1/*` (Bearer token)

| Method & path | Purpose |
|---|---|
| `GET /health` | Connectivity check (no auth) |
| `POST /auth/claim` · `/auth/login` · `/auth/refresh` · `/auth/logout` | Activation with a one-time code, sign-in, rotating refresh tokens |
| `GET /me` · `PATCH /me/preferences` | Profile, `section`, attendance `policy`, notification preferences |
| `GET /home` | Profile, today (with `day_status`, `late_minutes`), last 5 days, unread count, `next_class` |
| `GET /attendance/today` · `/attendance?month=YYYY-MM` · `/attendance/<date>` | Days with sessions; month adds `calendar` (every school day: `present`/`late`/`absent`/`excused`/`holiday`/…) and `summary.rate` |
| `GET /notifications…` · `POST /notifications/<id>/read` · `/read-all` | Inbox |
| `GET /schedule?date=` or `?from=&to=` | The section's timetable as dated events (holidays skipped) |
| `GET /announcements` · `/announcements/<id>` | Feed (school-wide + own section) |
| `GET/POST /tasks` · `PATCH/DELETE /tasks/<id>` | Own tasks + teacher assignments (assignments can be completed, not edited) |
| `GET /directory?q=` · `/rooms?q=` · `/rooms/<id>` · `/map/places` | Campus information |
| `GET/POST /lost-found` · `POST /lost-found/<id>/claim` · `/resolve` | Lost and found |
| `GET /library?q=` · `POST /library/<id>/reserve` · `GET/DELETE /library/reservations…` | Library |
| `GET /faq?q=` · `/support/assistance` · `GET/POST /support/tickets` | Support; staff replies arrive in the inbox |
| `GET/POST /excuses` | Excuse letters; approval turns an absence into `excused` |
| `GET /contacts` | School-approved contacts |

There is still no endpoint that writes attendance: only a reader tap (or an audited staff correction) changes `logs`.

## Staff and admin — `/api/v1/admin/*`

Roles: `admin` (everything), `registrar` (students, cards, readers, content, reports), `teacher` (reports, assignments,
section announcements, excuses, tickets), `guard` (readers, taps, visitor cards). `X-Admin-Key` acts as `admin`.

| Area | Routes |
|---|---|
| Sign-in | `POST /admin/auth/login` → `{token}` · `/logout` · `GET /me` · `POST /password` |
| Console metadata | `GET /admin/meta` (resources, fields, policy) · `GET /admin/dashboard` |
| Staff | `GET/POST /admin/staff` · `PATCH /admin/staff/<id>` (role, active, password) |
| Readers | `GET/POST /admin/devices` (key shown once) · `PATCH` · `POST …/rotate-key` · `POST …/arm-timeout` · `GET /admin/taps?unknown=1` |
| Students and cards | `GET/POST /admin/students` · `PUT …/profile` · `POST …/claim-code` · `…/reset-account` · `POST /admin/students/import` (CSV) · `GET/POST /admin/cards` · `DELETE /admin/cards/<id>` |
| Attendance | `GET /admin/logs?date=` · `PATCH /admin/logs/<id>` (manual time out / clear flag, audited) · `GET/PUT /admin/settings` · `POST /admin/jobs/close-day` |
| Reports | `GET /admin/reports/daily[.csv]?date=&section_id=` · `/monthly[.csv]?month=` · `/student/<id>?month=` |
| Reviews | `GET /admin/excuses` · `POST …/<id>/review` · `GET /admin/tickets` · `POST …/<id>/reply` · `GET/PATCH /admin/library/reservations` |
| Communication | `GET/POST/DELETE /admin/announcements` (optional `section_id`) · `GET /admin/sms` · `GET/POST/PATCH/DELETE /admin/contacts` |
| Table resources | `GET/POST /admin/<name>` · `PATCH/DELETE /admin/<name>/<id>` for `terms`, `sections`, `subjects`, `schedules`, `calendar`, `rooms`, `map_places`, `directory`, `library_items`, `lost_found`, `faq`, `assistance`, `guardians`, `assignments` |
| Audit | `GET /admin/audit` |

## Attendance policy and the end of the day

Settings (console → Attendance settings): school start `07:30`, late after `15` minutes, cutoff `18:00`, school days
Mon–Fri, visitor limit 4 h, plus the school calendar (holidays, no-class days, special school days).

At the cutoff the server flags still-open records `MISSING_TIME_OUT` and tells those students, then records the absent
students (no tap on a school day) and, when enabled, tells them and texts their guardians. Days missed while the PC was
off are caught up (up to a week). It is safe to run again (`tools/manage.py close-day`).

## Notifications

| Event | Inbox (category) |
|---|---|
| Time in / time out | "Attendance Recorded", or "Late Arrival Recorded" with the minutes (attendance) |
| Duplicate scan / time out with no time in | One warning per 10 minutes (attendance) |
| Cutoff: open record / no tap | "Missing Time Out" / "Absence Recorded" (attendance) |
| Announcement | its title (system or emergency) |
| Assignment, ticket reply, excuse decision, library update | system |

The Flutter app polls every 30 s and on resume. Guardian SMS go through `sms_outbox` (status visible in the console).

## Tools

| Command | Purpose |
|---|---|
| `python run_server.py` | Production server (waitress) |
| `python tools/manage.py create-staff` | First admin account (local, no key) |
| `python tools/manage.py add-reader GATE-1 "Main gate"` | Reader key for the firmware |
| `python tools/manage.py migrate` / `backup` / `close-day` | Maintenance |
| `python tools/school_admin.py …` | Admin API from the command line (`ADMIN_API_KEY`) |
| `python tools/seed_demo.py` | Demo school in an **empty** database (`RFID_DB=demo.db`) |
| `python tools/e2e_check.py` | End-to-end check of a running server |
| `python -m unittest discover -s tests` | Server tests |
