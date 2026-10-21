import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../navigation/app_destination.dart';
import '../../navigation/destination_registry.dart';

/// The root navigator key.
///
/// Category hubs, features and details are pushed on the root navigator, so
/// the shell (and therefore the dock and the launcher) is not rendered
/// underneath them. That is what guarantees a second dock or launcher can
/// never appear.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'pulse-root');

/// Builds the router from the registry.
///
/// [builders] maps a registry id to the widget that renders it. Every
/// registry id must have a builder, and every builder must have a registry
/// id; the tests enforce both directions.
GoRouter buildRouter(Map<String, GoRouterWidgetBuilder> builders) {
  Widget builder(BuildContext context, GoRouterState state, String id) {
    final b = builders[id];
    if (b == null) {
      throw StateError('No route builder registered for "$id".');
    }
    return b(context, state);
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PulseShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => builder(context, state, 'home'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (context, state) => builder(context, state, 'schedule'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => builder(context, state, 'tasks'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/updates',
                builder: (context, state) => builder(context, state, 'updates'),
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------------ category hubs
      for (final id in const ['academic', 'campus', 'personal', 'support'])
        GoRoute(
          path: lookupDestination(id)!.route,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => builder(context, state, id),
        ),

      // -------------------------------------------------- category features
      for (final d in kDestinations.where((d) => d.owner == NavOwner.categoryFeature))
        GoRoute(
          path: d.route,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => builder(context, state, d.id),
        ),

      // -------------------------------------------------------- detail pages
      for (final d in kDestinations.where((d) => d.owner == NavOwner.detail))
        GoRoute(
          path: d.route,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => builder(context, state, d.id),
        ),
    ],
  );
}
