import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pulse_flutter/core/api/api_client.dart';
import 'package:pulse_flutter/core/auth/token_store.dart';

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
