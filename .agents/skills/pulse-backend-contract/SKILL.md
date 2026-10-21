---
name: pulse-backend-contract
description: Verified PULSE backend facts (Flask /api/v1, claim-login-refresh auth, read-only attendance, inbox, contacts, preferences, devices) and the data-honesty rules for any app code that touches the API. Use whenever you write or review repositories, API clients, auth, attendance, notifications, Home data, offline/cached/error states, or anything that might invent endpoints or sample data, even if the user does not mention the backend.
---

# PULSE backend contract

These facts were verified from the repo in an earlier inspection. **Re-verify against `project/api/*`, `project/database.py`, `project/API_README.md` and the tests before relying on them**, and report any drift.

## Contract
- Base path `/api/v1`. Errors are `{"error":{"code","message"}}`; branch on `code`, never on message text.
- Auth: staff register the student and issue a one-time claim code. `POST /auth/claim {student_number, claim_code, password}`, `POST /auth/login {student_number, password}`, `POST /auth/refresh {refresh_token}` (refresh tokens ROTATE; replaying an old one revokes the session), `POST /auth/logout`.
- Reads: `GET /me`, `/home`, `/attendance/today`, `/attendance?month=YYYY-MM`, `/attendance/<date>`, `/notifications` (+ `/unread-count`, `/<id>`, `POST /<id>/read`, `POST /read-all`), `/contacts` (ships empty). `PATCH /me/preferences` (attendance alerts, announcements, sound, haptics). `POST /devices` (Expo push tokens only).
- Attendance statuses: `complete`, `pending`, `incomplete`, `unavailable`. Taps happen only on the RFID reader; the server decides in one transaction.
- `/api/v1/admin/*` exists. The student app must never call it.
- **No endpoints exist** for: schedule, tasks, notes, flashcards, an announcements feed (only inbox rows categorized emergency/system), directory/rooms, Digital ID, lost and found, attendance issue reports, Google/email login.
- Push: the existing device registration is Expo-only. Flutter needs FCM. Phase 1 = inbox polling + pull-to-refresh. A provider-aware backend change is a SEPARATE proposal needing my approval. Never fake push.

## Rules
1. Do not invent endpoints, fields, or states. If something is missing, document the gap and propose the smallest safe backend change for approval.
2. Tokens only in `flutter_secure_storage`. One automatic refresh on an expired access token, serialised so parallel requests share a single refresh. If refresh fails, sign out cleanly. Never log tokens.
3. Never retry a non-idempotent call blindly. Attendance is read-only here, so only reads auto-retry (bounded, with backoff).
4. Network failure/timeout/ambiguous response = **unknown**, shown with Retry. Never render it as absent, zero, or "no records".
5. Every data card distinguishes: loading, fresh (with last-updated), cached (labeled), empty (confirmed by a successful response), offline, error.
6. An authenticated account is not automatically a verified student. The backend is the authority; hiding a button is not authorization.
7. Sample data: one isolated file, labeled "Sample data", never imported by repositories. Remove it from a screen the moment that screen is wired to real data.
8. Local-only features (notes, flashcards, tasks, planner): device-private, versioned storage, labeled as the student's own content. Not official school information.
