import 'package:flutter/material.dart';

import '../../core/motion/pressable_scale.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// The weight of a [PulseButton].
enum PulseButtonVariant { primary, secondary }

/// A button with a clear pressed state.
class PulseButton extends StatelessWidget {
  const PulseButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PulseButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PulseButtonVariant variant;
  final IconData? icon;

  /// Shows an inline busy state and blocks the action.
  final bool busy;

  /// Whether the button fills the available width.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final enabled = onPressed != null && !busy;

    final background = switch (variant) {
      PulseButtonVariant.primary => t.primary,
      PulseButtonVariant.secondary => Colors.transparent,
    };
    final foreground = switch (variant) {
      PulseButtonVariant.primary => t.onPrimary,
      PulseButtonVariant.secondary => t.textPrimary,
    };

    final child = Container(
      constraints: const BoxConstraints(minHeight: kMinTouch),
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpacing.lg,
        vertical: PulseSpacing.md,
      ),
      decoration: BoxDecoration(
        color: enabled ? background : background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(PulseRadius.input),
        border: variant == PulseButtonVariant.secondary
            ? Border.all(color: t.borderStrong)
            : null,
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(foreground),
              ),
            ),
            const SizedBox(width: PulseSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: PulseSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PulseType.label.copyWith(
                color: enabled ? foreground : foreground.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );

    return PressableScale(
      onPressed: enabled ? onPressed : null,
      semanticLabel: label,
      excludeSemantics: true,
      pressedScale: 0.96,
      child: expanded ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}
