import 'package:flutter/material.dart';

import '../../core/motion/pulse_spring_curve.dart';
import '../../core/motion/pulse_motion.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import 'pulse_button.dart';

/// A modal bottom sheet with the Pulse form pattern.
///
/// It carries a grabber, a title, an optional subtitle, the content, and a
/// primary action that stays disabled until the form is valid. The sheet
/// shows an in-sheet two-dot loading state while it saves.
class PulseSheet extends StatelessWidget {
  const PulseSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.primaryEnabled = true,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final bool busy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PulseRadius.sheet),
          ),
          border: Border.all(color: t.border),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              PulseSpacing.lg,
              PulseSpacing.sm,
              PulseSpacing.lg,
              PulseSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: PulseSpacing.lg),
                Text(
                  title,
                  style: PulseType.heading.copyWith(color: t.textPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: PulseSpacing.xs),
                  Text(
                    subtitle!,
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ],
                const SizedBox(height: PulseSpacing.lg),
                child,
                if (primaryLabel != null) ...[
                  const SizedBox(height: PulseSpacing.lg),
                  if (busy) const _SheetBusyLabel() else
                    PulseButton(
                      label: primaryLabel!,
                      onPressed: primaryEnabled ? onPrimary : null,
                    ),
                ],
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: PulseSpacing.sm),
                  PulseButton(
                    label: secondaryLabel!,
                    onPressed: onSecondary,
                    variant: PulseButtonVariant.secondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The in-sheet loading state: two dots and a word.
class _SheetBusyLabel extends StatelessWidget {
  const _SheetBusyLabel();

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PulseSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Dot(color: t.primary, delay: 0),
          const SizedBox(width: PulseSpacing.sm),
          _Dot(color: t.accentCyan, delay: 160),
          const SizedBox(width: PulseSpacing.md),
          Text(
            'Saving',
            style: PulseType.label.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.delay});

  final Color color;
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Opens a sheet with the Pulse spring curve.
///
/// The sheet slides from the bottom over [PulseMotion.routeDuration] using
/// the Motion Law spring, so it matches every other transition in the app.
Future<T?> showPulseSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.pulse.scrim,
    sheetAnimationStyle: const AnimationStyle(
      curve: PulseSpringCurve(),
      reverseCurve: Curves.easeInCubic,
      duration: PulseMotion.routeDuration,
      reverseDuration: PulseMotion.routeDuration,
    ),
    builder: builder,
  );
}

/// The duration a sheet transition runs for, matching the Motion Law.
const Duration kSheetTransitionDuration = PulseMotion.routeDuration;
