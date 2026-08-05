import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/settings/application/fiat_currency_setting.dart';
import 'package:safe_wallet/features/settings/data/fiat_exchange_rate_repository.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('DefaultFiatExchangeRateRepository', () {
    test('loads a USD quote from Frankfurter and caches it', () async {
      final store = InMemoryFiatExchangeRateStore();
      final now = DateTime.utc(2026, 7, 31, 8);
      final repository = DefaultFiatExchangeRateRepository(
        client: MockClient((request) async {
          expect(request.url.host, 'api.frankfurter.dev');
          expect(request.url.path, '/v2/rates');
          expect(request.url.queryParameters['base'], 'USD');
          expect(request.url.queryParameters['quotes'], 'CNY');
          return http.Response(
            '[{"date":"2026-07-30","base":"USD",'
            '"quote":"CNY","rate":6.7603}]',
            200,
          );
        }),
        store: store,
        now: () => now,
      );
      addTearDown(repository.close);

      expect(await repository.getUsdRate(AppFiatCurrency.cny), 6.7603);
      expect(
        await store.read(AppFiatCurrency.cny),
        FiatExchangeRateCacheEntry(rate: 6.7603, fetchedAt: now),
      );
    });

    test('uses a fresh cached rate without making a request', () async {
      var requested = false;
      final now = DateTime.utc(2026, 7, 31, 8);
      final store = InMemoryFiatExchangeRateStore(
        entries: {
          AppFiatCurrency.eur: FiatExchangeRateCacheEntry(
            rate: 0.87,
            fetchedAt: now.subtract(const Duration(hours: 2)),
          ),
        },
      );
      final repository = DefaultFiatExchangeRateRepository(
        client: MockClient((request) async {
          requested = true;
          return http.Response('{}', 500);
        }),
        store: store,
        now: () => now,
      );
      addTearDown(repository.close);

      expect(await repository.getUsdRate(AppFiatCurrency.eur), 0.87);
      expect(requested, isFalse);
    });

    test('falls back to a stale cached rate when the request fails', () async {
      final now = DateTime.utc(2026, 7, 31, 8);
      final store = InMemoryFiatExchangeRateStore(
        entries: {
          AppFiatCurrency.jpy: FiatExchangeRateCacheEntry(
            rate: 163.46,
            fetchedAt: now.subtract(const Duration(days: 2)),
          ),
        },
      );
      final repository = DefaultFiatExchangeRateRepository(
        client: MockClient((request) async => http.Response('{}', 503)),
        store: store,
        now: () => now,
      );
      addTearDown(repository.close);

      expect(await repository.getUsdRate(AppFiatCurrency.jpy), 163.46);
    });

    test('returns one for USD without making a request', () async {
      var requested = false;
      final repository = DefaultFiatExchangeRateRepository(
        client: MockClient((request) async {
          requested = true;
          return http.Response('{}', 500);
        }),
      );
      addTearDown(repository.close);

      expect(await repository.getUsdRate(AppFiatCurrency.usd), 1);
      expect(requested, isFalse);
    });
  });

  test('Hive rate store keeps cached rates after reopening storage', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'safe_wallet_fiat_rate_test_',
    );
    addTearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });
    final fetchedAt = DateTime.utc(2026, 7, 31, 8);
    final registry = await StorageInitializer(
      path: tempDirectory.path,
    ).initialize();
    final store = HiveFiatExchangeRateStore(registry: registry);

    await store.write(
      AppFiatCurrency.cny,
      FiatExchangeRateCacheEntry(rate: 6.7603, fetchedAt: fetchedAt),
    );
    await Hive.close();

    final reopenedRegistry = await StorageInitializer(
      path: tempDirectory.path,
    ).initialize();
    final reopenedStore = HiveFiatExchangeRateStore(
      registry: reopenedRegistry,
    );

    expect(
      await reopenedStore.read(AppFiatCurrency.cny),
      FiatExchangeRateCacheEntry(rate: 6.7603, fetchedAt: fetchedAt),
    );
  });
}
