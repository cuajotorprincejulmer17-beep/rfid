import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/navigation/pulse_fan_layout.dart';

void main() {
  group('Choosing the fan mode', () {
    test('is a column above a text scale of 1.4', () {
      expect(
        chooseFanMode(availableAbove: 600, textScale: 1.5),
        FanMode.column,
      );
      expect(
        chooseFanMode(availableAbove: 600, textScale: 1.41),
        FanMode.column,
      );
    });

    test('is a row below 190 dp of headroom', () {
      expect(
        chooseFanMode(availableAbove: 189, textScale: 1.0),
        FanMode.row,
      );
      expect(
        chooseFanMode(availableAbove: 100, textScale: 1.0),
        FanMode.row,
      );
    });

    test('is an arc otherwise', () {
      expect(
        chooseFanMode(availableAbove: 190, textScale: 1.0),
        FanMode.arc,
      );
      expect(
        chooseFanMode(availableAbove: 600, textScale: 1.4),
        FanMode.arc,
      );
    });

    test('the text scale wins over the available space', () {
      expect(
        chooseFanMode(availableAbove: 100, textScale: 2.0),
        FanMode.column,
      );
    });
  });

  group('The arc offsets', () {
    final offsets = fanOffsets(FanMode.arc, 4);

    test('all four items move upward', () {
      for (final offset in offsets) {
        expect(offset.dy, lessThan(0), reason: 'The fan must open upward only');
      }
    });

    test('the four items fit inside 320 dp of width', () {
      final leftmost = offsets.map((o) => o.dx).reduce(math.min);
      final rightmost = offsets.map((o) => o.dx).reduce(math.max);
      final extent = rightmost - leftmost;

      // Each item is 72 dp wide, so half of it sits past the offset.
      final total = extent + 72;
      expect(total, lessThanOrEqualTo(320));
    });

    test('neighbouring items are at least 72 dp apart', () {
      for (var i = 0; i < offsets.length - 1; i++) {
        final distance = (offsets[i] - offsets[i + 1]).distance;
        expect(
          distance,
          greaterThanOrEqualTo(72),
          reason: 'Items $i and ${i + 1} overlap',
        );
      }
    });

    test('the first item is to the left and the last to the right', () {
      expect(offsets.first.dx, lessThan(0));
      expect(offsets.last.dx, greaterThan(0));
    });

    test('the arc is symmetric about the centre', () {
      expect(offsets.first.dx, closeTo(-offsets.last.dx, 0.001));
      expect(offsets.first.dy, closeTo(offsets.last.dy, 0.001));
    });
  });

  group('The row offsets', () {
    final offsets = fanOffsets(FanMode.row, 4);

    test('all items move upward', () {
      for (final offset in offsets) {
        expect(offset.dy, lessThan(0));
      }
    });

    test('the items are spread horizontally', () {
      expect(offsets.first.dx, lessThan(0));
      expect(offsets.last.dx, greaterThan(0));
    });
  });

  group('The column offsets', () {
    final offsets = fanOffsets(FanMode.column, 4);

    test('all items move upward', () {
      for (final offset in offsets) {
        expect(offset.dy, lessThan(0));
      }
    });

    test('the items are stacked without overlapping', () {
      for (var i = 0; i < offsets.length - 1; i++) {
        final gap = (offsets[i].dy - offsets[i + 1].dy).abs();
        expect(gap, greaterThanOrEqualTo(64));
      }
    });

    test('the items are centred', () {
      for (final offset in offsets) {
        expect(offset.dx, closeTo(0, 0.001));
      }
    });
  });
}
