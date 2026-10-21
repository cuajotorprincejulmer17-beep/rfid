import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';

/// The six states every data region must be able to show
/// (backend contract rule 5).
enum PulseDataStatus {
  /// Not requested yet.
  idle,

  /// First load in flight.
  loading,

  /// A successful response just arrived.
  fresh,

  /// Showing data from a previous successful response (e.g. offline).
  cached,

  /// A successful response confirmed there is nothing to show.
  empty,

  /// The request failed. The outcome is unknown, never "absent".
  error,
}

/// A value plus how it was obtained, so the UI can label it honestly.
///
/// [value] is deliberately nullable so "the server said there is nothing" and
/// "we do not know" stay distinct.
@immutable
class PulseData<T> {
  const PulseData({
    required this.status,
    this.value,
    this.lastUpdated,
    this.error,
    this.isStale = false,
  });

  /// Nothing loaded yet.
  const PulseData.idle()
      : status = PulseDataStatus.idle,
        value = null,
        lastUpdated = null,
        error = null,
        isStale = false;

  /// First load in flight.
  const PulseData.loading()
      : status = PulseDataStatus.loading,
        value = null,
        lastUpdated = null,
        error = null,
        isStale = false;

  /// A successful response. A null [value] means the server confirmed there
  /// is nothing to show.
  factory PulseData.fresh(T? value, {DateTime? lastUpdated}) => PulseData<T>(
        status: PulseDataStatus.fresh,
        value: value,
        lastUpdated: lastUpdated ?? DateTime.now(),
      );

  /// Showing an older successful response.
  factory PulseData.cached(T? value, {required DateTime lastUpdated, bool isStale = true}) =>
      PulseData<T>(
        status: PulseDataStatus.cached,
        value: value,
        lastUpdated: lastUpdated,
        isStale: isStale,
      );

  /// The request failed. [error] explains why. Never render as absent/zero.
  factory PulseData.error(Object error, {T? value, DateTime? lastUpdated}) => PulseData<T>(
        status: PulseDataStatus.error,
        value: value,
        lastUpdated: lastUpdated,
        error: error,
      );

  final PulseDataStatus status;
  final T? value;
  final DateTime? lastUpdated;
  final Object? error;

  /// True when the value shown is older than the last attempt.
  final bool isStale;

  bool get isLoading => status == PulseDataStatus.loading;

  bool get hasError => status == PulseDataStatus.error;

  /// True when there is nothing to render but no failure either.
  bool get isBlank => value == null;

  /// True when the failure means the outcome is unknown.
  ///
  /// A network failure or timeout is **not** the same as "no records".
  bool get isUnknown {
    final e = error;
    return e is ApiException && e.isUnknownOutcome;
  }

  /// Human label for the "last updated" line.
  String? get lastUpdatedLabel {
    final at = lastUpdated;
    if (at == null) return null;
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}
