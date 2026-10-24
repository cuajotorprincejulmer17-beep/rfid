import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_controller.dart';
import '../core/storage/preferences_store.dart';

/// The default school server, supplied at build time with
/// `--dart-define=API_BASE_URL=...`. The student can change it in Settings.
///
/// The default points at the host machine as the Android emulator sees it,
/// because a phone cannot reach `localhost`.
const String kDefaultServerUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5001',
);

/// Build with `--dart-define=DEMO=true` to show the built-in sample data even
/// when signed in (for demonstrating the app without a school server).
const bool kDemoMode = bool.fromEnvironment('DEMO');

/// The API client. Overridden at the root of the app.
///
/// It is null when the app runs without a backend (tests, previews), and
/// every real-data provider then reports "not connected" rather than
/// inventing data.
final apiClientProvider = Provider<ApiClient?>((ref) => null);

/// The auth controller. Overridden at the root of the app.
final authControllerProvider = Provider<AuthController?>((ref) => null);

/// The current auth status, kept in step with [AuthController].
class AuthStatusNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    final auth = ref.watch(authControllerProvider);
    if (auth == null) return AuthStatus.signedOut;
    void listener() => state = auth.status;
    auth.addListener(listener);
    ref.onDispose(() => auth.removeListener(listener));
    return auth.status;
  }
}

final authStatusProvider = NotifierProvider<AuthStatusNotifier, AuthStatus>(
  AuthStatusNotifier.new,
);

/// The school server address the app talks to.
class ServerUrlController extends Notifier<String> {
  @override
  String build() {
    final stored =
        ref.read(preferencesStoreProvider).getString(PrefKeys.serverUrl);
    return (stored == null || stored.isEmpty) ? kDefaultServerUrl : stored;
  }

  /// Switches to [value].
  ///
  /// Tokens belong to the server that issued them, so moving to a different
  /// server signs the student out first.
  Future<void> setUrl(String value) async {
    final url = normaliseServerUrl(value);
    if (url == state) return;
    final auth = ref.read(authControllerProvider);
    if (auth != null && auth.isSignedIn) await auth.signOut();
    ref.read(apiClientProvider)?.baseUrl = url;
    state = url;
    await ref.read(preferencesStoreProvider).setString(PrefKeys.serverUrl, url);
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlController, String>(
  ServerUrlController.new,
);

/// Trims [value], adds `http://` when no scheme was typed and drops a
/// trailing slash, so `192.168.1.20:5001/` becomes `http://192.168.1.20:5001`.
String normaliseServerUrl(String value) {
  var url = value.trim();
  if (url.isEmpty) return kDefaultServerUrl;
  if (!url.contains('://')) url = 'http://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// Whether [value] looks like a usable server address.
bool isValidServerUrl(String value) {
  final uri = Uri.tryParse(normaliseServerUrl(value));
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
