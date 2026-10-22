import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_text_field.dart';
import '../../shared/widgets/status_pill.dart';

/// The Library page.
class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.items,
    this.query = '',
    this.onQueryChanged,
  });

  final List<LibraryItem> items;
  final String query;
  final ValueChanged<String>? onQueryChanged;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final featured = widget.items.where((i) => i.featured).toList();
    final rest = widget.items.where((i) => !i.featured).toList();

    return PulsePage(
      title: 'Library',
      subtitle: 'Collections and availability',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseTextField(
            controller: _controller,
            hint: 'Search by title, author or shelf',
            onSubmitted: widget.onQueryChanged,
          ),
          const SizedBox(height: PulseSpacing.lg),
          if (widget.items.isEmpty)
            Text(
              'Nothing matches that search.',
              style: PulseType.body.copyWith(color: t.textSecondary),
            ),
          if (featured.isNotEmpty) ...[
            Text(
              'Featured',
              style: PulseType.heading.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: PulseSpacing.md),
            for (final item in featured)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                child: PulseCard(
                  featured: true,
                  onTap: () => context.push(
                    lookupDestination('library-item')!
                        .route
                        .replaceFirst(':id', item.id),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 22,
                        color: t.navSelected,
                      ),
                      const SizedBox(width: PulseSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              style: PulseType.body
                                  .copyWith(color: t.textPrimary),
                            ),
                            Text(
                              item.author,
                              style: PulseType.caption
                                  .copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PulseSpacing.md),
                      StatusPill(
                        label: item.available ? 'Available' : 'On loan',
                        tone: item.available
                            ? StatusTone.success
                            : StatusTone.neutral,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: PulseSpacing.md),
          ],
          if (rest.isNotEmpty) ...[
            Text(
              'Available collections',
              style: PulseType.heading.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: PulseSpacing.md),
            for (final item in rest)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                child: PulseCard(
                  onTap: () => context.push(
                    lookupDestination('library-item')!
                        .route
                        .replaceFirst(':id', item.id),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              style: PulseType.body
                                  .copyWith(color: t.textPrimary),
                            ),
                            const SizedBox(height: PulseSpacing.xs),
                            Text(
                              '${item.author} - shelf ${item.shelf}',
                              style: PulseType.caption
                                  .copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PulseSpacing.md),
                      StatusPill(
                        label: item.available ? 'Available' : 'On loan',
                        tone: item.available
                            ? StatusTone.success
                            : StatusTone.neutral,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
