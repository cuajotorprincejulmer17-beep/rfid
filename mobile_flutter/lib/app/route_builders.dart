import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_exception.dart';
import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
import '../data/models/models.dart';
import '../features/academic/attendance_page.dart';
import '../features/campus/digital_id_page.dart';
import '../features/campus/directory_page.dart';
import '../features/campus/library_page.dart';
import '../features/campus/lost_found_page.dart';
import '../features/campus/map_page.dart';
import '../features/campus/room_finder_page.dart';
import '../features/category_hub_page.dart';
import '../features/home/home_page.dart';
import '../features/personal/personal_pages.dart';
import '../features/schedule/schedule_page.dart';
import '../features/support/support_pages.dart';
import '../features/tasks/tasks_page.dart';
import '../features/updates/updates_page.dart';
import '../shared/models/app_failure.dart';
import '../shared/models/demo_models.dart';
import '../shared/repositories/repository_providers.dart';
import '../shared/repositories/repositories.dart';
import '../shared/widgets/pulse_card.dart';
import '../shared/widgets/pulse_page.dart';
import '../shared/widgets/status_pill.dart';
import 'app_data.dart';

/// Builds every page in the app.
///
/// Each builder is registered against a registry id, so the router and the
/// registry can never drift apart.
Map<String, GoRouterWidgetBuilder> buildRouteBuilders() {
  return <String, GoRouterWidgetBuilder>{
    'home': (context, state) => const _HomeRoute(),
    'schedule': (context, state) => const _ScheduleRoute(),
    'tasks': (context, state) => const _TasksRoute(),
    'updates': (context, state) => const _UpdatesRoute(),

    'academic': (context, state) =>
        const CategoryHubPage(categoryId: 'academic'),
    'campus': (context, state) => const _HubRoute('campus'),
    'personal': (context, state) =>
        const CategoryHubPage(categoryId: 'personal'),
    'support': (context, state) => const _HubRoute('support'),

    'attendance': (context, state) => const _AttendanceRoute(),
    'insights': (context, state) => const _InsightsRoute(),
    'history': (context, state) => const _AcademicHistoryRoute(),
    'digital-id': (context, state) => const _DigitalIdRoute(),
    'rooms': (context, state) => const _RoomFinderRoute(),
    'directory': (context, state) => const _DirectoryRoute(),
    'lost-found': (context, state) => const _LostFoundRoute(),
    'library': (context, state) => const _LibraryRoute(),
    'map': (context, state) => const _MapRoute(),
    'profile': (context, state) => const _ProfileRoute(),
    'appearance': (context, state) => const AppearancePage(),
    'settings': (context, state) => const SettingsPage(),
    'assistance': (context, state) => const _AssistanceRoute(),
    'faq': (context, state) => const _FaqRoute(),
    'contact': (context, state) => const _ContactRoute(),

    // Detail routes.
    'schedule-event': (context, state) => const _DetailStub(
      title: 'Event',
      message: 'Event details are not built yet.',
    ),
    'task-detail': (context, state) => const _DetailStub(
      title: 'Task',
      message: 'Task details are not built yet.',
    ),
    'update-detail': (context, state) => const _DetailStub(
      title: 'Update',
      message: 'Update details are not built yet.',
    ),
    'attendance-history': (context, state) => const _AcademicHistoryRoute(),
    'room-detail': (context, state) => const _DetailStub(
      title: 'Room',
      message: 'Room details are not built yet.',
    ),
    'lost-found-new': (context, state) => const _LostFoundRoute(),
    'lost-found-detail': (context, state) => const _DetailStub(
      title: 'Lost Item',
      message: 'Item details are not built yet.',
    ),
    'library-item': (context, state) => const _DetailStub(
      title: 'Library Item',
      message: 'Item details are not built yet.',
    ),
    'map-place': (context, state) => const _MapRoute(),
    'faq-item': (context, state) => const _FaqRoute(),
  };
}

