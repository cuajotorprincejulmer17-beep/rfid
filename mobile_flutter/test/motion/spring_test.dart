import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/motion/pulse_motion.dart';

/// Simulates the Motion Law spring and samples its response.
///
/// The test re-simulates the spring rather than trusting a number, so it
/// fails if the spring ever drifts away from the specification.
double _responseAt(Duration elapsed) {
  final simulation = SpringSimulation(
    PulseMotion.spring,
    0,
    1,
    0,
  );
  return simulation.x(elapsed.inMilliseconds / 1000);
}

/// The error of the response at [elapsed], relative to the target of 1.
double _errorAt(Duration elapsed) => (1 - _responseAt(elapsed)).abs();

void main() {
  group('The Motion Law spring', () {
    test('is mass 1, stiffness 1450, damping 61', () {
      expect(PulseMotion.spring.mass, 1);
      expect(PulseMotion.spring.stiffness, 1450);
      expect(PulseMotion.spring.damping, 61);
    });

    test('reaches 90% of the target by 80 ms', () {
      expect(_responseAt(const Duration(milliseconds: 80)), greaterThanOrEqualTo(0.90));
    });

    test('is within 3% of the target by 110 ms', () {
      expect(_errorAt(const Duration(milliseconds: 110)), lessThanOrEqualTo(0.03));
    });

    test('is within 1.2% of the target by 170 ms', () {
      expect(_errorAt(const Duration(milliseconds: 170)), lessThanOrEqualTo(0.012));
    });

    test('is settled by 400 ms', () {
      expect(_errorAt(const Duration(milliseconds: 400)), lessThanOrEqualTo(0.002));
    });

    test('overshoots by less than 2%', () {
      var peak = 0.0;
      for (var ms = 0; ms <= 400; ms += 1) {
        final value = _responseAt(Duration(milliseconds: ms));
        if (value > peak) peak = value;
      }
      expect(peak - 1, lessThan(0.02));
    });

    test('never falls back below its starting point', () {
      for (var ms = 20; ms <= 400; ms += 5) {
        expect(
          _responseAt(Duration(milliseconds: ms)),
          greaterThan(0),
          reason: 'The spring fell below its starting point at ${ms}ms',
        );
      }
    });
  });

  group('The Motion Law constants', () {
    test('the single-flight lock is 150 ms', () {
      expect(PulseMotion.lockMs, 150);
    });

    test('route transitions run for 170 ms', () {
      expect(PulseMotion.routeDuration, const Duration(milliseconds: 170));
    });

    test('the press scale is 0.96 and the launcher scale is 0.94', () {
      expect(PulseMotion.pressedScale, 0.96);
      expect(PulseMotion.launcherPressedScale, 0.94);
    });
  });
}
