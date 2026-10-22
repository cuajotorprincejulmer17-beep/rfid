import 'dart:async';

import '../../models/app_failure.dart';
import '../../models/demo_models.dart';
import '../repositories.dart';
import 'sample_data.dart';

/// How long a sample repository takes to answer, so a loading state is
/// visible.
const Duration kSampleLatency = Duration(milliseconds: 400);

/// The base of the sample repositories.
///
/// It holds the mutable copies of the sample data, applies the current
/// [DemoScenario], and simulates the network.
abstract class _SampleRepository {
  _SampleRepository(this.scenario);

  final DemoScenario scenario;

  /// Whether this repository is serving sample data rather than the real
  /// backend. The UI uses it to show the "Sample data" chip.
  bool get isSampleData => true;

  Future<void> _wait() => Future<void>.delayed(kSampleLatency);

  /// Applies the scenario. Returns null when the call should succeed.
  AppFailure? _failure() {
    switch (scenario) {
      case DemoScenario.normal:
      case DemoScenario.empty:
        return null;
      case DemoScenario.error:
        return const AppFailure(
          AppFailureKind.unknown,
          'The server did not answer, so this status is unknown.',
        );
      case DemoScenario.offline:
        return const AppFailure(
          AppFailureKind.offline,
          "You're offline, so this could not be loaded.",
        );
      case DemoScenario.unverified:
        return const AppFailure(
          AppFailureKind.unknown,
          'This feature needs a permission that has not been granted.',
        );
    }
  }
}

/// The sample schedule.
class SampleScheduleRepository extends _SampleRepository
    implements ScheduleRepository {
  SampleScheduleRepository(super.scenario);

  @override
  Future<List<ScheduleEvent>> eventsForDay(DateTime date) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    return sampleEvents
        .where(
          (e) =>
              e.start.year == date.year &&
              e.start.month == date.month &&
              e.start.day == date.day,
        )
        .toList();
  }

  @override
  Future<List<ScheduleEvent>> eventsBetween(DateTime from, DateTime to) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    return sampleEvents
        .where((e) => e.start.isBefore(to) && e.end.isAfter(from))
        .toList();
  }
}

/// The sample tasks.
class SampleTaskRepository extends _SampleRepository
    implements TaskRepository {
  SampleTaskRepository(super.scenario);

  final List<PulseTask> _tasks = List<PulseTask>.from(sampleTasks);
  int _nextId = 100;

  @override
  Future<List<PulseTask>> all() async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final sorted = List<PulseTask>.from(_tasks)
      ..sort((a, b) => a.due.compareTo(b.due));
    return sorted;
  }

  @override
  Future<PulseTask> add(PulseTask task) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final created = PulseTask(
      id: 'task-${_nextId++}',
      title: task.title,
      course: task.course,
      due: task.due,
      priority: task.priority,
    );
    _tasks.add(created);
    return created;
  }

  @override
  Future<PulseTask> setCompleted(String id, {required bool completed}) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw const AppFailure(
        AppFailureKind.notFound,
        'That task no longer exists.',
      );
    }
    final updated = _tasks[index].copyWith(completed: completed);
    _tasks[index] = updated;
    return updated;
  }
}

/// The sample updates.
class SampleUpdatesRepository extends _SampleRepository
    implements UpdatesRepository {
  SampleUpdatesRepository(super.scenario);

  final List<UpdateItem> _updates = List<UpdateItem>.from(sampleUpdates);

  @override
  Future<List<UpdateItem>> all() async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final sorted = List<UpdateItem>.from(_updates)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return sorted;
  }

  @override
  Future<UpdateItem> markRead(String id) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final index = _updates.indexWhere((u) => u.id == id);
    if (index < 0) {
      throw const AppFailure(
        AppFailureKind.notFound,
        'That update no longer exists.',
      );
    }
    final updated = _updates[index].copyWith(read: true);
    _updates[index] = updated;
    return updated;
  }

  @override
  Future<UpdateItem> setSaved(String id, {required bool saved}) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final index = _updates.indexWhere((u) => u.id == id);
    if (index < 0) {
      throw const AppFailure(
        AppFailureKind.notFound,
        'That update no longer exists.',
      );
    }
    final updated = _updates[index].copyWith(saved: saved);
    _updates[index] = updated;
    return updated;
  }
}

