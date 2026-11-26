import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';

/// The student home: a truthful RFID status, a ready-for-server PULSE card,
/// professor activities, and personal reminders.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.greeting,
    this.subtitle = 'Your campus. In sync.',
    this.rfidState,
    this.lastRfidScan,
    this.nextClassTitle,
    this.nextClassDetail,
    this.professorActivityTitles = const <String>[],
    this.personalReminderTitles = const <String>[],
    this.updateTitles = const <String>[],
    this.showSampleDataChip = true,
    this.onRefresh,
  });

  final String greeting;
  final String subtitle;

  /// `in`, `out`, `not_in`, or null when the server has not answered.
  final String? rfidState;
  final DateTime? lastRfidScan;
  final String? nextClassTitle;
  final String? nextClassDetail;
  final List<String> professorActivityTitles;
  final List<String> personalReminderTitles;
  final List<String> updateTitles;
  final bool showSampleDataChip;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        bottom: false,
        child: _refreshable(
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(PulseSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.success.withValues(alpha: 0.13),
                        border: Border.all(
                          color: t.success.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(Icons.eco_outlined, color: t.success),
                    ),
                    const SizedBox(width: PulseSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OLFU PULSE',
                            style: PulseType.label.copyWith(
                              color: t.textPrimary,
                            ),
                          ),
                          Text(
                            'Student verified wins',
                            style: PulseType.caption.copyWith(
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.account_circle_outlined, color: t.textSecondary),
                  ],
                ),
                const SizedBox(height: PulseSpacing.xl),
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
                _RfidStatusCard(state: rfidState, lastScan: lastRfidScan),
                const SizedBox(height: PulseSpacing.md),
                const _PulseProgressCard(),
                const SizedBox(height: PulseSpacing.xl),
                const _QuickActionsRow(),
                const SizedBox(height: PulseSpacing.xl),
                if (nextClassTitle != null) ...[
                  const SectionHeader(title: 'Next on your schedule'),
                  const SizedBox(height: PulseSpacing.md),
                  _ListRow(
                    icon: Icons.calendar_today_outlined,
                    eyebrow: nextClassDetail ?? 'Scheduled class',
                    title: nextClassTitle!,
                    onTap: () =>
                        context.push(lookupDestination('schedule')!.route),
                  ),
                  const SizedBox(height: PulseSpacing.xl),
                ],
                SectionHeader(
                  title: 'Professor activities',
                  actionLabel: 'View all',
                  onAction: () =>
                      context.push(lookupDestination('tasks')!.route),
                ),
                const SizedBox(height: PulseSpacing.md),
                if (professorActivityTitles.isEmpty)
                  const _QuietNote(
                    text: 'Your professor’s activities will appear here.',
                  )
                else
                  for (final title in professorActivityTitles.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                      child: _ListRow(
                        icon: Icons.school_outlined,
                        eyebrow: 'Professor activity · verification required',
                        title: title,
                        onTap: () =>
                            context.push(lookupDestination('tasks')!.route),
                      ),
                    ),
                const SizedBox(height: PulseSpacing.lg),
                SectionHeader(
                  title: 'My reminders',
                  actionLabel: 'View all',
                  onAction: () =>
                      context.push(lookupDestination('tasks')!.route),
                ),
                const SizedBox(height: PulseSpacing.md),
                if (personalReminderTitles.isEmpty)
                  const _QuietNote(text: 'No personal reminders yet.')
                else
                  for (final title in personalReminderTitles.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                      child: _ListRow(
                        icon: Icons.bookmark_outline,
                        eyebrow: 'Personal reminder · no PULSE points',
                        title: title,
                        onTap: () =>
                            context.push(lookupDestination('tasks')!.route),
                      ),
                    ),
                const SizedBox(height: PulseSpacing.lg),
                SectionHeader(
                  title: 'Announcements',
                  actionLabel: 'View all',
                  onAction: () =>
                      context.push(lookupDestination('updates')!.route),
                ),
                const SizedBox(height: PulseSpacing.md),
                if (updateTitles.isEmpty)
                  const _QuietNote(text: 'Nothing new right now.')
                else
                  for (final title in updateTitles.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                      child: _ListRow(
                        icon: Icons.campaign_outlined,
                        eyebrow: 'Campus announcement',
                        title: title,
                        onTap: () =>
                            context.push(lookupDestination('updates')!.route),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _refreshable(Widget child) => onRefresh == null
      ? child
      : RefreshIndicator(onRefresh: onRefresh!, child: child);
}

class _RfidStatusCard extends StatelessWidget {
  const _RfidStatusCard({required this.state, required this.lastScan});

  final String? state;
  final DateTime? lastScan;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final (label, tone, icon) = switch (state) {
      'in' => ('IN', StatusTone.success, Icons.login_rounded),
      'out' => ('OUT', StatusTone.neutral, Icons.logout_rounded),
      'not_in' => (
        'NOT SCANNED',
        StatusTone.warning,
        Icons.credit_card_off_outlined,
      ),
      _ => ('UNKNOWN', StatusTone.neutral, Icons.wifi_off_outlined),
    };
    final detail = lastScan == null
        ? state == null
              ? 'The school server has not reported a scan status.'
              : 'No RFID scan has been reported today.'
        : 'Last RFID scan · ${_clock(lastScan!)}';
    return PulseCard(
      featured: true,
      onTap: () => context.push(lookupDestination('attendance')!.route),
      semanticLabel: 'RFID status $label. Open attendance.',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.softFill,
              border: Border.all(color: t.primary.withValues(alpha: 0.45)),
            ),
            child: Icon(Icons.contactless_outlined, color: t.navSelected),
          ),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RFID status',
                  style: PulseType.label.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  detail,
                  style: PulseType.caption.copyWith(color: t.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: PulseSpacing.sm),
          Column(
            children: [
              Icon(icon, size: 18, color: _toneColor(t, tone)),
              const SizedBox(height: PulseSpacing.xs),
              StatusPill(label: label, tone: tone),
            ],
          ),
        ],
      ),
    );
  }

  static Color _toneColor(PulseTokens t, StatusTone tone) => switch (tone) {
    StatusTone.success => t.success,
    StatusTone.warning => t.warning,
    StatusTone.danger => t.error,
    StatusTone.info => t.accentCyan,
    StatusTone.neutral => t.textSecondary,
  };

  static String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

