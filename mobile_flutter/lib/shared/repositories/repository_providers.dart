import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/preferences_store.dart';
import 'demo/demo_sample_repositories.dart';
import 'repositories.dart';

/// The demo scenario the sample repositories use.
///
/// The student picks it in Settings, so the loading, empty, error, offline
/// and permission-denied states can be demonstrated.
class DemoScenarioController extends Notifier<DemoScenario> {
  @override
  DemoScenario build() {
    final stored =
        ref.read(preferencesStoreProvider).getString(PrefKeys.demoScenario);
    return DemoScenario.values.firstWhere(
      (s) => s.name == stored,
      orElse: () => DemoScenario.normal,
    );
  }

  /// Switches the scenario and persists the choice.
  Future<void> setScenario(DemoScenario value) async {
    if (state == value) return;
    state = value;
    await ref
        .read(preferencesStoreProvider)
        .setString(PrefKeys.demoScenario, value.name);
  }
}

final demoScenarioProvider =
    NotifierProvider<DemoScenarioController, DemoScenario>(
  DemoScenarioController.new,
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return SampleScheduleRepository(ref.watch(demoScenarioProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return SampleTaskRepository(ref.watch(demoScenarioProvider));
});

final updatesRepositoryProvider = Provider<UpdatesRepository>((ref) {
  return SampleUpdatesRepository(ref.watch(demoScenarioProvider));
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return SampleRoomRepository(ref.watch(demoScenarioProvider));
});

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  return SampleDirectoryRepository(ref.watch(demoScenarioProvider));
});

final lostFoundRepositoryProvider = Provider<LostFoundRepository>((ref) {
  return SampleLostFoundRepository(ref.watch(demoScenarioProvider));
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return SampleLibraryRepository(ref.watch(demoScenarioProvider));
});

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return SampleMapRepository(ref.watch(demoScenarioProvider));
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SampleSupportRepository(ref.watch(demoScenarioProvider));
});
