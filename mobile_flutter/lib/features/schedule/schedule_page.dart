import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';
import '../../shared/widgets/pulse_segmented.dart';
import '../../shared/widgets/status_pill.dart';

/// The range of the schedule being shown.
enum ScheduleRange { today, week, month }

/// The Schedule page.
///
/// It has no top-corner controls. The segmented control at the top is a
/// local control that changes what the page shows.
class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.events,
    this.loading = false,
  });

  /// The events the page shows, already filtered to the chosen range.
  final List<ScheduleEvent> events;

  final bool loading;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  ScheduleRange _range = ScheduleRange.today;
  String _filter = 'All';

  static const List<String> _filters = <String>['All', 'Classes', 'Exams', 'Personal'];

  List<ScheduleEvent> get _visible {
    if (_filter == 'All') return widget.events;
    final kind = switch (_filter) {
      'Classes' => 'class',
      'Exams' => 'exam',
      'Personal' => 'personal',
      _ => 'class',
    };
    return widget.events.where((e) => e.kind == kind).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final events = _visible;

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
                'Schedule',
                style: PulseType.title.copyWith(color: t.textPrimary),
              ),
              const SizedBox(height: PulseSpacing.lg),

              PulseSegmented<ScheduleRange>(
                segments: const <PulseSegment<ScheduleRange>>[
                  PulseSegment(value: ScheduleRange.today, label: 'Today'),
                  PulseSegment(value: ScheduleRange.week, label: 'Week'),
                  PulseSegment(value: ScheduleRange.month, label: 'Month'),
                ],
                value: _range,
                onChanged: (value) => setState(() => _range = value),
              ),

              const SizedBox(height: PulseSpacing.lg),

              // The filter chips. They are local controls, not a top-corner
              // menu.
              Wrap(
                spacing: PulseSpacing.sm,
                runSpacing: PulseSpacing.sm,
                children: [
                  for (final filter in _filters)
                    PulseChip(
                      label: filter,
                      selected: _filter == filter,
                      onSelected: () => setState(() => _filter = filter),
                    ),
                ],
              ),

              const SizedBox(height: PulseSpacing.lg),

              if (events.isEmpty)
                _EmptyDay(hasFilters: _filter != 'All')
              else
                for (final event in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                    child: _EventCard(event: event),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The empty state for a day with nothing on it.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseCard(
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 28, color: t.textSecondary),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            'Nothing scheduled',
            style: PulseType.label.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.xs),
          Text(
            hasFilters
                ? 'No events match the current filter.'
                : 'This day has no classes, exams or personal events.',
            textAlign: TextAlign.center,
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One event on the schedule.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ScheduleEvent event;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    final (String label, StatusTone tone) = switch (event.status) {
      EventStatus.upcoming => ('Upcoming', StatusTone.info),
      EventStatus.now => ('Now', StatusTone.success),
      EventStatus.done => ('Done', StatusTone.neutral),
    };

    final time = '${_two(event.start.hour)}:${_two(event.start.minute)}'
        ' - ${_two(event.end.hour)}:${_two(event.end.minute)}';

    return PulseCard(
      onTap: () => context.push(
        lookupDestination('schedule-event')!.route.replaceFirst(':id', event.id),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.title,
                  style: PulseType.body.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  '$time - ${event.room}',
                  style: PulseType.caption.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: PulseSpacing.md),
          StatusPill(label: label, tone: tone),
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
