import 'package:flutter/material.dart';

import '../../core/motion/pressable_scale.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A section title with an optional "View all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: PulseType.heading.copyWith(color: t.textPrimary),
          ),
        ),
        if (actionLabel != null && onAction != null)
          PressableScale(
            onPressed: onAction,
            semanticLabel: actionLabel,
            excludeSemantics: true,
            pressedScale: 0.94,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PulseSpacing.sm,
                vertical: PulseSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: PulseType.label.copyWith(color: t.accentCyan),
                  ),
                  const SizedBox(width: PulseSpacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: t.accentCyan,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
