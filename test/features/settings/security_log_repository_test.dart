import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('HiveSecurityLogRepository', () {
    late Directory tempDirectory;
    late HiveSecurityLogRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_security_log_test_',
      );
      final registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      repository = HiveSecurityLogRepository(registry: registry, maxEntries: 2);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('records events without requiring an enable setting', () async {
      await repository.record(
        SecurityLogEventType.createWallet,
        occurredAt: DateTime.utc(2026, 7, 31, 9),
      );

      expect(await repository.listEntries(), [
        SecurityLogEntry(
          type: SecurityLogEventType.createWallet,
          occurredAt: DateTime.utc(2026, 7, 31, 9),
        ),
      ]);
    });

    test('returns newest successful events first', () async {
      await repository.record(
        SecurityLogEventType.createWallet,
        occurredAt: DateTime.utc(2026, 7, 31, 9),
      );
      await repository.record(
        SecurityLogEventType.viewMnemonic,
        walletName: 'Main Wallet',
        occurredAt: DateTime.utc(2026, 7, 31, 10),
      );
      expect(await repository.listEntries(), [
        SecurityLogEntry(
          type: SecurityLogEventType.viewMnemonic,
          walletName: 'Main Wallet',
          occurredAt: DateTime.utc(2026, 7, 31, 10),
        ),
        SecurityLogEntry(
          type: SecurityLogEventType.createWallet,
          occurredAt: DateTime.utc(2026, 7, 31, 9),
        ),
      ]);
    });

    test(
      'persists wallet and chain context without sensitive material',
      () async {
        await repository.record(
          SecurityLogEventType.signTransaction,
          walletName: 'Trading Wallet',
          chainName: 'EVM',
          assetSymbol: 'ETH',
          amount: '0.25',
          occurredAt: DateTime.utc(2026, 7, 31, 11),
        );

        expect(
          (await repository.listEntries()).single,
          SecurityLogEntry(
            type: SecurityLogEventType.signTransaction,
            walletName: 'Trading Wallet',
            chainName: 'EVM',
            assetSymbol: 'ETH',
            amount: '0.25',
            occurredAt: DateTime.utc(2026, 7, 31, 11),
          ),
        );
      },
    );

    test('persists wrapped native security events', () async {
      await repository.record(
        SecurityLogEventType.wrapNative,
        walletName: 'Main Wallet',
        chainName: 'Ethereum',
        assetSymbol: 'ETH',
        amount: '1',
        occurredAt: DateTime.utc(2026, 8, 4),
      );

      final entry = (await repository.listEntries()).single;
      expect(entry.type, SecurityLogEventType.wrapNative);
      expect(entry.assetSymbol, 'ETH');
      expect(entry.amount, '1');
    });

    test(
      'persists a public counterparty address for staking actions',
      () async {
        await repository.record(
          SecurityLogEventType.tronDelegateResource,
          walletName: 'Tron Wallet',
          chainName: 'Tron',
          assetSymbol: 'TRX',
          amount: '5',
          address: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
          occurredAt: DateTime.utc(2026, 8, 2),
        );

        expect(
          (await repository.listEntries()).single.address,
          'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
        );
      },
    );

    test('keeps only the configured number of recent events', () async {
      await repository.record(
        SecurityLogEventType.createWallet,
        occurredAt: DateTime.utc(2026, 7, 31, 8),
      );
      await repository.record(
        SecurityLogEventType.importWallet,
        occurredAt: DateTime.utc(2026, 7, 31, 9),
      );
      await repository.record(
        SecurityLogEventType.deleteWallet,
        occurredAt: DateTime.utc(2026, 7, 31, 10),
      );

      final entries = await repository.listEntries();
      expect(entries, hasLength(2));
      expect(entries.map((entry) => entry.type), [
        SecurityLogEventType.deleteWallet,
        SecurityLogEventType.importWallet,
      ]);
    });
  });
}
