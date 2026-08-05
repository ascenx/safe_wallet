import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/wallet/data/hive_wallet_repository.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';
import 'package:safe_wallet/shared/crypto/wallet_crypto_service.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('plaintext storage leakage', () {
    const mnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const privateKey =
        '4c0883a69102937d6231471b5dbb6204fe512961708279ded5b205db7368a7f5';

    late Directory tempDirectory;
    late HiveWalletRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_plaintext_storage_test_',
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

    test('mnemonic plaintext is not found in Hive files', () async {
      await repository.createWallet(password: 'StrongPass-123');
      await Hive.close();

      final storedText = _storageText(tempDirectory);

      expect(storedText, isNot(contains(mnemonic)));
      for (final word in mnemonic.split(' ').toSet()) {
        expect(storedText, isNot(contains(word)));
      }
    });

    test('private key plaintext is not found in Hive files', () async {
      await repository.importPrivateKeyWallet(
        privateKey: privateKey,
        password: 'StrongPass-123',
      );
      await Hive.close();

      final storedText = _storageText(tempDirectory).toLowerCase();

      expect(storedText, isNot(contains(privateKey)));
      expect(storedText, isNot(contains('0x$privateKey')));
    });

    test('Sui suiprivkey plaintext is not found in Hive files', () async {
      const suiPrivateKey =
          'suiprivkey1qrwsjvr6gwaxmsvxk4cfun99ra8uwxg3c9pl0nhle7xxpe4s80y05ctazer';
      await repository.importPrivateKeyWallet(
        privateKey: suiPrivateKey,
        password: 'StrongPass-123',
        chain: WalletPrivateKeyChain.sui,
      );
      await Hive.close();

      final storedText = _storageText(tempDirectory);

      expect(storedText, isNot(contains(suiPrivateKey)));
    });

    test('derived encryption keys are not serialized', () async {
      await repository.createWallet(password: 'StrongPass-123');
      await Hive.close();

      final storedText = _storageText(tempDirectory);

      expect(storedText, isNot(contains('walletDEK')));
      expect(storedText, isNot(contains('passwordKEK')));
      expect(storedText, isNot(contains('walletDek')));
      expect(storedText, isNot(contains('passwordKek')));
    });
  });
}

String _storageText(Directory directory) {
  final bytes = <int>[];
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File) {
      bytes.addAll(entity.readAsBytesSync());
    }
  }
  return latin1.decode(bytes, allowInvalid: true);
}
