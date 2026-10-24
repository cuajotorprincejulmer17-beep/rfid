import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'token_store.dart';

/// Where the app is with respect to authentication.
enum AuthStatus { unknown, signedOut, signedIn }

/// Owns the signed-in state and the auth calls.
///
/// The controller never stores a token itself: it hands them straight to
/// [TokenStore] (secure storage) and reads them back from there.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.tokenStore});

  final ApiClient api;
  final TokenStore tokenStore;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _lastErrorCode;
  String? _lastErrorMessage;

  AuthStatus get status => _status;

  AuthUser? get user => _user;

  /// The last backend error code, so the UI can react without matching text.
  String? get lastErrorCode => _lastErrorCode;

  /// The server's message for the last failure. Safe to show.
  String? get lastErrorMessage => _lastErrorMessage;

  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// Restores a session from secure storage on cold start.
  ///
  /// Returns true when a usable access token was found. The token itself is
  /// validated by the first real request, so a stale token simply produces a
  /// refresh attempt rather than a false "signed out".
  Future<bool> restore() async {
    final token = await tokenStore.readAccessToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
    _status = AuthStatus.signedIn;
    notifyListeners();
    return true;
  }

  /// `POST /auth/login`.
  Future<bool> signIn({
    required String studentNumber,
    required String password,
  }) async {
    _lastErrorCode = null;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final session = await api.login(
        studentNumber: studentNumber.trim(),
        password: password,
      );
      await _storeSession(session);
      _user = session.user;
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastErrorCode = e.code;
      _lastErrorMessage = e.message;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }

  /// `POST /auth/claim`.
  Future<bool> claimAccount({
    required String studentNumber,
    required String claimCode,
    required String password,
  }) async {
    _lastErrorCode = null;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final session = await api.claim(
        studentNumber: studentNumber.trim(),
        claimCode: claimCode.trim(),
        password: password,
      );
      await _storeSession(session);
      _user = session.user;
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastErrorCode = e.code;
      _lastErrorMessage = e.message;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }

  /// `POST /auth/logout`, then clear local tokens.
  ///
  /// A failure to reach the server still clears the local session: the user
  /// asked to sign out, so the device must not keep the tokens.
  Future<void> signOut() async {
    try {
      await api.logout();
    } catch (_) {
      // The local session is cleared regardless.
    }
    await tokenStore.clear();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Called by [ApiClient] when a refresh failed and the session is gone.
  void onSessionExpired() {
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> _storeSession(AuthSession session) async {
    await tokenStore.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }
}
