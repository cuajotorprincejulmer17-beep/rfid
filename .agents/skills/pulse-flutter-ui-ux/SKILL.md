---
name: pulse-flutter-ui-ux
description: 'PULSE visual identity and Flutter UI/UX rules: tokens, ThemeExtension, four themes, typography, spacing, layout for 320dp to tablet, touch targets, accessibility, empty/loading/error/offline states, the Pulse Core dock, More panel, Home hierarchy, and a pre-merge UX checklist. Use for ANY Flutter screen, widget, theme, layout, or visual polish task, and whenever the user says design, UI, UX, look, spacing, typography, dark mode, accessibility, or "make it match the reference".'
---

# PULSE Flutter UI/UX

Goal: a premium, student-focused app that feels like PULSE (dark navy + electric violet, distinctive circular nav), not a generic Material template with a purple seed color.

## Identity
- Foundation near-black navy; electric violet used **selectively**: borders, rings, the featured card, active states, the Pulse button. Glow only on important elements (Pulse button, featured card, fan items), restrained. No heavy gradients, glassmorphism, clutter, tiny text.
- Themes: Dark, Light, Mono, Midnight, plus System (default). Persist the choice. See `references/tokens.md` (contrast-validated).
- One icon family, one stroke weight. Wordmark "PULSE" is letter-spaced (~4dp) with the pulse-line mark.

## Implementation rules
1. Colors/spacing/radii/typography come from tokens only: `ThemeData` + a `ThemeExtension<PulseColors>` (implement `copyWith` and `lerp`). No hex literals in widgets.
2. Build ONE reusable widget per concept (PulseCard incl. featured variant, PulseButton, StateView, StatusBadge, SectionHeader, IconCircle, PulseDock, MorePanel). Screens compose them.
3. Respect `MediaQuery.paddingOf` / `SafeArea`; never hardcode status-bar or gesture-bar heights.
4. Layout must survive 320x640, 360x800, 412x915 and a 800x1280 tablet, and **text scale 2.0** without overflow: use `Flexible`/`Expanded`/`Wrap`, no fixed heights around text, `maxLines` + `overflow` deliberately, and wrap labels (never clip, e.g. "Tasks & Planner").
5. Min touch target 48x48dp. Visible focus/pressed states (InkWell/ink overlays). Semantics labels on every icon-only control; mark disabled items `Semantics(enabled:false)` with the reason in the label.
6. Contrast: body and muted text >= 4.5:1 on every surface including the featured tint. Never convey meaning by color alone (status = icon + text).
7. Copy is honest and plain. "Not built yet", "Needs school backend", "You're offline. Showing saved data, last updated 9:41". Never "Verified" unless the server says so; use the server's actual state wording.
8. Every data region has all six states (see `pulse-backend-contract`). Empty states carry a next action. Error states carry Retry.

## Key layouts
- **Bottom bar:** Home, Schedule, [Pulse Core], Tasks, More. The Pulse button (ring, MENU label) sits in a curved cradle (CustomPainter/ClipPath) rising from the bar so it is integrated, not floating. Labels never overlap the fan.
- **Pulse Core fan:** dims the whole screen including the bar; button is redrawn above the scrim as Close in the same spot; 6 items (Home, Schedule, Attendance, Tasks, Updates, More) on an arc that fits 320dp wide and never collides with the button or bar.
- **More:** separate from Pulse Core. Rounded-top full-height scrollable panel over the dimmed app: drag handle, PULSE header (notifications, profile), group cards Academic / Study Space / Campus / Personal, round icon tiles, bottom dock identical to the bar with a prominent Close. Unavailable tiles are visibly disabled with the reason.
- **Home order:** greeting -> featured Attendance card (violet-tinted, the single hero) -> Next class -> Upcoming tasks ("View all") -> Latest updates -> compact Study Space. No big unexplained gaps; consistent 16/24 vertical rhythm.
- Attendance icon = card-tap (RFID cards), not a fingerprint.

## Behavior
- Opening/closing Pulse Core or More must NOT change navigation history. Android Back (`PopScope`) closes an open overlay first. Use a shell route (`go_router`). Check the installed Flutter version's `PopScope` callback names.
- Provide light/dark/system switching with an immediate, flicker-free update.

## UX checklist (run before calling any screen done)
[ ] Matches reference hierarchy (one hero per screen)  [ ] tokens only  [ ] 6 data states  [ ] 320dp and 2.0x text scale  [ ] 48dp targets + Semantics  [ ] all 4 themes legible  [ ] Back/history correct  [ ] no sample data in real paths  [ ] disabled controls explain why  [ ] motion follows `pulse-flutter-animation`
