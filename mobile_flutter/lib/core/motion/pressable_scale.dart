import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/pulse_theme.dart';
import 'pulse_motion.dart';

/// A target that gives physical feedback.
///
/// The scale drops on pointer **down**, not on tap-up, and springs back on
/// release. The action fires on tap-up while the pointer is still inside the
/// target, and dragging out of the target cancels the activation.
///
/// A 150 ms single-flight lock makes a double tap fire exactly once, so a
/// ghost tap cannot duplicate an action.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
    this.pressedScale = PulseMotion.pressedScale,
    this.minSize = kMinTouch,
    this.haptic = true,
    this.excludeSemantics = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double pressedScale;
  final double minSize;
  final bool haptic;

  /// When true the child's own semantics are replaced by [semanticLabel].
  final bool excludeSemantics;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press =
      AnimationController.unbounded(vsync: this, value: 0);

  /// When the target last fired, used for the single-flight lock.
  DateTime? _lastFire;

  bool get _enabled => widget.onPressed != null;

  void _down(PointerDownEvent event) {
    if (!_enabled) return;
    if (widget.haptic) {
      HapticFeedback.selectionClick();
    }
    PulseMotion.animateTo(_press, 1, reduced: PulseMotion.reduced(context));
  }

  void _release() {
    PulseMotion.animateTo(_press, 0, reduced: PulseMotion.reduced(context));
  }

  void _activate() {
    if (!_enabled) return;

    // The lock is measured against the app clock, so it behaves the same in
    // a test as it does on a device.
    final now = clock.now();
    final last = _lastFire;
    if (last != null &&
        now.difference(last).inMilliseconds < PulseMotion.lockMs) {
      return;
    }
    _lastFire = now;
    widget.onPressed!();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeSemantics && widget.semanticLabel != null,
      onTap: _enabled ? _activate : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minSize,
              minHeight: widget.minSize,
            ),
            child: AnimatedBuilder(
              animation: _press,
              child: widget.child,
              builder: (context, child) {
                final s = 1 - (1 - widget.pressedScale) * _press.value;
                return Transform.scale(
                  scale: s,
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
