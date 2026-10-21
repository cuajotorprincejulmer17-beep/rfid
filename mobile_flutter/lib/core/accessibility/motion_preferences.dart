import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';

/// How the app treats motion.
enum ReduceMotionSetting {
  /// Follow the system setting.
  system,

  /// Always reduce motion.
  on,

  /// Never reduce motion, even if the system asks for it.
  off;

  String get label => switch (this) {
        ReduceMotionSetting.system => 'Follow system',
        ReduceMotionSetting.on => 'On',
        ReduceMotionSetting.off => 'Off',
      };
}

/// The in-app reduce-motion switch.
///
/// The switch can only *add* restriction: "Off" still respects a system
/// request for reduced motion, because the operating system setting is an
/// accessibility guarantee.
class ReduceMotionController extends Notifier<ReduceMotionSetting> {
  @override
  ReduceMotionSetting build() {
    final stored =
        ref.read(preferencesStoreProvider).getString(PrefKeys.reduceMotion);
    return ReduceMotionSetting.values.firstWhere(
      (s) => s.name == stored,
      orElse: () => ReduceMotionSetting.system,
    );
  }

  Future<void> setSetting(ReduceMotionSetting value) async {
    if (state == value) return;
    state = value;
    await ref
        .read(preferencesStoreProvider)
        .setString(PrefKeys.reduceMotion, value.name);
  }

  /// Whether motion should be reduced given the platform setting.
  bool reduces(BuildContext context) {
    final system = MediaQuery.disableAnimationsOf(context);
    return switch (state) {
      ReduceMotionSetting.system => system,
      ReduceMotionSetting.on => true,
      ReduceMotionSetting.off => system,
    };
  }
}

final reduceMotionControllerProvider =
    NotifierProvider<ReduceMotionController, ReduceMotionSetting>(
  ReduceMotionController.new,
);

/// Whether the user wants haptic feedback.
class HapticsController extends Notifier<bool> {
  @override
  bool build() {
    return ref.read(preferencesStoreProvider).getBool(PrefKeys.haptics) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    if (state == value) return;
    state = value;
    await ref.read(preferencesStoreProvider).setBool(PrefKeys.haptics, value);
  }
}

final hapticsControllerProvider =
    NotifierProvider<HapticsController, bool>(HapticsController.new);
