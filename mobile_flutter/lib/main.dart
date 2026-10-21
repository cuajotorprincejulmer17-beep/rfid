import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/pulse_app.dart';
import 'core/accessibility/motion_preferences.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/token_store.dart';
import 'core/storage/preferences_store.dart';
import 'features/splash/pulse_splash_screen.dart';

/// Server configuration.
///
/// The URL is supplied at build time with `--dart-define=API_BASE_URL=...`.
/// It is a plain address, never a secret. The default points at the host
/// machine's LAN address, because a phone cannot reach `localhost`.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5001',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await PreferencesStore.open();
  final tokenStore = SecureTokenStore();
  final api = ApiClient(baseUrl: kApiBaseUrl, tokenStore: tokenStore);
  final auth = AuthController(api: api, tokenStore: tokenStore);

  // When a refresh fails the session is gone; route back to sign-in.
  api.onSessionExpired = auth.onSessionExpired;

  await auth.restore();

  runApp(
    PulseProviderScope(
      preferences: preferences,
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

    return Stack(
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
    );
  }
}
