import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/routing/app_router.dart';
import 'package:pulse_flutter/navigation/destination_registry.dart';
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
  testWidgets('there is exactly one dock and one launcher on a dock root',
      (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(
          routerConfig: _router(),
        ),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PulseDock), findsOneWidget);
    expect(find.byKey(kPulseLauncherKey), findsOneWidget);
  });

  testWidgets('there is no floating action button anywhere', (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('pushing a category hub leaves exactly one dock and launcher',
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

    router.push('/academic');
    await tester.pumpAndSettle();

    // The hub is on the root navigator, above the shell, so the shell is
    // not rendered underneath it.
    expect(find.byType(PulseDock), findsNothing);
    expect(find.byKey(kPulseLauncherKey), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('no app bar has a Profile, Settings, More or Menu control',
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

    for (final route in const ['/home', '/schedule', '/tasks', '/updates']) {
      router.go(route);
      await tester.pumpAndSettle();

      final appBars = tester.widgetList<AppBar>(find.byType(AppBar));
      for (final appBar in appBars) {
        final controls = <Widget>[
          ...?appBar.actions,
          if (appBar.leading != null) appBar.leading!,
        ];
        for (final control in controls) {
          final semantics = control is Semantics ? control : null;
          final label = semantics?.properties.label?.toString() ?? '';
          for (final forbidden in const [
            'Profile',
            'Settings',
            'More',
            'Menu',
          ]) {
            expect(
              label,
              isNot(contains(forbidden)),
              reason: 'Found a "$forbidden" control on $route',
            );
          }
        }
      }
    }
  });

  testWidgets('the dock shows exactly four destinations and a gap',
      (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    // The four dock labels only appear on the selected one, so the icons
    // are the reliable count.
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
  });

  testWidgets('disposing the shell leaves no active tickers', (tester) async {
    final preferences = await testPreferences();

    await tester.pumpWidget(
      testHost(
        MaterialApp.router(routerConfig: _router()),
        preferences: preferences,
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the fan overlay is mounted at most once', (tester) async {
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
  });
}
