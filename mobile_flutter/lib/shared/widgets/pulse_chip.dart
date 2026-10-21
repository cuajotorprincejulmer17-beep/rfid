import 'package:flutter/material.dart';

import '../../core/motion/pulse_motion.dart';
import '../../core/motion/pressable_scale.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A compact selectable chip.
///
/// Selection is a state swap, so it uses the Motion Law spring rather than
/// a timed colour tween.
class PulseChip extends StatefulWidget {
  const PulseChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  State<PulseChip> createState() => _PulseChipState();
}

class _PulseChipState extends State<PulseChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController.unbounded(vsync: this, value: widget.selected ? 1 : 0);

  @override
  void didUpdateWidget(PulseChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      PulseMotion.animateTo(
        _t,
        widget.selected ? 1 : 0,
        reduced: PulseMotion.reduced(context),
      );
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = _t.value.clamp(0.0, 1.0);
        return PressableScale(
          onPressed: widget.onSelected,
          semanticLabel: widget.label,
          excludeSemantics: true,
          pressedScale: 0.96,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PulseSpacing.md,
              vertical: PulseSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Color.lerp(t.surfaceElevated, t.selectedPillFill, v),
              borderRadius: BorderRadius.circular(PulseRadius.input),
              border: Border.all(
                color: Color.lerp(t.border, t.selectedPillBorder, v)!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 16,
                    color: Color.lerp(t.textSecondary, t.navSelected, v),
                  ),
                  const SizedBox(width: PulseSpacing.xs),
                ],
                Text(
                  widget.label,
                  style: PulseType.label.copyWith(
                    color: Color.lerp(t.textSecondary, t.navSelected, v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
