import 'dart:convert';

/// Models mirroring the verified `/api/v1` payloads.
///
/// Field names match the backend exactly (`project/api/student.py`,
/// `project/api/inbox.py`). Nothing here is invented.

/// Profile from `/me` and `/home`.
class PulseProfile {
  const PulseProfile({
    required this.name,
    required this.studentNumber,
    required this.courseSection,
    required this.phone,
    required this.rfidRegistered,
    required this.rfidStatus,
  });

  final String name;
  final String? studentNumber;
  final String? courseSection;
  final String? phone;
  final bool rfidRegistered;
  final String rfidStatus;

  factory PulseProfile.fromJson(Map<String, dynamic> json) {
    final rfid = json['rfid'];
    final rfidMap = rfid is Map ? Map<String, dynamic>.from(rfid) : const <String, dynamic>{};
    return PulseProfile(
      name: (json['name'] as String?) ?? '',
      studentNumber: json['student_number'] as String?,
      courseSection: json['course_section'] as String?,
      phone: json['phone'] as String?,
      rfidRegistered: rfidMap['registered'] == true,
      rfidStatus: (rfidMap['status'] as String?) ?? 'unknown',
    );
  }
}

/// Notification preferences. `emergency_alerts` is always true (the backend
/// forces it and the app must not offer a switch for it).
class PulsePreferences {
  const PulsePreferences({
    required this.attendanceAlerts,
    required this.announcements,
    required this.sound,
    required this.haptics,
    required this.emergencyAlerts,
  });

  final bool attendanceAlerts;
  final bool announcements;
  final bool sound;
  final bool haptics;
  final bool emergencyAlerts;

  static const PulsePreferences defaults = PulsePreferences(
    attendanceAlerts: true,
    announcements: true,
    sound: true,
    haptics: true,
    emergencyAlerts: true,
  );

  factory PulsePreferences.fromJson(Map<String, dynamic> json) => PulsePreferences(
        attendanceAlerts: json['attendance_alerts'] == true,
        announcements: json['announcements'] == true,
        sound: json['sound'] == true,
        haptics: json['haptics'] == true,
        emergencyAlerts: json['emergency_alerts'] != false,
      );

  Map<String, dynamic> toPatchJson() => {
        'attendance_alerts': attendanceAlerts,
        'announcements': announcements,
        'sound': sound,
        'haptics': haptics,
      };
}

/// One scan session inside a day.
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.timeIn,
    required this.timeOut,
    required this.status,
  });

  final int id;
  final DateTime? timeIn;
  final DateTime? timeOut;

  /// `complete` | `pending` | `incomplete`
  final String status;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      AttendanceSession(
        id: (json['id'] as num).toInt(),
        timeIn: parseServerTime(json['time_in']),
        timeOut: parseServerTime(json['time_out']),
        status: (json['status'] as String?) ?? 'incomplete',
      );
}

/// One day's attendance.
class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.status,
    required this.timeIn,
    required this.timeOut,
    required this.sessions,
    this.state,
    this.expectedScan,
  });

  final DateTime date;

  /// `complete` | `pending` | `incomplete` | `unavailable`
  final String status;

  final DateTime? timeIn;
  final DateTime? timeOut;
  final List<AttendanceSession> sessions;

  /// `not_in` | `in` | `out` — only on the "today" payload.
  final String? state;

  /// `time_in` | `time_out` | null — only on the "today" payload.
  final String? expectedScan;

  bool get hasRecord => status != 'unavailable';

  factory AttendanceDay.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'];
    final sessions = rawSessions is List
        ? rawSessions
            .whereType<Map>()
            .map((e) => AttendanceSession.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AttendanceSession>[];
    return AttendanceDay(
      date: parseServerTime(json['date']) ?? DateTime.now(),
      status: (json['status'] as String?) ?? 'unavailable',
      timeIn: parseServerTime(json['time_in']),
      timeOut: parseServerTime(json['time_out']),
      sessions: sessions,
      state: json['state'] as String?,
      expectedScan: json['expected_scan'] as String?,
    );
  }
}

