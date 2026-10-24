# Deploying PULSE at school

One Windows (or macOS/Linux) PC runs the server and keeps the database. The RFID readers, the kiosk display, staff
browsers and student phones all reach it over the school WiFi.

```
[ESP32 + RC522 + LCD] --WiFi-->  ┐
[Kiosk display PC/TV] --LAN--->  ├──>  School PC: python run_server.py  (port 5001)  ──> rfid_system.db
[Staff browser /admin] --LAN-->  │                                                     backups/
[Student phones (app)] --WiFi->  ┘
```

## 1. The server PC

1. Install Python 3.11+ (tick "Add Python to PATH").
2. In `project\`:
   ```bat
   python -m venv .venv
   .venv\Scripts\pip install -r requirements.txt
   copy .env.example .env
   ```
3. Edit `.env`. Set `ADMIN_API_KEY` to a new random value:
   `python -c "import secrets; print(secrets.token_urlsafe(32))"`.
   **The key that used to be in `notes.md` is in the git history: do not reuse it.**
4. Create the first staff account (asks for a password):
   ```bat
   .venv\Scripts\python tools\manage.py create-staff admin "School Administrator" --role admin
   ```
5. Start the server: double-click `run_server.bat` (or `python run_server.py`). On first start it migrates the existing
   `rfid_system.db` and writes a copy to `backups\` first.
6. Give the PC a fixed address: a DHCP reservation in the router (preferred) or a static IPv4. Note it, e.g. `192.168.1.50`.
7. Allow the port through Windows Firewall (admin PowerShell):
   ```powershell
   New-NetFirewallRule -DisplayName "PULSE 5001" -Direction Inbound -Protocol TCP -LocalPort 5001 -Action Allow -Profile Private
   ```
   Set the school WiFi to the **Private** network profile.
8. Start it with Windows: Task Scheduler → Create Task → "At log on" → action `run_server.bat`, "Start in" the
   `project` folder.

Check from another device on the WiFi: `http://192.168.1.50:5001/api/v1/health` shows `"status": "ok"`.

## 2. Staff console

Open `http://192.168.1.50:5001/admin` and sign in. Then, in order:

1. **Administration → Staff accounts**: one account per registrar, teacher and guard.
2. **School → Terms, Sections, Subjects**, then **Campus → Rooms**, then **School → Class schedules**.
3. **Administration → Attendance settings**: start time, late threshold, cutoff, school days. **School calendar**: holidays.
4. **People → Students**: "Import CSV" (`uid,name,student_number,section,phone`) or "Add student" and tap the card on
   any reader, then "Use last tapped card".
5. **People → Students → App code** for each student who will use the phone app.
6. Optional: **Guardians** for SMS, **Campus** content (directory, map, library, FAQ), **Announcements**.

## 3. RFID readers (ESP32)

1. Console → **People → RFID readers → Add reader** (code `GATE-1`, mode `KIOSK`, or an `IN`/`OUT` pair for separate
   entrance and exit readers). Copy the three lines it shows.
2. Open `project/rfid_reader/rfid_reader.ino` in Arduino IDE 2 and set `WIFI_SSID`, `WIFI_PASS`, `SERVER_BASE`
   (`http://192.168.1.50:5001`), `DEVICE_CODE`, `DEVICE_KEY`. The WiFi must be **2.4 GHz**.
3. Libraries: MFRC522 (GithubCommunity), LiquidCrystal I2C (Frank de Brabander), ArduinoJson 7. Board: ESP32 Dev Module.
   Upload.
4. The LCD shows `PULSE 2.0.0` then `System Ready`. The console shows the reader online within a minute.
5. Optional TIME OUT push button: GPIO 27 to GND.
6. When every reader runs v2, set `ALLOW_LEGACY_TAP=0` in `.env` and restart.

Wiring is unchanged (see `project/PROJECT_GUIDE.md` §3). Without an LCD use `rfid_reader_no_lcd/`.

If the server is unreachable the reader stores up to 50 taps (`SAVED OFFLINE`) and sends them, with their original
times, when it is back.

## 4. Kiosk display (TIME OUT screen)

On the PC or TV next to the gate:
```bat
set RFID_SERVER=http://192.168.1.50:5001
set RFID_DEVICE_KEY=<the GATE-1 key>
python student_display.py
```
Without `RFID_DEVICE_KEY` it drives the legacy `DEFAULT` reader.

## 5. Student phones

Install the app (`mobile_flutter`, `flutter build apk` for Android). On first launch: **Change** the school server to
`http://192.168.1.50:5001`, **Test connection**, then **Activate your account** with the student number and the app code.
The phone must be on the school WiFi.

## 6. Backups

- Automatic: before every migration (`backups\rfid_system-<time>-pre-migration.db`).
- Daily: Task Scheduler, daily at 19:00, `.venv\Scripts\python tools\manage.py backup`. Copy `backups\` to a USB drive
  or cloud folder weekly.
- Restore: stop the server, copy a backup over `rfid_system.db`, start the server.

## 7. Checks before the defence

```bat
.venv\Scripts\python -m unittest discover -s tests
set ADMIN_API_KEY=<your key>
.venv\Scripts\python tools\e2e_check.py http://192.168.1.50:5001
```
`ALL CHECKS PASSED` means reader → server → app → reports work end to end. For a rehearsal without real data:
`set RFID_DB=demo.db` then `python tools\seed_demo.py` and `python run_server.py`.

## Security notes

- Keep the server on the school LAN. Do not port-forward it to the internet. For remote access use a VPN or an HTTPS
  tunnel that blocks `/api/v1/admin/*`.
- Every reader has its own key; rotate it in the console if an ESP32 is lost.
- The keyless desktop routes (`/users`, `/logs`) answer only the server PC itself.
- Staff actions are recorded in **Administration → Audit log**.
