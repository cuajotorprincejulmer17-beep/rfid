import 'dart:math' as math;
import 'dart:ui';

/// How the fan lays its four items out.
enum FanMode {
  /// An upward arc. The default.
  arc,

  /// A single row. Used in short landscape windows.
  row,

  /// A column of full-width pill buttons. Used at large text scales.
  column,
}

/// Chooses the fan layout for the space and text scale available.
///
/// The text scale wins over the space: an arc cannot hold a large label, so
/// above 1.4 the fan becomes a column of pill buttons.
FanMode chooseFanMode({required double availableAbove, required double textScale}) {
  if (textScale > 1.4) {
    return FanMode.column;
  }
  if (availableAbove < 190) {
    return FanMode.row;
  }
  return FanMode.arc;
}

/// The offsets from the launcher centre to each fan item.
///
/// `dy` is always negative: the fan opens upward only, never downward.
List<Offset> fanOffsets(FanMode mode, int count) {
  switch (mode) {
    case FanMode.arc:
      const radius = 116.0;
      const startDeg = 150.0;
      const endDeg = 30.0;
      return List<Offset>.generate(count, (i) {
        final deg = count == 1
            ? 90.0
            : startDeg - i * (startDeg - endDeg) / (count - 1);
        final rad = deg * math.pi / 180;
        return Offset(radius * math.cos(rad), -radius * math.sin(rad));
      });
    case FanMode.row:
      return List<Offset>.generate(
        count,
        (i) => Offset((i - (count - 1) / 2) * 84, -92),
      );
    case FanMode.column:
      return List<Offset>.generate(count, (i) => Offset(0, -(84 + i * 64.0)));
  }
}

/// The size of a fan item's hit area.
const double kFanItemWidth = 72;

/// The minimum height of a fan item's hit area.
const double kFanItemHeight = 48;

/// The diameter of the visible fan item circle.
const double kFanItemCircle = 56;

/// The width of the fan item's pill button in column mode.
const double kFanColumnWidth = 220;
