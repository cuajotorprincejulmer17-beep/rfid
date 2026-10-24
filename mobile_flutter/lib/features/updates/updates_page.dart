import 'package:flutter/material.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../data/models/models.dart' show formatClock, formatShortDate;
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';

/// A category chip: the label shown and the [UpdateItem.category] it keeps.
typedef UpdateCategory = ({String label, String? value});

/// The sample-data categories.
const List<UpdateCategory> kSampleCategories = <UpdateCategory>[
  (label: 'All', value: null),
  (label: 'School', value: 'school'),
  (label: 'Events', value: 'events'),
  (label: 'Academic', value: 'academic'),
];

/// The school inbox categories (`project/api/inbox.py`).
const List<UpdateCategory> kInboxCategories = <UpdateCategory>[
  (label: 'All', value: null),
  (label: 'Attendance', value: 'attendance'),
  (label: 'Announcements', value: 'system'),
  (label: 'Emergency', value: 'emergency'),
];

/// The Updates page.
///
/// The only controls are the category chips and the saved filter. There is
/// no bell in the top corner: the dock carries the unread count instead.
class UpdatesPage extends StatefulWidget {
  const UpdatesPage({
    super.key,
    required this.updates,
    this.categories = kSampleCategories,
    this.loading = false,
    this.error,
    this.onOpen,
    this.onToggleSaved,
    this.onRefresh,
    this.onMarkAllRead,
  });

  final List<UpdateItem> updates;
  final List<UpdateCategory> categories;
  final bool loading;

  /// Why the updates could not be loaded. Null when they loaded.
  final String? error;
  final void Function(UpdateItem update)? onOpen;

  /// Saving is offered only when this is set.
  final void Function(UpdateItem update, bool saved)? onToggleSaved;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onMarkAllRead;

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  String? _category;
  bool _savedOnly = false;

  List<UpdateItem> get _visible {
    return widget.updates.where((update) {
      if (_savedOnly && !update.saved) return false;
      if (_category == null) return true;
      return update.category == _category;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final updates = _visible;
    final hasUnread = widget.updates.any((update) => !update.read);

    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        PulseSpacing.lg,
        PulseSpacing.lg,
        PulseSpacing.lg,
        PulseSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Updates',
                  style: PulseType.title.copyWith(color: t.textPrimary),
                ),
              ),
              if (widget.onMarkAllRead != null && hasUnread)
                TextButton(
                  onPressed: widget.onMarkAllRead,
                  child: Text(
                    'Mark all read',
                    style: PulseType.label.copyWith(color: t.accentCyan),
                  ),
                ),
            ],
          ),
          const SizedBox(height: PulseSpacing.lg),

          Wrap(
            spacing: PulseSpacing.sm,
            runSpacing: PulseSpacing.sm,
            children: [
              for (final category in widget.categories)
                PulseChip(
                  label: category.label,
                  selected: _category == category.value,
                  onSelected: () => setState(() => _category = category.value),
                ),
              if (widget.onToggleSaved != null)
                PulseChip(
                  label: 'Saved',
                  icon: Icons.bookmark_outline,
                  selected: _savedOnly,
                  onSelected: () => setState(() => _savedOnly = !_savedOnly),
                ),
            ],
          ),

          const SizedBox(height: PulseSpacing.lg),

          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(PulseSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.error != null)
            PulseCard(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 28, color: t.error),
                  const SizedBox(height: PulseSpacing.sm),
                  Text(
                    widget.error!,
                    textAlign: TextAlign.center,
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            )
          else if (updates.isEmpty)
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
                        : widget.updates.isEmpty
                        ? 'Nothing yet. Attendance records and school '
                              'announcements will appear here.'
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
    );

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        bottom: false,
        child: widget.onRefresh == null
            ? scroll
            : RefreshIndicator(onRefresh: widget.onRefresh!, child: scroll),
      ),
    );
  }
}

/// One update in the list.
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update, this.onOpen, this.onToggleSaved});

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
                    fontWeight: update.read ? FontWeight.w400 : FontWeight.w600,
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
          const SizedBox(height: PulseSpacing.xs),
          Text(
            '${formatShortDate(update.publishedAt)}, '
            '${formatClock(update.publishedAt)}',
            style: PulseType.caption.copyWith(
              color: t.textSecondary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
