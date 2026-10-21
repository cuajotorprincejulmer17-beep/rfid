# Testing the PULSE Flutter app

Two levels:

1. **Automated** — `flutter analyze`, `flutter test`, `flutter build`. No device needed.
2. **Manual** — run the app on the emulator against a real server.

---

## 1. Automated checks (no device needed)

Open a **new** PowerShell window (the environment variables were set for new
shells only — an old window will still say `flutter: command not found`).

```powershell
cd C:\Users\cuajo\OneDrive\Desktop\rfid-main\mobile_flutter

flutter --version      # expect 3.47.7
flutter analyze        # expect: No issues found!
flutter test           # expect: All tests passed! (207 tests)
```

Build the APK:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

> `10.0.2.2` is how the Android emulator reaches your PC's loopback.
> On a **real phone**, use your PC's LAN IP instead, e.g.
> `--dart-define=API_BASE_URL=http://192.168.1.20:5001`.

---

## 2. Start an isolated test server

**Your real database (`project/rfid_system.db`) is never touched.** The script
copies the server code to `%TEMP%\pulse_test_server\code` and keeps the test
database in `%TEMP%\pulse_test_server\data`, so a fresh empty one is created
on the first run and then reused.

```powershell
cd C:\Users\cuajo\OneDrive\Desktop\rfid-main
python mobile_flutter\tool\make_test_server.py
```

It prints:

```
  API URL (from the emulator) : http://10.0.2.2:5001
  API URL (from this PC)       : http://127.0.0.1:5001

  Student number : 2026-0001
  Password       : pulse-test-1234
```

It also registers a card (`000000000001`) and posts a **real** RFID tap, so
attendance and the inbox already have data.

The database **persists across restarts**, so `--stop` then a fresh start
keeps the same student and the same attendance. Use `--clean` to wipe it.

Stop / delete it:

```powershell
python mobile_flutter\tool\make_test_server.py --stop    # stop only
python mobile_flutter\tool\make_test_server.py --clean   # stop + delete everything
```

---

## 3. Run the app on the emulator

Start the emulator (it may already be running):

```powershell
$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
& "$SdkRoot\emulator\emulator.exe" -avd Pulse_API_36
```

In a **second** window, install and launch:

```powershell
cd C:\Users\cuajo\OneDrive\Desktop\rfid-main\mobile_flutter
adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell monkey -p com.pulse.pulse_flutter -c android.intent.category.LAUNCHER 1
```

Or use `flutter run` for hot reload:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

**Sign in with:**

| Field | Value |
|---|---|
| Student number | `2026-0001` |
| Password | `pulse-test-1234` |

---

## 4. What to check by hand

| # | Where | What to do | Expected |
|---|---|---|---|
| 1 | Sign in | Enter the credentials above | Home shows **"Time in recorded"**, **"2 unread"**, and the student name |
| 2 | Attendance | Tap the hero card | **0 Complete / 1 Pending / 0 Incomplete**, "Updated just now" |
| 3 | Inbox | Tap the bell | "Attendance Recorded" + "Welcome" rows |
| 4 | More panel | Tap **More** | Groups *Academic / Study Space / Campus / Personal*. Disabled tiles show a grey reason |
| 5 | Settings | Tap the gear | Theme radio buttons, preference switches, server URL, **Test connection** → "Server responded." |
| 6 | Theme | Pick Light / Mono / Midnight | The app re-colours **instantly**, no restart |
| 7 | Back | Open More, press Back | The panel closes; you stay on Home |
| 8 | Back | On Attendance, press Back | You return to Home |
| 9 | Back | On Home, press Back | The app closes (correct — nothing to go back to) |
| 10 | **Offline** | Stop the server (`--stop`), then pull-to-refresh | **"Status unknown — We couldn't reach the school server… This is not the same as being absent."** + **Retry** |
| 11 | Retry | Restart the server, tap **Retry** | Fresh data returns |
| 12 | Large text | Settings → Accessibility → Display size → Largest | No clipped words, no overflow stripes |
| 13 | Real data | `python mobile_flutter\tool\make_test_server.py --clean`, then use the **real** server | The app talks to `project/` as normal |

> **#10 is the most important check.** A failed request must read as
> *unknown*, never as *absent*, *0* or *no records*.

---

## 5. Testing the RFID tap

The app never submits attendance — the server decides, in one transaction,
when a physical card is tapped. To simulate a tap without hardware:

```powershell
# While the test server is running
$body = @{ uid = "000000000001" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://127.0.0.1:5001/tap" -Method Post -Body $body -ContentType "application/json"
```

A student card returns `TIME_IN_OK` the first time. Tapping again returns
`ALREADY_CHECKED_IN` (the app must still show the **original** time-in).

To time out, the server needs the "timeout arm" that the kiosk normally
sends — `POST /timeout-arm` on the app root.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `flutter: command not found` | Old PowerShell window | Open a **new** window |
| `Gradle requires JVM 17 or later` | Old window has Oracle JRE 8 | New window, or set `JAVA_HOME` to `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot` |
| "Could not load / Sign in to continue" | The app has a token from a server that is gone | The app now returns to sign-in automatically. Sign in again |
| "Status unknown" | The server is not reachable | Check `--dart-define=API_BASE_URL`. `10.0.2.2` for the emulator, LAN IP for a phone |
| "Server responded." fails | Server down | `python mobile_flutter\tool\make_test_server.py` |
| Emulator won't start: "multiple emulators with the same AVD" | One is already running | `adb emu kill`, then start it again |
| Emulator: "hasCompatibleHypervisor … not met" | The hypervisor driver is missing | `sdkmanager "extras;google;Android_Emulator_Hypervisor_Driver"`, then `cd` into the driver folder and run `silent_install.bat` as admin |
| Port 5001 already in use | An old test server is running | `python mobile_flutter\tool\make_test_server.py --clean` |
| Cleartext HTTP blocked | A **release** build | Cleartext is allowed in the debug manifest only. A release build needs HTTPS |

---

## 7. Backend tests (read-only)

The Python suite is the baseline for the server and never touches your
real database (it builds its own):

```powershell
cd C:\Users\cuajo\OneDrive\Desktop\rfid-main\project
python -m unittest tests.test_api -v
```

Expected: `Ran 33 tests … OK`.
