import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/api/api_exception.dart';
import 'package:pulse_flutter/core/state/pulse_data.dart';
import 'package:pulse_flutter/core/theme/pulse_theme.dart';
import 'package:pulse_flutter/core/theme/pulse_tokens.dart';
import 'package:pulse_flutter/data/models/models.dart';
import 'package:pulse_flutter/shared/widgets/pulse_data_state_view.dart';

/// Wraps [child] in the minimum Material scaffolding the widgets need.
Widget host(Widget child) {
  return MaterialApp(
    theme: buildPulseTheme(PulseTokens.dark),
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('PulseData states', () {
    test('a network failure is unknown, never an empty result', () {
      final data = PulseData<String>.error(
        const ApiException(code: 'network', message: 'no route'),
      );

      expect(data.hasError, isTrue);
      expect(data.isUnknown, isTrue);
      expect(data.status, PulseDataStatus.error);
      // Crucially: it is NOT reported as empty.
      expect(data.status, isNot(PulseDataStatus.empty));
    });

    test('a timeout is unknown too', () {
      final data = PulseData<String>.error(
        const ApiException(code: 'timeout', message: 'too slow'),
      );
      expect(data.isUnknown, isTrue);
    });

    test('a server-side error is a known failure, not unknown', () {
      final data = PulseData<String>.error(
        const ApiException(
          code: 'internal_error',
          message: 'boom',
          statusCode: 500,
        ),
      );
      expect(data.hasError, isTrue);
      expect(data.isUnknown, isFalse);
    });

    test('fresh and cached carry the last-updated time', () {
      final at = DateTime.now().subtract(const Duration(minutes: 5));
      final fresh = PulseData.fresh('value');
      final cached = PulseData.cached('value', lastUpdated: at);

      expect(fresh.lastUpdated, isNotNull);
      expect(cached.lastUpdated, at);
      expect(cached.isStale, isTrue);
    });
  });

  group('AttendanceDay parsing', () {
    test('reads the server payload shape', () {
      final day = AttendanceDay.fromJson({
        'date': '2026-10-20',
        'status': 'complete',
        'time_in': '2026-10-20T07:45:00+08:00',
        'time_out': '2026-10-20T08:30:00+08:00',
        'sessions': [
          {
            'id': 1,
            'time_in': '2026-10-20T07:45:00+08:00',
            'time_out': '2026-10-20T08:30:00+08:00',
            'status': 'complete',
          },
        ],
      });

      expect(day.status, 'complete');
      expect(day.sessions, hasLength(1));
      expect(day.timeIn, isNotNull);
      expect(day.timeOut, isNotNull);
      expect(day.hasRecord, isTrue);
    });

    test('an unavailable day has no record', () {
      final day = AttendanceDay.fromJson({
        'date': '2026-10-19',
        'status': 'unavailable',
        'time_in': null,
        'time_out': null,
        'sessions': <dynamic>[],
      });

      expect(day.status, 'unavailable');
      expect(day.hasRecord, isFalse);
      expect(day.timeIn, isNull);
    });

    test('an unknown status is preserved rather than guessed', () {
      final day = AttendanceDay.fromJson({'status': 'weird'});
      expect(day.status, 'weird');
    });
  });

  group('StateView rendering', () {
    testWidgets('a failure shows Retry and never an empty message', (tester) async {
      var retried = false;

      await tester.pumpWidget(host(
        PulseDataStateView<String>(
          data: PulseData<String>.error(
            const ApiException(code: 'network', message: "Couldn't reach the server."),
          ),
          onRetry: () => retried = true,
          emptyTitle: 'Nothing here',
          builder: (context, value, freshness) => Text(value),
        ),
      ));

      expect(find.text('Status unknown'), findsOneWidget);
      expect(find.text('Nothing here'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('a confirmed empty response shows the empty state', (tester) async {
      await tester.pumpWidget(host(
        PulseDataStateView<String>(
          data: PulseData.fresh(null),
          emptyTitle: 'No attendance records',
          emptyBody: 'The server confirmed there are no records.',
          builder: (context, value, freshness) => Text(value),
        ),
      ));

      expect(find.text('No attendance records'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a fresh value renders the content', (tester) async {
      await tester.pumpWidget(host(
        PulseDataStateView<String>(
          data: PulseData.fresh('hello'),
          builder: (context, value, freshness) => Text(value),
        ),
      ));

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('a cached value renders with the cached marker', (tester) async {
      await tester.pumpWidget(host(
        PulseDataStateView<String>(
          data: PulseData.cached(
            'hello',
            lastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
          ),
          builder: (context, value, freshness) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value),
              ?freshness,
            ],
          ),
        ),
      ));

      expect(find.text('hello'), findsOneWidget);
      expect(find.textContaining('Saved copy'), findsOneWidget);
    });

    testWidgets('a fresh value is labelled with its update time',
        (tester) async {
      await tester.pumpWidget(host(
        PulseDataStateView<String>(
          data: PulseData.fresh('hello'),
          builder: (context, value, freshness) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value),
              ?freshness,
            ],
          ),
        ),
      ));

      expect(find.text('hello'), findsOneWidget);
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(find.textContaining('Saved copy'), findsNothing);
    });
  });
}