/// Counts for a period, from `GET /attendance`.
class AttendanceSummary {
  const AttendanceSummary({
    required this.complete,
    required this.incomplete,
    required this.pending,
  });

  final int complete;
  final int incomplete;
  final int pending;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) => AttendanceSummary(
        complete: (json['complete'] as num?)?.toInt() ?? 0,
        incomplete: (json['incomplete'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
      );
}

/// A month (or range) of attendance.
class AttendanceRange {
  const AttendanceRange({
    required this.from,
    required this.to,
    required this.days,
    required this.summary,
  });

  final DateTime from;
  final DateTime to;
  final List<AttendanceDay> days;
  final AttendanceSummary summary;

  factory AttendanceRange.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final days = rawDays is List
        ? rawDays
            .whereType<Map>()
            .map((e) => AttendanceDay.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AttendanceDay>[];
    final rawSummary = json['summary'];
    return AttendanceRange(
      from: parseServerTime(json['from']) ?? DateTime.now(),
      to: parseServerTime(json['to']) ?? DateTime.now(),
      days: days,
      summary: rawSummary is Map
          ? AttendanceSummary.fromJson(Map<String, dynamic>.from(rawSummary))
          : const AttendanceSummary(complete: 0, incomplete: 0, pending: 0),
    );
  }
}

/// The Home payload: profile + today + recent days + unread count.
class HomeSnapshot {
  const HomeSnapshot({
    required this.profile,
    required this.today,
    required this.recent,
    required this.unreadCount,
  });

  final PulseProfile profile;
  final AttendanceDay today;
  final List<AttendanceDay> recent;
  final int unreadCount;

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final todayJson = json['today'];
    final rawRecent = json['recent'];
    return HomeSnapshot(
      profile: PulseProfile.fromJson(
        profileJson is Map ? Map<String, dynamic>.from(profileJson) : const <String, dynamic>{},
      ),
      today: AttendanceDay.fromJson(
        todayJson is Map ? Map<String, dynamic>.from(todayJson) : const <String, dynamic>{},
      ),
      recent: rawRecent is List
          ? rawRecent
              .whereType<Map>()
              .map((e) => AttendanceDay.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <AttendanceDay>[],
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// An inbox notification.
class InboxItem {
  const InboxItem({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  final int id;

  /// `attendance` | `emergency` | `system`
  final String category;

  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: (json['id'] as num).toInt(),
        category: (json['category'] as String?) ?? 'system',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
        isRead: json['read'] == true,
        readAt: parseServerTime(json['read_at']),
      );
}

/// A page of inbox items.
class InboxPage {
  const InboxPage({required this.items, this.nextBefore});

  final List<InboxItem> items;

  /// Id to pass as `?before=` for the next page. Null when there are no more.
  final int? nextBefore;

  factory InboxPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => InboxItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <InboxItem>[];
    final next = json['next_before'];
    return InboxPage(
      items: items,
      nextBefore: next is num ? next.toInt() : null,
    );
  }
}

/// A school-approved contact. The list ships empty; nothing is invented.
class FacultyContact {
  const FacultyContact({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    required this.notes,
    this.updatedAt,
  });

  final int id;
  final String role;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime? updatedAt;

  factory FacultyContact.fromJson(Map<String, dynamic> json) => FacultyContact(
        id: (json['id'] as num).toInt(),
        role: (json['role'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        phone: json['phone'] as String?,
        notes: json['notes'] as String?,
        updatedAt: parseServerTime(json['updated_at']),
      );
}

/// Parses an ISO 8601 timestamp from the server.
///
/// The backend sends school-local time with an explicit `+08:00` offset
/// (`common.to_iso`), so the value is converted to the device's local zone.
DateTime? parseServerTime(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Formats a time the way the backend's `clock()` helper does: `9:41 AM`.
String formatClock(DateTime? time) {
  if (time == null) return '--';
  final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// Formats a date as `Oct 22`.
String formatShortDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

/// Full date, e.g. `Wednesday, Oct 22`.
String formatLongDate(DateTime date) {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  return '${days[date.weekday - 1]}, ${formatShortDate(date)}';
}

/// ISO-ish encoder for query strings.
String encodeQueryValue(Object value) => jsonEncode(value);
