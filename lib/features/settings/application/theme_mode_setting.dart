import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get materialThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

final themeModeSettingStoreProvider = Provider<ThemeModeSettingStore>(
  (ref) => InMemoryThemeModeSettingStore(),
);

final themeModeSettingProvider =
    AsyncNotifierProvider<ThemeModeSettingController, AppThemeMode>(
      ThemeModeSettingController.new,
    );

abstract interface class ThemeModeSettingStore {
  Future<String?> readThemeModeId();

  Future<void> saveThemeModeId(String value);
}

final class InMemoryThemeModeSettingStore implements ThemeModeSettingStore {
  InMemoryThemeModeSettingStore({String? themeModeId})
    : _themeModeId = themeModeId;

  String? _themeModeId;

  @override
  Future<String?> readThemeModeId() async => _themeModeId;

  @override
  Future<void> saveThemeModeId(String value) async {
    _themeModeId = value;
  }
}

final class HiveThemeModeSettingStore implements ThemeModeSettingStore {
  HiveThemeModeSettingStore({required HiveBoxRegistry registry})
    : _registry = registry;

  final HiveBoxRegistry _registry;

  @override
  Future<String?> readThemeModeId() async {
    final value = _registry.settingsBox.get(StorageKeys.themeModeId);
    return value is String ? value : null;
  }

  @override
  Future<void> saveThemeModeId(String value) {
    return _registry.settingsBox.put(StorageKeys.themeModeId, value);
  }
}

final class ThemeModeSettingController extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() async {
    final storedId = await ref
        .read(themeModeSettingStoreProvider)
        .readThemeModeId();
    return AppThemeMode.values
            .where((mode) => mode.name == storedId)
            .firstOrNull ??
        AppThemeMode.light;
  }

  Future<void> setThemeMode(AppThemeMode value) async {
    state = AsyncData(value);
    await ref.read(themeModeSettingStoreProvider).saveThemeModeId(value.name);
  }
}
