import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_segmented.dart';
import '../../shared/widgets/pulse_sheet.dart';
import '../../shared/widgets/pulse_text_field.dart';
import '../../shared/widgets/status_pill.dart';

/// Whether the list shows reported or claimed items.
enum LostFoundFilter { reported, claimed }

/// The Lost and Found page.
class LostFoundPage extends StatefulWidget {
  const LostFoundPage({
    super.key,
    required this.items,
    this.onReport,
  });

  final List<LostFoundItem> items;
  final Future<void> Function(LostFoundItem item)? onReport;

  @override
  State<LostFoundPage> createState() => _LostFoundPageState();
}

class _LostFoundPageState extends State<LostFoundPage> {
  LostFoundFilter _filter = LostFoundFilter.reported;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    final categories = widget.items.map((i) => i.category).toSet().toList()..sort();
    final visible = widget.items.where((item) {
      final matchesFilter = _filter == LostFoundFilter.claimed
          ? item.claimed
          : !item.claimed;
      final matchesCategory = _category == null || item.category == _category;
      return matchesFilter && matchesCategory;
    }).toList();

    return PulsePage(
      title: 'Lost and Found',
      subtitle: 'Reported items on campus',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Report lost item',
          onPressed: widget.onReport == null
              ? null
              : () => _openReportSheet(context),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PulseSegmented<LostFoundFilter>(
            segments: const <PulseSegment<LostFoundFilter>>[
              PulseSegment(
                value: LostFoundFilter.reported,
                label: 'Reported',
              ),
              PulseSegment(
                value: LostFoundFilter.claimed,
                label: 'Claimed',
              ),
            ],
            value: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: PulseSpacing.lg),
          if (categories.isNotEmpty)
            Wrap(
              spacing: PulseSpacing.sm,
              runSpacing: PulseSpacing.sm,
              children: [
                for (final category in categories)
                  PulseChip(
                    label: category,
                    selected: _category == category,
                    onSelected: () => setState(
                      () => _category = _category == category ? null : category,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: PulseSpacing.lg),
          if (visible.isEmpty)
            PulseCard(
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 28,
                    color: t.textSecondary,
                  ),
                  const SizedBox(height: PulseSpacing.sm),
                  Text(
                    'Nothing here',
                    style: PulseType.label.copyWith(color: t.textPrimary),
                  ),
                  const SizedBox(height: PulseSpacing.xs),
                  Text(
                    'No items match this filter.',
                    textAlign: TextAlign.center,
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                child: PulseCard(
                  onTap: () => context.push(
                    lookupDestination('lost-found-detail')!
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
                              item.name,
                              style:
                                  PulseType.body.copyWith(color: t.textPrimary),
                            ),
                            const SizedBox(height: PulseSpacing.xs),
                            Text(
                              '${item.category} - ${item.location}',
                              style: PulseType.caption
                                  .copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PulseSpacing.md),
                      StatusPill(
                        label: item.claimed ? 'Claimed' : 'Reported',
                        tone: item.claimed
                            ? StatusTone.success
                            : StatusTone.warning,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _openReportSheet(BuildContext context) async {
    final created = await showPulseSheet<LostFoundItem>(
      context: context,
      builder: (context) => const ReportLostItemSheet(),
    );
    if (created != null && widget.onReport != null) {
      await widget.onReport!(created);
    }
  }
}

/// The Report lost item sheet.
class ReportLostItemSheet extends StatefulWidget {
  const ReportLostItemSheet({super.key});

  @override
  State<ReportLostItemSheet> createState() => _ReportLostItemSheetState();
}

class _ReportLostItemSheetState extends State<ReportLostItemSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _category = 'Belongings';
  String? _nameError;
  String? _locationError;
  bool _busy = false;

  static const List<String> _categories = <String>[
    'Belongings',
    'Stationery',
    'Cards',
    'Books',
  ];

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final valid = _name.text.trim().isNotEmpty &&
        _location.text.trim().isNotEmpty;

    return PulseSheet(
      title: 'Report a lost item',
      subtitle: 'Tell the campus what was lost and where.',
      primaryLabel: 'Report item',
      primaryEnabled: valid,
      busy: _busy,
      onPrimary: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseTextField(
            controller: _name,
            label: 'Item name',
            hint: 'What was lost?',
            errorText: _nameError,
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _location,
            label: 'Last seen location',
            hint: 'Where was it last seen?',
            errorText: _locationError,
          ),
          const SizedBox(height: PulseSpacing.lg),
          Text(
            'Category',
            style: PulseType.label.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: PulseSpacing.sm),
          Wrap(
            spacing: PulseSpacing.sm,
            runSpacing: PulseSpacing.sm,
            children: [
              for (final category in _categories)
                PulseChip(
                  label: category,
                  selected: _category == category,
                  onSelected: () => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _description,
            label: 'Description',
            hint: 'Optional. Colour, brand, anything that helps.',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final location = _location.text.trim();
    if (name.isEmpty || location.isEmpty) {
      setState(() {
        _nameError = name.isEmpty ? 'Say what was lost.' : null;
        _locationError = location.isEmpty ? 'Say where it was last seen.' : null;
      });
      return;
    }
    setState(() {
      _nameError = null;
      _locationError = null;
      _busy = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.of(context).pop(
      LostFoundItem(
        id: 'new',
        name: name,
        category: _category,
        location: location,
        reportedAt: DateTime.now(),
        claimed: false,
      ),
    );
  }
}
