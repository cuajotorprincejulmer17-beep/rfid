# PULSE mobile (Stage 1c, Expo SDK 58 + TypeScript)

This Expo app lives beside the Flask project in `mobile/`. Stage 1c is an offline
UI prototype using clearly labelled sample data: it does not currently make API,
RFID, attendance, or authentication requests. Nothing in `project/` (Python,
RFID, ESP32, database, or Flask configuration) was modified for this integration.

## Run
```
cd mobile
npm ci
npx expo start            # scan the QR code with Expo Go (same Wi-Fi)
```

## Future API configuration

Stage 1c only displays the API URL setting; it does not consume it yet. When a
later stage adds a client, copy `.env.example` to `.env` and set:

```env
EXPO_PUBLIC_API_URL=http://<PC LAN IP>:5001
```

Use the PC's LAN IPv4 rather than `localhost` for a physical phone on the same
Wi-Fi. A future client should append `/api/v1` to this base URL. `EXPO_PUBLIC_*`
values are bundled into the app, so never put `ADMIN_API_KEY`, database credentials,
tokens, or other secrets in `.env`. No production backend configuration change is
needed or included here.

## Checks
`npm run typecheck` · `npm test`

## Navigation (Stage 1c, matches the latest design references)
- Bottom bar: Home, Schedule, **Pulse Core** (centre), Tasks, More.
- **Pulse Core** is seated in a raised dock cradle, opens a quick-action arc (Home, Schedule, Attendance, Tasks, Updates, More), and turns into Close above a full-screen scrim.
- **More** is a separate rounded, full-height scrollable panel over the dimmed app: Academic, Study Space, Campus, Personal, with a matching dock and Close control at bottom centre.
- Overlays never change navigation history. Android Back closes the open overlay first (`src/navigation/overlay.ts`, tested).
- Every More tile is a real destination or disabled with a visible reason. No Financial group; no fake Digital ID, Room Finder or Lost & Found.
- Attendance uses a card-tap icon (RFID cards, not fingerprints).

## Stage 1c status
Done: themes (dark, light, mono, midnight, system) with contrast tests; navigation above; Settings > Appearance;
Home with clearly labelled SAMPLE data (`src/mock`, never imported by API code).
Schedule, Tasks, Updates, Attendance, Notes, Review are honest "not built yet" placeholders.

## Not done yet
Stage 2 login/claim + secure tokens; 3 real Home/Attendance/Updates; 4 Notes + Review (editor, flashcards, reminders);
5 Schedule/Tasks/Workload; 6 Directory, Profile, push; 7 Insights, accessibility, hardening.

## Integration limitations

The app has not been run on a device or emulator as part of this integration.
Layout, animations, Pulse Core fan placement, real Back-button behaviour, Flask
connectivity, authentication, RFID, and attendance hardware remain untested.
