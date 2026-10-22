import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/accessibility/motion_preferences.dart';
import '../core/motion/pulse_motion.dart';
import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
import 'app_destination.dart';
import 'destination_registry.dart';
import 'pulse_fan_controller.dart';
import 'pulse_fan_layout.dart';

/// The fan overlay.
///
/// Exactly one instance of this widget exists, mounted in the shell. It
/// owns a single unbounded controller whose value drives the position, the
/// scale, the opacity of the four items and the opacity of the scrim, all
/// from the same spring value, so there is never a stagger.
class PulseFanOverlay extends ConsumerStatefulWidget {
  const PulseFanOverlay({
    super.key,
    required this.launcherCenter,
    required this.availableAbove,
  });

  /// The centre of the launcher in global coordinates.
  final Offset launcherCenter;

  /// The vertical space above the launcher, in logical pixels.
  final double availableAbove;

  @override
  ConsumerState<PulseFanOverlay> createState() => _PulseFanOverlayState();
}

class _PulseFanOverlayState extends ConsumerState<PulseFanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    // `listenManual` is the only subscription that may be created outside
    // `build`. It is closed automatically when this element unmounts.
    ref.listenManual<PulseFanState>(pulseFanProvider, _onFanChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(pulseFanProvider);
      if (current.phase == FanPhase.opening) {
        _onFanChanged(const PulseFanState(), current);
      } else if (current.phase == FanPhase.open) {
        _controller.value = 1;
      }
    });
  }

  void _onFanChanged(PulseFanState? previous, PulseFanState next) {
    if (previous?.phase == next.phase) return;

    final reduced = _reducedMotion();

    switch (next.phase) {
      case FanPhase.opening:
        PulseMotion.animateTo(_controller, 1, reduced: reduced)
            .whenComplete(() {
          if (mounted) ref.read(pulseFanProvider.notifier).onOpened();
        });
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Pulse menu, ${fanCategories.length} options',
          Directionality.of(context),
        );
      case FanPhase.closing:
        PulseMotion.animateTo(_controller, 0, reduced: reduced)
            .whenComplete(() {
          if (!mounted) return;
          final route = ref.read(pulseFanProvider.notifier).onClosed();
          if (route != null) {
            context.push(route);
          }
        });
      case FanPhase.closed:
      case FanPhase.open:
        break;
    }
  }

  bool _reducedMotion() {
    final setting = ref.read(reduceMotionControllerProvider);
    final system = MediaQuery.disableAnimationsOf(context);
    return switch (setting) {
      ReduceMotionSetting.system => system,
      ReduceMotionSetting.on => true,
      ReduceMotionSetting.off => system,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(pulseFanProvider).phase;
    if (phase == FanPhase.closed) {
      return const SizedBox.shrink();
    }

    final t = context.pulse;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final mode = chooseFanMode(
      availableAbove: widget.availableAbove,
      textScale: textScale,
    );
    final offsets = fanOffsets(mode, fanCategories.length);
    final reduced = _reducedMotion();

    return Stack(
      children: [
        // The scrim blocks every interaction below it from the first frame.
        Positioned.fill(
          child: BlockSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(pulseFanProvider.notifier).close(),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => ColoredBox(
                  color: t.scrim.withValues(
                    alpha: t.scrim.a * _controller.value.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
        ),

        // The four category items.
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value.clamp(0.0, 1.0);
                return Stack(
                  children: [
                    for (var i = 0; i < fanCategories.length; i++)
                      _buildItem(
                        context,
                        fanCategories[i],
                        offsets[i],
                        progress,
                        mode,
                        reduced,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    AppDestination destination,
    Offset offset,
    double progress,
    FanMode mode,
    bool reduced,
  ) {
    final t = context.pulse;
    final haptics = ref.read(hapticsControllerProvider);

    final position = Offset.lerp(Offset.zero, offset, progress)!;
    final scale = reduced ? 1.0 : 0.6 + 0.4 * progress;
    final opacity = reduced ? (progress > 0 ? 1.0 : 0.0) : progress;

    final label = Text(
      destination.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: PulseType.caption.copyWith(color: t.textPrimary),
    );

    final circle = Container(
      width: kFanItemCircle,
      height: kFanItemCircle,
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: t.primary, width: 1.5),
      ),
      child: Icon(destination.icon, size: 24, color: t.navSelected),
    );

    final Widget content;
    if (mode == FanMode.column) {
      content = Container(
        width: kFanColumnWidth,
        constraints: const BoxConstraints(minHeight: kFanItemHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: PulseSpacing.lg,
          vertical: PulseSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: t.surfaceElevated,
          borderRadius: BorderRadius.circular(PulseRadius.pill),
          border: Border.all(color: t.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: 20, color: t.navSelected),
            const SizedBox(width: PulseSpacing.md),
            Flexible(
              child: Text(
                destination.title,
                style: PulseType.label.copyWith(color: t.textPrimary),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: PulseSpacing.xs),
          // Labels are clamped in arc and row modes so they stay readable.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child: label,
          ),
        ],
      );
    }

    final itemWidth =
        mode == FanMode.column ? kFanColumnWidth : kFanItemWidth;
    return Positioned(
      left: widget.launcherCenter.dx + position.dx - itemWidth / 2,
      top: widget.launcherCenter.dy + position.dy - kFanItemHeight / 2,
      width: itemWidth,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (haptics) HapticFeedback.lightImpact();
              ref.read(pulseFanProvider.notifier).select(destination.route);
            },
            child: Semantics(
              button: true,
              label: destination.semanticLabel,
              child: SizedBox(
                width: kFanItemWidth,
                height: kFanItemHeight,
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
