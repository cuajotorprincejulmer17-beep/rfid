import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/repositories/pulse_repository.dart';
import '../shared/models/demo_models.dart';
import '../shared/repositories/repository_providers.dart';

/// The API client and its repository.
///
/// The app is independently runnable, so the real backend is optional: when
/// no client is supplied the attendance and profile regions report that
/// they could not be loaded rather than showing made-up data.
final pulseRepositoryProvider = Provider<PulseRepository?>((ref) => null);

/// Today's attendance, as the server reported it.
final todayAttendanceProvider = FutureProvider<AttendanceDay?>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return null;
  return repository.fetchToday();
});

/// The attendance of the days before today.
final recentAttendanceProvider =
    FutureProvider<List<AttendanceDay>>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return const <AttendanceDay>[];
  final snapshot = await repository.fetchHome();
  return snapshot.recent;
});

/// The student's profile, as the server reported it.
final profileProvider = FutureProvider<PulseProfile?>((ref) async {
  final repository = ref.watch(pulseRepositoryProvider);
  if (repository == null) return null;
  final me = await repository.fetchMe();
  return me.profile;
});

/// The sample events for today.
final todayEventsProvider = FutureProvider<List<ScheduleEvent>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.eventsForDay(DateTime.now());
});

/// The sample tasks.
final tasksProvider = FutureProvider<List<PulseTask>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.all();
});

/// The sample updates.
final updatesProvider = FutureProvider<List<UpdateItem>>((ref) async {
  final repository = ref.watch(updatesRepositoryProvider);
  return repository.all();
});
