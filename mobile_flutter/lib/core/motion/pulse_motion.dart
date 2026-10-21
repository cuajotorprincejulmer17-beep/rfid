import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// The Motion Law.
///
/// Every micro-interaction in the app uses one spring. It is tuned to feel
/// like a 150 ms response: it reaches 90% at about 78 ms, is within 2% at
/// about 99 ms, is within 1% at about 166 ms, and overshoots by about 1.5%.
class PulseMotion {
  PulseMotion._();

  /// The one spring. Mass 1, stiffness 1450, damping 61.
  static const SpringDescription spring =
      SpringDescription(mass: 1, stiffness: 1450, damping: 61);

  /// How long a target stays locked after it fires, so a double tap cannot
  /// trigger the action twice.
  static const int lockMs = 150;

  /// Route and sheet transitions run over this long.
  static const Duration routeDuration = Duration(milliseconds: 170);

  /// The scale a target shrinks to while it is held down.
  static const double pressedScale = 0.96;

  /// The launcher shrinks a little further than everything else.
  static const double launcherPressedScale = 0.94;

  /// Whether the user asked for less motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Retargets [controller] to [target] with the spring, keeping the current
  /// velocity so an interrupted transition never restarts from zero.
  ///
  /// The controller must be created with `AnimationController.unbounded` so
  /// overshoot is allowed.
  static TickerFuture animateTo(
    AnimationController controller,
    double target, {
    required bool reduced,
  }) {
    if (reduced) {
      controller.value = target;
      return TickerFuture.complete();
    }
    final simulation = SpringSimulation(
      spring,
      controller.value,
      target,
      controller.velocity,
    );
    return controller.animateWith(simulation);
  }
}
