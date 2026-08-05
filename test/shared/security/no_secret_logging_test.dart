import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/wallet/data/hive_wallet_repository.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';
import 'package:safe_wallet/shared/crypto/wallet_crypto_service.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('secret logging leakage', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const privateKey =
        '4c0883a69102937d6231471b5dbb6204fe512961708279ded5b205db7368a7f5';

    late Directory tempDirectory;
    late HiveWalletRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_secret_logging_test_',
      );
      final registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      repository = HiveWalletRepository(
        registry: registry,
        walletCryptoService: WalletCryptoService(
          kdfService: const KdfService(iterations: 1000),
        ),
        mnemonicFactory: () => mnemonic,
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('mnemonic words are not emitted during create import unlock failures',
        () async {
      final logs = await _captureLogs(() async {
        await expectLater(
          HiveWalletRepository(
            registry: await StorageInitializer(
              path: tempDirectory.path,
            ).initialize(),
            mnemonicFactory: () => 'invalid mnemonic words',
          ).createWallet(password: 'StrongPass-123'),
          throwsA(isA<WalletError>()),
        );
        await expectLater(
          repository.importMnemonicWallet(
            mnemonic: 'invalid $mnemonic',
            password: 'StrongPass-123',
          ),
          throwsA(isA<WalletError>()),
        );
        final account = await repository.importMnemonicWallet(
          mnemonic: mnemonic,
          password: 'correct-password',
        );
        await expectLater(
          repository.unlock(
            walletId: account.id,
            password: 'wrong-password',
          ),
          throwsA(isA<Object>()),
        );
      });

      for (final word in mnemonic.split(' ').toSet()) {
        expect(logs, isNot(contains(word)));
      }
    });

    test('private key is not emitted in logs or error messages', () async {
      Object? caughtError;
      final logs = await _captureLogs(() async {
        try {
          await repository.importPrivateKeyWallet(
            privateKey: 'not-a-key-$privateKey',
            password: 'StrongPass-123',
          );
        } catch (error) {
          caughtError = error;
        }
      });

      expect(caughtError, isNotNull);
      expect(logs, isNot(contains(privateKey)));
      expect(caughtError.toString(), isNot(contains(privateKey)));
    });

    test('Sui private key is not emitted in logs or error messages', () async {
      const suiPrivateKey =
          'suiprivkey1qrwsjvr6gwaxmsvxk4cfun99ra8uwxg3c9pl0nhle7xxpe4s80y05ctazer';
      Object? caughtError;
      final logs = await _captureLogs(() async {
        try {
          await repository.importPrivateKeyWallet(
            privateKey: '${suiPrivateKey}invalid',
            password: 'StrongPass-123',
            chain: WalletPrivateKeyChain.sui,
          );
        } catch (error) {
          caughtError = error;
        }
      });

      expect(caughtError, isNotNull);
      expect(logs, isNot(contains(suiPrivateKey)));
      expect(caughtError.toString(), isNot(contains(suiPrivateKey)));
    });
  });
}

Future<String> _captureLogs(Future<void> Function() action) async {
  final buffer = StringBuffer();
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      buffer.writeln(message);
    }
  };
  try {
    await runZoned(
      action,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          buffer.writeln(line);
        },
      ),
    );
  } finally {
    debugPrint = previousDebugPrint;
  }
  return buffer.toString();
}
