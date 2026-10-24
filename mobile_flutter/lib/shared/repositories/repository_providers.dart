import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/storage/preferences_store.dart';
import '../../data/repositories/api_repositories.dart';
import 'demo/demo_sample_repositories.dart';
import 'repositories.dart';

/// The demo scenario the sample repositories use.
///
/// The student picks it in Settings, so the loading, empty, error, offline
/// and permission-denied states can be demonstrated.
class DemoScenarioController extends Notifier<DemoScenario> {
  @override
  DemoScenario build() {
    final stored = ref
        .read(preferencesStoreProvider)
        .getString(PrefKeys.demoScenario);
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

/// Whether the feature repositories serve the built-in sample data.
///
/// They serve the school server whenever a student is signed in, unless the
/// app was built in demo mode.
final usingSampleDataProvider = Provider<bool>((ref) {
  if (kDemoMode) return true;
  return ref.watch(apiClientProvider) == null ||
      ref.watch(authStatusProvider) != AuthStatus.signedIn;
});

/// The API client when the feature repositories should use it, else null.
final _liveApiProvider = Provider<ApiClient?>((ref) {
  return ref.watch(usingSampleDataProvider)
      ? null
      : ref.watch(apiClientProvider);
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiScheduleRepository(api)
      : SampleScheduleRepository(ref.watch(demoScenarioProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiTaskRepository(api)
      : SampleTaskRepository(ref.watch(demoScenarioProvider));
});

/// The sample updates. Signed in, the Updates tab reads the real inbox instead.
final updatesRepositoryProvider = Provider<UpdatesRepository>((ref) {
  return SampleUpdatesRepository(ref.watch(demoScenarioProvider));
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiRoomRepository(api)
      : SampleRoomRepository(ref.watch(demoScenarioProvider));
});

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiDirectoryRepository(api)
      : SampleDirectoryRepository(ref.watch(demoScenarioProvider));
});

final lostFoundRepositoryProvider = Provider<LostFoundRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiLostFoundRepository(api)
      : SampleLostFoundRepository(ref.watch(demoScenarioProvider));
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiLibraryRepository(api)
      : SampleLibraryRepository(ref.watch(demoScenarioProvider));
});

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiMapRepository(api)
      : SampleMapRepository(ref.watch(demoScenarioProvider));
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final api = ref.watch(_liveApiProvider);
  return api != null
      ? ApiSupportRepository(api)
      : SampleSupportRepository(ref.watch(demoScenarioProvider));
});
