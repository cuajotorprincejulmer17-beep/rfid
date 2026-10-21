import 'package:flutter/material.dart';

import '../../core/motion/pressable_scale.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A round icon tile with a label, used on the category hubs.
///
/// A feature tile is the only way a feature appears on a hub, so a feature
/// can never be listed twice.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? description;

  /// Whether the feature works yet.
  final bool enabled;

  /// Why the feature is unavailable. Shown to the user, never hidden.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final color = enabled ? t.navSelected : t.textSecondary;

    return PressableScale(
      onPressed: enabled ? onTap : null,
      semanticLabel: enabled
          ? label
          : '$label. Unavailable. ${disabledReason ?? 'Not available yet'}',
      excludeSemantics: true,
      pressedScale: 0.94,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: enabled ? t.softFill : t.surfaceElevated.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: enabled ? t.primary.withValues(alpha: 0.5) : t.border,
              ),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            label,
            style: PulseType.label.copyWith(
              color: enabled ? t.textPrimary : t.textSecondary,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: PulseSpacing.xs),
            Text(
              description!,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ] else if (!enabled && disabledReason != null) ...[
            const SizedBox(height: PulseSpacing.xs),
            Text(
              disabledReason!,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
