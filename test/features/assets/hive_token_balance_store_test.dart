import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/assets/data/hive_token_balance_store.dart';
import 'package:safe_wallet/features/assets/data/token_balance_store.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('HiveTokenBalanceStore', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_token_balance_store_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('persists token balances across storage reopen', () async {
      final registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final store = HiveTokenBalanceStore(registry: registry);
      final entry = TokenBalanceCacheEntry(
        rawBalance: '1500000000000000000',
        formattedBalance: '1.5',
        updatedAt: DateTime.utc(2026, 6, 9, 1),
        expiresAt: DateTime.utc(2026, 6, 9, 1, 1),
      );

      await store.putAll({'1:0x111:native': entry});
      await Hive.close();

      final reopenedRegistry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final reopenedStore = HiveTokenBalanceStore(registry: reopenedRegistry);

      final loaded = await reopenedStore.getAll(['1:0x111:native']);

      expect(loaded['1:0x111:native'], entry);
    });
  });
}
