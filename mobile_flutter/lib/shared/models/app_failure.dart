/// A typed failure.
///
/// A failure is never rendered as "absent" or "zero". It is one of these,
/// and the UI shows the matching state.
enum AppFailureKind {
  /// The device could not reach the server. The outcome is unknown.
  offline,

  /// The thing the user asked for does not exist.
  notFound,

  /// The session is missing or expired.
  unauthorized,

  /// Anything else. The outcome is unknown.
  unknown,
}

/// A failure with a human message.
class AppFailure implements Exception {
  const AppFailure(
    this.kind,
    this.message, {
    this.statusCode,
  });

  final AppFailureKind kind;
  final String message;
  final int? statusCode;

  /// Whether the outcome of the request is unknown.
  bool get isUnknownOutcome =>
      kind == AppFailureKind.offline || kind == AppFailureKind.unknown;

  @override
  String toString() => 'AppFailure(${kind.name}: $message)';
}
