import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/app_router.dart';
import '../core/storage/preferences_store.dart';
import '../core/theme/pulse_theme.dart';
import '../core/theme/pulse_tokens.dart';
import '../core/theme/theme_controller.dart';
import '../navigation/destination_registry.dart';
import 'placeholder_page.dart';

/// The Pulse app root.
///
/// It owns the router and the theme, and nothing else. The router is built
/// from the destination registry, so a destination cannot exist without a
/// route.
class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key});

  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp> {
  late final GoRouter _router = buildRouter(_routeBuilders);

  /// One builder per registry id.
  final Map<String, GoRouterWidgetBuilder> _routeBuilders =
      <String, GoRouterWidgetBuilder>{
    for (final d in kDestinations)
      d.id: (context, state) => PlaceholderPage(title: d.title),
  };

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'Pulse',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: buildPulseTheme(theme.tokens),
    );
  }
}

/// The provider scope for the whole app.
class PulseProviderScope extends StatelessWidget {
  const PulseProviderScope({
    super.key,
    required this.preferences,
    required this.child,
  });

  final PreferencesStore preferences;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
      child: child,
    );
  }
}
