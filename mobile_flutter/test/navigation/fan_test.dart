import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/routing/app_router.dart';
import 'package:pulse_flutter/core/storage/preferences_store.dart';
import 'package:pulse_flutter/navigation/destination_registry.dart';
import 'package:pulse_flutter/navigation/pulse_fan_controller.dart';
import 'package:pulse_flutter/navigation/pulse_dock.dart';
import 'package:pulse_flutter/navigation/pulse_fan_overlay.dart';
import 'package:pulse_flutter/navigation/pulse_launcher.dart';
import 'package:pulse_flutter/shared/widgets/pulse_page.dart';

import '../helpers.dart';

/// Builds the router with a stub page for every destination.
GoRouter _router() {
  return buildRouter(<String, GoRouterWidgetBuilder>{
    for (final d in kDestinations)
      d.id: (context, state) => PulsePage(title: d.title, child: const SizedBox()),
  });
}

void main() {
  testWidgets('tapping the launcher opens the fan', (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PulseFanOverlay), findsNothing);

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    expect(find.byType(PulseFanOverlay), findsOneWidget);
  });

  testWidgets('the fan shows exactly the four category hubs',
      (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    for (final category in fanCategories) {
      expect(
        find.text(category.title),
        findsOneWidget,
        reason: '${category.title} must be in the fan',
      );
    }
  });

  testWidgets('the fan never shows a dock destination', (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    for (final dock in dockDestinations) {
      expect(
        find.descendant(
          of: find.byType(PulseFanOverlay),
          matching: find.text(dock.title),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('tapping the scrim closes the fan', (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();
    expect(find.byType(PulseFanOverlay), findsOneWidget);

    // Tap the very top of the screen, away from the fan items.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(PulseFanOverlay), findsNothing);
  });

  testWidgets('a double tap on the launcher leaves a consistent state',
      (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    // The fan is either open or closed, never broken, and no exception was
    // thrown.
    expect(tester.takeException(), isNull);
    expect(
      find.byType(PulseFanOverlay).evaluate().length,
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('choosing a category pushes the route exactly once',
      (tester) async {
    final preferences = await testPreferences();
    final router = _router();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: router),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Academic'));
    await tester.pumpAndSettle();

    // The hub replaced the shell, so the dock is gone and only the hub is
    // on screen.
    expect(find.byType(PulseDock), findsNothing);
    expect(find.byKey(kPulseLauncherKey), findsNothing);
    expect(find.text('Academic'), findsOneWidget);
  });

  testWidgets('two rapid taps on a category push exactly one route',
      (tester) async {
    final preferences = await testPreferences();
    final router = _router();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: router),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Academic'));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text('Academic'));
    await tester.pumpAndSettle();

    expect(find.byType(PulseDock), findsNothing);
    expect(find.byKey(kPulseLauncherKey), findsNothing);
    // The hub is rendered once, not stacked twice.
    expect(find.text('Academic'), findsOneWidget);
  });

  testWidgets('the fan closes before the route is pushed', (tester) async {
    final preferences = await testPreferences();
    final router = _router();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: router),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Campus'));
    // The closing spring runs before the push.
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(PulseFanOverlay), findsOneWidget);
    expect(find.byType(PulseDock), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(PulseFanOverlay), findsNothing);
    expect(find.byType(PulseDock), findsNothing);
    expect(find.text('Campus'), findsOneWidget);
  });

  testWidgets('switching a dock tab closes the fan', (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kPulseLauncherKey));
    await tester.pumpAndSettle();
    expect(find.byType(PulseFanOverlay), findsOneWidget);

    await tester.tap(find.byIcon(Icons.task_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(PulseFanOverlay), findsNothing);
  });

  testWidgets('the fan state machine hands out a pending route once',
      (tester) async {
    final preferences = await testPreferences();
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(pulseFanProvider.notifier);

    notifier.open();
    expect(container.read(pulseFanProvider).phase, FanPhase.opening);

    notifier.onOpened();
    expect(container.read(pulseFanProvider).phase, FanPhase.open);

    notifier.select('/academic');
    final closing = container.read(pulseFanProvider);
    expect(closing.phase, FanPhase.closing);
    expect(closing.pendingRoute, '/academic');

    // A second selection while closing is ignored.
    notifier.select('/campus');
    expect(container.read(pulseFanProvider).pendingRoute, '/academic');

    expect(notifier.onClosed(), '/academic');
    expect(container.read(pulseFanProvider).phase, FanPhase.closed);

    // The route is handed out only once.
    expect(notifier.onClosed(), isNull);
  });

  testWidgets('reopening while closing retargets the spring',
      (tester) async {
    final preferences = await testPreferences();
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(pulseFanProvider.notifier);

    notifier.open();
    notifier.onOpened();
    notifier.close();
    expect(container.read(pulseFanProvider).phase, FanPhase.closing);

    notifier.open();
    expect(container.read(pulseFanProvider).phase, FanPhase.opening);
  });
}