/// The Home page, wired to the repositories.
class _HomeRoute extends ConsumerWidget {
  const _HomeRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider);
    // The next class within a week, so the card is not empty on weekends.
    final events = ref.watch(scheduleRangeProvider(ScheduleRange.week));
    final tasks = ref.watch(tasksProvider);
    final profile = ref.watch(profileProvider).value;
    final inbox = ref.watch(inboxProvider).value;
    final updates = ref.watch(updatesProvider);

    final attendance = today.value;
    final tone = attendance == null
        ? null
        : switch (attendance.status) {
            'complete' => StatusTone.success,
            'pending' => StatusTone.warning,
            'incomplete' => StatusTone.danger,
            _ => StatusTone.neutral,
          };

    final now = DateTime.now();
    final nextEvent = (events.value ?? const <ScheduleEvent>[])
        .where((e) => e.end.isAfter(now))
        .firstOrNull;
    final taskList = tasks.value ?? const [];
    // Signed in: the real inbox. Without a server: the sample updates.
    final updateTitles = inbox != null
        ? inbox.take(3).map((n) => n.title).toList()
        : (updates.value ?? const []).take(3).map((u) => u.title).toList();
    final firstName = profile?.name.trim().split(RegExp(r'\s+')).first;

    return HomePage(
      greeting: (firstName == null || firstName.isEmpty)
          ? 'Welcome back'
          : 'Welcome back, $firstName',
      attendanceStatus: tone,
      attendanceLabel: attendance == null
          ? 'Attendance'
          : _attendanceHeadline(attendance),
      nextClassTitle: nextEvent?.title,
      nextClassDetail: nextEvent == null ? null : '${_when(nextEvent.start)} · ${nextEvent.room}',
      tasksDueToday: taskList
          .where((t) => !t.completed && DateUtils.isSameDay(t.due, now))
          .length,
      taskTitles: taskList
          .where((t) => !t.completed)
          .take(3)
          .map((t) => t.title)
          .toList(),
      updateTitles: updateTitles,
      showSampleDataChip: ref.watch(usingSampleDataProvider),
      onRefresh: () async {
        refreshServerData(ref.invalidate);
        ref.invalidate(scheduleRangeProvider);
        ref.invalidate(tasksProvider);
        await ref.read(todayAttendanceProvider.future);
      },
    );
  }

  /// The small line above "Your attendance" on the Home card.
  static String _attendanceHeadline(AttendanceDay day) {
    if (day.state == 'in' && day.timeIn != null) {
      return 'Timed in at ${formatClock(day.timeIn)}';
    }
    if (day.state == 'out' && day.timeOut != null) {
      return 'Timed out at ${formatClock(day.timeOut)}';
    }
    if (day.state == 'not_in') return 'Not timed in yet today';
    return 'Attendance';
  }
}

/// The Schedule page, wired to the repository.
class _ScheduleRoute extends ConsumerStatefulWidget {
  const _ScheduleRoute();

  @override
  ConsumerState<_ScheduleRoute> createState() => _ScheduleRouteState();
}

class _ScheduleRouteState extends ConsumerState<_ScheduleRoute> {
  ScheduleRange _range = ScheduleRange.today;

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(scheduleRangeProvider(_range));
    return SchedulePage(
      events: events.value ?? const [],
      loading: events.isLoading && !events.hasValue,
      onRangeChanged: (range) => setState(() => _range = range),
    );
  }
}

/// The Tasks page, wired to the repository.
class _TasksRoute extends ConsumerWidget {
  const _TasksRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final repository = ref.watch(taskRepositoryProvider);
    return TasksPage(
      tasks: tasks.value ?? const [],
      onAddTask: (task) async {
        await _guarded(context, () => repository.add(task));
        ref.invalidate(tasksProvider);
      },
      onToggleComplete: (task, completed) async {
        await _guarded(
          context,
          () => repository.setCompleted(task.id, completed: completed),
        );
        ref.invalidate(tasksProvider);
      },
    );
  }
}

