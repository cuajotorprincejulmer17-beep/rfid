import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A surface card.
///
/// The fill is `surface` at 92% alpha, the border is 1 dp, and the radius is
/// 16 dp. A card carries a glow only when it is the single featured element
/// of its region.
class PulseCard extends StatelessWidget {
  const PulseCard({
    super.key,
    required this.child,
    this.onTap,
    this.featured = false,
    this.elevated = false,
    this.padding = const EdgeInsets.all(PulseSpacing.lg),
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Whether this card is the one glowing element of its region.
  final bool featured;

  /// Whether to use `surfaceElevated` instead of `surface`.
  final bool elevated;

  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final fill = featured
        ? t.featuredFill
        : t.surface.withValues(alpha: 0.92);
    final border = featured
        ? t.primary.withValues(alpha: 0.55)
        : t.border;

    final shadow = featured
        ? [
            BoxShadow(
              color: t.isLight
                  ? t.glow.withValues(alpha: 0.18)
                  : t.glow.withValues(alpha: 0.24),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(PulseRadius.card),
        border: Border.all(color: border, width: 1),
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        container: semanticLabel != null,
        child: content,
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      container: semanticLabel != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PulseRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
