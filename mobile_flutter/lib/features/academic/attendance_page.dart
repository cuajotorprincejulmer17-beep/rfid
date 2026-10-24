import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../data/models/models.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_page.dart';
import '../../shared/widgets/pulse_sheet.dart';
import '../../shared/widgets/pulse_text_field.dart';
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
    this.onRefresh,
    this.excuses = const <ExcuseLetter>[],
    this.onSubmitExcuse,
  });

  /// The day's attendance, as the server reported it.
  final AttendanceDay? today;

  /// The days before today, as the server reported them.
  final List<AttendanceDay> recent;

  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  /// Pull-to-refresh. Null disables it.
  final Future<void> Function()? onRefresh;

  /// The student's excuse letters, newest first.
  final List<ExcuseLetter> excuses;

  /// Sends an excuse letter. Null hides the action (no server).
  final Future<void> Function(DateTime date, String reason)? onSubmitExcuse;

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

    final page = PulsePage(
      title: 'Attendance',
      subtitle: 'Reported by the server',
      actions: [
        IconButton(
          icon: const Icon(Icons.history_outlined),
          tooltip: 'View history',
          onPressed: () =>
              context.push(lookupDestination('attendance-history')!.route),
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
                        label: day.dayStatus == 'late'
                            ? 'Late ${day.lateMinutes} min'
                            : _label(day.status),
                        tone: day.dayStatus == 'late'
                            ? StatusTone.warning
                            : _tone(day.status),
                      ),
                  ],
                ),
                const SizedBox(height: PulseSpacing.md),
                Text(
                  day == null ? 'No status yet' : _headline(day),
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

          if (onSubmitExcuse != null) ...[
            const SizedBox(height: PulseSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Excuse letters',
                    style: PulseType.heading.copyWith(color: t.textPrimary),
                  ),
                ),
                PulseButton(
                  label: 'Send one',
                  icon: Icons.edit_note_rounded,
                  variant: PulseButtonVariant.secondary,
                  expanded: false,
                  onPressed: () => showPulseSheet<void>(
                    context: context,
                    builder: (context) =>
                        ExcuseLetterSheet(onSubmit: onSubmitExcuse!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PulseSpacing.md),
            if (excuses.isEmpty)
              Text(
                'Absent for a good reason? Send an excuse letter and your '
                'adviser will review it.',
                style: PulseType.caption.copyWith(color: t.textSecondary),
              )
            else
              for (final letter in excuses.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                  child: PulseCard(
                    padding: const EdgeInsets.all(PulseSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dateLabel(letter.date),
                                style: PulseType.body.copyWith(
                                  color: t.textPrimary,
                                ),
                              ),
                              Text(
                                letter.reviewNote ?? letter.reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: PulseType.caption.copyWith(
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: switch (letter.status) {
                            'approved' => 'Approved',
                            'rejected' => 'Not approved',
                            _ => 'Pending',
                          },
                          tone: switch (letter.status) {
                            'approved' => StatusTone.success,
                            'rejected' => StatusTone.danger,
                            _ => StatusTone.warning,
                          },
                        ),
                      ],
                    ),
                  ),
                ),
          ],

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
    return onRefresh == null
        ? page
        : RefreshIndicator(onRefresh: onRefresh!, child: page);
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

/// The sheet that sends an excuse letter for one day.
class ExcuseLetterSheet extends StatefulWidget {
  const ExcuseLetterSheet({super.key, required this.onSubmit});

  final Future<void> Function(DateTime date, String reason) onSubmit;

  @override
  State<ExcuseLetterSheet> createState() => _ExcuseLetterSheetState();
}

class _ExcuseLetterSheetState extends State<ExcuseLetterSheet> {
  final TextEditingController _reason = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseSheet(
      title: 'Excuse letter',
      subtitle:
          'Your adviser reviews it. Approved letters mark the day excused.',
      primaryLabel: 'Send',
      primaryEnabled: _reason.text.trim().length >= 5,
      busy: _busy,
      onPrimary: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseButton(
            label: 'Day: ${AttendancePage._dateLabel(_date)}',
            icon: Icons.calendar_today_outlined,
            variant: PulseButtonVariant.secondary,
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: now.subtract(const Duration(days: 60)),
                lastDate: now.add(const Duration(days: 30)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _reason,
            label: 'Reason',
            hint: 'For example: fever, clinic slip given to the registrar',
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: PulseSpacing.sm),
            Text(_error!, style: PulseType.caption.copyWith(color: t.error)),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_date, _reason.text.trim());
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
