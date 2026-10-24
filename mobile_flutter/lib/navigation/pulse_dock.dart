import 'package:flutter/material.dart';

import '../core/motion/pulse_motion.dart';
import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
import 'app_destination.dart';
import 'destination_registry.dart';

/// The height of the dock.
const double kDockHeight = 64;

/// The gap in the middle of the dock, where the launcher sits.
const double kDockLauncherGap = 72;

/// The inset of the dock from the left and right edges.
const double kDockSideInset = 16;

/// The distance below the safe area the dock floats at.
const double kDockBottomInset = 12;

/// The extra bottom padding the body of a screen needs so its content is
/// never hidden behind the dock.
double dockBottomPadding(BuildContext context) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  return kDockHeight + kDockBottomInset + safeBottom + 24;
}

/// The floating pill dock.
///
/// It holds the four dock destinations and a gap for the launcher. The
/// selected destination expands into a filled pill that shows its label;
/// the others are icon only. The pill width is the one place the app
/// animates layout, because the width is the selection.
class PulseDock extends StatefulWidget {
  const PulseDock({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.unreadCount = 0,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;
  final int unreadCount;

  @override
  State<PulseDock> createState() => _PulseDockState();
}

class _PulseDockState extends State<PulseDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring =
      AnimationController.unbounded(vsync: this, value: 1);

  @override
  void didUpdateWidget(PulseDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId) {
      PulseMotion.animateTo(_spring, 0, reduced: PulseMotion.reduced(context));
      PulseMotion.animateTo(_spring, 1, reduced: PulseMotion.reduced(context));
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final items = dockDestinations;

    return Container(
      height: kDockHeight,
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(PulseRadius.pill),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isLight ? 0.10 : 0.36),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Five slots: Home, Schedule, the gap for the launcher, Tasks,
          // Updates. The gap sits between Schedule and Tasks, so the two
          // destinations on either side of it are symmetrical and the gap
          // lands exactly under the launcher that floats above it.
          for (final destination in items) ...[
            if (destination.id == 'tasks')
              const SizedBox(width: kDockLauncherGap),
            Expanded(
              child: _DockItem(
                destination: destination,
                selected: destination.id == widget.selectedId,
                spring: _spring,
                onTap: () => widget.onSelected(destination.id),
                badgeCount:
                    destination.id == 'updates' ? widget.unreadCount : 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One destination inside the dock.
class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.spring,
    required this.onTap,
    this.badgeCount = 0,
  });

  final AppDestination destination;
  final bool selected;
  final AnimationController spring;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(builder: (context, constraints) => AnimatedBuilder(
          animation: spring,
          builder: (context, child) {
            // The label needs room for the icon, the text and the pill
            // padding; on a narrow phone the pill stays icon-only rather
            // than overflowing. The semantics label still names the tab.
            final showLabel = selected &&
                textScale < 1.3 &&
                constraints.maxWidth >= _labelWidth(destination.title, textScale);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: showLabel ? PulseSpacing.md : PulseSpacing.sm,
                    vertical: PulseSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? t.selectedPillFill : Colors.transparent,
                    borderRadius: BorderRadius.circular(PulseRadius.pill),
                    border: Border.all(
                      color: selected ? t.selectedPillBorder : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            destination.icon,
                            size: 22,
                            color: selected ? t.navSelected : t.navUnselected,
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: t.error,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeCount > 9 ? '9+' : '$badgeCount',
                                  style: PulseType.caption.copyWith(
                                    color: t.background,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (showLabel) ...[
                        const SizedBox(width: PulseSpacing.xs),
                        Text(
                          destination.title,
                          style: PulseType.label.copyWith(
                            color: t.navSelected,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        )),
      ),
    );
  }

  /// The width a pill with an icon and [title] needs: icon, gap, text and
  /// horizontal padding, measured with the label style.
  static double _labelWidth(String title, double textScale) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: PulseType.label),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.linear(textScale),
      maxLines: 1,
    )..layout();
    final width = 22 + PulseSpacing.xs + painter.width + PulseSpacing.md * 2 + 2;
    painter.dispose();
    return width;
  }
}
