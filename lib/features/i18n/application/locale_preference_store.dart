import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';
import 'app_locale_mode.dart';

abstract interface class LocalePreferenceStore {
  Future<AppLocaleMode> readLocaleMode();

  Future<void> saveLocaleMode(AppLocaleMode mode);
}

final class HiveLocalePreferenceStore implements LocalePreferenceStore {
  HiveLocalePreferenceStore({required HiveBoxRegistry registry})
    : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<AppLocaleMode> readLocaleMode() async {
    final value = _registry.settingsBox.get(StorageKeys.localeModeId);
    return AppLocaleModePersistence.fromValue(value);
  }

  @override
  Future<void> saveLocaleMode(AppLocaleMode mode) {
    return _registry.settingsBox.put(
      StorageKeys.localeModeId,
      mode.persistenceValue,
    );
  }
}

final class InMemoryLocalePreferenceStore implements LocalePreferenceStore {
  AppLocaleMode _mode;

  InMemoryLocalePreferenceStore({
    AppLocaleMode initialMode = AppLocaleMode.system,
  }) : _mode = initialMode;

  @override
  Future<AppLocaleMode> readLocaleMode() async => _mode;

  @override
  Future<void> saveLocaleMode(AppLocaleMode mode) async {
    _mode = mode;
  }
}
