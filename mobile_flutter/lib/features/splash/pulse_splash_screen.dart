import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/motion/pulse_motion.dart';
import 'pulse_mark_painter.dart';

/// The cold-start splash.
///
/// It always renders in the Pulse Purple Dark look, whatever theme the
/// student chose, because the brand moment has to be the same every time.
/// It runs for at most 3350 ms and can be skipped with a tap.
class PulseSplashScreen extends StatefulWidget {
  const PulseSplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<PulseSplashScreen> createState() => _PulseSplashScreenState();
}

class _PulseSplashScreenState extends State<PulseSplashScreen>
    with SingleTickerProviderStateMixin {
  static const int totalMs = 3350;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: totalMs),
  );
  bool _started = false;
  bool _finished = false;

  /// The progress of one window of the timeline.
  double _segment(int from, int to, [Curve curve = Curves.easeInOut]) =>
      Interval(
        from / totalMs,
        to / totalMs,
        curve: curve,
      ).transform(_controller.value);

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (PulseMotion.reduced(context)) {
      // Reduced motion draws the final frame and holds it briefly.
      _controller.value = 1;
      Future<void>.delayed(const Duration(milliseconds: 600), _finish);
    } else {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pulse',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_controller.value < 1 && !PulseMotion.reduced(context)) {
            _controller.value = 1;
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF05060F),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.1,
                colors: <Color>[Color(0x598B5CF6), Color(0x00000000)],
              ),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final lift = _segment(2500, 3100, Curves.easeOutCubic);
                  final word = _segment(2500, 3100, Curves.easeOut);
                  final underline = _segment(3100, 3350, Curves.easeOut);
                  final blur = 8 * (1 - word);

                  Widget wordmark = const Text(
                    'PULSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      fontFamily: 'Inter',
                    ),
                  );
                  if (blur > 0.1) {
                    wordmark = ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: wordmark,
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Transform.translate(
                        offset: Offset(0, -24 * lift),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: const Size(220, 147),
                            painter: PulseMarkPainter(
                              trace: _segment(300, 1500, Curves.easeInOutCubic),
                              streak: _segment(1350, 1650, Curves.easeIn),
                              impact: _segment(1650, 2250, Curves.linear),
                              solid: _segment(1800, 2500, Curves.easeOut),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(opacity: word, child: wordmark),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: word,
                        child: const Text(
                          'Your campus. In sync.',
                          style: TextStyle(
                            color: Color(0xFFA9B2DB),
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 56 * underline,
                        height: 2,
                        color: PulseMarkPainter.cyan,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
