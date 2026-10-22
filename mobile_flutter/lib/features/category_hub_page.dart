import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
import '../navigation/destination_registry.dart';
import '../shared/widgets/feature_tile.dart';
import '../shared/widgets/pulse_page.dart';

/// A category hub.
///
/// The hub lists only the features the registry places under it, so a
/// feature can never appear in two categories and there is no universal More
/// list anywhere in the app.
class CategoryHubPage extends StatelessWidget {
  const CategoryHubPage({
    super.key,
    required this.categoryId,
    this.sampleData = false,
  });

  /// The registry id of the category, for example `academic`.
  final String categoryId;

  /// Whether the features under this category are backed by sample data.
  final bool sampleData;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final category = lookupDestination(categoryId)!;
    final features = featuresOf(categoryId);

    return PulsePage(
      title: category.title,
      subtitle: 'Choose what you need',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sampleData) ...[
            const SampleDataChip(),
            const SizedBox(height: PulseSpacing.lg),
          ],
          Wrap(
            spacing: PulseSpacing.lg,
            runSpacing: PulseSpacing.xl,
            children: [
              for (final feature in features)
                SizedBox(
                  width: 104,
                  child: FeatureTile(
                    icon: feature.icon,
                    label: feature.title,
                    onTap: () => context.push(feature.route),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PulseSpacing.xl),
          Text(
            '${features.length} feature${features.length == 1 ? '' : 's'} in '
            '${category.title}.',
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
