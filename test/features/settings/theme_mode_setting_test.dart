import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/settings/application/theme_mode_setting.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('ThemeModeSettingController', () {
    ProviderContainer buildContainer(ThemeModeSettingStore store) {
      final container = ProviderContainer(
        overrides: [themeModeSettingStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('uses light mode by default', () async {
      final container = buildContainer(InMemoryThemeModeSettingStore());

      expect(
        await container.read(themeModeSettingProvider.future),
        AppThemeMode.light,
      );
    });

    test('persists the selected theme mode through the store', () async {
      final store = InMemoryThemeModeSettingStore();
      final firstContainer = buildContainer(store);

      await firstContainer
          .read(themeModeSettingProvider.notifier)
          .setThemeMode(AppThemeMode.dark);

      final secondContainer = buildContainer(store);
      expect(
        await secondContainer.read(themeModeSettingProvider.future),
        AppThemeMode.dark,
      );
    });

    test('falls back to light mode for an unknown stored id', () async {
      final container = buildContainer(
        InMemoryThemeModeSettingStore(themeModeId: 'unknown-mode'),
      );

      expect(
        await container.read(themeModeSettingProvider.future),
        AppThemeMode.light,
      );
    });

    test(
      'Hive store keeps the selected mode after reopening storage',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'safe_wallet_theme_mode_test_',
        );
        addTearDown(() async {
          await Hive.close();
          if (tempDirectory.existsSync()) {
            await tempDirectory.delete(recursive: true);
          }
        });
        final registry = await StorageInitializer(
          path: tempDirectory.path,
        ).initialize();
        final store = HiveThemeModeSettingStore(registry: registry);

        await store.saveThemeModeId(AppThemeMode.system.name);
        await Hive.close();

        final reopenedRegistry = await StorageInitializer(
          path: tempDirectory.path,
        ).initialize();
        final reopenedStore = HiveThemeModeSettingStore(
          registry: reopenedRegistry,
        );

        expect(await reopenedStore.readThemeModeId(), AppThemeMode.system.name);
      },
    );
  });
}