/// The Updates page: the school inbox when signed in, sample data otherwise.
class _UpdatesRoute extends ConsumerWidget {
  const _UpdatesRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(inboxRepositoryProvider);
    if (repository == null) {
      final updates = ref.watch(updatesProvider);
      return UpdatesPage(updates: updates.value ?? const []);
    }

    final inbox = ref.watch(inboxProvider);
    Future<void> reload() async {
      ref.invalidate(inboxProvider);
      ref.invalidate(unreadCountProvider);
      await ref.read(inboxProvider.future);
    }

    return UpdatesPage(
      updates: (inbox.value ?? const []).map(_toUpdate).toList(),
      categories: kInboxCategories,
      loading: inbox.isLoading && !inbox.hasValue,
      error: inbox.hasError && !inbox.hasValue
          ? "Couldn't load your notifications from the school server."
          : null,
      onRefresh: reload,
      onOpen: (update) async {
        if (update.read) return;
        await repository.markRead(int.parse(update.id));
        await reload();
      },
      onMarkAllRead: () async {
        await repository.markAllRead();
        await reload();
      },
    );
  }

  static UpdateItem _toUpdate(InboxItem item) => UpdateItem(
    id: '${item.id}',
    title: item.title,
    body: item.body,
    category: item.category,
    publishedAt: item.createdAt,
    read: item.isRead,
  );
}

/// The Attendance page, wired to the real server.
class _AttendanceRoute extends ConsumerWidget {
  const _AttendanceRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider);
    final recent = ref.watch(recentAttendanceProvider);

    if (ref.watch(pulseRepositoryProvider) == null) {
      return const AttendancePage(
        today: null,
        error:
            'Not connected to the school server. Sign in to see the '
            'attendance recorded by the RFID reader.',
      );
    }

    if (today.isLoading && !today.hasValue) {
      return const PulsePage(
        title: 'Attendance',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (today.hasError) {
      return AttendancePage(
        today: null,
        error:
            'The server did not answer, so your attendance status is '
            'unknown. It is not the same as being absent.',
        onRetry: () => ref.invalidate(todayAttendanceProvider),
      );
    }

    final excuses = ref.watch(excusesProvider);
    final repository = ref.watch(pulseRepositoryProvider)!;
    return AttendancePage(
      excuses: excuses.value ?? const [],
      onSubmitExcuse: (date, reason) async {
        await repository.submitExcuse(date, reason);
        ref.invalidate(excusesProvider);
      },
      today: today.value,
      // Today has its own card, so the list shows the days before it.
      recent: (recent.value ?? const [])
          .where((day) => !DateUtils.isSameDay(day.date, today.value?.date))
          .toList(),
      onRefresh: () async {
        ref.invalidate(todayAttendanceProvider);
        ref.invalidate(recentAttendanceProvider);
        await ref.read(todayAttendanceProvider.future);
      },
    );
  }
}

/// Workload and Insights.
class _InsightsRoute extends ConsumerWidget {
  const _InsightsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.pulse;
    final tasks = ref.watch(tasksProvider).value ?? const [];
    final today = ref.watch(todayAttendanceProvider).value;
    final recent = ref.watch(recentAttendanceProvider).value ?? const [];

    final open = tasks.where((task) => !task.completed).toList();
    final highPriority = open.where((task) => task.priority == 'high').length;
    final recorded = recent.where((d) => d.status == 'complete').length;