/// A deliberately zero-state rewards card until the school exposes verified
/// reward totals. The app must never calculate points from a self-checked box.
class _PulseProgressCard extends StatelessWidget {
  const _PulseProgressCard();

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Container(
      padding: const EdgeInsets.all(PulseSpacing.lg),
      decoration: BoxDecoration(
        color: t.success,
        borderRadius: BorderRadius.circular(PulseRadius.card + 4),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -44,
            bottom: -68,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.17),
                  width: 26,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your verified PULSE',
                      style: PulseType.label.copyWith(color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PulseSpacing.sm,
                      vertical: PulseSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PulseRadius.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Campus Explorer',
                      style: PulseType.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PulseSpacing.md),
              Text(
                '0 PULSE',
                style: PulseType.title.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                'RFID scans and professor approvals count. Personal reminders do not.',
                style: PulseType.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: PulseSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(PulseRadius.pill),
                child: LinearProgressIndicator(
                  value: 0,
                  minHeight: 8,
                  color: const Color(0xFFFFD567),
                  backgroundColor: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                'Reward rules will appear when your school enables them.',
                style: PulseType.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuietNote extends StatelessWidget {
  const _QuietNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: PulseType.body.copyWith(color: context.pulse.textSecondary),
  );
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: t.softFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: t.navSelected),
          ),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PulseType.body.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PulseType.caption.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textSecondary),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = <(String, IconData, String)>[
      (
        'Attendance',
        Icons.contactless_outlined,
        lookupDestination('attendance')!.route,
      ),
      (
        'Schedule',
        Icons.calendar_today_outlined,
        lookupDestination('schedule')!.route,
      ),
      (
        'Digital ID',
        Icons.badge_outlined,
        lookupDestination('digital-id')!.route,
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
