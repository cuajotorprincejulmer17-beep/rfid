---
name: pulse-flutter-animation
description: 'Motion design and Flutter animation implementation for PULSE: motion tokens, a per-component animation spec (Pulse button, fan, More panel, tabs, cards, lists, attendance status, skeletons, flashcard flip, autosave chip), reduced-motion handling, interruptibility, performance, and animation tests. Use whenever you add or change any transition, animation, gesture, overlay, loading effect, or micro-interaction, and whenever the user says smooth, animate, transition, motion, polish, or "feel".'
---

# PULSE motion (Flutter)

Principle: motion explains cause and effect and confirms state. It is **smooth and restrained**, never decorative, never blocking. If an animation would delay the user, shorten or drop it.

## Tokens (one `Motion` class; no magic numbers in widgets)
- Durations: instant 90ms (press), fast 140ms, base 200ms, slow 280ms, sheet 320ms (open) / 240ms (close).
- Curves: enter `easeOutCubic`; exit `easeInCubic`; emphasis (fan items only) `easeOutBack` with a **small** overshoot; standard `easeInOutCubic`.
- Reduced motion: `MediaQuery.disableAnimationsOf(context)` -> durations 0 (or a plain crossfade <= 100ms). Looping animations (shimmer, glow) become static. Every animation below has a reduced path and a test.
```dart
class Motion {
  static bool reduced(BuildContext c) => MediaQuery.disableAnimationsOf(c);
  static Duration d(BuildContext c, Duration base) => reduced(c) ? Duration.zero : base;
}
```

## Per-component spec
| Component | Motion | Notes |
|---|---|---|
| Pulse button (press) | scale 1 -> 0.94 on down (instant), back (fast); ring glow intensity eases up | `HapticFeedback.selectionClick()` only if the user's haptics preference is on |
| Pulse icon -> Close | rotate 0 -> 90deg + crossfade pulse/close icon, fast | `AnimatedSwitcher` + `RotationTransition`; label MENU <-> CLOSE crossfade |
| Fan open | scrim fades to ~80% (base). 6 items fly from the button centre along their arc: translate + scale 0.6 -> 1 + opacity, **staggered** ~30-40ms via `Interval` (start `i*0.06`) | one `AnimationController`, `CurvedAnimation` per item with `reverseCurve` |
| Fan close | reverse, **no stagger**, fast (140ms) | must be interruptible: tapping mid-open calls `reverse()` from the current value |
| Fan item tap | item scales 1.08 briefly, fan closes, then navigate | navigate after close starts, not after it finishes |
| More panel open | slides up from bottom (sheet 320ms, enter curve) while scrim fades (base). Content is visible immediately; do not stagger tiles | `SlideTransition` / `Transform.translate`; avoid animating height/layout |
| More panel close | slides down (240ms exit curve); also by drag-down past ~25% height or fling velocity | `GestureDetector`/`DraggableScrollableSheet`; Android Back closes it first (`PopScope`); support predictive back where the platform provides it |
| Dock (More) | identical geometry to the bar so Close sits exactly where Pulse sits; no extra motion | |
| Tab switch | content fade-through (fast); active icon colour tween (fast); NO horizontal slide | `IndexedStack` + `FadeTransition` or `AnimatedSwitcher` |
| Cards (press) | scale 0.98 + ink overlay (instant) | `InkWell` + `AnimatedScale` |
| First list load | items fade + 8dp upward slide, stagger <= 40ms, **max 6 items**, once per screen load | never replay on refresh/rebuild |
| Skeleton loading | soft shimmer, 1.2s loop | static when reduced; stop when off-screen |
| Attendance status change | `AnimatedSwitcher` crossfade (base). A check draw-on (CustomPainter, 400ms) only when the **server-confirmed** status first arrives | never animate toward "success" before the server confirms; pending shows a calm progress indicator |
| Offline banner | slide-down + fade (base) | announce via `SemanticsService` |
| Autosave chip | saving -> saved -> failed crossfade (fast); "failed" persists until resolved | no spinner flicker for saves < 300ms (delay showing "Saving...") |
| Flashcard flip | 3D flip 350ms: `Matrix4.identity()..setEntry(3,2,0.001)..rotateY(a)`, swap face at 90deg | reduced -> crossfade |
| Review grading | card slides off in the grade direction + brief tint (success/danger), next card fades in | grade buttons remain the primary control; swipe is an extra |
| Checklist toggle | check scales in (fast), text strike-through fades | |
| Theme change | `AnimatedTheme` default or instant; no flicker | |
| Route push/pop | platform defaults via `PageTransitionsTheme`; do not hand-roll | |

## Implementation rules
1. Simple state changes: implicit widgets (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedScale`, `AnimatedSwitcher`, `TweenAnimationBuilder`). Orchestrated/stagger/gesture-driven: explicit `AnimationController` with `SingleTickerProviderStateMixin`. **Always dispose controllers.**
2. Animate **transforms and opacity** (`Transform`, `SlideTransition`, `ScaleTransition`, `FadeTransition`), not layout. Use `AnimatedBuilder(child: ...)` so the static subtree is not rebuilt. Wrap heavy animated areas in `RepaintBoundary`.
3. No `Opacity` widget over large subtrees (use `FadeTransition`). Avoid `saveLayer` triggers (large clips + opacity, big blurred shadows). Pre-define `BoxShadow`s; keep blur modest.
4. Overlay controllers live above the router so open/close never touches navigation history.
5. Every controller must be safe if the user taps rapidly (interruptible, no stuck scrim, no double navigation).
6. No animation may hide an error or imply unconfirmed success.

## Verify
- Widget tests: `await tester.pump(Duration(...))` at start/mid/end; assert scrim visible when open and gone when closed; rapid double-tap leaves a consistent state; a test with `MediaQuery(data: ...copyWith(disableAnimations: true))` completes instantly; no pending timers/tickers at test end.
- Profile on a mid-range Android device: `flutter run --profile`, DevTools Performance; target no dropped frames during fan, panel, list entry. Report honestly if you could not run on a device.
