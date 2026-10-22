import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
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
    'campus': (context, state) =>
        const CategoryHubPage(categoryId: 'campus', sampleData: true),
    'personal': (context, state) => const CategoryHubPage(categoryId: 'personal'),
    'support': (context, state) =>
        const CategoryHubPage(categoryId: 'support', sampleData: true),

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
    'contact': (context, state) => const ContactSupportPage(),

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
    final events = ref.watch(todayEventsProvider);
    final tasks = ref.watch(tasksProvider);
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

    final nextEvent = events.value?.firstOrNull;
    final taskList = tasks.value ?? const [];
    final updateList = updates.value ?? const [];

    return HomePage(
      greeting: 'Welcome back',
      attendanceStatus: tone,
      nextClassTitle: nextEvent?.title,
      nextClassDetail: nextEvent?.room,
      tasksDueToday:
          taskList.where((t) => !t.completed).length,
      taskTitles: taskList
          .where((t) => !t.completed)
          .take(3)
          .map((t) => t.title)
          .toList(),
      updateTitles: updateList.take(3).map((u) => u.title).toList(),
    );
  }
}

/// The Schedule page, wired to the repository.
class _ScheduleRoute extends ConsumerWidget {
  const _ScheduleRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(todayEventsProvider);
    return SchedulePage(events: events.value ?? const []);
  }
}

/// The Tasks page, wired to the repository.
class _TasksRoute extends ConsumerWidget {
  const _TasksRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    return TasksPage(tasks: tasks.value ?? const []);
  }
}

/// The Updates page, wired to the repository.
class _UpdatesRoute extends ConsumerWidget {
  const _UpdatesRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(updatesProvider);
    return UpdatesPage(updates: updates.value ?? const []);
  }
}

/// The Attendance page, wired to the real server.
class _AttendanceRoute extends ConsumerWidget {
  const _AttendanceRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayAttendanceProvider);
    final recent = ref.watch(recentAttendanceProvider);

    if (today.isLoading) {
      return const PulsePage(
        title: 'Attendance',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (today.hasError) {
      return AttendancePage(
        today: null,
        error: 'The server did not answer, so your attendance status is '
            'unknown. It is not the same as being absent.',
        onRetry: () => ref.invalidate(todayAttendanceProvider),
      );
    }

    return AttendancePage(
      today: today.value,
      recent: recent.value ?? const [],
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
            detail: 'On your device, your own content',
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
            'Nothing here is an official school statistic. The task counts '
            'come from your device; the attendance counts come from the '
            'server.',
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

/// The Academic History page.
class _AcademicHistoryRoute extends ConsumerWidget {
  const _AcademicHistoryRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.pulse;
    final recent = ref.watch(recentAttendanceProvider);

    if (recent.isLoading) {
      return const PulsePage(
        title: 'Academic History',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final days = recent.value ?? const [];

    return PulsePage(
      title: 'Academic History',
      subtitle: 'From the school attendance server',
      child: days.isEmpty
          ? Text(
              'No history to show yet.',
              style: PulseType.body.copyWith(color: t.textSecondary),
            )
          : Column(
              children: [
                for (final day in days)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpacing.sm),
                    child: PulseCard(
                      padding: const EdgeInsets.all(PulseSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${day.date.year}-'
                              '${day.date.month.toString().padLeft(2, '0')}-'
                              '${day.date.day.toString().padLeft(2, '0')}',
                              style: PulseType.body.copyWith(color: t.textPrimary),
                            ),
                          ),
                          StatusPill(
                            label: day.status,
                            tone: switch (day.status) {
                              'complete' => StatusTone.success,
                              'pending' => StatusTone.warning,
                              'incomplete' => StatusTone.danger,
                              _ => StatusTone.neutral,
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
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

    return DigitalIdPage(
      name: profile?.name ?? 'Demo Student',
      studentNumber: profile?.studentNumber ?? 'DEMO-0000',
      program: profile?.courseSection ?? 'Sample programme',
      section: profile?.courseSection ?? 'Sample section',
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
class _LostFoundRoute extends ConsumerWidget {
  const _LostFoundRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(lostFoundRepositoryProvider).all();
    return FutureBuilder<List<LostFoundItem>>(
      future: items,
      builder: (context, snapshot) => LostFoundPage(
        items: snapshot.data ?? const [],
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
      builder: (context, snapshot) => MapPage(places: snapshot.data ?? const []),
    );
  }
}

/// The Profile page.
class _ProfileRoute extends ConsumerWidget {
  const _ProfileRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    return ProfilePage(
      name: profile?.name ?? 'Demo Student',
      studentNumber: profile?.studentNumber ?? 'DEMO-0000',
      courseSection: profile?.courseSection,
      phone: profile?.phone,
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
