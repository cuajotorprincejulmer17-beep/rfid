# PULSE tokens (WCAG AA validated for text pairs; re-run a contrast unit test in Dart)

| Token | Dark | Light | Mono | Midnight |
|---|---|---|---|---|
| bg | #0B0A14 | #F7F5FF | #0A0A0A | #050A1A |
| surface | #15131F | #FFFFFF | #141414 | #0D1530 |
| surfaceAlt | #1E1B2E | #EEEAFB | #1F1F1F | #16214A |
| border | #2E2A47 | #D9D2F2 | #333333 | #26346B |
| text | #F4F2FF | #1A1530 | #F5F5F5 | #EEF2FF |
| textMuted | #B4AFD0 | #5B5675 | #B3B3B3 | #AAB6E0 |
| primary | #7C3AED | #6D28D9 | #E5E5E5 | #7C3AED |
| onPrimary | #FFFFFF | #FFFFFF | #0A0A0A | #FFFFFF |
| accent | #A78BFA | #6D28D9 | #A3A3A3 | #A78BFA |
| success | #34D399 | #047857 | #86EFAC | #34D399 |
| warning | #FBBF24 | #92400E | #FDE68A | #FBBF24 |
| danger | #F87171 | #B91C1C | #FCA5A5 | #F87171 |

Featured card surface = mix(surface, primary, 16%); featured border = mix(border, primary, 60%). Verify text, textMuted and accent >= 4.5:1 on it in all four themes (the light accent had to be darkened to pass).

Spacing: 4, 8, 12, 16, 24, 32. Radii: 8, 12, 16, 24 (sheet top 28), pill. Touch target 48. Pulse button 68dp, cradle 92dp.
Type scale (scales with system text size): title 26/32 w700, heading 18/24 w600, body 16/22, caption 14/19, micro 12 (use sparingly). Bundle the font as an asset (no runtime font download; the app must work offline).
