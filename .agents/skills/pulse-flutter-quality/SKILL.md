---
name: pulse-flutter-quality
description: 'Verification and reporting for the PULSE Flutter app: flutter analyze/test/build, widget, golden and accessibility tests, the required test list, device-vs-software honesty, and the end-of-stage report format. Use after every implementation stage, whenever you write or run tests, before saying something works, and when asked to review, debug, or verify.'
---

# PULSE Flutter quality

## Commands (run from `mobile_flutter/`)
`flutter --version`, `flutter doctor -v` (report missing pieces instead of faking), `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. Backend baseline (read-only): run the existing Python tests from `project/` and report results; do not commit generated DB/log files.

## Required tests (add as the feature lands)
- Theme: contrast >= 4.5:1 for text/muted/onPrimary/status colors in all four themes, including the featured-card tint.
- Navigation: Back closes an open overlay first; overlays do not alter router history; Pulse Core and More are independent; every More tile is a real destination or disabled with a reason; fan fits a 320dp width.
- Data honesty: failed attendance request renders "unknown + Retry", never absent/0; protected data unreachable when unauthenticated; sample data not imported by repositories.
- Auth: single serialised refresh on expiry; replayed-refresh failure signs out; tokens only in secure storage; logout clears state.
- Notes (Stage 4+): autosave never silently loses edits, overlapping saves are safe; generated flashcards are editable before saving; the source note stays intact; reminders/notifications never claim success before confirmation.
- Accessibility: `meetsGuideline(androidTapTargetGuideline)`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` on key screens; semantics labels on icon-only buttons.
- Responsive goldens (flutter_test `matchesGoldenFile`): 320x640, 360x800, 412x915, tablet 800x1280; text scale 1.0 / 1.5 / 2.0; dark and light. Update goldens only intentionally and say so.
- Animations: see `pulse-flutter-animation` (start/mid/end pumps, reduced-motion path, rapid taps).

## Honesty
- Never claim a test passed unless you ran it. Software tests are not hardware verification; the app and RFID reader were not exercised unless I say so. State plainly when something was **not run on a device**.
- If a check fails, report it with the cause and your fix or recommendation. Do not weaken a test to make it pass.

## End-of-stage report (always this shape)
1. Goal and scope  2. Files changed (list)  3. Checks run with pass/fail counts  4. Regressions found  5. UNKNOWN / unverified  6. What remains / next stage  7. Anything needing my approval.
