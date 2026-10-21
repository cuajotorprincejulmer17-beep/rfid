import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';

/// A static loading placeholder.
///
/// The Motion Law forbids shimmer loops, so a loading region shows a flat
/// tonal block that holds still.
class PulseSkeleton extends StatelessWidget {
  const PulseSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = PulseRadius.input,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A stack of skeletons shaped like a list row.
class PulseSkeletonList extends StatelessWidget {
  const PulseSkeletonList({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: PulseSpacing.md),
            child: Row(
              children: [
                const PulseSkeleton(width: 40, height: 40, radius: 20),
                const SizedBox(width: PulseSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PulseSkeleton(height: 14, width: double.infinity),
                      const SizedBox(height: PulseSpacing.xs),
                      PulseSkeleton(height: 12, width: 140),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
