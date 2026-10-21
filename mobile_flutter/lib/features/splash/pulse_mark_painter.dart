import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Color _a(Color c, double opacity) =>
    c.withValues(alpha: (opacity.clamp(0.0, 1.0) * 255).round().toDouble());

/// Paints the Pulse heartbeat mark for the splash.
///
/// The four inputs are the four windows of the splash timeline: the trace
/// that draws the mark in from both ends, the streak that runs along the
/// baseline, the impact that fires the glitch, ring and sparks, and the
/// resolve that thickens the stroke into a white core.
class PulseMarkPainter extends CustomPainter {
  PulseMarkPainter({
    required this.trace,
    required this.streak,
    required this.impact,
    required this.solid,
  });

  final double trace;
  final double streak;
  final double impact;
  final double solid;

  static const Color violet = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF22D3EE);
  static const Size markBox = Size(120, 80);

  /// The path of the heartbeat mark.
  static Path markPath() => Path()
    ..moveTo(0, 40)
    ..lineTo(30, 40)
    ..lineTo(40, 26)
    ..lineTo(50, 54)
    ..lineTo(64, 4)
    ..lineTo(78, 72)
    ..lineTo(88, 40)
    ..lineTo(120, 40);

  Paint _stroke(Color color, double width, {double blur = 0}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }
    return paint;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / markBox.width;
    canvas.save();
    canvas.translate(0, (size.height - markBox.height * scale) / 2);
    canvas.scale(scale);

    final full = markPath();
    final metric = full.computeMetrics().first;
    final length = metric.length;

    Path visible() {
      if (trace >= 1) return full;
      final half = length * 0.5 * trace;
      return metric.extractPath(0, half)
        ..addPath(metric.extractPath(length - half, length), Offset.zero);
    }

    // The RGB split is strongest at the start of the impact window.
    final glitch = (impact > 0 && impact < 0.25) ? 4.0 * (1 - impact / 0.25) : 0.0;
    final split = ui.lerpDouble(2.5, 1.2, solid)! + glitch;
    final width = ui.lerpDouble(1.6, 5.0, solid)!;
    final path = visible();

    canvas.drawPath(path, _stroke(_a(violet, 0.55), width + 4, blur: 6));
    canvas.drawPath(path.shift(Offset(-split, 0)), _stroke(cyan, width));
    canvas.drawPath(path.shift(Offset(split, 0)), _stroke(violet, width));
    canvas.drawPath(
      path,
      _stroke(
        Color.lerp(const Color(0xFFD9DFFF), Colors.white, solid)!,
        width * 0.7,
      ),
    );

    // The two glowing heads that trace the path from both ends.
    if (trace < 1) {
      for (final offset in <double>[
        length * 0.5 * trace,
        length - length * 0.5 * trace,
      ]) {
        final tangent = metric.getTangentForOffset(offset);
        if (tangent == null) continue;
        canvas.drawCircle(
          tangent.position,
          5,
          Paint()
            ..color = _a(cyan, 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(tangent.position, 2.2, Paint()..color = Colors.white);
      }
    }

    // The streak that runs into the spike.
    if (streak > 0 && streak < 1) {
      final head = ui.lerpDouble(-40, 56, streak)!;
      final glow = _stroke(_a(Colors.white, 0.9), 3, blur: 4);
      canvas.drawLine(Offset(head - 24, 40), Offset(head, 40), glow);
      canvas.drawLine(
        Offset(head - 24, 40),
        Offset(head, 40),
        _stroke(Colors.white, 1.4),
      );
    }

    // The impact: an expanding ring and fourteen radial sparks.
    if (impact > 0 && impact < 1) {
      const center = Offset(60, 40);
      final ring = 90 * Curves.easeOut.transform(impact);
      canvas.drawCircle(center, ring, _stroke(_a(cyan, 1 - impact), 1.2));
      final spark = _stroke(_a(Colors.white, 1 - impact), 1.4);
      for (var i = 0; i < 14; i++) {
        final angle = i * math.pi * 2 / 14;
        final direction = Offset(math.cos(angle), math.sin(angle));
        final inner = 34 + 56 * impact;
        final outer = inner + 12 * (1 - impact);
        canvas.drawLine(
          center + direction * inner,
          center + direction * outer,
          spark,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(PulseMarkPainter old) =>
      old.trace != trace ||
      old.streak != streak ||
      old.impact != impact ||
      old.solid != solid;
}
