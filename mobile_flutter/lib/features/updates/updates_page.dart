import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';

/// The Updates page.
///
/// The only controls are the category chips and the saved filter. There is
/// no bell in the top corner: the dock carries the unread count instead.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({
    super.key,
    required this.updates,
    this.onOpen,
    this.onToggleSaved,
  });

  final List<UpdateItem> updates;
  final void Function(UpdateItem update)? onOpen;
  final void Function(UpdateItem update, bool saved)? onToggleSaved;

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  String _category = 'All';
  bool _savedOnly = false;

  static const List<String> _categories = <String>[
    'All',
    'School',
    'Events',
    'Academic',
  ];

  List<UpdateItem> get _visible {
    return widget.updates.where((update) {
      if (_savedOnly && !update.saved) return false;
      if (_category == 'All') return true;
      return update.category == _category.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final updates = _visible;

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PulseSpacing.lg,
            PulseSpacing.lg,
            PulseSpacing.lg,
            PulseSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Updates',
                style: PulseType.title.copyWith(color: t.textPrimary),
              ),
              const SizedBox(height: PulseSpacing.lg),

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
                  PulseChip(
                    label: 'Saved',
                    icon: Icons.bookmark_outline,
                    selected: _savedOnly,
                    onSelected: () => setState(() => _savedOnly = !_savedOnly),
                  ),
                ],
              ),

              const SizedBox(height: PulseSpacing.lg),

              if (updates.isEmpty)
                PulseCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
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
                        _savedOnly
                            ? 'You have not saved any updates yet.'
                            : 'No updates match this filter.',
                        textAlign: TextAlign.center,
                        style: PulseType.caption.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                for (final update in updates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                    child: _UpdateCard(
                      update: update,
                      onOpen: widget.onOpen == null
                          ? null
                          : () => widget.onOpen!(update),
                      onToggleSaved: widget.onToggleSaved == null
                          ? null
                          : () => widget.onToggleSaved!(update, !update.saved),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One update in the list.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
    this.onOpen,
    this.onToggleSaved,
  });

  final UpdateItem update;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return PulseCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  update.title,
                  style: PulseType.body.copyWith(
                    color: update.read ? t.textSecondary : t.textPrimary,
                    fontWeight:
                        update.read ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              if (onToggleSaved != null)
                Semantics(
                  button: true,
                  label: update.saved ? 'Remove from saved' : 'Save update',
                  child: IconButton(
                    icon: Icon(
                      update.saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline,
                      size: 20,
                      color: update.saved ? t.accentCyan : t.textSecondary,
                    ),
                    onPressed: onToggleSaved,
                    tooltip: update.saved ? 'Remove from saved' : 'Save',
                  ),
                ),
            ],
          ),
          const SizedBox(height: PulseSpacing.xs),
          Text(
            update.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}
