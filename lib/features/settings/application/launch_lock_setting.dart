import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

final launchLockSettingStoreProvider = Provider<LaunchLockSettingStore>(
  (ref) => InMemoryLaunchLockSettingStore(),
);

final launchLockSettingProvider =
    AsyncNotifierProvider<LaunchLockSettingController, bool>(
  LaunchLockSettingController.new,
);

abstract interface class LaunchLockSettingStore {
  Future<bool> readRequirePasswordOnLaunch();

  Future<void> saveRequirePasswordOnLaunch(bool value);
}

final class InMemoryLaunchLockSettingStore implements LaunchLockSettingStore {
  InMemoryLaunchLockSettingStore({bool? requirePasswordOnLaunch})
      : _requirePasswordOnLaunch = requirePasswordOnLaunch;

  bool? _requirePasswordOnLaunch;

  @override
  Future<bool> readRequirePasswordOnLaunch() async {
    return _requirePasswordOnLaunch ?? true;
  }

  @override
  Future<void> saveRequirePasswordOnLaunch(bool value) async {
    _requirePasswordOnLaunch = value;
  }
}

final class HiveLaunchLockSettingStore implements LaunchLockSettingStore {
  HiveLaunchLockSettingStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<bool> readRequirePasswordOnLaunch() async {
    final value = _registry.settingsBox.get(
      StorageKeys.requirePasswordOnLaunch,
    );
    return value is bool ? value : true;
  }

  @override
  Future<void> saveRequirePasswordOnLaunch(bool value) {
    return _registry.settingsBox.put(
      StorageKeys.requirePasswordOnLaunch,
      value,
    );
  }
}

final class LaunchLockSettingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref
        .read(launchLockSettingStoreProvider)
        .readRequirePasswordOnLaunch();
  }

  Future<void> setRequirePasswordOnLaunch(bool value) async {
    state = AsyncData(value);
    await ref
        .read(launchLockSettingStoreProvider)
        .saveRequirePasswordOnLaunch(value);
  }
}
