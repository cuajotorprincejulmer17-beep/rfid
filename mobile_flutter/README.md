# PULSE (Flutter)

The student app for the RFID attendance system. It talks to the same Flask
server and SQLite database as the ESP32 reader (`../project`).

## Requirements

- Flutter **3.47.7** or newer (Dart 3.13.5+, required by Riverpod 3.4)
- The backend running: `cd ../project && python app.py` (port 5001)

## Run

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

`API_BASE_URL` is only the default. The address can be changed in the app
on the sign-in page or in Settings → School account. Which address to use:

| Where the app runs | Server address |
|---|---|
| iOS simulator on the server PC | `http://127.0.0.1:5001` |
| Android emulator on the server PC | `http://10.0.2.2:5001` |
| A real phone on the school WiFi | `http://<PC IPv4 address>:5001` |

## First sign-in

A student account is activated once with a code from the school office:

```bash
cd ../project
python tools/school_admin.py students
python tools/school_admin.py set-profile <user_id> <student_number> --section "BSIT - 2A"
python tools/school_admin.py claim-code <user_id>
```

In the app: **First time? Activate your account**, then enter the student
number, the code and a new password. After that, sign in with the student
number and password.

## What is live and what is sample data

Signed in, every screen reads the school server: Home, Attendance (with excuse letters) and its history (present,
late, absent, excused), Schedule (today, week, month), Tasks (own tasks and teacher assignments), Updates (the
inbox), Digital ID, Profile, Room Finder, Map, Directory, Lost and Found, Library, FAQ, Assistance and Contact Support
(messages and replies). The app polls every 30 seconds and refreshes when it returns to the foreground, so a card tap
shows up within one interval.

Signed out, or built with `--dart-define=DEMO=true`, the campus features show the built-in sample data and say so
with a "Sample data" chip. Attendance never shows sample data.

## Test

```bash
flutter analyze
flutter test
```
