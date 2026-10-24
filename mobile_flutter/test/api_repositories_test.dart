import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pulse_flutter/app/route_builders.dart';
import 'package:pulse_flutter/app/session.dart';
import 'package:pulse_flutter/core/auth/auth_controller.dart';
import 'package:pulse_flutter/core/routing/app_router.dart';
import 'package:pulse_flutter/core/storage/preferences_store.dart';
import 'package:pulse_flutter/core/theme/pulse_theme.dart';
import 'package:pulse_flutter/core/theme/pulse_tokens.dart';
import 'package:pulse_flutter/data/models/models.dart';
import 'package:pulse_flutter/data/repositories/api_repositories.dart';
import 'package:pulse_flutter/shared/repositories/demo/demo_sample_repositories.dart';
import 'package:pulse_flutter/shared/repositories/repository_providers.dart';
import 'package:pulse_flutter/shared/widgets/pulse_page.dart';

import 'fake_server.dart';
import 'helpers.dart' show testPreferences;

Map<String, dynamic> _items(List<Map<String, dynamic>> items) => {'items': items};

void main() {
  group('API repositories map the server payloads', () {
    test('schedule events', () async {
      final server = FakeSchoolServer()
        ..on('/schedule', _items([
          {
            'id': '4-2026-10-26', 'title': 'Data Structures', 'subject_code': 'IT201',
            'start': '2026-10-26T08:00:00+08:00', 'end': '2026-10-26T09:30:00+08:00',
            'room': 'Computer Lab 1, IT Building', 'kind': 'class', 'teacher': 'Ramon Cruz', 'note': null,
          },
        ]));
      final events = await ApiScheduleRepository(server.client()).eventsForDay(DateTime(2026, 10, 26));
      expect(events.single.title, 'Data Structures');
      expect(events.single.room, 'Computer Lab 1, IT Building');
      expect(events.single.note, 'IT201 · Ramon Cruz');
      expect(events.single.end.difference(events.single.start), const Duration(minutes: 90));
      expect(server.requests.single, 'GET /schedule');
    });

    test('tasks: list, add and complete', () async {
      final task = {
        'id': 7, 'title': 'Lab 3', 'course': 'IT202', 'due': '2026-10-31T17:00:00+08:00',
        'priority': 'high', 'completed': false, 'kind': 'assignment',
      };
      final server = FakeSchoolServer()
        ..on('/tasks', _items([task]))
        ..on('/tasks/7', {...task, 'completed': true});
      final repo = ApiTaskRepository(server.client());
      final all = await repo.all();
      expect((all.single.id, all.single.course, all.single.priority), ('7', 'IT202', 'high'));
      final done = await repo.setCompleted('7', completed: true);
      expect(done.completed, isTrue);
      expect(server.requests, contains('PATCH /tasks/7'));
    });

    test('map places are scaled from the 0-1000 grid to the canvas', () async {
      final server = FakeSchoolServer()
        ..on('/map/places', _items([
          {'id': 1, 'name': 'Gym', 'kind': 'facility', 'x': 500, 'y': 500, 'width': 100, 'height': 1000},
        ]));
      final place = (await ApiMapRepository(server.client()).places()).single;
      expect((place.x, place.y, place.width, place.height), (190.0, 110.0, 38.0, 220.0));
    });

    test('lost and found: claim a found item, resolve my own lost item', () async {
      Map<String, dynamic> item(int id, String kind, bool mine, String status) => {
            'id': id, 'kind': kind, 'name': 'Umbrella', 'category': 'other', 'location': 'Gym',
            'status': status, 'claimed': status == 'closed', 'mine': mine,
            'reported_at': '2026-10-20T08:00:00+08:00',
          };
      final server = FakeSchoolServer()
        ..on('/lost-found', {...(_items([item(1, 'found', false, 'open'), item(2, 'lost', true, 'open')]))})
        ..on('/lost-found/1/claim', item(1, 'found', false, 'claim_requested'))
        ..on('/lost-found/2/resolve', item(2, 'lost', true, 'closed'));
      final repo = ApiLostFoundRepository(server.client());
      final items = await repo.all();
      expect(items.first.name, 'Found: Umbrella');
      expect((await repo.setClaimed('1', claimed: true)).claimed, isTrue);
      expect((await repo.setClaimed('2', claimed: true)).claimed, isTrue);
      expect(server.requests, containsAll(['POST /lost-found/1/claim', 'POST /lost-found/2/resolve']));
    });

    test('library reserve and support tickets', () async {
      final server = FakeSchoolServer()
        ..on('/library/3/reserve', {
          'id': 3, 'title': 'Clean Code', 'author': 'Martin', 'shelf': 'A1', 'available': false,
          'featured': true, 'my_reservation': 'reserved',
        })
        ..on('/support/tickets', _items([
          {
            'id': 1, 'subject': 'Card', 'body': 'Help', 'status': 'answered', 'reply': 'Visit the registrar.',
            'created_at': '2026-10-20T08:00:00+08:00', 'replied_at': '2026-10-20T09:00:00+08:00',
          },
        ]));
      final book = await ApiLibraryRepository(server.client()).reserve('3');
      expect((book.available, book.featured), (false, true));
      final tickets = await ApiSupportRepository(server.client()).tickets();
      expect((tickets.single.status, tickets.single.reply), ('answered', 'Visit the registrar.'));
    });

    test('attendance range reads the calendar and the rate', () {
      final range = AttendanceRange.fromJson({
        'from': '2026-10-01', 'to': '2026-10-31',
        'days': <dynamic>[],
        'summary': {'complete': 3, 'incomplete': 0, 'pending': 0, 'present': 2, 'late': 1, 'absent': 1,
          'excused': 0, 'rate': 75.0},
        'calendar': [
          {'date': '2026-10-19', 'day_status': 'late', 'late_minutes': 22},
          {'date': '2026-10-20', 'day_status': 'absent', 'late_minutes': 0},
        ],
      });
      expect(range.summary.rate, 75.0);
      expect(range.calendar.first.lateMinutes, 22);
      expect(range.calendar.last.dayStatus, 'absent');
    });
  });

  testWidgets('signed in, features use the server and the sample chip is gone', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = FakeSchoolServer()
      ..on('/home', homePayload())
      ..on('/me', {...homePayload()['profile'] as Map, 'preferences': {}, 'unread_count': 0})
      ..on('/attendance/today', homePayload()['today'] as Object)
      ..on('/notifications', {'items': <dynamic>[], 'next_before': null})
      ..on('/notifications/unread-count', {'total': 0, 'by_category': {}})
      ..on('/tasks', _items(<Map<String, dynamic>>[]))
      ..onRaw('/schedule', (r) {
        final now = DateTime.now();
        final start = now.add(const Duration(hours: 1));
        return http.Response(
          jsonEncode(_items([
            {'id': 'x', 'title': 'Web Development', 'start': start.toIso8601String(),
              'end': start.add(const Duration(hours: 1)).toIso8601String(), 'room': 'Lab 2, IT Building',
              'kind': 'class'},
          ])),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    final store = FakeTokenStore()
      ..access = 'test-access-token'
      ..refresh = 'test-refresh-token';
    final api = server.client(store: store);
    final auth = AuthController(api: api, tokenStore: store);
    await auth.restore();
    final PreferencesStore preferences = await testPreferences();
    final router = buildRouter(buildRouteBuilders(), auth: auth);
    addTearDown(router.dispose);

    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        preferencesStoreProvider.overrideWithValue(preferences),
        apiClientProvider.overrideWithValue(api),
        authControllerProvider.overrideWithValue(auth),
      ],
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return MaterialApp.router(theme: buildPulseTheme(PulseThemeName.dark.tokens), routerConfig: router);
      }),
    ));
    await tester.pumpAndSettle();

    expect(captured.read(usingSampleDataProvider), isFalse);
    expect(captured.read(scheduleRepositoryProvider), isA<ApiScheduleRepository>());
    expect(find.byType(SampleDataChip), findsNothing);
    expect(find.text('Web Development'), findsOneWidget);
    expect(server.requests, containsAll(['GET /schedule', 'GET /tasks']));

    await auth.signOut();
    await tester.pumpAndSettle();
    expect(captured.read(usingSampleDataProvider), isTrue);
    expect(captured.read(scheduleRepositoryProvider), isA<SampleScheduleRepository>());
  });
}
