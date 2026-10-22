import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_text_field.dart';

/// The size of the painted map, in map units.
const Size kMapCanvasSize = Size(380, 220);

/// The campus map.
///
/// The map is painted, not a tile map, so it works with no network and no
/// API key. It pans and zooms, and a pin opens a sheet with the building.
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.places,
    this.query = '',
    this.onQueryChanged,
    this.onOpenPlace,
  });

  final List<MapPlace> places;
  final String query;
  final ValueChanged<String>? onQueryChanged;
  final void Function(MapPlace place)? onOpenPlace;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);
  final TransformationController _transform = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final highlight = widget.query.trim().toLowerCase();

    return PulsePage(
      title: 'Map',
      subtitle: 'Campus buildings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseTextField(
            controller: _controller,
            hint: 'Search for a building',
            onSubmitted: widget.onQueryChanged,
          ),
          const SizedBox(height: PulseSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(PulseRadius.card),
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(PulseRadius.card),
                border: Border.all(color: t.border),
              ),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 3,
                child: SizedBox(
                  width: kMapCanvasSize.width,
                  height: kMapCanvasSize.height,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CampusMapPainter(
                        places: widget.places,
                        tokens: t,
                        highlight: highlight,
                      ),
                      child: _PinOverlay(
                        places: widget.places,
                        highlight: highlight,
                        onTap: widget.onOpenPlace,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PulseSpacing.lg),
          Text(
            'Buildings',
            style: PulseType.heading.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.md),
          for (final place in widget.places)
            Padding(
              padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
              child: PulseCard(
                padding: const EdgeInsets.all(PulseSpacing.md),
                onTap: widget.onOpenPlace == null
                    ? null
                    : () => widget.onOpenPlace!(place),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, size: 20, color: t.textSecondary),
                    const SizedBox(width: PulseSpacing.md),
                    Expanded(
                      child: Text(
                        place.name,
                        style: PulseType.body.copyWith(color: t.textPrimary),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: t.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws the map background: the paths and the building blocks.
class _CampusMapPainter extends CustomPainter {
  const _CampusMapPainter({
    required this.places,
    required this.tokens,
    required this.highlight,
  });

  final List<MapPlace> places;
  final PulseTokens tokens;
  final String highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = tokens.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // The paths that run between the buildings.
    final path = Path()
      ..moveTo(10, 100)
      ..lineTo(size.width - 10, 100);
    canvas.drawPath(path, pathPaint);

    final crossing = Path()
      ..moveTo(140, 10)
      ..lineTo(140, size.height - 10);
    canvas.drawPath(crossing, pathPaint);

    for (final place in places) {
      final matches = highlight.isEmpty ||
          place.name.toLowerCase().contains(highlight);

      final rect = Rect.fromLTWH(
        place.x,
        place.y,
        place.width,
        place.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..color = matches
              ? tokens.primary.withValues(alpha: 0.22)
              : tokens.surfaceElevated,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..color = matches ? tokens.primary : tokens.borderStrong
          ..style = PaintingStyle.stroke
          ..strokeWidth = matches ? 2 : 1,
      );
    }
  }

  @override
  bool shouldRepaint(_CampusMapPainter oldDelegate) =>
      oldDelegate.places != places ||
      oldDelegate.tokens != tokens ||
      oldDelegate.highlight != highlight;
}

/// Places the tappable pins on top of the painted map.
class _PinOverlay extends StatelessWidget {
  const _PinOverlay({
    required this.places,
    required this.highlight,
    this.onTap,
  });

  final List<MapPlace> places;
  final String highlight;
  final void Function(MapPlace place)? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return Stack(
      children: [
        for (final place in places)
          Positioned(
            left: place.x,
            top: place.y + place.height / 2 - 12,
            width: place.width,
            child: Semantics(
              button: true,
              label: place.name,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap == null ? null : () => onTap!(place),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PulseSpacing.sm,
                      vertical: PulseSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: highlight.isEmpty ||
                              place.name.toLowerCase().contains(highlight)
                          ? t.primary.withValues(alpha: 0.85)
                          : t.surfaceElevated,
                      borderRadius: BorderRadius.circular(PulseRadius.input),
                      border: Border.all(color: t.border),
                    ),
                    child: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseType.caption.copyWith(
                        color: highlight.isEmpty ||
                                place.name.toLowerCase().contains(highlight)
                            ? t.onPrimary
                            : t.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
