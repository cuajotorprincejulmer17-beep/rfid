import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';
import '../../shared/widgets/pulse_sheet.dart';
import '../../shared/widgets/pulse_text_field.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_pill.dart';

/// Professor-assigned activities and private student reminders.
///
/// The two are intentionally separate: only the school can create an
/// activity, and completion in this screen never grants a reward by itself.
class TasksPage extends StatelessWidget {
  const TasksPage({
    super.key,
    required this.tasks,
    this.onAddTask,
    this.onToggleComplete,
  });

  final List<PulseTask> tasks;
  final Future<void> Function(PulseTask task)? onAddTask;
  final Future<void> Function(PulseTask task, bool completed)? onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final soon = DateTime.now().add(const Duration(days: 2));
    final activities = tasks
        .where((task) => task.source == TaskSource.professor)
        .toList();
    final reminders = tasks
        .where((task) => task.source == TaskSource.personal)
        .toList();

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PulseSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Activities',
                      style: PulseType.title.copyWith(color: t.textPrimary),
                    ),
                  ),
                  PulseButton(
                    label: 'Add reminder',
                    icon: Icons.add_rounded,
                    variant: PulseButtonVariant.secondary,
                    expanded: false,
                    onPressed: onAddTask == null
                        ? null
                        : () => _openAddSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                'Keep school activities and your own reminders distinct.',
                style: PulseType.body.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: PulseSpacing.lg),
              const _VerificationNote(),
              const SizedBox(height: PulseSpacing.xl),
              const SectionHeader(title: 'Professor activities'),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                'Created by your professor or school. PULSE is awarded only after the school verifies it.',
                style: PulseType.caption.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: PulseSpacing.md),
              if (activities.isEmpty)
                const _EmptyGroup(
                  icon: Icons.school_outlined,
                  title: 'No professor activities yet',
                  detail: 'New activities will appear here when they are assigned to you.',
                )
              else
                for (final task in activities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                    child: _TaskCard(
                      task: task,
                      soon: task.due.isBefore(soon),
                      onToggle: onToggleComplete == null
                          ? null
                          : () => onToggleComplete!(task, !task.completed),
                    ),
                  ),
              const SizedBox(height: PulseSpacing.xl),
              const SectionHeader(title: 'My reminders'),
              const SizedBox(height: PulseSpacing.xs),
              Text(
                'Private reminders you create for yourself. They never earn PULSE.',
                style: PulseType.caption.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: PulseSpacing.md),
              if (reminders.isEmpty)
                const _EmptyGroup(
                  icon: Icons.bookmark_add_outlined,
                  title: 'No reminders yet',
                  detail: 'Add one for anything you want to remember.',
                )
              else
                for (final task in reminders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.md),
                    child: _TaskCard(
                      task: task,
                      soon: task.due.isBefore(soon),
                      onToggle: onToggleComplete == null
                          ? null
                          : () => onToggleComplete!(task, !task.completed),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final created = await showPulseSheet<PulseTask>(
      context: context,
      builder: (context) => const AddTaskSheet(),
    );
    if (created != null && onAddTask != null) await onAddTask!(created);
  }
}

class _VerificationNote extends StatelessWidget {
  const _VerificationNote();

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return Container(
      padding: const EdgeInsets.all(PulseSpacing.md),
      decoration: BoxDecoration(
        color: t.success.withValues(alpha: t.isLight ? 0.11 : 0.16),
        borderRadius: BorderRadius.circular(PulseRadius.card),
        border: Border.all(color: t.success.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: t.success),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Text(
              'PULSE is verification-based: only an RFID record or a professor-approved activity can count. Completing a personal reminder cannot add points.',
              style: PulseType.caption.copyWith(color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseCard(
      child: Row(
        children: [
          Icon(icon, color: t.textSecondary),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PulseType.label.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  detail,
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.soon, this.onToggle});

  final PulseTask task;
  final bool soon;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final isActivity = task.source == TaskSource.professor;
    final (
      String priorityLabel,
      StatusTone priorityTone,
    ) = switch (task.priority) {
      'high' => ('High', StatusTone.danger),
      'medium' => ('Medium', StatusTone.warning),
      _ => ('Low', StatusTone.neutral),
    };

    return PulseCard(
      onTap: () => context.push(
        lookupDestination('task-detail')!.route.replaceFirst(':id', task.id),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            checked: task.completed,
            label: task.completed
                ? 'Mark as not done'
                : isActivity
                ? 'Mark activity as ready for review'
                : 'Mark reminder as done',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: task.completed ? t.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: task.completed ? t.primary : t.borderStrong,
                    width: 1.5,
                  ),
                ),
                child: task.completed
                    ? Icon(Icons.check_rounded, size: 18, color: t.onPrimary)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: PulseSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isActivity
                          ? Icons.school_outlined
                          : Icons.bookmark_outline,
                      size: 15,
                      color: isActivity ? t.success : t.textSecondary,
                    ),
                    const SizedBox(width: PulseSpacing.xs),
                    Expanded(
                      child: Text(
                        isActivity ? 'Professor activity' : 'Personal reminder',
                        style: PulseType.caption.copyWith(
                          color: isActivity ? t.success : t.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  task.title,
                  style: PulseType.body.copyWith(
                    color: task.completed ? t.textSecondary : t.textPrimary,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  '${task.course} · due ${_dueLabel(task.due)}',
                  style: PulseType.caption.copyWith(color: t.textSecondary),
                ),
                if (isActivity) ...[
                  const SizedBox(height: PulseSpacing.xs),
                  Text(
                    task.completed
                        ? 'Marked ready — PULSE waits for faculty approval.'
                        : 'PULSE can be awarded only after faculty approval.',
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: PulseSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(label: priorityLabel, tone: priorityTone),
              if (soon && !task.completed) ...[
                const SizedBox(height: PulseSpacing.sm),
                Icon(Icons.schedule_rounded, size: 16, color: t.warning),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _dueLabel(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(due.year, due.month, due.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    if (diff < 0) return 'overdue';
    return 'in $diff days';
  }
}

/// The sheet can only create a personal reminder. Professor activities arrive
/// from the school server and cannot be created from the student app.
class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _course = TextEditingController();
  String _priority = 'medium';
  String? _titleError;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _course.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final valid = _title.text.trim().isNotEmpty;
    return PulseSheet(
      title: 'Add reminder',
      subtitle: 'This is private to you and never earns PULSE.',
      primaryLabel: 'Add reminder',
      primaryEnabled: valid,
      busy: _busy,
      onPrimary: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseTextField(
            controller: _title,
            label: 'Reminder',
            hint: 'What do you want to remember?',
            errorText: _titleError,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: PulseSpacing.lg),
          PulseTextField(
            controller: _course,
            label: 'Course',
            hint: 'Optional',
          ),
          const SizedBox(height: PulseSpacing.lg),
          Text(
            'Priority',
            style: PulseType.label.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: PulseSpacing.sm),
          Wrap(
            spacing: PulseSpacing.sm,
            children: [
              for (final priority in const ['low', 'medium', 'high'])
                PulseChip(
                  label: priority[0].toUpperCase() + priority.substring(1),
                  selected: _priority == priority,
                  onSelected: () => setState(() => _priority = priority),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give the reminder a title.');
      return;
    }
    setState(() {
      _titleError = null;
      _busy = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pop(
      PulseTask(
        id: 'new',
        title: title,
        course: _course.text.trim().isEmpty ? 'General' : _course.text.trim(),
        due: DateTime.now().add(const Duration(days: 3)),
        priority: _priority,
        source: TaskSource.personal,
      ),
    );
  }
}
