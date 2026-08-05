import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/assets/data/hive_token_price_store.dart';
import 'package:safe_wallet/features/assets/data/token_price_repository.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('HiveTokenPriceStore', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_token_price_store_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('persists token prices across storage reopen', () async {
      final registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final store = HiveTokenPriceStore(registry: registry);
      final entry = TokenPriceCacheEntry(
        quote: TokenPriceQuote(
          priceUsd: 3000,
          source: TokenPriceSource.coinGecko,
          updatedAt: DateTime.utc(2026, 6, 8, 1),
        ),
        expiresAt: DateTime.utc(2026, 6, 8, 1, 2),
      );

      await store.putAll({'1:native': entry});
      await Hive.close();

      final reopenedRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final reopenedStore = HiveTokenPriceStore(registry: reopenedRegistry);

      final loaded = await reopenedStore.getAll(['1:native']);

      expect(loaded['1:native'], entry);
    });
  });
}
