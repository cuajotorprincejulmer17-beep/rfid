import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/pulse_theme.dart';
import '../../core/theme/pulse_tokens.dart';
import '../../navigation/destination_registry.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/widgets/pulse_button.dart';
import '../../shared/widgets/pulse_card.dart';
import '../../shared/widgets/pulse_chip.dart';
import '../../shared/widgets/pulse_text_field.dart';
import '../../shared/widgets/pulse_sheet.dart';
import '../../shared/widgets/status_pill.dart';

/// The filter applied to the task list.
enum TaskFilter { all, dueSoon, completed }

/// The Tasks page.
///
/// The only control is the filter row and the "Add task" action, which
/// opens the sheet pattern. There is no floating action button.
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
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 2));

    final visible = tasks.where((task) {
      if (task.completed) return true;
      return true;
    }).toList();

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: PulseType.title.copyWith(color: t.textPrimary),
                    ),
                  ),
                  PulseButton(
                    label: 'Add task',
                    icon: Icons.add_rounded,
                    variant: PulseButtonVariant.secondary,
                    expanded: false,
                    onPressed: onAddTask == null
                        ? null
                        : () => _openAddSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: PulseSpacing.lg),

              if (visible.isEmpty)
                PulseCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.checklist_outlined,
                        size: 28,
                        color: t.textSecondary,
                      ),
                      const SizedBox(height: PulseSpacing.sm),
                      Text(
                        'No tasks yet',
                        style: PulseType.label.copyWith(color: t.textPrimary),
                      ),
                      const SizedBox(height: PulseSpacing.xs),
                      Text(
                        'Add a task to keep track of what is due.',
                        textAlign: TextAlign.center,
                        style: PulseType.caption.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                for (final task in visible)
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
    if (created != null && onAddTask != null) {
      await onAddTask!(created);
    }
  }
}

/// One task in the list.
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.soon,
    this.onToggle,
  });

  final PulseTask task;
  final bool soon;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;

    final (String label, StatusTone tone) = switch (task.priority) {
      'high' => ('High', StatusTone.danger),
      'medium' => ('Medium', StatusTone.warning),
      _ => ('Low', StatusTone.neutral),
    };

    return PulseCard(
      onTap: () => context.push(
        lookupDestination('task-detail')!.route.replaceFirst(':id', task.id),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            checked: task.completed,
            label: task.completed ? 'Mark as not done' : 'Mark as done',
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: PulseType.body.copyWith(
                    color: task.completed ? t.textSecondary : t.textPrimary,
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  '${task.course} - due ${_dueLabel(task.due)}',
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

/// The Add task sheet.
///
/// The primary action stays disabled until the title is filled in, and the
/// validation error is inline.
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
      title: 'Add task',
      subtitle: 'Tasks live on your device. They are your own content.',
      primaryLabel: 'Add task',
      primaryEnabled: valid,
      busy: _busy,
      onPrimary: _submit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PulseTextField(
            controller: _title,
            label: 'Title',
            hint: 'What needs doing?',
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
      setState(() => _titleError = 'Give the task a title.');
      return;
    }
    setState(() {
      _titleError = null;
      _busy = true;
    });

    // The sheet shows its own loading state while it saves.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    Navigator.of(context).pop(
      PulseTask(
        id: 'new',
        title: title,
        course: _course.text.trim().isEmpty
            ? 'General'
            : _course.text.trim(),
        due: DateTime.now().add(const Duration(days: 3)),
        priority: _priority,
      ),
    );
  }
}
