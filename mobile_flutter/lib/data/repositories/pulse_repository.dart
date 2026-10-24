import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../models/models.dart';

/// Reads Home, attendance and profile data.
///
/// Every method returns a [PulseData] so the UI can tell fresh data from
/// cached data from a genuine failure.
class PulseRepository {
  PulseRepository(this._api);

  final ApiClient _api;

  /// `GET /home` — profile + today + last 5 days + unread count.
  Future<HomeSnapshot> fetchHome() async {
    final json = await _api.getJson('/home');
    return HomeSnapshot.fromJson(json);
  }

  /// `GET /me` — profile, preferences and unread count.
  Future<
    ({PulseProfile profile, PulsePreferences preferences, int unreadCount})
  >
  fetchMe() async {
    final json = await _api.getJson('/me');
    final rawPrefs = json['preferences'];
    return (
      profile: PulseProfile.fromJson(json),
      preferences: rawPrefs is Map
          ? PulsePreferences.fromJson(Map<String, dynamic>.from(rawPrefs))
          : PulsePreferences.defaults,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// `GET /attendance/today`.
  Future<AttendanceDay> fetchToday() async {
    final json = await _api.getJson('/attendance/today');
    return AttendanceDay.fromJson(json);
  }

  /// `GET /attendance?month=YYYY-MM`.
  Future<AttendanceRange> fetchMonth(String month) async {
    final json = await _api.getJson('/attendance', query: {'month': month});
    return AttendanceRange.fromJson(json);
  }

  /// `GET /attendance/<YYYY-MM-DD>`.
  Future<AttendanceDay> fetchDay(DateTime date) async {
    final stamp =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final json = await _api.getJson('/attendance/$stamp');
    return AttendanceDay.fromJson(json);
  }

  /// `PATCH /me/preferences`.
  Future<PulsePreferences> updatePreferences(PulsePreferences prefs) async {
    final json = await _api.patchJson('/me/preferences', prefs.toPatchJson());
    final raw = json['preferences'];
    if (raw is Map) {
      return PulsePreferences.fromJson(Map<String, dynamic>.from(raw));
    }
    return prefs;
  }

  /// `GET /contacts` — school-approved contacts. Ships empty.
  Future<List<FacultyContact>> fetchContacts() async {
    final json = await _api.getJson('/contacts');
    final raw = json['items'];
    if (raw is! List) return const <FacultyContact>[];
    return raw
        .whereType<Map>()
        .map((e) => FacultyContact.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /excuses` — the student's excuse letters, newest first.
  Future<List<ExcuseLetter>> fetchExcuses() async {
    final json = await _api.getJson('/excuses');
    final raw = json['items'];
    if (raw is! List) return const <ExcuseLetter>[];
    return raw
        .whereType<Map>()
        .map((e) => ExcuseLetter.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /excuses`.
  Future<ExcuseLetter> submitExcuse(DateTime date, String reason) async {
    final stamp =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final json = await _api.postJson('/excuses', {
      'date': stamp,
      'reason': reason,
    });
    return ExcuseLetter.fromJson(json);
  }

  /// `GET /health` — used by the "test connection" action in Settings.
  Future<bool> ping() async {
    try {
      await _api.health();
      return true;
    } on ApiException {
      return false;
    }
  }
}
