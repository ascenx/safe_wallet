import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

final backgroundPrivacyShieldSettingStoreProvider =
    Provider<BackgroundPrivacyShieldSettingStore>(
  (ref) => InMemoryBackgroundPrivacyShieldSettingStore(),
);

final backgroundPrivacyShieldSettingProvider =
    AsyncNotifierProvider<BackgroundPrivacyShieldSettingController, bool>(
  BackgroundPrivacyShieldSettingController.new,
);

abstract interface class BackgroundPrivacyShieldSettingStore {
  Future<bool> readEnabled();

  Future<void> saveEnabled(bool value);
}

final class InMemoryBackgroundPrivacyShieldSettingStore
    implements BackgroundPrivacyShieldSettingStore {
  InMemoryBackgroundPrivacyShieldSettingStore({bool? enabled})
      : _enabled = enabled;

  bool? _enabled;

  @override
  Future<bool> readEnabled() async => _enabled ?? true;

  @override
  Future<void> saveEnabled(bool value) async {
    _enabled = value;
  }
}

final class HiveBackgroundPrivacyShieldSettingStore
    implements BackgroundPrivacyShieldSettingStore {
  HiveBackgroundPrivacyShieldSettingStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<bool> readEnabled() async {
    final value = _registry.settingsBox.get(
      StorageKeys.backgroundPrivacyShieldEnabled,
    );
    return value is bool ? value : true;
  }

  @override
  Future<void> saveEnabled(bool value) {
    return _registry.settingsBox.put(
      StorageKeys.backgroundPrivacyShieldEnabled,
      value,
    );
  }
}

final class BackgroundPrivacyShieldSettingController
    extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    return ref.read(backgroundPrivacyShieldSettingStoreProvider).readEnabled();
  }

  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    await ref
        .read(backgroundPrivacyShieldSettingStoreProvider)
        .saveEnabled(value);
  }
}
