Continue building PULSE (Expo SDK 58, TypeScript, React Navigation 7) in `mobile/` of my repo
(github.com/cuajotorprincejulmer17-beep/rfid). Follow the PULSE skills and project instructions.
Do NOT modify anything in `project/` (Flask, SQLite, RFID, ESP32).

DONE: themes + contrast tests; Stage 1b navigation per the latest design: tabs Home, Schedule, Pulse Core,
Tasks, More; Pulse Core fan and More overlay are separate; overlays keep history; Android Back closes the overlay
first (src/navigation/overlay.ts); More menu data in src/navigation/menu.ts (each tile real or disabled with reason);
sample-data Home (src/mock only). `npm run typecheck`, `npm test` (27 tests) and Android bundle export pass.
UNVERIFIED: never run on device/emulator (fan placement, animations, real Back).

BACKEND FACTS (verified from code): `/api/v1`; POST /auth/claim {student_number, claim_code, password};
POST /auth/login {student_number, password}; POST /auth/refresh {refresh_token} (rotates; replay revokes);
POST /auth/logout; GET /me, /home, /attendance/today, /attendance?month=YYYY-MM, /attendance/<date>,
/notifications (+/unread-count, /<id>, POST /<id>/read, /read-all), /contacts, PATCH /me/preferences, POST /devices.
Errors: {"error":{"code","message"}}. Attendance is READ-ONLY (complete/pending/incomplete/unavailable).
No endpoints exist for schedule, tasks, notes, announcements feed, directory, Digital ID, lost and found.

NEXT = Stage 2: typed API client (src/services), tokens in expo-secure-store, one auto-refresh on `token_expired`,
claim + login screens (no Google/Email buttons), sign-out, auth gate, client tests (401 refresh, network failure
= unknown, never false success). Then Stage 3 real Home/Attendance/Updates; Stage 4 Notes + Review (local-only).
OPEN: rotate the exposed ADMIN_API_KEY in notes.md; Android cleartext HTTP; test on a real device.
