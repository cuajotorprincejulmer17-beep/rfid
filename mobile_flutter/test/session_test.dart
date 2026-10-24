import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/app/route_builders.dart';
import 'package:pulse_flutter/app/session.dart';
import 'package:pulse_flutter/core/auth/auth_controller.dart';
import 'package:pulse_flutter/core/routing/app_router.dart';
import 'package:pulse_flutter/core/storage/preferences_store.dart';
import 'package:pulse_flutter/core/theme/pulse_theme.dart';
import 'package:pulse_flutter/core/theme/pulse_tokens.dart';
import 'package:pulse_flutter/features/auth/auth_pages.dart';
import 'package:pulse_flutter/navigation/pulse_dock.dart';

import 'fake_server.dart';
import 'helpers.dart' show testPreferences;

/// Tokens as `/auth/login` and `/auth/claim` return them.
Map<String, dynamic> _sessionPayload() => {
      'access_token': 'access-${'x' * 20}',
      'refresh_token': 'refresh-${'y' * 20}',
      'token_type': 'Bearer',
      'expires_in': 3600,
      'refresh_expires_in': 2592000,
      'user': {'name': 'Juan Dela Cruz', 'student_number': '2026-0001'},
    };

/// Seeds every endpoint the signed-in app reads.
FakeSchoolServer _signedInServer() {
  final home = homePayload(name: 'Juan Dela Cruz');
  return FakeSchoolServer()
    ..on('/auth/login', _sessionPayload())
    ..on('/home', home)
    ..on('/me', {...home['profile'] as Map, 'preferences': {}, 'unread_count': 1})
    ..on('/attendance/today', home['today'] as Object)
    ..on('/attendance', attendancePayload())
    ..on('/notifications', notificationsPayload())
    ..on('/notifications/unread-count', {
      'total': 1,
      'by_category': {'attendance': 1, 'emergency': 0, 'system': 0},
    })
    ..on('/contacts', {'items': <dynamic>[], 'kind': 'school'});
}

/// Hosts the real router and route builders against [server].
Future<({GoRouter router, AuthController auth, FakeTokenStore store})> _pumpApp(
  WidgetTester tester,
  FakeSchoolServer server, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = FakeTokenStore();
  if (signedIn) {
    store
      ..access = 'test-access-token'
      ..refresh = 'test-refresh-token';
  }
  final api = server.client(store: store);
  final auth = AuthController(api: api, tokenStore: store);
  api.onSessionExpired = auth.onSessionExpired;
  await auth.restore();

  final PreferencesStore preferences = await testPreferences();
  final router = buildRouter(buildRouteBuilders(), auth: auth);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesStoreProvider.overrideWithValue(preferences),
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWithValue(auth),
      ],
      child: MaterialApp.router(
        theme: buildPulseTheme(PulseThemeName.dark.tokens),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, auth: auth, store: store);
}

void main() {
  group('server address', () {
    test('adds a scheme and drops trailing slashes', () {
      expect(normaliseServerUrl(' 192.168.1.20:5001/ '), 'http://192.168.1.20:5001');
      expect(normaliseServerUrl('https://school.example'), 'https://school.example');
    });

    test('rejects addresses without a host', () {
      expect(isValidServerUrl('192.168.1.20:5001'), isTrue);
      expect(isValidServerUrl('http://'), isFalse);
      expect(isValidServerUrl('ftp://school'), isFalse);
    });
  });

  testWidgets('a signed-out student lands on sign-in and signs in',
      (tester) async {
    final server = _signedInServer();
    final app = await _pumpApp(tester, server);

    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(PulseDock), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), '2026-0001');
    await tester.enterText(find.byType(TextField).at(1), 'correct-horse');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(app.auth.isSignedIn, isTrue);
    expect(app.store.access, startsWith('access-'));
    expect(find.byType(PulseDock), findsOneWidget);
    expect(find.text('Welcome back, Juan'), findsOneWidget);
    expect(server.requests, contains('POST /auth/login'));
    expect(server.requests, contains('GET /attendance/today'));
  });

  testWidgets('a wrong password shows the reason and keeps the student out',
      (tester) async {
    final server = _signedInServer()
      ..onRaw(
        '/auth/login',
        (_) => http.Response(
          jsonEncode({
            'error': {
              'code': 'invalid_credentials',
              'message': 'Incorrect student number or password.',
            },
          }),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );
    final app = await _pumpApp(tester, server);

    await tester.enterText(find.byType(TextField).at(0), '2026-0001');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(app.auth.isSignedIn, isFalse);
    expect(find.text('Incorrect student number or password.'), findsOneWidget);
    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('Updates shows the school inbox and marks an item read',
      (tester) async {
    final server = _signedInServer()
      ..on('/notifications/11/read', {
        ...(notificationsPayload()['items'] as List).first as Map<String, dynamic>,
        'read': true,
      });
    final app = await _pumpApp(tester, server, signedIn: true);

    app.router.go('/updates');
    await tester.pumpAndSettle();

    expect(find.text('Attendance Recorded'), findsOneWidget);
    expect(find.text('Welcome to PULSE'), findsOneWidget);
    expect(find.text('Announcements'), findsOneWidget);
    // Saving is a sample-data feature; the server has no saved flag.
    expect(find.text('Saved'), findsNothing);

    await tester.tap(find.text('Attendance Recorded'));
    await tester.pumpAndSettle();
    expect(server.requests, contains('POST /notifications/11/read'));
  });

  testWidgets('signing out from Settings returns to sign-in', (tester) async {
    final server = _signedInServer()..on('/auth/logout', {'success': true});
    final app = await _pumpApp(tester, server, signedIn: true);

    app.router.push('/personal/settings');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(app.store.access, isNull);
    expect(find.byType(SignInPage), findsOneWidget);
    expect(server.requests, contains('POST /auth/logout'));
  });

  testWidgets('without a server, Attendance says it is not connected',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final preferences = await testPreferences();
    final router = buildRouter(buildRouteBuilders());
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
        child: MaterialApp.router(
          theme: buildPulseTheme(PulseThemeName.dark.tokens),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/academic/attendance');
    await tester.pumpAndSettle();

    expect(find.textContaining('Not connected to the school server'), findsOneWidget);
    expect(find.text('No status yet'), findsNothing);
  });
}
