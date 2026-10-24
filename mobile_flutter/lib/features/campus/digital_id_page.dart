import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';

/// The Digital ID page.
///
/// The card is a demo. The QR-style pattern is generated from the id
/// string, and it is labelled as a demo code, never as an official
/// credential.
class DigitalIdPage extends StatefulWidget {
  const DigitalIdPage({
    super.key,
    required this.name,
    required this.studentNumber,
    this.program = 'Sample programme',
    this.section = 'Sample section',
    this.subtitle = 'Demo card',
    this.programLabel = 'Programme',
    this.sectionLabel = 'Section',
    this.permissionDenied = false,
    this.onPermissionRetry,
  });

  final String name;
  final String studentNumber;
  final String program;
  final String section;

  /// Where the card's details come from.
  final String subtitle;
  final String programLabel;
  final String sectionLabel;

  /// Whether the feature is unavailable because a permission is missing.
  final bool permissionDenied;

  final VoidCallback? onPermissionRetry;

  @override
  State<DigitalIdPage> createState() => _DigitalIdPageState();
}

class _DigitalIdPageState extends State<DigitalIdPage> {
  int _seed = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    if (widget.permissionDenied) {
      return PulsePage(
        title: 'Digital ID',
        child: PulseCard(
          child: Column(
            children: [
              Icon(Icons.lock_outline, size: 30, color: t.warning),
              const SizedBox(height: PulseSpacing.md),
              Text(
                'Permission needed',
                style: PulseType.label.copyWith(color: t.textPrimary),
              ),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                'The digital ID needs a permission that has not been '
                'granted. The app cannot show the card without it.',
                textAlign: TextAlign.center,
                style: PulseType.caption.copyWith(color: t.textSecondary),
              ),
              if (widget.onPermissionRetry != null) ...[
                const SizedBox(height: PulseSpacing.lg),
                PulseButton(
                  label: 'Try again',
                  onPressed: widget.onPermissionRetry,
                  variant: PulseButtonVariant.secondary,
                  expanded: false,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return PulsePage(
      title: 'Digital ID',
      subtitle: widget.subtitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh code',
          onPressed: () => setState(() => _seed++),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseCard(
            featured: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: t.softFill,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: t.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 24,
                        color: t.navSelected,
                      ),
                    ),
                    const SizedBox(width: PulseSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.name,
                            style: PulseType.heading
                                .copyWith(color: t.textPrimary),
                          ),
                          Text(
                            widget.studentNumber,
                            style: PulseType.caption
                                .copyWith(color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PulseSpacing.lg),
                _DetailRow(label: widget.programLabel, value: widget.program),
                _DetailRow(label: widget.sectionLabel, value: widget.section),
                const SizedBox(height: PulseSpacing.lg),
                Center(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: _DemoCodePainter(
                        seed: '${widget.studentNumber}-$_seed',
                        foreground: t.textPrimary,
                        background: t.background,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  'Demo code, not an official credential',
                  textAlign: TextAlign.center,
                  style: PulseType.caption.copyWith(color: t.warning),
                ),
              ],
            ),
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseButton(
            label: 'Share a plain-text summary',
            icon: Icons.ios_share_rounded,
            variant: PulseButtonVariant.secondary,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: '${widget.name} (${widget.studentNumber})\n'
                      '${widget.programLabel}: ${widget.program}\n'
                      '${widget.sectionLabel}: ${widget.section}\n'
                      'Demo code, not an official credential.',
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Summary copied to the clipboard.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One label and value row on the card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Padding(
      padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PulseType.body.copyWith(color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a deterministic QR-style pattern.
///
/// The pattern is generated from a seed string, so the same id always draws
/// the same code, and refreshing the code changes the seed.
class _DemoCodePainter extends CustomPainter {
  const _DemoCodePainter({
    required this.seed,
    required this.foreground,
    required this.background,
  });

  final String seed;
  final Color foreground;
  final Color background;

  static const int _modules = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _modules;
    final random = math.Random(seed.hashCode);

    final paint = Paint()..color = foreground;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = background,
    );

    for (var y = 0; y < _modules; y++) {
      for (var x = 0; x < _modules; x++) {
        // The three finder patterns stay solid so the code looks like a code.
        if (_isFinder(x, y)) continue;
        if (random.nextDouble() > 0.52) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell, cell),
            paint,
          );
        }
      }
    }

    _drawFinder(canvas, paint, cell, 0, 0);
    _drawFinder(canvas, paint, cell, _modules - 7, 0);
    _drawFinder(canvas, paint, cell, 0, _modules - 7);
  }

  bool _isFinder(int x, int y) {
    bool inBox(int ox, int oy) =>
        x >= ox && x < ox + 7 && y >= oy && y < oy + 7;
    return inBox(0, 0) ||
        inBox(_modules - 7, 0) ||
        inBox(0, _modules - 7);
  }

  void _drawFinder(
    Canvas canvas,
    Paint paint,
    double cell,
    int ox,
    int oy,
  ) {
    final outer = Rect.fromLTWH(ox * cell, oy * cell, cell * 7, cell * 7);
    canvas.drawRect(outer, paint..style = PaintingStyle.stroke..strokeWidth = cell);
    final inner = Rect.fromLTWH(
      (ox + 2) * cell,
      (oy + 2) * cell,
      cell * 3,
      cell * 3,
    );
    canvas.drawRect(inner, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_DemoCodePainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.foreground != foreground ||
      oldDelegate.background != background;
}
