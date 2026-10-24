import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../core/auth/auth_controller.dart';
import '../data/models/models.dart';
import '../data/repositories/inbox_repository.dart';
import '../data/repositories/pulse_repository.dart';
import '../features/schedule/schedule_page.dart' show ScheduleRange;
import '../shared/models/demo_models.dart';
import '../shared/repositories/repository_providers.dart';
import 'session.dart';

/// The attendance and profile repository.
///
/// It exists only while a student is signed in to a real server. When it is
/// null the attendance and profile regions report that they are not
/// connected rather than showing made-up data.
final pulseRepositoryProvider = Provider<PulseRepository?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null || ref.watch(authStatusProvider) != AuthStatus.signedIn) {
    return null;
  }
  return PulseRepository(api);
});

/// The notification inbox repository, under the same rule.
final inboxRepositoryProvider = Provider<InboxRepository?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null || ref.watch(authStatusProvider) != AuthStatus.signedIn) {
    return null;
  }
  return InboxRepository(api);
});

/// Today's attendance, as the server reported it.
final todayAttendanceProvider = FutureProvider<AttendanceDay?>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return null;
  return repository.fetchToday();
});

/// The attendance of the last few days, today included.
final recentAttendanceProvider =
    FutureProvider<List<AttendanceDay>>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return const <AttendanceDay>[];
  final snapshot = await repository.fetchHome();
  return snapshot.recent;
});

/// One month of attendance, keyed by `YYYY-MM`.
final monthAttendanceProvider =
    FutureProvider.family<AttendanceRange?, String>((ref, month) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return null;
  return repository.fetchMonth(month);
});

/// The student's profile, as the server reported it.
final profileProvider = FutureProvider<PulseProfile?>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return null;
  final me = await repository.fetchMe();
  return me.profile;
});

/// The newest inbox notifications.
final inboxProvider = FutureProvider<List<InboxItem>?>((ref) async {
  final repository = ref.watch(inboxRepositoryProvider);
  if (repository == null) return null;
  final page = await repository.fetch(limit: 50);
  return page.items;
});

/// The unread notification count, shown on the Updates dock tab.
final unreadCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(inboxRepositoryProvider);
  if (repository == null) return 0;
  final count = await repository.fetchUnreadCount();
  return count.total;
});

/// The school-approved contacts.
final contactsProvider = FutureProvider<List<FacultyContact>?>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return null;
  return repository.fetchContacts();
});

/// The student's excuse letters.
final excusesProvider = FutureProvider<List<ExcuseLetter>>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return const <ExcuseLetter>[];
  return repository.fetchExcuses();
});

/// The student's support messages and replies.
final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  return ref.watch(supportRepositoryProvider).tickets();
});

/// The events in a range starting today: the timetable when signed in.
final scheduleRangeProvider =
    FutureProvider.family<List<ScheduleEvent>, ScheduleRange>((ref, range) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = switch (range) {
    ScheduleRange.today => 0,
    ScheduleRange.week => 6,
    ScheduleRange.month => 30,
  };
  if (days == 0) return repository.eventsForDay(today);
  return repository.eventsBetween(today, today.add(Duration(days: days, hours: 23, minutes: 59)));
});

/// Today's classes (the school timetable when signed in).
final todayEventsProvider = FutureProvider<List<ScheduleEvent>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.eventsForDay(DateTime.now());
});

/// The tasks (the student's own and teacher assignments when signed in).
final tasksProvider = FutureProvider<List<PulseTask>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.all();
});

/// The sample updates.
final updatesProvider = FutureProvider<List<UpdateItem>>((ref) async {
  final repository = ref.watch(updatesRepositoryProvider);
  return repository.all();
});

/// Re-reads everything that comes from the server.
///
/// Pass `ref.invalidate` from a widget or a provider.
void refreshServerData(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(todayAttendanceProvider);
  invalidate(recentAttendanceProvider);
  invalidate(monthAttendanceProvider);
  invalidate(profileProvider);
  invalidate(inboxProvider);
  invalidate(unreadCountProvider);
  invalidate(contactsProvider);
  invalidate(excusesProvider);
  invalidate(ticketsProvider);
}
