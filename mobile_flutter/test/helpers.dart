import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/api/api_client.dart';
import 'package:pulse_flutter/core/auth/token_store.dart';
import 'package:pulse_flutter/core/storage/preferences_store.dart';
import 'package:pulse_flutter/core/theme/pulse_theme.dart';
import 'package:pulse_flutter/core/theme/pulse_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An in-memory [TokenStore] for tests.
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

/// Builds a client whose requests are handled by [handler].
ApiClient buildClient(
  FakeTokenStore store,
  Future<http.Response> Function(http.Request request) handler,
) {
  return ApiClient(
    baseUrl: 'http://school.test:5001',
    tokenStore: store,
    httpClient: MockClient((request) => handler(request)),
  );
}

/// A JSON error body as the backend sends it.
http.Response errorResponse(int status, String code, String message) {
  return http.Response(
    jsonEncode({
      'error': {'code': code, 'message': message},
    }),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Builds a preferences store backed by mocked shared preferences.
Future<PreferencesStore> testPreferences([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return PreferencesStore(await SharedPreferences.getInstance());
}

/// Hosts [child] in a themed app with a provider scope.
Widget testHost(
  Widget child, {
  required PreferencesStore preferences,
  PulseThemeName theme = PulseThemeName.dark,
  bool disableAnimations = false,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    child: MaterialApp(
      theme: buildPulseTheme(theme.tokens),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        );
      },
      home: child,
    ),
  );
}

/// Sets the size of the test view.
void setTestSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
