import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/settings/application/fiat_currency_setting.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  test('formats every fiat currency with its matching symbol', () {
    expect(formatFiatValue(1234.5, AppFiatCurrency.usd), '\$1,234.50');
    expect(formatFiatValue(1234.5, AppFiatCurrency.cny), '¥1,234.50');
    expect(formatFiatValue(1234.5, AppFiatCurrency.eur), '€1,234.50');
    expect(formatFiatValue(1234.5, AppFiatCurrency.jpy), '¥1,234.50');
    expect(formatFiatValue(-8, AppFiatCurrency.cny), '-¥8.00');
  });

  group('FiatCurrencySettingController', () {
    ProviderContainer buildContainer(FiatCurrencySettingStore store) {
      final container = ProviderContainer(
        overrides: [
          fiatCurrencySettingStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('uses USD by default', () async {
      final container = buildContainer(InMemoryFiatCurrencySettingStore());

      expect(
        await container.read(fiatCurrencySettingProvider.future),
        AppFiatCurrency.usd,
      );
    });

    test('persists the selected fiat currency through the store', () async {
      final store = InMemoryFiatCurrencySettingStore();
      final firstContainer = buildContainer(store);

      await firstContainer
          .read(fiatCurrencySettingProvider.notifier)
          .setCurrency(AppFiatCurrency.cny);

      final secondContainer = buildContainer(store);
      expect(
        await secondContainer.read(fiatCurrencySettingProvider.future),
        AppFiatCurrency.cny,
      );
    });

    test('falls back to USD for an unknown stored code', () async {
      final container = buildContainer(
        InMemoryFiatCurrencySettingStore(currencyCode: 'UNKNOWN'),
      );

      expect(
        await container.read(fiatCurrencySettingProvider.future),
        AppFiatCurrency.usd,
      );
    });

    test('Hive store keeps the selected currency after reopening storage',
        () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_fiat_currency_test_',
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
      final store = HiveFiatCurrencySettingStore(registry: registry);

      await store.saveCurrencyCode(AppFiatCurrency.eur.code);
      await Hive.close();

      final reopenedRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final reopenedStore = HiveFiatCurrencySettingStore(
        registry: reopenedRegistry,
      );

      expect(
        await reopenedStore.readCurrencyCode(),
        AppFiatCurrency.eur.code,
      );
    });
  });
}
