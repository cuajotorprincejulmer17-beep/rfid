import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/pulse_app.dart';
import 'app/session.dart';
import 'core/accessibility/motion_preferences.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/token_store.dart';
import 'core/storage/preferences_store.dart';
import 'features/splash/pulse_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await PreferencesStore.open();
  final tokenStore = SecureTokenStore();
  // The server address is a plain address, never a secret. The student can
  // change it in Settings; the build-time default is the fallback.
  final storedUrl = preferences.getString(PrefKeys.serverUrl);
  final api = ApiClient(
    baseUrl: (storedUrl == null || storedUrl.isEmpty)
        ? kDefaultServerUrl
        : storedUrl,
    tokenStore: tokenStore,
  );
  final auth = AuthController(api: api, tokenStore: tokenStore);

  // When a refresh fails the session is gone; route back to sign-in.
  api.onSessionExpired = auth.onSessionExpired;

  await auth.restore();

  runApp(
    PulseProviderScope(
      preferences: preferences,
      api: api,
      auth: auth,
      child: PulseBootstrap(api: api, auth: auth, tokenStore: tokenStore),
    ),
  );
}

/// The app root, which owns the cold-start splash.
///
/// The splash is shown on cold start only. It is never persisted, so a warm
/// start goes straight to the app.
class PulseBootstrap extends ConsumerStatefulWidget {
  const PulseBootstrap({
    super.key,
    required this.api,
    required this.auth,
    required this.tokenStore,
  });

  final ApiClient api;
  final AuthController auth;
  final TokenStore tokenStore;

  @override
  ConsumerState<PulseBootstrap> createState() => _PulseBootstrapState();
}

class _PulseBootstrapState extends ConsumerState<PulseBootstrap> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    // Watched so the splash rebuilds when the preference changes.
    ref.watch(reduceMotionControllerProvider);

    // The splash sits above MaterialApp, so it supplies its own direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          const PulseApp(),
          if (!_splashDone)
            Positioned.fill(
              child: PulseSplashScreen(
                onFinished: () {
                  if (mounted) setState(() => _splashDone = true);
                },
              ),
            ),
        ],
      ),
    );
  }
}
