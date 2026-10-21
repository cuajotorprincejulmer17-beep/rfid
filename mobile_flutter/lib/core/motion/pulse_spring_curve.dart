import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'pulse_motion.dart';

/// Maps a time-based 0..1 route or sheet animation onto the Motion Law
/// spring.
///
/// Use it with [PulseMotion.routeDuration] (170 ms), the time in which the
/// spring is within 1% of its target.
class PulseSpringCurve extends Curve {
  const PulseSpringCurve();

  static final SpringSimulation _simulation =
      SpringSimulation(PulseMotion.spring, 0, 1, 0);

  @override
  double transformInternal(double t) =>
      _simulation.x(t * PulseMotion.routeDuration.inMilliseconds / 1000);
}
