import 'package:flutter/material.dart';

import '../core/motion/pulse_motion.dart';
import '../core/motion/pressable_scale.dart';
import '../core/theme/pulse_tokens.dart';
import 'pulse_glyph.dart';

/// The diameter of the launcher circle.
const double kLauncherSize = 64;

/// How far the launcher is lifted above the dock.
const double kLauncherLift = 20;

/// The key that identifies the one launcher in the app.
const Key kPulseLauncherKey = Key('pulse-launcher');

/// The centre launcher.
///
/// It is a launcher and nothing else: it has no route, it is not a tab, and
/// it never opens a dock destination. It sits above the scrim so the user
/// can always close the fan with the same control that opened it.
class PulseLauncher extends StatelessWidget {
  const PulseLauncher({
    super.key,
    required this.onPressed,
    this.open = false,
    this.haptics = true,
  });

  final VoidCallback onPressed;

  /// Whether the fan is open, so the glyph can show a close icon.
  final bool open;

  /// Whether the haptics setting allows feedback.
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PressableScale(
      key: kPulseLauncherKey,
      onPressed: onPressed,
      semanticLabel: open ? 'Close Pulse menu' : 'Open Pulse menu',
      excludeSemantics: true,
      pressedScale: PulseMotion.launcherPressedScale,
      haptic: haptics,
      child: Semantics(
        button: true,
        expanded: open,
        child: Container(
          width: kLauncherSize,
          height: kLauncherSize,
          decoration: BoxDecoration(
            color: t.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: t.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: t.glow.withValues(alpha: t.isLight ? 0.18 : 0.35),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              ),
              child: open
                  ? Icon(
                      Icons.close_rounded,
                      key: const ValueKey('close'),
                      size: 26,
                      color: t.navSelected,
                    )
                  : Padding(
                      key: const ValueKey('pulse'),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: PulseGlyph(
                        size: 24,
                        color: t.accentCyan,
                        strokeWidth: 2.4,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
