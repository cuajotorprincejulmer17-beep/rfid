import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The preferences store, shared by every controller that persists a setting.
///
/// It is overridden at the root of the app with the real store, and in tests
/// with a store built from `SharedPreferences.setMockInitialValues`.
final preferencesStoreProvider = Provider<PreferencesStore>((ref) {
  throw UnimplementedError(
    'The preferences store must be overridden at the root of the app.',
  );
});

/// The non-secret preferences the app persists.
///
/// Everything here is a user preference or a local demo setting. No token,
/// no credential and no school data ever goes through this store.
abstract final class PrefKeys {
  /// The chosen theme: one of the `PulseThemeName` names.
  static const String theme = 'pulse.theme';

  /// How the app treats motion: `system`, `on`, `off`.
  static const String reduceMotion = 'pulse.reduceMotion';

  /// Whether haptics fire.
  static const String haptics = 'pulse.haptics';

  /// The demo scenario the sample repositories use.
  static const String demoScenario = 'pulse.demoScenario';

  /// The display name the student edited on the Profile page.
  static const String displayName = 'pulse.displayName';

  /// The school server address, e.g. `http://192.168.1.20:5001`.
  static const String serverUrl = 'pulse.serverUrl';
}

/// A thin wrapper over [SharedPreferences] so the rest of the app never
/// touches the plugin directly and tests can seed it with
/// `SharedPreferences.setMockInitialValues`.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesStore> open() async =>
      PreferencesStore(await SharedPreferences.getInstance());

  /// Reads a string, or null when it was never set.
  String? getString(String key) => _prefs.getString(key);

  /// Writes a string. Returns false when the write failed.
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  /// Reads a boolean, or null when it was never set.
  bool? getBool(String key) => _prefs.getBool(key);

  /// Writes a boolean. Returns false when the write failed.
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  /// Removes a key. Returns false when the removal failed.
  Future<bool> remove(String key) => _prefs.remove(key);
}
