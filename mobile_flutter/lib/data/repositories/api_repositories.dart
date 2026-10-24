import '../../core/api/api_client.dart';
import '../../shared/models/demo_models.dart';
import '../../shared/repositories/repositories.dart';
import '../models/models.dart';

/// The feature repositories backed by the school server.
///
/// Each one implements the same interface as its sample-data twin, so the
/// screens do not know which one they are talking to. Field names follow
/// `project/api/student_school.py`.

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> _items(Map<String, dynamic> json) {
  final raw = json['items'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String _str(Object? v) => v == null ? '' : '$v';

/// `GET /schedule`.
class ApiScheduleRepository implements ScheduleRepository {
  ApiScheduleRepository(this._api);

  final ApiClient _api;

  static ScheduleEvent _event(Map<String, dynamic> j) => ScheduleEvent(
    id: _str(j['id']),
    title: _str(j['title']),
    start: parseServerTime(j['start']) ?? DateTime.now(),
    end: parseServerTime(j['end']) ?? DateTime.now(),
    room: _str(j['room']),
    kind: j['kind'] == 'exam' ? 'exam' : 'class',
    note: [
      if (j['subject_code'] != null) j['subject_code'],
      if (j['teacher'] != null) j['teacher'],
      if (j['note'] != null) j['note'],
    ].join(' · '),
  );

  @override
  Future<List<ScheduleEvent>> eventsForDay(DateTime date) async {
    final json = await _api.getJson('/schedule', query: {'date': _ymd(date)});
    return _items(json).map(_event).toList();
  }

  @override
  Future<List<ScheduleEvent>> eventsBetween(DateTime from, DateTime to) async {
    final json = await _api.getJson(
      '/schedule',
      query: {'from': _ymd(from), 'to': _ymd(to)},
    );
    return _items(json).map(_event).toList();
  }
}

/// `GET/POST/PATCH /tasks`: the student's own tasks plus teacher assignments.
class ApiTaskRepository implements TaskRepository {
  ApiTaskRepository(this._api);

  final ApiClient _api;

  static PulseTask _task(Map<String, dynamic> j) => PulseTask(
    id: _str(j['id']),
    title: _str(j['title']),
    course: _str(j['course']).isEmpty
        ? (j['kind'] == 'assignment' ? 'Assignment' : 'Personal')
        : _str(j['course']),
    due: parseServerTime(j['due']) ?? DateTime.now(),
    priority: _str(j['priority']).isEmpty ? 'medium' : _str(j['priority']),
    completed: j['completed'] == true,
  );

  @override
  Future<List<PulseTask>> all() async {
    final json = await _api.getJson('/tasks');
    return _items(json).map(_task).toList();
  }

  @override
  Future<PulseTask> add(PulseTask task) async {
    final json = await _api.postJson('/tasks', {
      'title': task.title,
      'course': task.course,
      'due': task.due.toIso8601String(),
      'priority': task.priority,
    });
    return _task(json);
  }

  @override
  Future<PulseTask> setCompleted(String id, {required bool completed}) async {
    final json = await _api.patchJson('/tasks/$id', {'completed': completed});
    return _task(json);
  }
}

/// `GET /rooms`.
class ApiRoomRepository implements RoomRepository {
  ApiRoomRepository(this._api);

  final ApiClient _api;

  static CampusRoom _room(Map<String, dynamic> j) => CampusRoom(
    id: _str(j['id']),
    name: _str(j['code']).isEmpty
        ? _str(j['name'])
        : '${j['code']} · ${j['name']}',
    building: _str(j['building']),
    floor: (j['floor'] as num?)?.toInt() ?? 0,
    capacity: (j['capacity'] as num?)?.toInt() ?? 0,
    services: (j['services'] is List)
        ? (j['services'] as List).map((e) => '$e').toList()
        : const <String>[],
  );

  @override
  Future<List<CampusRoom>> search(String query) async {
    final json = await _api.getJson(
      '/rooms',
      query: {if (query.isNotEmpty) 'q': query},
    );
    return _items(json).map(_room).toList();
  }

  @override
  Future<CampusRoom?> byId(String id) async {
    final json = await _api.getJson('/rooms/$id');
    return _room(json);
  }
}

/// `GET /directory`.
class ApiDirectoryRepository implements DirectoryRepository {
  ApiDirectoryRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<DirectoryEntry>> search(String query) async {
    final json = await _api.getJson(
      '/directory',
      query: {if (query.isNotEmpty) 'q': query},
    );
    return _items(json)
        .map(
          (j) => DirectoryEntry(
            id: _str(j['id']),
            name: _str(j['name']),
            role: _str(j['role']),
            department: _str(j['department']),
            email: j['email'] as String?,
            phone: j['phone'] as String?,
          ),
        )
        .toList();
  }
}

/// `GET/POST /lost-found`.
class ApiLostFoundRepository implements LostFoundRepository {
  ApiLostFoundRepository(this._api);

  final ApiClient _api;

  /// Items the student may act on: their own lost reports, and found items.
  final Map<String, Map<String, dynamic>> _raw = {};

  LostFoundItem _item(Map<String, dynamic> j) {
    _raw[_str(j['id'])] = j;
    final kind = j['kind'] == 'lost' ? 'Lost' : 'Found';
    return LostFoundItem(
      id: _str(j['id']),
      name: '$kind: ${_str(j['name'])}',
      category: _str(j['category']),
      location: _str(j['location']),
      reportedAt: parseServerTime(j['reported_at']) ?? DateTime.now(),
      claimed: j['claimed'] == true || j['status'] == 'claim_requested',
    );
  }

  @override
  Future<List<LostFoundItem>> all({String? category}) async {
    final json = await _api.getJson(
      '/lost-found',
      query: {'category': ?category},
    );
    return _items(json).map(_item).toList();
  }

  @override
  Future<LostFoundItem> report(LostFoundItem item) async {
    final json = await _api.postJson('/lost-found', {
      'kind': 'lost',
      'name': item.name,
      'category': item.category,
      'location': item.location,
    });
    return _item(json);
  }

  /// Claims a found item, or marks the student's own lost item recovered.
  @override
  Future<LostFoundItem> setClaimed(String id, {required bool claimed}) async {
    final raw = _raw[id];
    final mine = raw != null && raw['mine'] == true && raw['kind'] == 'lost';
    final json = await _api.postJson(
      mine ? '/lost-found/$id/resolve' : '/lost-found/$id/claim',
    );
    return _item(json);
  }
}

/// `GET /library`, `POST /library/<id>/reserve`.
class ApiLibraryRepository implements LibraryRepository {
  ApiLibraryRepository(this._api);

  final ApiClient _api;

  static LibraryItem _book(Map<String, dynamic> j) => LibraryItem(
    id: _str(j['id']),
    title: _str(j['title']),
    author: _str(j['author']),
    shelf: _str(j['shelf']),
    available: j['available'] == true,
    featured: j['featured'] == true,
  );

  @override
  Future<List<LibraryItem>> search(String query) async {
    final json = await _api.getJson(
      '/library',
      query: {if (query.isNotEmpty) 'q': query},
    );
    return _items(json).map(_book).toList();
  }

  @override
  Future<LibraryItem> reserve(String id) async {
    final json = await _api.postJson('/library/$id/reserve');
    return _book(json);
  }
}

/// `GET /map/places`. The server stores places on a 0–1000 grid; the app's
/// canvas is [canvasWidth] × [canvasHeight], so positions are scaled.
class ApiMapRepository implements MapRepository {
  ApiMapRepository(
    this._api, {
    this.canvasWidth = 380,
    this.canvasHeight = 220,
  });

  final ApiClient _api;
  final double canvasWidth;
  final double canvasHeight;

  MapPlace _place(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return MapPlace(
      id: _str(j['id']),
      name: _str(j['name']),
      x: n('x') * canvasWidth / 1000,
      y: n('y') * canvasHeight / 1000,
      width: n('width') * canvasWidth / 1000,
      height: n('height') * canvasHeight / 1000,
    );
  }

  @override
  Future<List<MapPlace>> places() async {
    final json = await _api.getJson('/map/places');
    return _items(json).map(_place).toList();
  }

  @override
  Future<MapPlace?> byId(String id) async {
    final json = await _api.getJson('/map/places/$id');
    return _place(json);
  }
}

/// `GET /faq`, `GET /support/assistance`, `GET/POST /support/tickets`.
class ApiSupportRepository implements SupportRepository {
  ApiSupportRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<FaqItem>> faq(String query) async {
    final json = await _api.getJson(
      '/faq',
      query: {if (query.isNotEmpty) 'q': query},
    );
    return _items(json)
        .map(
          (j) => FaqItem(
            id: _str(j['id']),
            question: _str(j['question']),
            answer: _str(j['answer']),
          ),
        )
        .toList();
  }

  @override
  Future<List<AssistancePath>> assistance() async {
    final json = await _api.getJson('/support/assistance');
    return _items(json)
        .map(
          (j) => AssistancePath(
            id: _str(j['id']),
            title: _str(j['title']),
            description: _str(j['description']),
            iconName: _str(j['icon']),
          ),
        )
        .toList();
  }

  @override
  Future<void> sendTicket({
    required String subject,
    required String body,
  }) async {
    await _api.postJson('/support/tickets', {'subject': subject, 'body': body});
  }

  @override
  Future<List<SupportTicket>> tickets() async {
    final json = await _api.getJson('/support/tickets');
    return _items(json).map(SupportTicket.fromJson).toList();
  }
}
