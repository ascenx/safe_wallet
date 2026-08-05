import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/wallet/data/hive_wallet_repository.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';
import 'package:safe_wallet/shared/crypto/wallet_crypto_service.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('high-risk wallet operations', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

    late Directory tempDirectory;
    late HiveWalletRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_high_risk_operation_test_',
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

    test('export mnemonic requires the current wallet password', () async {
      final account = await repository.createWallet(
        password: 'correct-password',
      );

      await expectLater(
        repository.exportSecret(
          walletId: account.id,
          password: 'wrong-password',
          secretType: WalletSecretType.mnemonic,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      expect(
        await repository.exportSecret(
          walletId: account.id,
          password: 'correct-password',
          secretType: WalletSecretType.mnemonic,
        ),
        mnemonic,
      );
    });

    test('export private key requires the current wallet password', () async {
      final account = await repository.createWallet(
        password: 'correct-password',
      );

      await expectLater(
        repository.exportSecret(
          walletId: account.id,
          password: 'wrong-password',
          secretType: WalletSecretType.evmPrivateKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      expect(
        await repository.exportSecret(
          walletId: account.id,
          password: 'correct-password',
          secretType: WalletSecretType.evmPrivateKey,
        ),
        isNotEmpty,
      );
    });

    test('export BTC private key requires the current wallet password',
        () async {
      final account = await repository.createWallet(
        password: 'correct-password',
      );

      await expectLater(
        repository.exportSecret(
          walletId: account.id,
          password: 'wrong-password',
          secretType: WalletSecretType.btcPrivateKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      expect(
        await repository.exportSecret(
          walletId: account.id,
          password: 'correct-password',
          secretType: WalletSecretType.btcPrivateKey,
        ),
        isNotEmpty,
      );
    });

    test('delete wallet requires password and removes only after verification',
        () async {
      final account = await repository.createWallet(
        password: 'correct-password',
      );

      await expectLater(
        repository.deleteWallet(
          walletId: account.id,
          password: 'wrong-password',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      expect(await repository.getWallets(), contains(account));

      await repository.deleteWallet(
        walletId: account.id,
        password: 'correct-password',
      );

      expect(await repository.getWallets(), isEmpty);
    });

    test('change password requires current password before re-encrypting',
        () async {
      final account = await repository.createWallet(
        password: 'old-password',
      );

      await expectLater(
        repository.changePassword(
          walletId: account.id,
          currentPassword: 'wrong-password',
          newPassword: 'new-password',
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      await repository.unlock(walletId: account.id, password: 'old-password');

      await repository.changePassword(
        walletId: account.id,
        currentPassword: 'old-password',
        newPassword: 'new-password',
      );

      await expectLater(
        repository.unlock(walletId: account.id, password: 'old-password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final unlockResult = await repository.unlock(
        walletId: account.id,
        password: 'new-password',
      );
      expect(unlockResult.account, account);
    });
  });
}
