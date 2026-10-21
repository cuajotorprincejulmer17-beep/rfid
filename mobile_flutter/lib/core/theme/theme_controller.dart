import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';
import 'pulse_tokens.dart';

/// The user's theme choice.
class ThemeController extends Notifier<PulseThemeName> {
  @override
  PulseThemeName build() {
    final stored = ref.read(preferencesStoreProvider).getString(PrefKeys.theme);
    return PulseThemeName.values.firstWhere(
      (t) => t.name == stored,
      orElse: () => PulseThemeName.dark,
    );
  }

  /// Switches the theme and persists the choice.
  Future<void> setTheme(PulseThemeName value) async {
    if (state == value) return;
    state = value;
    await ref
        .read(preferencesStoreProvider)
        .setString(PrefKeys.theme, value.name);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, PulseThemeName>(ThemeController.new);
