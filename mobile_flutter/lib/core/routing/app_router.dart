import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/auth/auth_pages.dart';
import '../../navigation/app_destination.dart';
import '../../navigation/destination_registry.dart';
import '../auth/auth_controller.dart';

/// The sign-in routes. They sit outside the registry: they are not
/// destinations a signed-in student can navigate to.
const String kSignInRoute = '/sign-in';
const String kClaimRoute = '/claim';

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
///
/// When [auth] is given, a signed-out student can only reach the sign-in
/// and claim pages, and a signed-in student is sent away from them.
GoRouter buildRouter(
  Map<String, GoRouterWidgetBuilder> builders, {
  AuthController? auth,
}) {
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
    refreshListenable: auth,
    redirect: auth == null
        ? null
        : (context, state) {
            final onAuthPage = state.matchedLocation == kSignInRoute ||
                state.matchedLocation == kClaimRoute;
            if (!auth.isSignedIn) return onAuthPage ? null : kSignInRoute;
            return onAuthPage ? '/home' : null;
          },
    routes: [
      // ------------------------------------------------------- sign-in
      if (auth != null) ...[
        GoRoute(
          path: kSignInRoute,
          builder: (context, state) => const SignInPage(),
        ),
        GoRoute(
          path: kClaimRoute,
          builder: (context, state) => const ClaimAccountPage(),
        ),
      ],

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
