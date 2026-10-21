# Pulse Flutter — decisions

Judgement calls made while building the Flutter app to the
`PULSE_FLUTTER_MASTER_PROMPT.md` specification. The specification is the
source of truth; this file records where reality forced a different choice
and why.

## 2026-10-21 — Rebuild to the master prompt spec

The spec replaces the previous information architecture (a More panel with a
grid of tiles, a 3-item Pulse Core fan, no dock tabs) with a canonical
destination registry, a four-item fan of category hubs, and a five-position
floating dock. The old `lib/ui/` tree is removed rather than patched,
because the two structures are not compatible: the old shell owned its own
tab state in `setState` and routed screens with `context.go`, while the spec
requires `StatefulShellRoute.indexedStack` with the root navigator for
category hubs.

### D1 — Attendance keeps the real, read-only server read

The spec asks for a "Start demo scan" button that simulates the attendance
decision client-side. The repository's hard rules say attendance is
read-only and server-derived, and the app already reads the real
`GET /api/v1/attendance/today`.

**Decision:** the Attendance page shows the real server status
(`complete` / `pending` / `incomplete` / `unavailable`) and the real
recorded times. There is no client-side scan simulation that decides
attendance, because a simulated scan would put a decision the backend owns
into the client, and a failure would have to be rendered as "unknown" rather
than "absent".

The spec's demo scan flow is still reachable, but only as a clearly labelled
simulation of the *reader* step, in its own section, below the real status
card. It never writes attendance state and never claims verification.

### D2 — Three themes, not five

The spec defines Pulse Purple Dark, Mono and Light. The previous app also
shipped Midnight and a System option. The user chose the spec's three
themes. Pulse Purple Dark replaces the old "Dark" palette; Midnight and
System are dropped. Every palette is re-derived from the spec's measured
token table, so contrast is recomputed rather than inherited.

### D3 — Sample data stays in one isolated file

The spec's repositories are demo-backed. The backend contract forbids
inventing endpoints, so the features the backend does not serve (schedule,
tasks, directory, digital ID, lost and found, library, map) cannot come from
the server. They are served by repository implementations backed by a single
isolated sample-data file, labelled "Sample data" in the UI.

The rule "no feature has two global entry points" and "sample data never
imported by repositories" is honoured in one direction only: the sample file
is imported **only** by the sample-data repository implementations, never by
a screen and never by a real-data repository. The real-data repositories
(`attendance`, `inbox`, `profile`, `contacts`) keep calling the real API.

### D4 — Attendance history and insights are computed from real data

`/api/v1` has `GET /attendance/today` and `GET /attendance?month=YYYY-MM`,
so attendance history and the attendance rate shown in Workload and
Insights are computed from those real reads. Only the non-attendance parts
of Insights (due-soon task load) come from sample data, and the page labels
which is which.

### D5 — Pre-existing golden failures are recorded, not silently fixed

Before any change, `flutter test` failed 48 golden tests (the Home
goldens, small pixel diffs of about 0.26%) with `flutter analyze` clean.
These pre-date this work. The old Home screen and the old golden set are
replaced by the new design, so the old goldens are deleted and a new
18-golden set is generated deliberately with
`flutter test --update-goldens`, as the spec requires.

### D6 — Motion Law overrides the older animation skill

`.agents/skills/pulse-flutter-animation` describes duration-and-curve motion
with staggered entrances. The spec's Motion Law is explicit, is the newer
document, and says it beats every other duration, stagger or easing. The
spec wins: one spring (`mass 1, stiffness 1450, damping 61`), no entry
staggers, no shimmer loops, 150 ms single-flight lock, pointer-down feedback.

The older skill's genuinely additive rules are kept where they do not
conflict: one reusable widget per concept, controllers created in
`initState` and disposed in `dispose`, transforms and opacity rather than
layout, and a reduced-motion path for every animation.

### D7 — Fonts are bundled from the official Inter release

The spec requires Inter bundled in `assets/fonts/` and never downloaded at
runtime. The four static weights (Regular 400, Medium 500, SemiBold 600,
Bold 700) come from the official Inter 4.0 release archive. The SIL Open
Font License is bundled alongside them.
