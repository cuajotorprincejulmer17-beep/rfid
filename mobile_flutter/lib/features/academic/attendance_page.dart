import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../data/models/models.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/status_pill.dart';

/// The Attendance page.
///
/// The status shown is the one the server reported. The app never decides
/// an attendance outcome, so there is no "mark me present" action and no
/// client-side scan that could write attendance.
class AttendancePage extends StatelessWidget {
  const AttendancePage({
    super.key,
    required this.today,
    this.recent = const <AttendanceDay>[],
    this.loading = false,
    this.error,
    this.onRetry,
  });

  /// The day's attendance, as the server reported it.
  final AttendanceDay? today;

  /// The days before today, as the server reported them.
  final List<AttendanceDay> recent;

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    if (loading) {
      return const PulsePage(
        title: 'Attendance',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return PulsePage(
        title: 'Attendance',
        child: _ErrorCard(message: error!, onRetry: onRetry),
      );
    }

    final day = today;

    return PulsePage(
      title: 'Attendance',
      subtitle: 'Reported by the server',
      actions: [
        IconButton(
          icon: const Icon(Icons.history_outlined),
          tooltip: 'View history',
          onPressed: () => context.push(
            lookupDestination('attendance-history')!.route,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The status card.
          PulseCard(
            featured: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today',
                        style: PulseType.label.copyWith(color: t.textSecondary),
                      ),
                    ),
                    if (day != null)
                      StatusPill(
                        label: _label(day.status),
                        tone: _tone(day.status),
                      ),
                  ],
                ),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  day == null
                      ? 'No status yet'
                      : _headline(day),
                  style: PulseType.heading.copyWith(color: t.textPrimary),
                ),
                if (day != null) ...[
                  const SizedBox(height: PulseSpacing.sm),
                  Text(
                    _detail(day),
                    style: PulseType.body.copyWith(color: t.textSecondary),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: PulseSpacing.lg),

          // The explanation of what the status means.
          PulseCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: t.textSecondary),
                const SizedBox(width: PulseSpacing.md),
                Expanded(
                  child: Text(
                    'Attendance is recorded by tapping your card on the '
                    'reader at the gate. The server decides the outcome and '
                    'the app only shows the status it is given.',
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          if (recent.isNotEmpty) ...[
            const SizedBox(height: PulseSpacing.xl),
            Text(
              'Recent activity',
              style: PulseType.heading.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: PulseSpacing.md),
            for (final day in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                child: PulseCard(
                  padding: const EdgeInsets.all(PulseSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateLabel(day.date),
                          style: PulseType.body.copyWith(color: t.textPrimary),
                        ),
                      ),
                      StatusPill(
                        label: _label(day.status),
                        tone: _tone(day.status),
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

  static String _label(String status) => switch (status) {
        'complete' => 'Recorded',
        'pending' => 'Pending',
        'incomplete' => 'Not recorded',
        'unavailable' => 'Unavailable',
        _ => 'Unknown',
      };

  static StatusTone _tone(String status) => switch (status) {
        'complete' => StatusTone.success,
        'pending' => StatusTone.warning,
        'incomplete' => StatusTone.danger,
        'unavailable' => StatusTone.neutral,
        _ => StatusTone.neutral,
      };

  static String _headline(AttendanceDay day) => switch (day.status) {
        'complete' => 'Your attendance is recorded',
        'pending' => 'A session is still open',
        'incomplete' => 'No session was recorded',
        'unavailable' => 'The status could not be determined',
        _ => 'The status is unknown',
      };

  static String _detail(AttendanceDay day) {
    final timeIn = day.timeIn;
    final timeOut = day.timeOut;
    if (timeIn == null && timeOut == null) {
      return 'The server did not report a time for this day.';
    }
    final in_ = timeIn == null ? 'not in' : 'in at ${_time(timeIn)}';
    final out = timeOut == null ? 'not out' : 'out at ${_time(timeOut)}';
    return 'You were $in_ and $out.';
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime date) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// The error card shown when the attendance could not be loaded.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseCard(
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 28, color: t.error),
          const SizedBox(height: PulseSpacing.sm),
          Text(
            'Status unknown',
            style: PulseType.label.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: PulseSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: PulseSpacing.lg),
            PulseButton(
              label: 'Retry',
              onPressed: onRetry,
              variant: PulseButtonVariant.secondary,
              expanded: false,
            ),
          ],
        ],
      ),
    );
  }
}
