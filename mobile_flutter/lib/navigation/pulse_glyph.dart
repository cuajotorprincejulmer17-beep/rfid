import 'package:flutter/material.dart';

import '../core/theme/pulse_tokens.dart';

/// The Pulse heartbeat mark.
///
/// The mark is a single polyline: a flat baseline, a small dip, a tall
/// spike, a deep valley and a second tall spike, returning to the baseline.
/// It is painted, never an icon font, so it scales cleanly and can glow.
class PulseGlyph extends StatelessWidget {
  const PulseGlyph({
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  /// The path of the mark in a 120 x 80 box.
  static const List<Offset> _points = <Offset>[
    Offset(0, 40),
    Offset(30, 40),
    Offset(40, 26),
    Offset(50, 54),
    Offset(64, 4),
    Offset(78, 72),
    Offset(88, 40),
    Offset(120, 40),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return SizedBox(
      width: size,
      height: size * (80 / 120),
      child: CustomPaint(
        painter: _PulseGlyphPainter(
          color: color ?? t.accentCyan,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _PulseGlyphPainter extends CustomPainter {
  const _PulseGlyphPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 120;
    final scaleY = size.height / 80;

    final path = Path();
    for (var i = 0; i < PulseGlyph._points.length; i++) {
      final p = PulseGlyph._points[i];
      final offset = Offset(p.dx * scaleX, p.dy * scaleY);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PulseGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