    return PulsePage(
      title: 'Workload and Insights',
      subtitle: 'Counts from your own data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Metric(
            label: 'Open tasks',
            value: '${open.length}',
            detail: 'Your tasks and teacher assignments',
          ),
          const SizedBox(height: PulseSpacing.md),
          _Metric(
            label: 'High priority',
            value: '$highPriority',
            detail: 'Of your open tasks',
          ),
          const SizedBox(height: PulseSpacing.md),
          _Metric(
            label: 'Days recorded',
            value: '$recorded',
            detail: 'From the school attendance server',
          ),
          if (today != null) ...[
            const SizedBox(height: PulseSpacing.md),
            _Metric(
              label: 'Today',
              value: today.status,
              detail: 'As reported by the server',
            ),
          ],
          const SizedBox(height: PulseSpacing.lg),
          Text(
            'Nothing here is an official school statistic. Attendance counts '
            'come from the school server; see Attendance History for your '
            'present, late and absent days.',
            style: PulseType.caption.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// One metric on the Insights page.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulseCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: PulseType.label.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: PulseSpacing.xs),
                Text(
                  value,
                  style: PulseType.title.copyWith(color: t.textPrimary),
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

/// The attendance history: this month, from the server.
class _AcademicHistoryRoute extends ConsumerWidget {
  const _AcademicHistoryRoute();

  static const List<String> _monthNames = <String>[
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.pulse;
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final range = ref.watch(monthAttendanceProvider(month));

    if (range.isLoading && !range.hasValue) {
      return const PulsePage(
        title: 'Attendance History',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final data = range.value;
    final timesByDate = {
      for (final d in data?.days ?? const <AttendanceDay>[])
        '${d.date.year}-${d.date.month}-${d.date.day}': d,
    };
    // School days only, newest first. Older servers send no calendar: fall
    // back to the days that have taps.
    final calendar = (data?.calendar ?? const <CalendarDay>[])
        .where((d) => !const {'no_school', 'upcoming'}.contains(d.dayStatus))
        .toList()
        .reversed
        .toList();
    final String? message = range.hasError
        ? "Couldn't load your history from the school server."
        : data == null
        ? 'Not connected to the school server.'
        : calendar.isEmpty && data.days.isEmpty
        ? 'No attendance recorded this month yet.'
        : null;
    final summary = data?.summary;

    return PulsePage(
      title: 'Attendance History',
      subtitle:
          '${_monthNames[now.month - 1]} ${now.year}, '
          'from the school server',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary != null && message == null) ...[
            Wrap(
              spacing: PulseSpacing.sm,
              runSpacing: PulseSpacing.sm,
              children: [
                if (summary.rate != null)
                  StatusPill(
                    label: '${summary.rate!.toStringAsFixed(0)}% attendance',
                    tone: StatusTone.neutral,
                  ),
                StatusPill(
                  label: '${summary.present} present',
                  tone: StatusTone.success,
                ),
                if (summary.late > 0)
                  StatusPill(
                    label: '${summary.late} late',
                    tone: StatusTone.warning,
                  ),
                if (summary.absent > 0)
                  StatusPill(
                    label: '${summary.absent} absent',
                    tone: StatusTone.danger,
                  ),
                if (summary.excused > 0)
                  StatusPill(
                    label: '${summary.excused} excused',
                    tone: StatusTone.neutral,
                  ),
              ],
            ),
            const SizedBox(height: PulseSpacing.lg),
          ],
          if (message != null)
            Text(
              message,
              style: PulseType.body.copyWith(color: t.textSecondary),
            )
          else
            for (final day in calendar)
              Padding(
                padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                child: _HistoryRow(
                  day: day,
                  times:
                      timesByDate['${day.date.year}-${day.date.month}-${day.date.day}'],
                ),
              ),
        ],
      ),
    );
  }
}

/// One school day in the attendance history.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.day, this.times});

  final CalendarDay day;
  final AttendanceDay? times;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    final (label, tone) = switch (day.dayStatus) {
      'present' => ('Present', StatusTone.success),
      'late' => ('Late ${day.lateMinutes} min', StatusTone.warning),
      'absent' => ('Absent', StatusTone.danger),
      'excused' => ('Excused', StatusTone.neutral),
      'not_yet' => ('Not yet', StatusTone.neutral),
      'holiday' => ('Holiday', StatusTone.neutral),
      'no_class' => ('No class', StatusTone.neutral),
      _ => (day.dayStatus, StatusTone.neutral),
    };
    final missingOut =
        times != null &&
        times!.timeOut == null &&
        day.date.day != DateTime.now().day;
    return PulseCard(
      padding: const EdgeInsets.all(PulseSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatLongDate(day.date),
                  style: PulseType.body.copyWith(color: t.textPrimary),
                ),
                if (times != null) ...[
                  const SizedBox(height: PulseSpacing.xs),
                  Text(
                    'In ${formatClock(times!.timeIn)}  ·  Out ${formatClock(times!.timeOut)}'
                    '${missingOut ? '  ·  no time out' : ''}',
                    style: PulseType.caption.copyWith(color: t.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          StatusPill(label: label, tone: tone),
        ],
      ),
    );
  }
}

/// The Digital ID page.
class _DigitalIdRoute extends ConsumerWidget {
  const _DigitalIdRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final scenario = ref.watch(demoScenarioProvider);

