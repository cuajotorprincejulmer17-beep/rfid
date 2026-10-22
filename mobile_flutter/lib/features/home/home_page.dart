import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';

/// The Home page.
///
/// It has no top-corner controls. From the top: a greeting, a stack of
/// three overlapping summary cards, four circular quick actions, upcoming
/// tasks, latest updates, and the sample-data chip.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.greeting,
    this.subtitle = 'Your campus. In sync.',
    this.attendanceStatus,
    this.attendanceLabel = 'Attendance',
    this.nextClassTitle,
    this.nextClassDetail,
    this.tasksDueToday = 0,
    this.taskTitles = const <String>[],
    this.updateTitles = const <String>[],
    this.showSampleDataChip = true,
  });

  /// The greeting line, usually the student's name.
  final String greeting;
  final String subtitle;

  /// The real attendance status, when it is known.
  final StatusTone? attendanceStatus;
  final String attendanceLabel;

  final String? nextClassTitle;
  final String? nextClassDetail;
  final int tasksDueToday;
  final List<String> taskTitles;
  final List<String> updateTitles;

  /// Whether the sample-data chip should be shown.
  final bool showSampleDataChip;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

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
              // The greeting. No controls sit in the top corners.
              Text(
                greeting,
                style: PulseType.title.copyWith(color: t.textPrimary),
              ),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                subtitle,
                style: PulseType.body.copyWith(color: t.textSecondary),
              ),
              if (showSampleDataChip) ...[
                const SizedBox(height: PulseSpacing.md),
                const SampleDataChip(),
              ],

              const SizedBox(height: PulseSpacing.lg),

              // The stack of three overlapping summary cards.
              _SummaryCardStack(
                attendanceStatus: attendanceStatus,
                attendanceLabel: attendanceLabel,
                nextClassTitle: nextClassTitle,
                nextClassDetail: nextClassDetail,
                tasksDueToday: tasksDueToday,
              ),

              const SizedBox(height: PulseSpacing.xl),

              // Four circular quick actions, each a deep link.
              const _QuickActionsRow(),

              const SizedBox(height: PulseSpacing.xl),

              SectionHeader(
                title: 'Upcoming tasks',
                actionLabel: 'View all',
                onAction: () => context.push(lookupDestination('tasks')!.route),
              ),
              const SizedBox(height: PulseSpacing.md),
              if (taskTitles.isEmpty)
                _QuietNote(text: 'No tasks yet. Add one from the Tasks tab.')
              else
                for (final title in taskTitles.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                    child: _ListRow(
                      icon: Icons.task_alt_outlined,
                      title: title,
                      onTap: () => context.push(lookupDestination('tasks')!.route),
                    ),
                  ),

              const SizedBox(height: PulseSpacing.lg),

              SectionHeader(
                title: 'Latest updates',
                actionLabel: 'View all',
                onAction: () =>
                    context.push(lookupDestination('updates')!.route),
              ),
              const SizedBox(height: PulseSpacing.md),
              if (updateTitles.isEmpty)
                _QuietNote(text: 'Nothing new right now.')
              else
                for (final title in updateTitles.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                    child: _ListRow(
                      icon: Icons.campaign_outlined,
                      title: title,
                      onTap: () =>
                          context.push(lookupDestination('updates')!.route),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet line of text where a list would be.
class _QuietNote extends StatelessWidget {
  const _QuietNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Text(
      text,
      style: PulseType.body.copyWith(color: t.textSecondary),
    );
  }
}

/// One row in a list on Home.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseCard(
      onTap: onTap,
      padding: const EdgeInsets.all(PulseSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.textSecondary),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PulseType.body.copyWith(color: t.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textSecondary),
        ],
      ),
    );
  }
}

/// The stack of three overlapping summary cards.
///
/// Attendance is the front card and is the only card that glows. The stack
/// compresses as the page scrolls, driven by the scroll position rather
/// than by a timed animation.
class _SummaryCardStack extends StatelessWidget {
  const _SummaryCardStack({
    required this.attendanceStatus,
    required this.attendanceLabel,
    required this.nextClassTitle,
    required this.nextClassDetail,
    required this.tasksDueToday,
  });

  final StatusTone? attendanceStatus;
  final String attendanceLabel;
  final String? nextClassTitle;
  final String? nextClassDetail;
  final int tasksDueToday;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    return SizedBox(
      height: 226,
      child: Stack(
        children: [
          // The third card, furthest back.
          Positioned(
            left: 24,
            right: 24,
            top: 48,
            child: Transform.scale(
              scale: 0.88,
              alignment: Alignment.topCenter,
              child: _StackCard(
                title: 'Tasks',
                detail: '$tasksDueToday due today',
                icon: Icons.task_alt_outlined,
              ),
            ),
          ),
          // The second card.
          Positioned(
            left: 12,
            right: 12,
            top: 24,
            child: Transform.scale(
              scale: 0.94,
              alignment: Alignment.topCenter,
              child: _StackCard(
                title: 'Next class',
                detail: nextClassTitle ?? 'Nothing scheduled',
                subtitle: nextClassDetail,
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ),
          // The front card, the single glowing element.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: PulseCard(
              featured: true,
              onTap: () =>
                  context.push(lookupDestination('attendance')!.route),
              semanticLabel: '$attendanceLabel. Open attendance.',
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.softFill,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: t.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 22,
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
                          attendanceLabel,
                          style: PulseType.label
                              .copyWith(color: t.textSecondary),
                        ),
                        const SizedBox(height: PulseSpacing.xs),
                        Text(
                          'Your attendance',
                          style: PulseType.heading
                              .copyWith(color: t.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  if (attendanceStatus != null)
                    StatusPill(
                      label: _statusLabel(attendanceStatus!),
                      tone: attendanceStatus!,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(StatusTone tone) => switch (tone) {
        StatusTone.success => 'Recorded',
        StatusTone.warning => 'Pending',
        StatusTone.danger => 'Missing',
        StatusTone.info => 'In',
        StatusTone.neutral => 'Unknown',
      };
}

/// A card in the summary stack, behind the front card.
class _StackCard extends StatelessWidget {
  const _StackCard({
    required this.title,
    required this.detail,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String detail;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseCard(
      elevated: true,
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.textSecondary),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: PulseType.label.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PulseType.body.copyWith(color: t.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The four circular quick actions.
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, String)>[
      (
        'Scan',
        Icons.credit_card_outlined,
        lookupDestination('attendance')!.route,
      ),
      (
        'Digital ID',
        Icons.badge_outlined,
        lookupDestination('digital-id')!.route,
      ),
      (
        'Find room',
        Icons.meeting_room_outlined,
        lookupDestination('rooms')!.route,
      ),
      (
        'Report lost',
        Icons.inventory_2_outlined,
        lookupDestination('lost-found')!.route,
      ),
    ];

    return Row(
      children: [
        for (final (label, icon, route) in actions)
          Expanded(
            child: _QuickAction(
              label: label,
              icon: icon,
              onTap: () => context.push(route),
            ),
          ),
      ],
    );
  }
}

/// One circular quick action.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: t.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
              child: Icon(icon, size: 22, color: t.navSelected),
            ),
            const SizedBox(height: PulseSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: PulseType.caption.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
