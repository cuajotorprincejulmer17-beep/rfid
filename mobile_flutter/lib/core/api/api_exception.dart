/// Errors the backend can return.
///
/// The backend always answers `{"error": {"code": "...", "message": "..."}}`.
/// Branch on [code], never on the message text (backend contract).
library;

import 'dart:io';

/// A structured failure from the API.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// Machine-readable code from the backend, or a local code for transport
  /// problems (see [ApiException.network], [ApiException.timeout]).
  final String code;

  /// Human-readable message. Safe to show, but never branch on it.
  final String message;

  /// HTTP status, when the failure came from a response.
  final int? statusCode;

  /// The request never produced a usable response.
  ///
  /// Per the backend contract this is **unknown**, never "absent" or "0".
  bool get isNetwork => code == 'network';

  /// The request timed out. Also unknown.
  bool get isTimeout => code == 'timeout';

  /// Transport-level failure where the outcome is genuinely ambiguous.
  bool get isUnknownOutcome => isNetwork || isTimeout;

  /// The access token expired; a refresh may fix it.
  bool get isTokenExpired => code == 'token_expired';

  /// The session is gone; the user must sign in again.
  bool get isUnauthorised => code == 'unauthorized' || code == 'invalid_refresh';

  /// The server rejected the request as malformed.
  bool get isInvalidRequest => code == 'invalid_field' || code == 'invalid_body';

  @override
  String toString() => 'ApiException($code, $message)';
}

/// Transport failures, which are *unknown* rather than *absent*.
class ApiExceptionFactory {
  const ApiExceptionFactory._();

  static ApiException network(Object cause) => ApiException(
        code: 'network',
        message: "Couldn't reach the school server.",
      );

  static ApiException timeout() => const ApiException(
        code: 'timeout',
        message: 'The school server took too long to respond.',
      );

  static ApiException socket() => const ApiException(
        code: 'network',
        message: "Couldn't reach the school server.",
      );
}

/// Wraps a [SocketException]/[HttpException] into an [ApiException].
ApiException mapTransportError(Object error) {
  if (error is SocketException) return ApiExceptionFactory.socket();
  if (error is HttpException) return ApiExceptionFactory.network(error);
  if (error is FormatException) {
    return const ApiException(
      code: 'bad_response',
      message: 'The school server sent an unexpected response.',
    );
  }
  return ApiExceptionFactory.network(error);
}
