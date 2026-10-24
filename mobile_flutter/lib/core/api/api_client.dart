import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_store.dart';
import 'api_exception.dart';

/// Result of an auth call: tokens plus the user summary.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.refreshExpiresIn,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final int? refreshExpiresIn;
  final AuthUser? user;
}

/// The `user` object returned by `/auth/claim` and `/auth/login`.
class AuthUser {
  const AuthUser({required this.name, required this.studentNumber});

  final String name;
  final String studentNumber;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        name: (json['name'] as String?) ?? '',
        studentNumber: (json['student_number'] as String?) ?? '',
      );
}

/// Notified when the session ends for good (refresh failed). The app listens
/// and routes the user back to sign-in.
typedef SessionExpiredCallback = void Function();

/// The single HTTP entry point for the app.
///
/// Responsibilities:
///  * attach the bearer token,
///  * refresh **once** on an expired access token, serialised so parallel
///    requests share one refresh round-trip,
///  * turn every failure into an [ApiException],
///  * never retry a non-idempotent call blindly.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  /// Base URL of the school server, e.g. `http://192.168.1.20:5001`.
  /// The `/api/v1` prefix is appended automatically. It can change at
  /// runtime from the Server address setting.
  String baseUrl;

  final TokenStore tokenStore;
  final http.Client _http;
  final Duration timeout;

  /// Called when the session cannot be recovered.
  SessionExpiredCallback? onSessionExpired;

  /// Guards the refresh so only one refresh runs at a time. Concurrent callers
  /// await the same future, so they share one refresh round-trip.
  Future<bool>? _refreshInFlight;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  String get _apiRoot {
    final base =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$base/api/v1';
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalised = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_apiRoot$normalised')
        .replace(queryParameters: (query == null || query.isEmpty) ? null : query);
  }

  // ------------------------------------------------------------------ public

  /// `GET /health`. No auth. Used for the "test connection" action.
  Future<Map<String, dynamic>> health() async {
    final res = await _send((h) => _http.get(_uri('/health'), headers: h));
    return _decodeMap(res);
  }

  /// `POST /auth/claim`. First-time sign-up with a one-time claim code.
  Future<AuthSession> claim({
    required String studentNumber,
    required String claimCode,
    required String password,
  }) async {
    final res = await _send(
      (h) => _http.post(
        _uri('/auth/claim'),
        headers: {...h, ..._jsonHeaders},
        body: jsonEncode({
          'student_number': studentNumber,
          'claim_code': claimCode,
          'password': password,
        }),
      ),
    );
    return _sessionFrom(res);
  }

  /// `POST /auth/login`.
  Future<AuthSession> login({
    required String studentNumber,
    required String password,
  }) async {
    final res = await _send(
      (h) => _http.post(
        _uri('/auth/login'),
        headers: {...h, ..._jsonHeaders},
        body: jsonEncode({
          'student_number': studentNumber,
          'password': password,
        }),
      ),
    );
    return _sessionFrom(res);
  }

  /// `POST /auth/logout`. Revokes the session server-side.
  Future<void> logout() async {
    await _send(
      (h) => _http.post(
        _uri('/auth/logout'),
        headers: {...h, ..._jsonHeaders},
        body: '{}',
      ),
      authenticated: true,
    );
  }

  /// Authenticated `GET` returning a JSON object.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _send(
      (h) => _http.get(_uri(path, query), headers: h),
      authenticated: true,
    );
    return _decodeMap(res);
  }

  /// Authenticated `PATCH` with a JSON body.
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      (h) => _http.patch(
        _uri(path),
        headers: {...h, ..._jsonHeaders},
        body: jsonEncode(body),
      ),
      authenticated: true,
    );
    return _decodeMap(res);
  }

  /// Authenticated `POST` with a JSON body.
  Future<Map<String, dynamic>> postJson(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final res = await _send(
      (h) => _http.post(
        _uri(path),
        headers: {...h, ..._jsonHeaders},
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      authenticated: true,
    );
    return _decodeMap(res);
  }

  /// Authenticated `GET` returning a JSON list.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _send(
      (h) => _http.get(_uri(path, query), headers: h),
      authenticated: true,
    );
    return _decodeList(res);
  }

  void dispose() => _http.close();

  // ------------------------------------------------------------------ internals

  AuthSession _sessionFrom(http.Response res) {
    final map = _decodeMap(res);
    return AuthSession(
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String,
      expiresIn: (map['expires_in'] as num?)?.toInt() ?? 3600,
      refreshExpiresIn: (map['refresh_expires_in'] as num?)?.toInt(),
      user: map['user'] is Map
          ? AuthUser.fromJson(Map<String, dynamic>.from(map['user'] as Map))
          : null,
    );
  }

  /// Runs [request] with the right headers.
  ///
  /// On `token_expired` it refreshes **once** and retries the request. The
  /// refresh is serialised: if several requests fail at the same moment only
  /// the first performs it; the rest wait and reuse the new access token.
  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool authenticated = false,
  }) async {
    try {
      var res = await _perform(request, authenticated: authenticated);
      if (res.statusCode == 401 && authenticated) {
        final code = _errorCode(res);
        if (code == 'token_expired') {
          // The access token aged out: refresh once and retry.
          final refreshed = await _refreshOnce();
          if (refreshed) {
            res = await _perform(request, authenticated: true);
          } else {
            await _endSession();
          }
        } else {
          // `unauthorized` means the session no longer exists on the server
          // (revoked, or the server was reset). Refreshing cannot help, so
          // the session ends and the user is asked to sign in again.
          await _endSession();
        }
      }
      _throwIfError(res);
      return res;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw mapTransportError(error);
    }
  }

  Future<http.Response> _perform(
    Future<http.Response> Function(Map<String, String> headers) request, {
    required bool authenticated,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (authenticated) {
      final token = await tokenStore.readAccessToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          code: 'unauthorized',
          message: 'Sign in to continue.',
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return request(headers).timeout(timeout);
  }

  /// Performs the refresh exactly once for all concurrent callers.
  Future<bool> _refreshOnce() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = _doRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final res = await _http
          .post(
            _uri('/auth/refresh'),
            headers: _jsonHeaders,
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return false;
      final map = _decodeMap(res);
      await tokenStore.saveTokens(
        accessToken: map['access_token'] as String,
        refreshToken: map['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _endSession() async {
    await tokenStore.clear();
    onSessionExpired?.call();
  }

  /// Converts a non-2xx response into an [ApiException].
  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final code = _errorCode(res) ?? 'http_${res.statusCode}';
    final message = _errorMessage(res) ?? 'Something went wrong on the server.';
    throw ApiException(code: code, message: message, statusCode: res.statusCode);
  }

  String? _errorCode(http.Response res) => _errorField(res, 'code');

  String? _errorMessage(http.Response res) => _errorField(res, 'message');

  String? _errorField(http.Response res, String field) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is Map) {
        final value = (body['error'] as Map)[field];
        if (value is String) return value;
      }
    } catch (_) {
      // Not a structured error body; fall through to the generic message.
    }
    return null;
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    final body = _decodeJson(res);
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const ApiException(
      code: 'bad_response',
      message: 'The school server sent an unexpected response.',
    );
  }

  List<dynamic> _decodeList(http.Response res) {
    final body = _decodeJson(res);
    if (body is List) return body;
    throw const ApiException(
      code: 'bad_response',
      message: 'The school server sent an unexpected response.',
    );
  }

  dynamic _decodeJson(http.Response res) {
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw const ApiException(
        code: 'bad_response',
        message: 'The school server sent an unexpected response.',
      );
    }
  }
}
