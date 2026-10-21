import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/api/api_client.dart';
import 'package:pulse_flutter/core/api/api_exception.dart';

import 'helpers.dart';

void main() {
  group('ApiClient request shape', () {
    test('login posts the documented fields to /api/v1/auth/login', () async {
      late http.Request seen;
      final store = FakeTokenStore();
      final client = buildClient(store, (request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'access_token': 'a1',
            'refresh_token': 'r1',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'user': {'name': 'Ada', 'student_number': '2023-0142'},
          }),
          200,
        );
      });

      final session = await client.login(
        studentNumber: '2023-0142',
        password: 'hunter22',
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/v1/auth/login');
      expect(jsonDecode(seen.body), {
        'student_number': '2023-0142',
        'password': 'hunter22',
      });
      expect(session.accessToken, 'a1');
      expect(session.user?.name, 'Ada');
      expect(session.user?.studentNumber, '2023-0142');
    });

    test('claim posts student_number, claim_code and password', () async {
      late http.Request seen;
      final store = FakeTokenStore();
      final client = buildClient(store, (request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'access_token': 'a2',
            'refresh_token': 'r2',
            'expires_in': 3600,
          }),
          201,
        );
      });

      await client.claim(
        studentNumber: '2023-0142',
        claimCode: 'ABCD-1234',
        password: 'hunter22',
      );

      expect(seen.url.path, '/api/v1/auth/claim');
      expect(jsonDecode(seen.body), {
        'student_number': '2023-0142',
        'claim_code': 'ABCD-1234',
        'password': 'hunter22',
      });
    });

    test('authenticated GET sends the bearer token', () async {
      late http.Request seen;
      final store = FakeTokenStore()..access = 'token-123';
      final client = buildClient(store, (request) async {
        seen = request;
        return http.Response(jsonEncode({'name': 'Ada'}), 200);
      });

      await client.getJson('/me');

      expect(seen.url.path, '/api/v1/me');
      expect(seen.headers['Authorization'], 'Bearer token-123');
    });

    test('attendance month query is passed through', () async {
      late http.Request seen;
      final store = FakeTokenStore()..access = 'token-123';
      final client = buildClient(store, (request) async {
        seen = request;
        return http.Response(jsonEncode({'days': [], 'summary': {}}), 200);
      });

      await client.getJson('/attendance', query: {'month': '2026-10'});

      expect(seen.url.path, '/api/v1/attendance');
      expect(seen.url.queryParameters['month'], '2026-10');
    });
  });

  group('ApiClient error mapping', () {
    test('a structured error body becomes an ApiException with its code',
        () async {
      final store = FakeTokenStore();
      final client = buildClient(
        store,
        (request) async => errorResponse(401, 'invalid_credentials', 'Nope.'),
      );

      await expectLater(
        client.login(studentNumber: 'x', password: 'y'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'invalid_credentials')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('a missing token is rejected before any request is sent', () async {
      var called = false;
      final store = FakeTokenStore();
      final client = buildClient(store, (request) async {
        called = true;
        return http.Response('{}', 200);
      });

      await expectLater(
        client.getJson('/me'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')),
      );
      expect(called, isFalse);
    });
  });

  group('ApiClient refresh', () {
    test('an expired token triggers one refresh and the request is retried',
        () async {
      final store = FakeTokenStore()
        ..access = 'old-access'
        ..refresh = 'refresh-1';
      var refreshCalls = 0;
      var profileCalls = 0;

      final client = buildClient(store, (request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          return http.Response(
            jsonEncode({'access_token': 'new-access', 'refresh_token': 'new-refresh'}),
            200,
          );
        }
        profileCalls++;
        if (profileCalls == 1) {
          return errorResponse(401, 'token_expired', 'Expired.');
        }
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response(jsonEncode({'name': 'Ada'}), 200);
      });

      final me = await client.getJson('/me');

      expect(me['name'], 'Ada');
      expect(refreshCalls, 1);
      expect(profileCalls, 2);
      expect(store.access, 'new-access');
    });

    test('parallel expired requests share a single refresh', () async {
      final store = FakeTokenStore()
        ..access = 'old-access'
        ..refresh = 'refresh-1';
      var refreshCalls = 0;
      var profileCalls = 0;

      final client = buildClient(store, (request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          // Make the refresh slow enough that the parallel calls overlap.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response(
            jsonEncode({'access_token': 'new-access', 'refresh_token': 'new-refresh'}),
            200,
          );
        }
        profileCalls++;
        if (profileCalls <= 2) {
          return errorResponse(401, 'token_expired', 'Expired.');
        }
        return http.Response(jsonEncode({'name': 'Ada'}), 200);
      });

      await Future.wait([
        client.getJson('/me'),
        client.getJson('/me'),
        client.getJson('/me'),
      ]);

      expect(refreshCalls, 1, reason: 'only one refresh round-trip');
    });

    test('a failed refresh signs the session out', () async {
      final store = FakeTokenStore()
        ..access = 'old-access'
        ..refresh = 'refresh-1';
      var expired = false;

      final client = buildClient(store, (request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          return errorResponse(401, 'invalid_refresh', 'Please sign in again.');
        }
        if (!expired) {
          expired = true;
          return errorResponse(401, 'token_expired', 'Expired.');
        }
        return http.Response(jsonEncode({'name': 'Ada'}), 200);
      });
      client.onSessionExpired = () {};

      await expectLater(
        client.getJson('/me'),
        throwsA(isA<ApiException>()),
      );

      expect(store.access, isNull, reason: 'tokens are cleared');
      expect(store.refresh, isNull);
    });

    test('an invalid session is not retried', () async {
      final store = FakeTokenStore()
        ..access = 'old-access'
        ..refresh = 'refresh-1';
      var refreshCalls = 0;
      var profileCalls = 0;

      final client = buildClient(store, (request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          return http.Response('{}', 200);
        }
        profileCalls++;
        return errorResponse(401, 'unauthorized', 'Sign in to continue.');
      });

      await expectLater(
        client.getJson('/me'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')),
      );

      expect(refreshCalls, 0, reason: 'only token_expired triggers a refresh');
      expect(profileCalls, 1);
    });

    test('an unauthorized session ends it and asks the user to sign in again',
        () async {
      // The server was reset or the session was revoked, so the access token
      // is unknown to it. Refreshing cannot help, so the app must clear the
      // tokens and return to the sign-in screen instead of retrying forever.
      final store = FakeTokenStore()
        ..access = 'stale-access'
        ..refresh = 'stale-refresh';
      var refreshCalls = 0;
      var sessionEnded = false;

      final client = buildClient(store, (request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls++;
          return http.Response('{}', 200);
        }
        return errorResponse(401, 'unauthorized', 'Sign in to continue.');
      });
      client.onSessionExpired = () => sessionEnded = true;

      await expectLater(
        client.getJson('/me'),
        throwsA(isA<ApiException>()),
      );

      expect(refreshCalls, 0, reason: 'an unknown session cannot be refreshed');
      expect(sessionEnded, isTrue, reason: 'the app must return to sign-in');
      expect(store.access, isNull, reason: 'the stale tokens are cleared');
      expect(store.refresh, isNull);
    });
  });

  group('ApiClient transport failures', () {
    test('a socket failure is unknown, not an empty result', () async {
      final store = FakeTokenStore()..access = 'token-123';
      final client = buildClient(store, (request) async {
        throw const SocketException('Connection refused');
      });

      await expectLater(
        client.getJson('/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'network')
              .having((e) => e.isUnknownOutcome, 'isUnknownOutcome', isTrue),
        ),
      );
    });

    test('a timeout is unknown, not an empty result', () async {
      final store = FakeTokenStore()..access = 'token-123';
      final client = ApiClient(
        baseUrl: 'http://school.test:5001',
        tokenStore: store,
        timeout: const Duration(milliseconds: 20),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.getJson('/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isUnknownOutcome, 'isUnknownOutcome', isTrue),
        ),
      );
    });
  });
}
