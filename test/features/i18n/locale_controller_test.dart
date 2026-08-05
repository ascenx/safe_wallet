import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  ProviderContainer buildContainer(LocalePreferenceStore store) {
    final container = ProviderContainer(
      overrides: [localePreferenceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('LocaleController', () {
    test('defaults to following the system locale', () async {
      final container = buildContainer(InMemoryLocalePreferenceStore());

      final mode = await container.read(localeControllerProvider.future);

      expect(mode, AppLocaleMode.system);
      expect(mode.locale, isNull);
    });

    test('changes to a manual language selection', () async {
      final container = buildContainer(InMemoryLocalePreferenceStore());

      await container.read(localeControllerProvider.notifier).setMode(
            AppLocaleMode.en,
          );

      expect(
        await container.read(localeControllerProvider.future),
        AppLocaleMode.en,
      );
      expect(AppLocaleMode.en.locale, const Locale('en'));
      expect(AppLocaleMode.zh.locale, const Locale('zh'));
    });

    test('persists manual language changes through the store', () async {
      final store = InMemoryLocalePreferenceStore();
      final firstContainer = buildContainer(store);

      await firstContainer.read(localeControllerProvider.notifier).setMode(
            AppLocaleMode.zh,
          );

      final secondContainer = buildContainer(store);

      expect(
        await secondContainer.read(localeControllerProvider.future),
        AppLocaleMode.zh,
      );
    });

    test(
      'Hive store keeps the selected language after reopening storage',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'safe_wallet_locale_test_',
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
        final store = HiveLocalePreferenceStore(registry: registry);

        await store.saveLocaleMode(AppLocaleMode.en);
        await Hive.close();

        final reopenedRegistry = await StorageInitializer(
          path: tempDirectory.path,
        ).initialize();
        final reopenedStore = HiveLocalePreferenceStore(
          registry: reopenedRegistry,
        );

        expect(await reopenedStore.readLocaleMode(), AppLocaleMode.en);
      },
    );
  });
}
