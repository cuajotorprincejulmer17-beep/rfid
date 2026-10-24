# PULSE — RFID attendance and student app

One Python server and one SQLite database shared by the ESP32 RFID readers, a staff admin console, a kiosk display
and the Flutter student app.

```
ESP32 + RC522 reader ──┐
Kiosk TIME OUT screen ─┤                               ┌─ rfid_system.db (SQLite, WAL)
Staff console /admin ──┼──> project/  Flask server ────┤
Desktop admin app_ui ──┤      (python run_server.py)   └─ backups/
Flutter student app ───┘
```

| Folder | What |
|---|---|
| `project/` | Server: tap logic, `/api/v1` for readers, students and staff, admin console (`admin_web/`), jobs, migrations, tools, tests |
| `project/rfid_reader/` | ESP32 firmware v2 (LCD); `rfid_reader_no_lcd/` for Serial Monitor only |
| `mobile_flutter/` | PULSE student app (Flutter) |
| `mobile/` | Earlier Expo prototype (superseded by `mobile_flutter/`) |
| `docs/` | `DEPLOYMENT.md` (school setup), `BACKEND_INTEGRATION_PLAN.md` (gap analysis and plan) |

## Quick start (development)

```bash
cd project
python -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env                                    # set ADMIN_API_KEY
.venv/bin/python tools/manage.py create-staff admin "Admin" --role admin
.venv/bin/python run_server.py                          # http://localhost:5001/admin
```

Demo data instead of real records: `RFID_DB=demo.db .venv/bin/python tools/seed_demo.py`, then start the server
with the same `RFID_DB`.

App: see `mobile_flutter/README.md`. Readers and school setup: see `docs/DEPLOYMENT.md`. API: `project/API_README.md`.

## Tests

```bash
cd project && .venv/bin/python -m unittest discover -s tests      # server
cd mobile_flutter && flutter test                                  # app
ADMIN_API_KEY=... python project/tools/e2e_check.py                 # a running server, end to end
```
