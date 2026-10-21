import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// The tone a status is drawn with.
enum StatusTone { neutral, success, warning, danger, info }

/// A status shown as an icon plus a word.
///
/// Status is never conveyed by colour alone, so every pill carries an icon
/// and a text label in every theme.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final StatusTone tone;

  /// Overrides the default icon for the tone.
  final IconData? icon;

  IconData get _icon => icon ?? switch (tone) {
        StatusTone.success => Icons.check_circle_outline,
        StatusTone.warning => Icons.error_outline,
        StatusTone.danger => Icons.cancel_outlined,
        StatusTone.info => Icons.info_outline,
        StatusTone.neutral => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final color = switch (tone) {
      StatusTone.success => t.success,
      StatusTone.warning => t.warning,
      StatusTone.danger => t.error,
      StatusTone.info => t.accentCyan,
      StatusTone.neutral => t.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpacing.sm,
        vertical: PulseSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PulseRadius.input),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: color),
          const SizedBox(width: PulseSpacing.xs),
          Text(
            label,
            style: PulseType.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
