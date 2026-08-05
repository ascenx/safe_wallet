import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/settings/application/theme_color_setting.dart';
import 'package:safe_wallet/shared/design/app_brand_colors.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('ThemeColorSettingController', () {
    ProviderContainer buildContainer(ThemeColorSettingStore store) {
      final container = ProviderContainer(
        overrides: [themeColorSettingStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('uses indigo by default', () async {
      final container = buildContainer(InMemoryThemeColorSettingStore());

      expect(
        await container.read(themeColorSettingProvider.future),
        AppThemeColor.indigo,
      );
    });

    test('persists the selected theme color through the store', () async {
      final store = InMemoryThemeColorSettingStore();
      final container = buildContainer(store);

      await container
          .read(themeColorSettingProvider.notifier)
          .setThemeColor(AppThemeColor.green);

      final restartedContainer = buildContainer(store);
      expect(
        await restartedContainer.read(themeColorSettingProvider.future),
        AppThemeColor.green,
      );
    });

    test('falls back to indigo for an unknown stored id', () async {
      final container = buildContainer(
        InMemoryThemeColorSettingStore(themeColorId: 'unknown-color'),
      );

      expect(
        await container.read(themeColorSettingProvider.future),
        AppThemeColor.indigo,
      );
    });

    test('Hive store keeps the selected color after reopening storage',
        () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_theme_color_test_',
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
      final store = HiveThemeColorSettingStore(registry: registry);

      await store.saveThemeColorId(AppThemeColor.rose.name);
      await Hive.close();

      final reopenedRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final reopenedStore = HiveThemeColorSettingStore(
        registry: reopenedRegistry,
      );

      expect(
        await reopenedStore.readThemeColorId(),
        AppThemeColor.rose.name,
      );
    });
  });
}