    if (profile != null) {
      return DigitalIdPage(
        name: profile.name,
        studentNumber: profile.studentNumber ?? 'Not assigned',
        subtitle: 'From the school server',
        programLabel: 'Course and section',
        program: profile.courseSection ?? 'Not provided',
        sectionLabel: 'RFID card',
        section: profile.rfidRegistered ? 'Registered' : 'Not registered',
      );
    }

    return DigitalIdPage(
      name: 'Demo Student',
      studentNumber: 'DEMO-0000',
      permissionDenied: scenario == DemoScenario.unverified,
    );
  }
}

/// The Room Finder page.
class _RoomFinderRoute extends ConsumerStatefulWidget {
  const _RoomFinderRoute();

  @override
  ConsumerState<_RoomFinderRoute> createState() => _RoomFinderRouteState();
}

class _RoomFinderRouteState extends ConsumerState<_RoomFinderRoute> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomRepositoryProvider).search(_query);
    return FutureBuilder<List<CampusRoom>>(
      future: rooms,
      builder: (context, snapshot) => RoomFinderPage(
        rooms: snapshot.data ?? const [],
        query: _query,
        onQueryChanged: (value) => setState(() => _query = value),
      ),
    );
  }
}

/// The Directory page.
class _DirectoryRoute extends ConsumerStatefulWidget {
  const _DirectoryRoute();

  @override
  ConsumerState<_DirectoryRoute> createState() => _DirectoryRouteState();
}

class _DirectoryRouteState extends ConsumerState<_DirectoryRoute> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(directoryRepositoryProvider).search(_query);
    return FutureBuilder<List<DirectoryEntry>>(
      future: entries,
      builder: (context, snapshot) => DirectoryPage(
        entries: snapshot.data ?? const [],
        query: _query,
        onQueryChanged: (value) => setState(() => _query = value),
      ),
    );
  }
}

/// The Lost and Found page.
class _LostFoundRoute extends ConsumerStatefulWidget {
  const _LostFoundRoute();

  @override
  ConsumerState<_LostFoundRoute> createState() => _LostFoundRouteState();
}

class _LostFoundRouteState extends ConsumerState<_LostFoundRoute> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(lostFoundRepositoryProvider);
    return FutureBuilder<List<LostFoundItem>>(
      key: ValueKey(_version),
      future: repository.all(),
      builder: (context, snapshot) => LostFoundPage(
        items: snapshot.data ?? const [],
        onReport: (item) async {
          await _guarded(context, () => repository.report(item));
          if (mounted) setState(() => _version++);
        },
      ),
    );
  }
}

/// The Library page.
class _LibraryRoute extends ConsumerStatefulWidget {
  const _LibraryRoute();

  @override
  ConsumerState<_LibraryRoute> createState() => _LibraryRouteState();
}