/// The sample rooms.
class SampleRoomRepository extends _SampleRepository
    implements RoomRepository {
  SampleRoomRepository(super.scenario);

  @override
  Future<List<CampusRoom>> search(String query) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<CampusRoom>.from(sampleRooms);
    return sampleRooms
        .where(
          (r) =>
              r.name.toLowerCase().contains(q) ||
              r.building.toLowerCase().contains(q) ||
              r.services.any((s) => s.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Future<CampusRoom?> byId(String id) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    for (final room in sampleRooms) {
      if (room.id == id) return room;
    }
    return null;
  }
}

/// The sample directory.
class SampleDirectoryRepository extends _SampleRepository
    implements DirectoryRepository {
  SampleDirectoryRepository(super.scenario);

  @override
  Future<List<DirectoryEntry>> search(String query) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<DirectoryEntry>.from(sampleDirectory);
    return sampleDirectory
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.role.toLowerCase().contains(q) ||
              e.department.toLowerCase().contains(q),
        )
        .toList();
  }
}

/// The sample lost and found items.
class SampleLostFoundRepository extends _SampleRepository
    implements LostFoundRepository {
  SampleLostFoundRepository(super.scenario);

  final List<LostFoundItem> _items = List<LostFoundItem>.from(sampleLostFound);
  int _nextId = 100;

  @override
  Future<List<LostFoundItem>> all({String? category}) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    if (category == null) return List<LostFoundItem>.from(_items);
    return _items.where((i) => i.category == category).toList();
  }

  @override
  Future<LostFoundItem> report(LostFoundItem item) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final created = LostFoundItem(
      id: 'lf-${_nextId++}',
      name: item.name,
      category: item.category,
      location: item.location,
      reportedAt: DateTime.now(),
      claimed: false,
    );
    _items.insert(0, created);
    return created;
  }

  @override
  Future<LostFoundItem> setClaimed(String id, {required bool claimed}) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) {
      throw const AppFailure(
        AppFailureKind.notFound,
        'That item no longer exists.',
      );
    }
    final updated = _items[index].copyWith(claimed: claimed);
    _items[index] = updated;
    return updated;
  }
}

/// The sample library.
class SampleLibraryRepository extends _SampleRepository
    implements LibraryRepository {
  SampleLibraryRepository(super.scenario);

  final List<LibraryItem> _items = List<LibraryItem>.from(sampleLibrary);

  @override
  Future<List<LibraryItem>> search(String query) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<LibraryItem>.from(_items);
    return _items
        .where(
          (i) =>
              i.title.toLowerCase().contains(q) ||
              i.author.toLowerCase().contains(q) ||
              i.shelf.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<LibraryItem> reserve(String id) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) {
      throw const AppFailure(
        AppFailureKind.notFound,
        'That item no longer exists.',
      );
    }
    final current = _items[index];
    final updated = LibraryItem(
      id: current.id,
      title: current.title,
      author: current.author,
      shelf: current.shelf,
      available: !current.available,
      featured: current.featured,
    );
    _items[index] = updated;
    return updated;
  }
}

/// The sample campus map.
class SampleMapRepository extends _SampleRepository
    implements MapRepository {
  SampleMapRepository(super.scenario);

  @override
  Future<List<MapPlace>> places() async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;
    return List<MapPlace>.from(sampleMapPlaces);
  }

  @override
  Future<MapPlace?> byId(String id) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    for (final place in sampleMapPlaces) {
      if (place.id == id) return place;
    }
    return null;
  }
}

/// The sample support content.
class SampleSupportRepository extends _SampleRepository
    implements SupportRepository {
  SampleSupportRepository(super.scenario);

  @override
  Future<List<FaqItem>> faq(String query) async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<FaqItem>.from(sampleFaq);
    return sampleFaq
        .where(
          (f) =>
              f.question.toLowerCase().contains(q) ||
              f.answer.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Future<List<AssistancePath>> assistance() async {
    await _wait();
    final failure = _failure();
    if (failure != null) throw failure;
    return List<AssistancePath>.from(sampleAssistance);
  }
}
