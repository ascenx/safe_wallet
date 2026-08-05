import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/shared/crypto/aes_gcm_service.dart';
import 'package:safe_wallet/shared/crypto/encrypted_payload.dart';
import 'package:safe_wallet/shared/crypto/encrypted_payload_codec.dart';
import 'package:solana_sdk/solana_sdk.dart';
import 'package:safe_wallet/features/wallet/data/hive_wallet_repository.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/crypto/kdf_service.dart';
import 'package:safe_wallet/shared/crypto/wallet_crypto_service.dart';
import 'package:safe_wallet/shared/errors/app_error.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';
import 'package:safe_wallet/shared/storage/hive_box_registry.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';
import 'package:safe_wallet/shared/storage/storage_keys.dart';

void main() {
  group('HiveWalletRepository', () {
    const testMnemonic =
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const testPrivateKey =
        '4c0883a69102937d6231471b5dbb6204fe512961708279ded5b205db7368a7f5';
    late Directory tempDirectory;
    late HiveBoxRegistry registry;
    late HiveWalletRepository repository;
    late WalletCryptoService walletCryptoService;
    late DateTime currentTime;

    setUp(() async {
      currentTime = DateTime.utc(2026, 6, 6, 12);
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_repository_test_',
      );
      registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      walletCryptoService = WalletCryptoService(
        kdfService: const KdfService(iterations: 1000),
      );
      repository = HiveWalletRepository(
        registry: registry,
        walletCryptoService: walletCryptoService,
        mnemonicFactory: () => testMnemonic,
        clock: () => currentTime,
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('creates a wallet without storing plaintext mnemonic', () async {
      final account = await repository.createWallet(
        password: 'StrongPass-123',
        name: 'Main Wallet',
      );

      expect(account.name, 'Main Wallet');
      expect(account.source, WalletAccountSource.mnemonic);
      expect(
        account.evmAddress.toLowerCase(),
        '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      );
      expect(account.tronAddress, 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH');
      expect(account.solanaAddress, isNotEmpty);
      expect(account.suiAddress, isNotEmpty);
      expect(base64Decode(account.suiPublicKey), hasLength(32));
      expect(account.btcAddress, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');

      final storedAccounts = await repository.getWallets();
      expect(storedAccounts.single.source, WalletAccountSource.mnemonic);

      final storedText = repository.debugStoredWalletText(account.id);
      expect(storedText, isNot(contains('abandon')));
    });

    test('rejects tampered public account metadata during unlock', () async {
      final account = await repository.createWallet(
        password: 'StrongPass-123',
        name: 'Main Wallet',
      );
      final record = Map<dynamic, dynamic>.from(
        registry.walletsBox.get(account.id) as Map,
      );
      final accountJson = Map<dynamic, dynamic>.from(record['account'] as Map)
        ..['evmAddress'] = '0x0000000000000000000000000000000000000001';
      await registry.walletsBox.put(account.id, {
        ...record,
        'account': accountJson,
      });

      await expectLater(
        repository.unlock(walletId: account.id, password: 'StrongPass-123'),
        throwsA(
          isA<WalletError>().having(
            (error) => error.code,
            'code',
            'wallet_data_integrity_failed',
          ),
        ),
      );
    });

    test('rejects metadata changed after a wallet key was unlocked', () async {
      final account = await repository.createWallet(password: 'StrongPass-123');
      final unlocked = await repository.unlock(
        walletId: account.id,
        password: 'StrongPass-123',
      );
      final record = Map<dynamic, dynamic>.from(
        registry.walletsBox.get(account.id) as Map,
      );
      final accountJson = Map<dynamic, dynamic>.from(record['account'] as Map)
        ..['solanaAddress'] = '11111111111111111111111111111111';
      await registry.walletsBox.put(account.id, {
        ...record,
        'account': accountJson,
      });

      await expectLater(
        repository.readKeyMaterial(
          walletId: account.id,
          walletDek: unlocked.walletDek,
        ),
        throwsA(
          isA<WalletError>().having(
            (error) => error.code,
            'code',
            'wallet_data_integrity_failed',
          ),
        ),
      );
    });

    test('wallet ids remain unique when creations share a timestamp', () async {
      final first = await repository.createWallet(
        password: 'StrongPass-123',
        name: 'First',
      );
      final second = await repository.createWallet(
        password: 'StrongPass-123',
        name: 'Second',
      );

      expect(second.id, isNot(first.id));
      expect(await repository.getWallets(), hasLength(2));
    });

    test(
      'deleting the last wallet removes the global password verifier',
      () async {
        final account = await repository.createWallet(
          password: 'FirstStrongPass-123',
        );
        await repository.deleteWallet(
          walletId: account.id,
          password: 'FirstStrongPass-123',
        );

        final replacement = await repository.createWallet(
          password: 'DifferentStrongPass-456',
        );

        expect(
          (await repository.unlock(
            walletId: replacement.id,
            password: 'DifferentStrongPass-456',
          )).account.id,
          replacement.id,
        );
      },
    );

    test('imports a private key wallet with a private key source', () async {
      final account = await repository.importPrivateKeyWallet(
        privateKey: testPrivateKey,
        password: 'StrongPass-123',
        name: 'Imported Private Key',
      );

      expect(account.name, 'Imported Private Key');
      expect(account.source, WalletAccountSource.privateKey);
      expect(account.evmAddress, isNotEmpty);
      expect(account.tronAddress, isNotEmpty);
      expect(account.solanaAddress, isEmpty);

      final storedAccounts = await repository.getWallets();
      expect(storedAccounts.single.source, WalletAccountSource.privateKey);
    });

    test(
      'imports a Solana private key wallet with Solana key material',
      () async {
        final keypair = Keypair.fromSeed(
          Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
        );

        final account = await repository.importPrivateKeyWallet(
          privateKey: base58Encode(keypair.secretKey),
          password: 'StrongPass-123',
          name: 'Imported Solana Private Key',
          chain: WalletPrivateKeyChain.solana,
        );

        expect(account.name, 'Imported Solana Private Key');
        expect(account.source, WalletAccountSource.privateKey);
        expect(account.evmAddress, isEmpty);
        expect(account.solanaAddress, keypair.publicKey.toBase58());

        final unlockResult = await repository.unlock(
          walletId: account.id,
          password: 'StrongPass-123',
        );
        final keyMaterial = await repository.readKeyMaterial(
          walletId: account.id,
          walletDek: unlockResult.walletDek,
        );
        expect(keyMaterial.evmPrivateKey, isNull);
        expect(keyMaterial.solanaPrivateKey, keypair.secretKey);
      },
    );

    test(
      'mnemonic wallets expose encrypted Sui Ed25519 key material',
      () async {
        final account = await repository.importMnemonicWallet(
          mnemonic: _suiVectorMnemonic,
          password: 'StrongPass-123',
          name: 'Sui Mnemonic',
        );

        expect(account.suiAddress, _suiVectorAddress);
        expect(base64Decode(account.suiPublicKey), hasLength(32));

        final unlockResult = await repository.unlock(
          walletId: account.id,
          password: 'StrongPass-123',
        );
        final keyMaterial = await repository.readKeyMaterial(
          walletId: account.id,
          walletDek: unlockResult.walletDek,
        );
        final exported = await repository.exportSecret(
          walletId: account.id,
          password: 'StrongPass-123',
          secretType: WalletSecretType.suiPrivateKey,
        );

        expect(keyMaterial.suiPrivateKey, hasLength(32));
        expect(exported, _suiVectorPrivateKey);
        expect(
          repository.debugStoredWalletText(account.id),
          isNot(contains(_suiVectorPrivateKey)),
        );
      },
    );

    test('imports and exports a standard Ed25519 suiprivkey wallet', () async {
      final account = await repository.importPrivateKeyWallet(
        privateKey: _suiVectorPrivateKey,
        password: 'StrongPass-123',
        name: 'Imported Sui Private Key',
        chain: WalletPrivateKeyChain.sui,
      );

      expect(account.source, WalletAccountSource.privateKey);
      expect(account.evmAddress, isEmpty);
      expect(account.btcAddress, isEmpty);
      expect(account.tronAddress, isEmpty);
      expect(account.solanaAddress, isEmpty);
      expect(account.suiAddress, _suiVectorAddress);
      expect(base64Decode(account.suiPublicKey), hasLength(32));

      final unlockResult = await repository.unlock(
        walletId: account.id,
        password: 'StrongPass-123',
      );
      final keyMaterial = await repository.readKeyMaterial(
        walletId: account.id,
        walletDek: unlockResult.walletDek,
      );
      final exported = await repository.exportSecret(
        walletId: account.id,
        password: 'StrongPass-123',
        secretType: WalletSecretType.suiPrivateKey,
      );

      expect(keyMaterial.evmPrivateKey, isNull);
      expect(keyMaterial.suiPrivateKey, hasLength(32));
      expect(exported, _suiVectorPrivateKey);
    });

    test('rejects non-Ed25519 suiprivkey imports', () async {
      await expectLater(
        repository.importPrivateKeyWallet(
          privateKey: _suiSecp256k1PrivateKey,
          password: 'StrongPass-123',
          name: 'Unsupported Sui Key',
          chain: WalletPrivateKeyChain.sui,
        ),
        throwsA(isA<WalletError>()),
      );

      expect(await repository.getWallets(), isEmpty);
    });

    test(
      'infers legacy private key wallet source from missing Solana address',
      () async {
        final account = await repository.importPrivateKeyWallet(
          privateKey: testPrivateKey,
          password: 'StrongPass-123',
          name: 'Legacy Private Key',
        );
        final record = Map<dynamic, dynamic>.from(
          registry.walletsBox.get(account.id) as Map,
        );
        final storedAccount = Map<dynamic, dynamic>.from(
          record['account'] as Map,
        )..remove('source');
        await registry.walletsBox.put(account.id, {
          ...record,
          'account': storedAccount,
        });

        final storedAccounts = await repository.getWallets();

        expect(storedAccounts.single.source, WalletAccountSource.privateKey);
      },
    );

    test('rejects invalid mnemonic import before saving', () async {
      await expectLater(
        repository.importMnemonicWallet(
          mnemonic:
              'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon',
          password: 'StrongPass-123',
          name: 'Imported',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'invalid_mnemonic',
          ),
        ),
      );

      expect(await repository.getWallets(), isEmpty);
    });

    test(
      'invalid mnemonic import does not initialize the global password',
      () async {
        await expectLater(
          repository.importMnemonicWallet(
            mnemonic:
                'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon',
            password: 'password-from-failed-import',
            name: 'Invalid',
          ),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'invalid_mnemonic',
            ),
          ),
        );

        final account = await repository.importMnemonicWallet(
          mnemonic: testMnemonic,
          password: 'correct-password',
          name: 'Imported',
        );

        final result = await repository.unlock(
          walletId: account.id,
          password: 'correct-password',
        );
        expect(result.account.id, account.id);
      },
    );

    test(
      'rejects invalid private key import with a wallet error before saving',
      () async {
        await expectLater(
          repository.importPrivateKeyWallet(
            privateKey: 'not-a-private-key',
            password: 'StrongPass-123',
            name: 'Imported',
          ),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'invalid_private_key',
            ),
          ),
        );

        expect(await repository.getWallets(), isEmpty);
      },
    );

    test(
      'invalid private key import does not initialize the global password',
      () async {
        await expectLater(
          repository.importPrivateKeyWallet(
            privateKey: 'not-a-private-key',
            password: 'password-from-failed-import',
            name: 'Invalid',
          ),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'invalid_private_key',
            ),
          ),
        );

        final account = await repository.importPrivateKeyWallet(
          privateKey: testPrivateKey,
          password: 'correct-password',
          name: 'Imported Private Key',
        );

        final result = await repository.unlock(
          walletId: account.id,
          password: 'correct-password',
        );
        expect(result.account.id, account.id);
      },
    );

    test(
      'rejects a common weak password when initializing the wallet',
      () async {
        await expectLater(
          repository.createWallet(password: 'password1234'),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'weak_wallet_password',
            ),
          ),
        );

        expect(await repository.getWallets(), isEmpty);
      },
    );

    test('fails to unlock with a wrong password', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'correct-password',
        name: 'Imported',
      );

      await expectLater(
        repository.unlock(walletId: account.id, password: 'wrong-password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('delays unlock after repeated wrong password attempts', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'correct-password',
        name: 'Imported',
      );

      for (var attempt = 0; attempt < 5; attempt += 1) {
        await expectLater(
          repository.unlock(walletId: account.id, password: 'wrong-password'),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        currentTime = currentTime.add(const Duration(seconds: 1));
      }

      await expectLater(
        repository.unlock(walletId: account.id, password: 'correct-password'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'password_attempt_locked',
          ),
        ),
      );

      currentTime = currentTime.add(const Duration(seconds: 31));

      final result = await repository.unlock(
        walletId: account.id,
        password: 'correct-password',
      );
      expect(result.account, account);
    });

    test('password lockout survives closing and reopening Hive', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'correct-password',
        name: 'Imported',
      );

      for (var attempt = 0; attempt < 5; attempt += 1) {
        await expectLater(
          repository.unlock(walletId: account.id, password: 'wrong-password'),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        currentTime = currentTime.add(const Duration(seconds: 1));
      }

      await Hive.close();
      registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      repository = HiveWalletRepository(
        registry: registry,
        walletCryptoService: walletCryptoService,
        mnemonicFactory: () => testMnemonic,
        clock: () => currentTime,
      );

      await expectLater(
        repository.unlock(walletId: account.id, password: 'correct-password'),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'password_attempt_locked',
          ),
        ),
      );
    });

    test(
      'unlocks with the correct password and returns repository-only key data',
      () async {
        final account = await repository.importMnemonicWallet(
          mnemonic: testMnemonic,
          password: 'correct-password',
          name: 'Imported',
        );

        final result = await repository.unlock(
          walletId: account.id,
          password: 'correct-password',
        );

        expect(result, isA<WalletUnlockResult>());
        expect(result.account, account);
        expect(result.walletDek, hasLength(32));
      },
    );

    test('unlock rejects tampered encrypted key material', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'correct-password',
        name: 'Imported',
      );
      final record = Map<dynamic, dynamic>.from(
        registry.walletsBox.get(account.id) as Map,
      );
      final encryptedKeyMaterial = Map<dynamic, dynamic>.from(
        record['encryptedKeyMaterial'] as Map,
      );
      final authTag = base64Decode(encryptedKeyMaterial['authTag'] as String);
      authTag[0] ^= 0xff;
      await registry.walletsBox.put(account.id, {
        ...record,
        'encryptedKeyMaterial': {
          ...encryptedKeyMaterial,
          'authTag': base64Encode(authTag),
        },
      });

      await expectLater(
        repository.unlock(walletId: account.id, password: 'correct-password'),
        throwsA(
          isA<WalletError>().having(
            (error) => error.code,
            'code',
            'wallet_data_integrity_failed',
          ),
        ),
      );
    });

    test('unlock does not recheck the global password verifier', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'wallet-password',
        name: 'Imported',
      );
      await _replaceGlobalPasswordVerifier(
        registry: registry,
        cryptoService: walletCryptoService,
        password: 'different-global-password',
      );
      repository = HiveWalletRepository(
        registry: registry,
        walletCryptoService: walletCryptoService,
        mnemonicFactory: () => testMnemonic,
        clock: () => currentTime,
      );

      final result = await repository.unlock(
        walletId: account.id,
        password: 'wallet-password',
      );

      expect(result.account.id, account.id);
      expect(result.walletDek, hasLength(32));
    });

    test(
      'unlock does not cache plaintext password for wallet creation',
      () async {
        final first = await repository.importMnemonicWallet(
          mnemonic: testMnemonic,
          password: 'global-password',
          name: 'First Wallet',
        );
        await repository.unlock(
          walletId: first.id,
          password: 'global-password',
        );

        await expectLater(
          repository.createWallet(name: 'Second Wallet'),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'wallet_locked',
            ),
          ),
        );
      },
    );

    test(
      'password encryption preserves leading and trailing whitespace',
      () async {
        const password = '  StrongPass-123  ';
        final account = await repository.createWallet(password: password);

        expect(
          (await repository.unlock(
            walletId: account.id,
            password: password,
          )).account.id,
          account.id,
        );
        await expectLater(
          repository.unlock(walletId: account.id, password: password.trim()),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      },
    );

    test('mnemonic wallets expose Bitcoin signing key material', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'StrongPass-123',
        name: 'Imported',
      );

      final unlockResult = await repository.unlock(
        walletId: account.id,
        password: 'StrongPass-123',
      );
      final keyMaterial = await repository.readKeyMaterial(
        walletId: account.id,
        walletDek: unlockResult.walletDek,
      );

      expect(keyMaterial.btcPrivateKey, hasLength(64));
      expect(
        repository.debugStoredWalletText(account.id),
        isNot(contains(keyMaterial.btcPrivateKey!)),
      );
    });

    test('exports Solana private key as an importable secret key', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'StrongPass-123',
        name: 'Imported',
      );

      final unlockResult = await repository.unlock(
        walletId: account.id,
        password: 'StrongPass-123',
      );
      final keyMaterial = await repository.readKeyMaterial(
        walletId: account.id,
        walletDek: unlockResult.walletDek,
      );

      final exported = await repository.exportSecret(
        walletId: account.id,
        password: 'StrongPass-123',
        secretType: WalletSecretType.solanaPrivateKey,
      );

      expect(
        exported,
        base58Encode(Uint8List.fromList(keyMaterial.solanaPrivateKey!)),
      );
    });

    test(
      'unlocks legacy mnemonic wallets by backfilling Bitcoin metadata',
      () async {
        final account = await repository.importMnemonicWallet(
          mnemonic: testMnemonic,
          password: 'StrongPass-123',
          name: 'Legacy Mnemonic',
        );
        final expectedBtcAddress = account.btcAddress;
        await _removeStoredBitcoinMetadata(
          registry: registry,
          walletId: account.id,
          password: 'StrongPass-123',
        );

        expect((await repository.getWallets()).single.btcAddress, isEmpty);

        final unlockResult = await repository.unlock(
          walletId: account.id,
          password: 'StrongPass-123',
        );
        final keyMaterial = await repository.readKeyMaterial(
          walletId: account.id,
          walletDek: unlockResult.walletDek,
        );

        expect(unlockResult.account.btcAddress, expectedBtcAddress);
        expect(
          (await repository.getWallets()).single.btcAddress,
          expectedBtcAddress,
        );
        expect(keyMaterial.btcPrivateKey, hasLength(64));
        expect(
          (registry.walletsBox.get(account.id)
              as Map)['keyMaterialSchemaVersion'],
          3,
        );
        expect(
          (registry.walletsBox.get(account.id) as Map)['keyMaterialAadVersion'],
          1,
        );
      },
    );

    test('backfills legacy mnemonic Sui metadata idempotently', () async {
      final account = await repository.importMnemonicWallet(
        mnemonic: _suiVectorMnemonic,
        password: 'StrongPass-123',
        name: 'Legacy Sui Mnemonic',
      );
      await _removeStoredSuiMetadata(
        registry: registry,
        walletId: account.id,
        password: 'StrongPass-123',
      );

      expect((await repository.getWallets()).single.suiAddress, isEmpty);
      expect((await repository.getWallets()).single.suiPublicKey, isEmpty);

      final firstUnlock = await repository.unlock(
        walletId: account.id,
        password: 'StrongPass-123',
      );
      final firstKeyMaterial = await repository.readKeyMaterial(
        walletId: account.id,
        walletDek: firstUnlock.walletDek,
      );
      final secondUnlock = await repository.unlock(
        walletId: account.id,
        password: 'StrongPass-123',
      );
      final secondKeyMaterial = await repository.readKeyMaterial(
        walletId: account.id,
        walletDek: secondUnlock.walletDek,
      );

      expect(firstUnlock.account.suiAddress, _suiVectorAddress);
      expect(secondUnlock.account.suiAddress, _suiVectorAddress);
      expect(base64Decode(firstUnlock.account.suiPublicKey), hasLength(32));
      expect(
        secondUnlock.account.suiPublicKey,
        firstUnlock.account.suiPublicKey,
      );
      expect(firstKeyMaterial.suiPrivateKey, hasLength(32));
      expect(secondKeyMaterial.suiPrivateKey, firstKeyMaterial.suiPrivateKey);
      expect(
        (await repository.getWallets()).single.suiAddress,
        _suiVectorAddress,
      );
      expect(
        (registry.walletsBox.get(account.id)
            as Map)['keyMaterialSchemaVersion'],
        3,
      );
      expect(
        (registry.walletsBox.get(account.id) as Map)['keyMaterialAadVersion'],
        1,
      );
    });

    test(
      'backfills Wallet Standard public key for legacy Sui key wallets',
      () async {
        final account = await repository.importPrivateKeyWallet(
          privateKey: _suiVectorPrivateKey,
          password: 'StrongPass-123',
          name: 'Legacy Sui Key',
          chain: WalletPrivateKeyChain.sui,
        );
        await _removeStoredSuiPublicKey(
          registry: registry,
          walletId: account.id,
          password: 'StrongPass-123',
        );

        expect((await repository.getWallets()).single.suiPublicKey, isEmpty);

        final unlocked = await repository.unlock(
          walletId: account.id,
          password: 'StrongPass-123',
        );

        expect(unlocked.account.suiAddress, _suiVectorAddress);
        expect(base64Decode(unlocked.account.suiPublicKey), hasLength(32));
        expect(
          (registry.walletsBox.get(account.id)
              as Map)['keyMaterialSchemaVersion'],
          3,
        );
      },
    );

    test(
      'imports a Bitcoin private key wallet with Bitcoin key material',
      () async {
        final mnemonicAccount = await repository.importMnemonicWallet(
          mnemonic: testMnemonic,
          password: 'StrongPass-123',
          name: 'Mnemonic',
        );
        final mnemonicUnlock = await repository.unlock(
          walletId: mnemonicAccount.id,
          password: 'StrongPass-123',
        );
        final mnemonicKeyMaterial = await repository.readKeyMaterial(
          walletId: mnemonicAccount.id,
          walletDek: mnemonicUnlock.walletDek,
        );

        final imported = await repository.importPrivateKeyWallet(
          privateKey: mnemonicKeyMaterial.btcPrivateKey!,
          password: 'StrongPass-123',
          name: 'Imported Bitcoin Private Key',
          chain: WalletPrivateKeyChain.bitcoin,
        );

        expect(imported.name, 'Imported Bitcoin Private Key');
        expect(imported.source, WalletAccountSource.privateKey);
        expect(imported.evmAddress, isEmpty);
        expect(imported.solanaAddress, isEmpty);
        expect(imported.btcAddress, mnemonicAccount.btcAddress);

        final importedUnlock = await repository.unlock(
          walletId: imported.id,
          password: 'StrongPass-123',
        );
        final importedKeyMaterial = await repository.readKeyMaterial(
          walletId: imported.id,
          walletDek: importedUnlock.walletDek,
        );
        expect(importedKeyMaterial.evmPrivateKey, isNull);
        expect(importedKeyMaterial.solanaPrivateKey, isNull);
        expect(
          importedKeyMaterial.btcPrivateKey,
          mnemonicKeyMaterial.btcPrivateKey,
        );
      },
    );

    test('imports a compressed Bitcoin WIF private key wallet', () async {
      final imported = await repository.importPrivateKeyWallet(
        privateKey: _compressedPrivateKeyOneWif,
        password: 'StrongPass-123',
        name: 'Imported Bitcoin WIF',
        chain: WalletPrivateKeyChain.bitcoin,
      );

      final importedUnlock = await repository.unlock(
        walletId: imported.id,
        password: 'StrongPass-123',
      );
      final importedKeyMaterial = await repository.readKeyMaterial(
        walletId: imported.id,
        walletDek: importedUnlock.walletDek,
      );

      expect(imported.name, 'Imported Bitcoin WIF');
      expect(imported.source, WalletAccountSource.privateKey);
      expect(imported.evmAddress, isEmpty);
      expect(imported.solanaAddress, isEmpty);
      expect(
        importedKeyMaterial.btcPrivateKey,
        '0000000000000000000000000000000000000000000000000000000000000001',
      );
    });

    test('exports Bitcoin private keys as compressed WIF', () async {
      final imported = await repository.importPrivateKeyWallet(
        privateKey: _privateKeyOneHex,
        password: 'StrongPass-123',
        name: 'Imported Bitcoin Hex',
        chain: WalletPrivateKeyChain.bitcoin,
      );

      final exported = await repository.exportSecret(
        walletId: imported.id,
        password: 'StrongPass-123',
        secretType: WalletSecretType.btcPrivateKey,
      );

      expect(exported, _compressedPrivateKeyOneWif);
    });

    test('rejects testnet Bitcoin WIF private keys', () async {
      await expectLater(
        repository.importPrivateKeyWallet(
          privateKey: _compressedTestnetPrivateKeyOneWif,
          password: 'StrongPass-123',
          name: 'Imported Testnet Bitcoin WIF',
          chain: WalletPrivateKeyChain.bitcoin,
        ),
        throwsA(isA<WalletError>()),
      );
    });

    test(
      'change password re-encrypts every wallet with the new global password',
      () async {
        final first = await repository.importMnemonicWallet(
          mnemonic: testMnemonic,
          password: 'old-global-password',
          name: 'First Wallet',
        );
        currentTime = currentTime.add(const Duration(microseconds: 1));
        final second = await repository.createWallet(
          password: 'old-global-password',
          name: 'Second Wallet',
        );

        await repository.changePassword(
          walletId: first.id,
          currentPassword: 'old-global-password',
          newPassword: 'new-global-password',
        );

        await expectLater(
          repository.unlock(
            walletId: first.id,
            password: 'old-global-password',
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        await expectLater(
          repository.unlock(
            walletId: second.id,
            password: 'old-global-password',
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        expect(
          (await repository.unlock(
            walletId: first.id,
            password: 'new-global-password',
          )).account.id,
          first.id,
        );
        expect(
          (await repository.unlock(
            walletId: second.id,
            password: 'new-global-password',
          )).account.id,
          second.id,
        );
      },
    );

    test('replays an interrupted cross-box password change journal', () async {
      final first = await repository.importMnemonicWallet(
        mnemonic: testMnemonic,
        password: 'old-global-password',
        name: 'First Wallet',
      );
      currentTime = currentTime.add(const Duration(microseconds: 1));
      await repository.createWallet(
        password: 'old-global-password',
        name: 'Second Wallet',
      );
      final oldWalletRecords = Map<dynamic, dynamic>.from(
        registry.walletsBox.toMap(),
      );
      final oldVerifier = registry.settingsBox.get(
        StorageKeys.globalPasswordVerifier,
      );

      await repository.changePassword(
        walletId: first.id,
        currentPassword: 'old-global-password',
        newPassword: 'new-global-password',
      );
      final newWalletRecords = Map<dynamic, dynamic>.from(
        registry.walletsBox.toMap(),
      );
      final newVerifier = registry.settingsBox.get(
        StorageKeys.globalPasswordVerifier,
      );

      await registry.walletsBox.clear();
      await registry.walletsBox.putAll(oldWalletRecords);
      await registry.settingsBox.put(
        StorageKeys.globalPasswordVerifier,
        oldVerifier,
      );
      await registry.settingsBox.put('pendingWalletMutation', {
        'version': 1,
        'walletPuts': newWalletRecords,
        'walletDeletes': <String>[],
        'globalPasswordVerifier': newVerifier,
        'deleteGlobalPasswordVerifier': false,
      });
      repository = HiveWalletRepository(
        registry: registry,
        walletCryptoService: walletCryptoService,
        mnemonicFactory: () => testMnemonic,
        clock: () => currentTime,
      );

      await repository.getWallets();

      expect(registry.settingsBox.get('pendingWalletMutation'), isNull);
      expect(
        (await repository.unlock(
          walletId: first.id,
          password: 'new-global-password',
        )).account.id,
        first.id,
      );
      await expectLater(
        repository.unlock(walletId: first.id, password: 'old-global-password'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('replays an interrupted wallet deletion journal', () async {
      final first = await repository.createWallet(
        password: 'StrongPass-123',
        name: 'First Wallet',
      );
      currentTime = currentTime.add(const Duration(microseconds: 1));
      final second = await repository.createWallet(
        password: 'StrongPass-123',
        name: 'Second Wallet',
      );
      await registry.settingsBox.put('pendingWalletMutation', {
        'version': 1,
        'walletPuts': <String, Object?>{},
        'walletDeletes': [first.id],
        'deleteGlobalPasswordVerifier': false,
      });
      repository = HiveWalletRepository(
        registry: registry,
        walletCryptoService: walletCryptoService,
        mnemonicFactory: () => testMnemonic,
        clock: () => currentTime,
      );

      final wallets = await repository.getWallets();

      expect(wallets.map((wallet) => wallet.id), [second.id]);
      expect(registry.settingsBox.get('pendingWalletMutation'), isNull);
    });

    test('change password rejects a common weak new password', () async {
      final account = await repository.createWallet(
        password: 'old-global-password',
      );

      await expectLater(
        repository.changePassword(
          walletId: account.id,
          currentPassword: 'old-global-password',
          newPassword: 'password1234',
        ),
        throwsA(
          isA<AppError>().having(
            (error) => error.code,
            'code',
            'weak_wallet_password',
          ),
        ),
      );

      final result = await repository.unlock(
        walletId: account.id,
        password: 'old-global-password',
      );
      expect(result.account.id, account.id);
    });
  });
}

const _privateKeyOneHex =
    '0000000000000000000000000000000000000000000000000000000000000001';
const _compressedPrivateKeyOneWif =
    'KwDiBf89QgGbjEhKnhXJuH7LrciVrZi3qYjgd9M7rFU73sVHnoWn';
const _compressedTestnetPrivateKeyOneWif =
    'cMahea7zqjxrtgAbB7LSGbcQUr1uX1ojuat9jZodMN87JcbXMTcA';
const _suiVectorMnemonic =
    'film crazy soon outside stand loop subway crumble thrive popular green '
    'nuclear struggle pistol arm wife phrase warfare march wheat nephew ask '
    'sunny firm';
const _suiVectorPrivateKey =
    'suiprivkey1qrwsjvr6gwaxmsvxk4cfun99ra8uwxg3c9pl0nhle7xxpe4s80y05ctazer';
const _suiVectorAddress =
    '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133';
const _suiSecp256k1PrivateKey =
    'suiprivkey1qxpfcxdsdqnjgkyt70z6s3jsvap7nwyt52evl6st599gtyt6274ej2j4nvj';

Future<void> _removeStoredBitcoinMetadata({
  required HiveBoxRegistry registry,
  required String walletId,
  required String password,
}) async {
  const payloadCodec = EncryptedPayloadCodec();
  final cryptoService = WalletCryptoService(
    kdfService: const KdfService(iterations: 1000),
  );
  final aesGcmService = AesGcmService();
  final record = Map<dynamic, dynamic>.from(
    registry.walletsBox.get(walletId) as Map,
  );
  final account = Map<dynamic, dynamic>.from(record['account'] as Map);
  final walletDek = await cryptoService.decryptWithPassword(
    payload: payloadCodec.fromJson(record['encryptedWalletDek'] as Map),
    password: password,
  );
  final encryptedKeyMaterial = payloadCodec.fromJson(
    record['encryptedKeyMaterial'] as Map,
  );
  final keyMaterialPlaintext = await aesGcmService.decrypt(
    ciphertext: encryptedKeyMaterial.ciphertext,
    nonce: encryptedKeyMaterial.nonce,
    authTag: encryptedKeyMaterial.authTag,
    keyBytes: walletDek,
    aad: _testKeyMaterialAad(walletId: walletId, account: account),
  );
  final keyMaterial =
      Map<String, dynamic>.from(
          jsonDecode(utf8.decode(keyMaterialPlaintext)) as Map,
        )
        ..remove('btcPrivateKey')
        ..remove('btcDerivationPath');
  final encrypted = await aesGcmService.encrypt(
    plaintext: utf8.encode(jsonEncode(keyMaterial)),
    keyBytes: walletDek,
  );
  account.remove('btcAddress');
  await registry.walletsBox.put(walletId, {
    ...record,
    'keyMaterialSchemaVersion': null,
    'keyMaterialAadVersion': null,
    'account': account,
    'encryptedKeyMaterial': payloadCodec.toJson(
      EncryptedPayload(
        version: WalletCryptoService.payloadVersion,
        algorithm: AesGcmService.algorithmName,
        kdf: 'none',
        kdfParams: const {},
        salt: const [],
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        authTag: encrypted.authTag,
        createdAt: DateTime.utc(2026, 6, 6, 12),
      ),
    ),
  });
}

Future<void> _removeStoredSuiMetadata({
  required HiveBoxRegistry registry,
  required String walletId,
  required String password,
}) async {
  const payloadCodec = EncryptedPayloadCodec();
  final cryptoService = WalletCryptoService(
    kdfService: const KdfService(iterations: 1000),
  );
  final aesGcmService = AesGcmService();
  final record = Map<dynamic, dynamic>.from(
    registry.walletsBox.get(walletId) as Map,
  );
  final account = Map<dynamic, dynamic>.from(record['account'] as Map);
  final walletDek = await cryptoService.decryptWithPassword(
    payload: payloadCodec.fromJson(record['encryptedWalletDek'] as Map),
    password: password,
  );
  final encryptedKeyMaterial = payloadCodec.fromJson(
    record['encryptedKeyMaterial'] as Map,
  );
  final keyMaterialPlaintext = await aesGcmService.decrypt(
    ciphertext: encryptedKeyMaterial.ciphertext,
    nonce: encryptedKeyMaterial.nonce,
    authTag: encryptedKeyMaterial.authTag,
    keyBytes: walletDek,
    aad: _testKeyMaterialAad(walletId: walletId, account: account),
  );
  final keyMaterial =
      Map<String, dynamic>.from(
          jsonDecode(utf8.decode(keyMaterialPlaintext)) as Map,
        )
        ..remove('suiPrivateKey')
        ..remove('suiDerivationPath');
  final encrypted = await aesGcmService.encrypt(
    plaintext: utf8.encode(jsonEncode(keyMaterial)),
    keyBytes: walletDek,
  );
  account
    ..remove('suiAddress')
    ..remove('suiPublicKey');
  await registry.walletsBox.put(walletId, {
    ...record,
    'keyMaterialSchemaVersion': null,
    'keyMaterialAadVersion': null,
    'account': account,
    'encryptedKeyMaterial': payloadCodec.toJson(
      EncryptedPayload(
        version: WalletCryptoService.payloadVersion,
        algorithm: AesGcmService.algorithmName,
        kdf: 'none',
        kdfParams: const {},
        salt: const [],
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        authTag: encrypted.authTag,
        createdAt: DateTime.utc(2026, 6, 6, 12),
      ),
    ),
  });
}

Future<void> _removeStoredSuiPublicKey({
  required HiveBoxRegistry registry,
  required String walletId,
  required String password,
}) async {
  const payloadCodec = EncryptedPayloadCodec();
  final cryptoService = WalletCryptoService(
    kdfService: const KdfService(iterations: 1000),
  );
  final aesGcmService = AesGcmService();
  final record = Map<dynamic, dynamic>.from(
    registry.walletsBox.get(walletId) as Map,
  );
  final account = Map<dynamic, dynamic>.from(record['account'] as Map);
  final walletDek = await cryptoService.decryptWithPassword(
    payload: payloadCodec.fromJson(record['encryptedWalletDek'] as Map),
    password: password,
  );
  final encryptedKeyMaterial = payloadCodec.fromJson(
    record['encryptedKeyMaterial'] as Map,
  );
  final keyMaterialPlaintext = await aesGcmService.decrypt(
    ciphertext: encryptedKeyMaterial.ciphertext,
    nonce: encryptedKeyMaterial.nonce,
    authTag: encryptedKeyMaterial.authTag,
    keyBytes: walletDek,
    aad: _testKeyMaterialAad(walletId: walletId, account: account),
  );
  final encrypted = await aesGcmService.encrypt(
    plaintext: keyMaterialPlaintext,
    keyBytes: walletDek,
  );
  account.remove('suiPublicKey');
  await registry.walletsBox.put(walletId, {
    ...record,
    'keyMaterialSchemaVersion': null,
    'keyMaterialAadVersion': null,
    'account': account,
    'encryptedKeyMaterial': payloadCodec.toJson(
      EncryptedPayload(
        version: WalletCryptoService.payloadVersion,
        algorithm: AesGcmService.algorithmName,
        kdf: 'none',
        kdfParams: const {},
        salt: const [],
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
        authTag: encrypted.authTag,
        createdAt: DateTime.utc(2026, 6, 6, 12),
      ),
    ),
  });
}

List<int> _testKeyMaterialAad({
  required String walletId,
  required Map<dynamic, dynamic> account,
}) {
  return utf8.encode(
    jsonEncode({
      'walletId': walletId,
      'source': account['source'],
      'evmAddress': (account['evmAddress'] as String).toLowerCase(),
      'tronAddress': account['tronAddress'] as String? ?? '',
      'solanaAddress': account['solanaAddress'],
      'btcAddress': (account['btcAddress'] as String? ?? '').toLowerCase(),
      'suiAddress': (account['suiAddress'] as String? ?? '').toLowerCase(),
      'suiPublicKey': account['suiPublicKey'] as String? ?? '',
    }),
  );
}

Future<void> _replaceGlobalPasswordVerifier({
  required HiveBoxRegistry registry,
  required WalletCryptoService cryptoService,
  required String password,
}) async {
  final payload = await cryptoService.encryptWithPassword(
    plaintext: utf8.encode('safe-wallet-global-password'),
    password: password,
  );
  await registry.settingsBox.put(
    StorageKeys.globalPasswordVerifier,
    const EncryptedPayloadCodec().toJson(payload),
  );
}