class _LibraryRouteState extends ConsumerState<_LibraryRoute> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(libraryRepositoryProvider).search(_query);
    return FutureBuilder<List<LibraryItem>>(
      future: items,
      builder: (context, snapshot) => LibraryPage(
        items: snapshot.data ?? const [],
        query: _query,
        onQueryChanged: (value) => setState(() => _query = value),
      ),
    );
  }
}

/// The Map page.
class _MapRoute extends ConsumerWidget {
  const _MapRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(mapRepositoryProvider).places();
    return FutureBuilder<List<MapPlace>>(
      future: places,
      builder: (context, snapshot) =>
          MapPage(places: snapshot.data ?? const []),
    );
  }
}

/// The Profile page.
class _ProfileRoute extends ConsumerWidget {
  const _ProfileRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final me = profile.value;
    if (me == null) {
      return PulsePage(
        title: 'Profile',
        child: profile.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Text(
                profile.hasError
                    ? "Couldn't load your profile from the school server."
                    : 'Not connected to the school server.',
                style: PulseType.body.copyWith(
                  color: context.pulse.textSecondary,
                ),
              ),
      );
    }
    return ProfilePage(
      name: me.name,
      studentNumber: me.studentNumber ?? 'Not assigned',
      courseSection: me.courseSection,
      phone: me.phone,
      rfidRegistered: me.rfidRegistered,
    );
  }
}

/// The Assistance page.
class _AssistanceRoute extends ConsumerWidget {
  const _AssistanceRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(supportRepositoryProvider).assistance();
    return FutureBuilder<List<AssistancePath>>(
      future: paths,
      builder: (context, snapshot) =>
          AssistancePage(paths: snapshot.data ?? const []),
    );
  }
}

/// The FAQ page.
class _FaqRoute extends ConsumerWidget {
  const _FaqRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faq = ref.watch(supportRepositoryProvider).faq('');
    return FutureBuilder<List<FaqItem>>(
      future: faq,
      builder: (context, snapshot) => FaqPage(items: snapshot.data ?? const []),
    );
  }
}

/// Contact Support, with the school-approved contacts from the server.
class _ContactRoute extends ConsumerWidget {
  const _ContactRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactsProvider);
    final tickets = ref.watch(ticketsProvider);
    final live = !ref.watch(usingSampleDataProvider);
    final repository = ref.watch(supportRepositoryProvider);
    return ContactSupportPage(
      contacts: contacts.value,
      contactsLoading: contacts.isLoading && !contacts.hasValue,
      tickets: live ? tickets.value : null,
      onSend: live
          ? (subject, body) async {
              await repository.sendTicket(subject: subject, body: body);
              ref.invalidate(ticketsProvider);
            }
          : null,
    );
  }
}

/// A detail page that has not been built yet.
class _DetailStub extends StatelessWidget {
  const _DetailStub({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = context.pulse;
    return PulsePage(
      title: title,
      child: PulseCard(
        child: Column(
          children: [
            Icon(Icons.construction_outlined, size: 28, color: t.textSecondary),
            const SizedBox(height: PulseSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PulseType.body.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A category hub; the "Sample data" chip shows only when the features
/// under it really are sample data.
class _HubRoute extends ConsumerWidget {
  const _HubRoute(this.categoryId);

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CategoryHubPage(
      categoryId: categoryId,
      sampleData: ref.watch(usingSampleDataProvider),
    );
  }
}

/// Runs a write and shows the server's message when it fails.
Future<void> _guarded(
  BuildContext context,
  Future<Object?> Function() action,
) async {
  try {
    await action();
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  } on AppFailure catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// `Today 08:00`, `Mon 08:00` or `Oct 31 08:00` for the next-class card.
String _when(DateTime start) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  final hhmm = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today $hhmm';
  if (diff == 1) return 'Tomorrow $hhmm';
  if (diff < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[start.weekday - 1]} $hhmm';
  }
  return '${formatShortDate(start)} $hhmm';
}
