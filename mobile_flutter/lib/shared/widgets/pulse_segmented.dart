import 'package:flutter/material.dart';

import '../../core/motion/pulse_motion.dart';
import '../../core/motion/pressable_scale.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// One option of a [PulseSegmented].
class PulseSegment<T> {
  const PulseSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A segmented control.
///
/// The selected segment is a filled pill inside a bordered track. Changing
/// the selection swaps state, so it uses the Motion Law spring.
class PulseSegmented<T> extends StatefulWidget {
  const PulseSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<PulseSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<PulseSegmented<T>> createState() => _PulseSegmentedState<T>();
}

class _PulseSegmentedState<T> extends State<PulseSegmented<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(PulseSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      PulseMotion.animateTo(_t, 0, reduced: PulseMotion.reduced(context));
      PulseMotion.animateTo(_t, 1, reduced: PulseMotion.reduced(context));
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
    return Container(
      padding: const EdgeInsets.all(PulseSpacing.xs),
      decoration: BoxDecoration(
        color: t.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(PulseRadius.input),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          for (final segment in widget.segments)
            Expanded(
              child: PressableScale(
                onPressed: () => widget.onChanged(segment.value),
                semanticLabel: segment.label,
                excludeSemantics: true,
                pressedScale: 0.97,
                child: AnimatedBuilder(
                  animation: _t,
                  builder: (context, _) {
                    final selected = segment.value == widget.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: PulseSpacing.sm,
                        horizontal: PulseSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? t.selectedPillFill : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(PulseRadius.input - 2),
                        border: Border.all(
                          color: selected
                              ? t.selectedPillBorder
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (segment.icon != null) ...[
                            Icon(
                              segment.icon,
                              size: 16,
                              color: selected ? t.navSelected : t.textSecondary,
                            ),
                            const SizedBox(width: PulseSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              segment.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PulseType.label.copyWith(
                                color:
                                    selected ? t.navSelected : t.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
