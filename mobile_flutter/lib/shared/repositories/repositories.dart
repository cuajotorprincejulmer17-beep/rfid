import '../../data/models/models.dart' show SupportTicket;
import '../models/demo_models.dart';

/// The state the sample repositories are in.
///
/// The scenario drives every sample repository, so the loading, empty,
/// error, offline and permission-denied states can be demonstrated and
/// tested without a server.
enum DemoScenario {
  /// Everything works.
  normal,

  /// The server confirms there is nothing to show.
  empty,

  /// The request fails.
  error,

  /// The device cannot reach the server.
  offline,

  /// The student did not grant the permission the feature needs.
  unverified;

  String get label => switch (this) {
    DemoScenario.normal => 'Normal',
    DemoScenario.empty => 'Empty',
    DemoScenario.error => 'Error',
    DemoScenario.offline => 'Offline',
    DemoScenario.unverified => 'Unverified',
  };

  String get description => switch (this) {
    DemoScenario.normal => 'Everything loads normally.',
    DemoScenario.empty => 'The server confirms there is nothing to show.',
    DemoScenario.error => 'Requests fail, so the status is unknown.',
    DemoScenario.offline => 'The device is offline.',
    DemoScenario.unverified => 'The permission the feature needs is missing.',
  };
}

/// Reads the schedule.
abstract interface class ScheduleRepository {
  /// The events of the day that contains [date].
  Future<List<ScheduleEvent>> eventsForDay(DateTime date);

  /// The events between [from] and [to].
  Future<List<ScheduleEvent>> eventsBetween(DateTime from, DateTime to);
}

/// Reads and writes the tasks.
abstract interface class TaskRepository {
  /// Every task, newest deadline first.
  Future<List<PulseTask>> all();

  /// Adds a task and returns it with its new id.
  Future<PulseTask> add(PulseTask task);

  /// Marks a task complete or reopens it.
  Future<PulseTask> setCompleted(String id, {required bool completed});
}

/// Reads and writes the updates.
abstract interface class UpdatesRepository {
  /// Every update, newest first.
  Future<List<UpdateItem>> all();

  /// Marks an update read.
  Future<UpdateItem> markRead(String id);

  /// Saves or unsaves an update.
  Future<UpdateItem> setSaved(String id, {required bool saved});
}

/// Reads the campus rooms.
abstract interface class RoomRepository {
  /// Every room, optionally filtered by a search term.
  Future<List<CampusRoom>> search(String query);

  /// One room by id.
  Future<CampusRoom?> byId(String id);
}

/// Reads the directory.
abstract interface class DirectoryRepository {
  /// Every entry, optionally filtered by a search term.
  Future<List<DirectoryEntry>> search(String query);
}

/// Reads and writes the lost and found items.
abstract interface class LostFoundRepository {
  /// Every item, optionally filtered by category.
  Future<List<LostFoundItem>> all({String? category});

  /// Reports a new item.
  Future<LostFoundItem> report(LostFoundItem item);

  /// Marks an item claimed.
  Future<LostFoundItem> setClaimed(String id, {required bool claimed});
}

/// Reads and writes the library.
abstract interface class LibraryRepository {
  /// Every item, optionally filtered by a search term.
  Future<List<LibraryItem>> search(String query);

  /// Reserves an item. Returns the updated item.
  Future<LibraryItem> reserve(String id);
}

/// Reads the campus map.
abstract interface class MapRepository {
  /// Every place on the map.
  Future<List<MapPlace>> places();

  /// One place by id.
  Future<MapPlace?> byId(String id);
}

/// Reads the FAQ.
abstract interface class SupportRepository {
  /// Every question, optionally filtered by a search term.
  Future<List<FaqItem>> faq(String query);

  /// Every support path.
  Future<List<AssistancePath>> assistance();

  /// Sends a message to the school office.
  Future<void> sendTicket({required String subject, required String body});

  /// The student's messages and the office's replies, newest first.
  Future<List<SupportTicket>> tickets();
}
