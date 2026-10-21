import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/api/api_client.dart';
import 'package:pulse_flutter/core/auth/token_store.dart';
import 'package:pulse_flutter/data/repositories/inbox_repository.dart';
import 'package:pulse_flutter/data/repositories/pulse_repository.dart';

/// A fake school server that answers the endpoints the app actually calls.
///
/// The payloads mirror the shapes the Flask server returns, so the widget
/// tests exercise the same parsing path as the app on a device. Nothing here
/// is imported by production code.
class FakeSchoolServer {
  FakeSchoolServer();

  final Map<String, http.Response Function(http.Request)> _routes = {};

  /// Registers a JSON response for [path] (exact match on the request path).
  void on(String path, Object body, {int status = 200}) {
    _routes[path] = (_) => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
  }

  /// Registers a raw response for [path].
  void onRaw(String path, http.Response Function(http.Request) handler) {
    _routes[path] = handler;
  }

  /// Requests seen by the fake, in order.
  final List<String> requests = [];

  ApiClient client({String baseUrl = 'http://school.test:5001'}) {
    final store = FakeTokenStore()
      ..access = 'test-access-token'
      ..refresh = 'test-refresh-token';
    return ApiClient(
      baseUrl: baseUrl,
      tokenStore: store,
      httpClient: MockClient((request) async {
        final path = request.url.path.replaceFirst('/api/v1', '');
        requests.add('${request.method} $path');
        final handler = _routes[path];
        if (handler == null) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'not_found', 'message': 'no route for $path'},
            }),
            404,
            headers: {'content-type': 'application/json'},
          );
        }
        return handler(request);
      }),
    );
  }

  PulseRepository repository({String baseUrl = 'http://school.test:5001'}) =>
      PulseRepository(client(baseUrl: baseUrl));

  InboxRepository inboxRepository({String baseUrl = 'http://school.test:5001'}) =>
      InboxRepository(client(baseUrl: baseUrl));
}

/// A token store for tests. Keeps tokens in memory, never on disk.
class FakeTokenStore implements TokenStore {
  String? access;
  String? refresh;

  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    clearCount++;
  }
}

/// A Home payload in the server's own shape.
Map<String, dynamic> homePayload({
  String name = 'Test Student',
  int unread = 2,
}) {
  return {
    'profile': {
      'name': name,
      'student_number': '2026-0001',
      'course_section': 'BSCS-1A',
      'phone': '09171234567',
      'rfid_registered': true,
      'rfid_status': 'registered',
    },
    'today': {
      'date': '2026-10-20',
      'status': 'pending',
      'time_in': '2026-10-20T21:23:00+08:00',
      'time_out': null,
      'state': 'in',
      'expected_scan': 'time_out',
      'sessions': [
        {
          'id': 1,
          'time_in': '2026-10-20T21:23:00+08:00',
          'time_out': null,
          'status': 'pending',
        },
      ],
    },
    'recent': [
      {
        'date': '2026-10-19',
        'status': 'complete',
        'time_in': '2026-10-19T07:45:00+08:00',
        'time_out': '2026-10-19T08:30:00+08:00',
        'sessions': <dynamic>[],
      },
      {
        'date': '2026-10-18',
        'status': 'unavailable',
        'time_in': null,
        'time_out': null,
        'sessions': <dynamic>[],
      },
    ],
    'unread_count': unread,
  };
}

/// An attendance-month payload in the server's own shape.
Map<String, dynamic> attendancePayload() {
  return {
    'from': '2026-10-01',
    'to': '2026-10-31',
    'days': [
      {
        'date': '2026-10-20',
        'status': 'pending',
        'time_in': '2026-10-20T21:23:00+08:00',
        'time_out': null,
        'sessions': <dynamic>[],
      },
      {
        'date': '2026-10-19',
        'status': 'complete',
        'time_in': '2026-10-19T07:45:00+08:00',
        'time_out': '2026-10-19T08:30:00+08:00',
        'sessions': <dynamic>[],
      },
    ],
    'summary': {'complete': 12, 'incomplete': 1, 'pending': 2},
  };
}

/// A notifications payload in the server's own shape.
Map<String, dynamic> notificationsPayload() {
  return {
    'items': [
      {
        'id': 11,
        'category': 'attendance',
        'title': 'Attendance Recorded',
        'body': 'Your time in was recorded at 9:23 PM.',
        'created_at': '2026-10-20T21:23:00+08:00',
        'is_read': false,
        'read_at': null,
      },
      {
        'id': 12,
        'category': 'system',
        'title': 'Welcome to PULSE',
        'body': 'Your student account is now active.',
        'created_at': '2026-10-19T08:00:00+08:00',
        'is_read': true,
        'read_at': '2026-10-19T09:00:00+08:00',
      },
    ],
    'next_before': null,
  };
}
