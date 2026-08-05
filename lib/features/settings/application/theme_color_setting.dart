import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

final themeColorSettingStoreProvider = Provider<ThemeColorSettingStore>(
  (ref) => InMemoryThemeColorSettingStore(),
);

final themeColorSettingProvider =
    AsyncNotifierProvider<ThemeColorSettingController, AppThemeColor>(
  ThemeColorSettingController.new,
);

abstract interface class ThemeColorSettingStore {
  Future<String?> readThemeColorId();

  Future<void> saveThemeColorId(String value);
}

final class InMemoryThemeColorSettingStore implements ThemeColorSettingStore {
  InMemoryThemeColorSettingStore({String? themeColorId})
      : _themeColorId = themeColorId;

  String? _themeColorId;

  @override
  Future<String?> readThemeColorId() async => _themeColorId;

  @override
  Future<void> saveThemeColorId(String value) async {
    _themeColorId = value;
  }
}

final class HiveThemeColorSettingStore implements ThemeColorSettingStore {
  HiveThemeColorSettingStore({required HiveBoxRegistry registry})
      : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<String?> readThemeColorId() async {
    final value = _registry.settingsBox.get(StorageKeys.themeColorId);
    return value is String ? value : null;
  }

  @override
  Future<void> saveThemeColorId(String value) {
    return _registry.settingsBox.put(StorageKeys.themeColorId, value);
  }
}

final class ThemeColorSettingController extends AsyncNotifier<AppThemeColor> {
  @override
  Future<AppThemeColor> build() async {
    final storedId =
        await ref.read(themeColorSettingStoreProvider).readThemeColorId();
    return AppThemeColor.values
            .where((color) => color.name == storedId)
            .firstOrNull ??
        AppThemeColor.indigo;
  }

  Future<void> setThemeColor(AppThemeColor value) async {
    state = AsyncData(value);
    await ref.read(themeColorSettingStoreProvider).saveThemeColorId(value.name);
  }
}
