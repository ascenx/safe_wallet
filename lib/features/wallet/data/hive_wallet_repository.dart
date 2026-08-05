import 'dart:convert';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Mnemonic;
import 'package:cryptography/cryptography.dart';
import 'package:solana_sdk/solana_sdk.dart';
import 'package:sui_dart/sui.dart' as sui;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart';

import '../../../shared/crypto/aes_gcm_service.dart';
import '../../../shared/crypto/encrypted_payload.dart';
import '../../../shared/crypto/encrypted_payload_codec.dart';
import '../../../shared/crypto/wallet_crypto_service.dart';
import '../../../shared/errors/wallet_error.dart';
import '../../../shared/security/password_attempt_limiter.dart';
import '../../../shared/security/hive_password_attempt_store.dart';
import '../../../shared/security/wallet_password_policy.dart';
import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/storage_keys.dart';
import '../domain/wallet_account.dart';
import 'key_derivation_service.dart';
import 'mnemonic_service.dart';
import 'wallet_repository.dart';

typedef MnemonicFactory = String Function();
typedef Clock = DateTime Function();

final class HiveWalletRepository implements WalletRepository {
  HiveWalletRepository({
    required HiveBoxRegistry registry,
    WalletCryptoService? walletCryptoService,
    AesGcmService? aesGcmService,
    MnemonicService mnemonicService = const MnemonicService(),
    KeyDerivationService keyDerivationService = const KeyDerivationService(),
    MnemonicFactory? mnemonicFactory,
    Clock? clock,
    PasswordAttemptLimiter? passwordAttemptLimiter,
    EncryptedPayloadCodec payloadCodec = const EncryptedPayloadCodec(),
  }) : _registry = registry,
       _walletCryptoService = walletCryptoService ?? WalletCryptoService(),
       _aesGcmService = aesGcmService ?? AesGcmService(),
       _mnemonicService = mnemonicService,
       _keyDerivationService = keyDerivationService,
       _mnemonicFactory =
           mnemonicFactory ?? (() => mnemonicService.generateMnemonic()),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _passwordAttemptLimiter =
           passwordAttemptLimiter ??
           PasswordAttemptLimiter(
             store: HivePasswordAttemptStore(settingsBox: registry.settingsBox),
           ),
       _payloadCodec = payloadCodec;

  final HiveBoxRegistry _registry;
  final WalletCryptoService _walletCryptoService;
  final AesGcmService _aesGcmService;
  final MnemonicService _mnemonicService;
  final KeyDerivationService _keyDerivationService;
  final MnemonicFactory _mnemonicFactory;
  final Clock _clock;
  final PasswordAttemptLimiter _passwordAttemptLimiter;
  final EncryptedPayloadCodec _payloadCodec;
  static const _globalPasswordAttemptKey = '__global_password__';
  static const _keyMaterialSchemaVersionKey = 'keyMaterialSchemaVersion';
  static const _currentKeyMaterialSchemaVersion = 3;
  static const _keyMaterialAadVersionKey = 'keyMaterialAadVersion';
  static const _currentKeyMaterialAadVersion = 1;
  static final _globalPasswordVerifierPlaintext = utf8.encode(
    'safe-wallet-global-password',
  );

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    return importMnemonicWallet(
      mnemonic: _mnemonicFactory(),
      password: password,
      name: name,
    );
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) async {
    _assertGlobalPasswordAvailable(password);
    final parsedMnemonic = _parseMnemonic(mnemonic);
    final evmAccount = _keyDerivationService.deriveEvmAccount(parsedMnemonic);
    final solanaAccount = _keyDerivationService.deriveSolanaAccount(
      parsedMnemonic,
    );
    final bitcoinAccount = _keyDerivationService.deriveBitcoinAccount(
      parsedMnemonic,
    );
    final tronAccount = _keyDerivationService.deriveTronAccount(parsedMnemonic);
    final suiAccount = _keyDerivationService.deriveSuiAccount(parsedMnemonic);
    final resolvedPassword = await _resolveGlobalPassword(password);
    final now = _clock();
    final account = WalletAccount(
      id: _newWalletId(now),
      name: name,
      evmAddress: evmAccount.address,
      tronAddress: tronAccount.address,
      solanaAddress: solanaAccount.address,
      btcAddress: bitcoinAccount.address,
      suiAddress: suiAccount.address,
      suiPublicKey: _suiPublicKeyFromPrivateKey(suiAccount.privateKey),
      source: WalletAccountSource.mnemonic,
      createdAt: now,
      updatedAt: now,
    );
    final keyMaterial = {
      'type': 'mnemonic',
      'mnemonic': parsedMnemonic.sentence,
      'evmPrivateKey': _bytesToHex(evmAccount.privateKey),
      'evmDerivationPath': evmAccount.derivationPath,
      'solanaPrivateKey': base64Encode(solanaAccount.privateKey),
      'solanaDerivationPath': solanaAccount.derivationPath,
      'btcPrivateKey': _bytesToHex(bitcoinAccount.privateKey),
      'btcDerivationPath': bitcoinAccount.derivationPath,
      'tronPrivateKey': _bytesToHex(tronAccount.privateKey),
      'tronDerivationPath': tronAccount.derivationPath,
      'suiPrivateKey': base64Encode(suiAccount.privateKey),
      'suiDerivationPath': suiAccount.derivationPath,
    };

    await _persistEncryptedWallet(
      account: account,
      keyMaterial: keyMaterial,
      password: resolvedPassword,
    );
    return account;
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) async {
    _assertGlobalPasswordAvailable(password);
    switch (chain) {
      case WalletPrivateKeyChain.evm:
      case WalletPrivateKeyChain.tron:
        final credentials = _parsePrivateKey(privateKey);
        final resolvedPassword = await _resolveGlobalPassword(password);
        return _importEvmPrivateKeyWallet(
          credentials: credentials,
          password: resolvedPassword,
          name: name,
        );
      case WalletPrivateKeyChain.bitcoin:
        final bitcoinPrivateKey = await _parseBitcoinPrivateKey(privateKey);
        final resolvedPassword = await _resolveGlobalPassword(password);
        return _importBitcoinPrivateKeyWallet(
          privateKey: bitcoinPrivateKey,
          password: resolvedPassword,
          name: name,
        );
      case WalletPrivateKeyChain.solana:
        final accountKey = _parseSolanaPrivateKey(privateKey);
        final resolvedPassword = await _resolveGlobalPassword(password);
        return _importSolanaPrivateKeyWallet(
          accountKey: accountKey,
          password: resolvedPassword,
          name: name,
        );
      case WalletPrivateKeyChain.sui:
        final suiAccount = _parseSuiPrivateKey(privateKey);
        final resolvedPassword = await _resolveGlobalPassword(password);
        return _importSuiPrivateKeyWallet(
          accountKey: suiAccount,
          password: resolvedPassword,
          name: name,
        );
    }
  }

  Future<WalletAccount> _importEvmPrivateKeyWallet({
    required EthPrivateKey credentials,
    required String password,
    required String name,
  }) async {
    final now = _clock();
    final account = WalletAccount(
      id: _newWalletId(now),
      name: name,
      evmAddress: '0x${credentials.address}',
      tronAddress: _tronAddressFromPrivateKey(credentials.privateKey),
      solanaAddress: '',
      btcAddress: '',
      source: WalletAccountSource.privateKey,
      createdAt: now,
      updatedAt: now,
    );

    await _persistEncryptedWallet(
      account: account,
      keyMaterial: {
        'type': 'evmPrivateKey',
        'evmPrivateKey': _bytesToHex(credentials.privateKey),
        'tronPrivateKey': _bytesToHex(credentials.privateKey),
      },
      password: password,
    );
    return account;
  }

  Future<WalletAccount> _importBitcoinPrivateKeyWallet({
    required List<int> privateKey,
    required String password,
    required String name,
  }) async {
    final now = _clock();
    final privateKeyValue = _bigIntFromBytes(privateKey);
    final bitcoinPrivateKey = wallet.PrivateKey(privateKeyValue);
    final publicKey = wallet.bitcoinbech32.createPublicKey(bitcoinPrivateKey);
    final account = WalletAccount(
      id: _newWalletId(now),
      name: name,
      evmAddress: '',
      tronAddress: '',
      solanaAddress: '',
      btcAddress: wallet.bitcoinbech32.createAddress(publicKey),
      source: WalletAccountSource.privateKey,
      createdAt: now,
      updatedAt: now,
    );

    await _persistEncryptedWallet(
      account: account,
      keyMaterial: {
        'type': 'btcPrivateKey',
        'btcPrivateKey': _bytesToHex(privateKey),
      },
      password: password,
    );
    return account;
  }

  Future<WalletAccount> _importSolanaPrivateKeyWallet({
    required Account accountKey,
    required String password,
    required String name,
  }) async {
    final now = _clock();
    final account = WalletAccount(
      id: _newWalletId(now),
      name: name,
      evmAddress: '',
      tronAddress: '',
      solanaAddress: accountKey.publicKeyStr,
      btcAddress: '',
      source: WalletAccountSource.privateKey,
      createdAt: now,
      updatedAt: now,
    );

    await _persistEncryptedWallet(
      account: account,
      keyMaterial: {
        'type': 'solanaPrivateKey',
        'solanaPrivateKey': base64Encode(accountKey.privateKey),
      },
      password: password,
    );
    return account;
  }

  Future<WalletAccount> _importSuiPrivateKeyWallet({
    required sui.SuiAccount accountKey,
    required String password,
    required String name,
  }) async {
    final now = _clock();
    final account = WalletAccount(
      id: _newWalletId(now),
      name: name,
      evmAddress: '',
      tronAddress: '',
      solanaAddress: '',
      btcAddress: '',
      suiAddress: accountKey.getAddress(),
      suiPublicKey: base64Encode(accountKey.getPublicKey()),
      source: WalletAccountSource.privateKey,
      createdAt: now,
      updatedAt: now,
    );

    await _persistEncryptedWallet(
      account: account,
      keyMaterial: {
        'type': 'suiPrivateKey',
        'suiPrivateKey': base64Encode(accountKey.getSecretKey()),
      },
      password: password,
    );
    return account;
  }

  @override
  Future<List<WalletAccount>> getWallets() async {
    await _recoverPendingWalletMutation();
    return _registry.walletsBox.values
        .whereType<Map>()
        .map((value) {
          try {
            final account = value['account'];
            return account is Map ? _accountFromJson(account) : null;
          } catch (_) {
            return null;
          }
        })
        .whereType<WalletAccount>()
        .toList(growable: false);
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) async {
    await _recoverPendingWalletMutation();
    final record = _walletRecord(walletId);
    final previous = _accountFromJson(record['account'] as Map);
    final renamed = WalletAccount(
      id: previous.id,
      name: name,
      evmAddress: previous.evmAddress,
      tronAddress: previous.tronAddress,
      solanaAddress: previous.solanaAddress,
      btcAddress: previous.btcAddress,
      suiAddress: previous.suiAddress,
      suiPublicKey: previous.suiPublicKey,
      source: previous.source,
      createdAt: previous.createdAt,
      updatedAt: _clock(),
    );
    await _registry.walletsBox.put(walletId, {
      ...record,
      'account': _accountToJson(renamed),
    });
    return renamed;
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    await _recoverPendingWalletMutation();
    await unlock(walletId: walletId, password: password);
    final deletesGlobalVerifier = _registry.walletsBox.length == 1;
    await _commitWalletMutation(
      walletDeletes: [walletId],
      deleteGlobalPasswordVerifier: deletesGlobalVerifier,
    );
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _recoverPendingWalletMutation();
    _assertNewWalletPasswordAllowed(newPassword);
    final now = _clock();
    await _passwordAttemptLimiter.assertAllowed(
      walletId: _globalPasswordAttemptKey,
      now: now,
    );
    final walletRecords = Map<dynamic, dynamic>.from(
      _registry.walletsBox.toMap(),
    );
    final decryptedWalletDeks = <String, List<int>>{};
    try {
      for (final entry in walletRecords.entries) {
        final walletId = entry.key as String;
        final record = entry.value;
        if (record is! Map) {
          continue;
        }
        final encryptedWalletDek = _payloadCodec.fromJson(
          record['encryptedWalletDek'] as Map,
        );
        decryptedWalletDeks[walletId] = await _walletCryptoService
            .decryptWithPassword(
              payload: encryptedWalletDek,
              password: currentPassword,
            );
      }
      await _verifyOrStoreGlobalPassword(currentPassword);
    } catch (_) {
      await _passwordAttemptLimiter.recordFailure(
        walletId: _globalPasswordAttemptKey,
        now: now,
      );
      rethrow;
    }

    final encryptedWalletDeks = <String, EncryptedPayload>{};
    for (final entry in decryptedWalletDeks.entries) {
      encryptedWalletDeks[entry.key] = await _walletCryptoService
          .encryptWithPassword(plaintext: entry.value, password: newPassword);
    }
    final updatedWalletRecords = <dynamic, dynamic>{};
    for (final entry in encryptedWalletDeks.entries) {
      final record = Map<dynamic, dynamic>.from(_walletRecord(entry.key));
      updatedWalletRecords[entry.key] = {
        ...record,
        'encryptedWalletDek': _payloadCodec.toJson(entry.value),
      };
    }
    final newVerifier = await _buildGlobalPasswordVerifier(newPassword);
    await _commitWalletMutation(
      walletPuts: updatedWalletRecords,
      globalPasswordVerifier: _payloadCodec.toJson(newVerifier),
    );
    await _passwordAttemptLimiter.recordSuccess(_globalPasswordAttemptKey);
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) async {
    final unlockResult = await unlock(walletId: walletId, password: password);
    final keyMaterial = await _decryptKeyMaterial(
      walletId: walletId,
      walletDek: unlockResult.walletDek,
    );
    final secret = switch (secretType) {
      WalletSecretType.mnemonic => keyMaterial['mnemonic'],
      WalletSecretType.evmPrivateKey => keyMaterial['evmPrivateKey'],
      WalletSecretType.btcPrivateKey => await _bitcoinPrivateKeyForExport(
        keyMaterial['btcPrivateKey'],
      ),
      WalletSecretType.tronPrivateKey => keyMaterial['tronPrivateKey'],
      WalletSecretType.solanaPrivateKey => _solanaPrivateKeyForExport(
        keyMaterial['solanaPrivateKey'],
      ),
      WalletSecretType.suiPrivateKey => _suiPrivateKeyForExport(
        keyMaterial['suiPrivateKey'],
      ),
    };
    if (secret is! String || secret.isEmpty) {
      throw StateError('Requested wallet secret is unavailable');
    }
    return secret;
  }

  Future<String?> _bitcoinPrivateKeyForExport(Object? privateKey) async {
    if (privateKey is! String || privateKey.trim().isEmpty) {
      return null;
    }
    final normalizedPrivateKey = _normalizePrivateKey(privateKey).toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedPrivateKey)) {
      return privateKey.trim();
    }
    final keyBytes = _validatedBitcoinPrivateKeyBytes(
      _hexToBytes(normalizedPrivateKey),
    );
    final payload = [0x80, ...keyBytes, 0x01];
    final checksum = (await _hash256(payload)).sublist(0, 4);
    return _encodeBase58([...payload, ...checksum]);
  }

  String? _solanaPrivateKeyForExport(Object? encodedPrivateKey) {
    if (encodedPrivateKey is! String || encodedPrivateKey.isEmpty) {
      return null;
    }
    return base58Encode(Uint8List.fromList(base64Decode(encodedPrivateKey)));
  }

  String? _suiPrivateKeyForExport(Object? encodedPrivateKey) {
    if (encodedPrivateKey is! String || encodedPrivateKey.isEmpty) {
      return null;
    }
    return sui.encodeSuiPrivateKey(
      Uint8List.fromList(base64Decode(encodedPrivateKey)),
      sui.SignatureScheme.Ed25519,
    );
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    await _recoverPendingWalletMutation();
    final record = _walletRecord(walletId);
    var account = _accountFromStoredRecord(record);
    var json = await _decryptKeyMaterial(
      walletId: walletId,
      walletDek: walletDek,
    );
    if (!_hasCurrentKeyMaterialSchema(record)) {
      final upgraded = await _maybeBackfillMnemonicMetadata(
        walletId: walletId,
        record: record,
        account: account,
        walletDek: walletDek,
        keyMaterial: json,
      );
      account = upgraded.account;
      json = upgraded.keyMaterial;
      await _markKeyMaterialSchemaCurrent(walletId);
    }
    await _assertKeyMaterialMatchesAccount(
      walletId: walletId,
      account: account,
      keyMaterial: json,
    );
    await _ensureKeyMaterialAadCurrent(
      walletId: walletId,
      account: account,
      walletDek: walletDek,
      keyMaterial: json,
    );
    final solanaPrivateKey = json['solanaPrivateKey'] as String?;
    final suiPrivateKey = json['suiPrivateKey'] as String?;
    return WalletKeyMaterial(
      evmPrivateKey: json['evmPrivateKey'] as String?,
      btcPrivateKey: json['btcPrivateKey'] as String?,
      tronPrivateKey: json['tronPrivateKey'] as String?,
      solanaPrivateKey: solanaPrivateKey == null
          ? null
          : base64Decode(solanaPrivateKey),
      suiPrivateKey: suiPrivateKey == null ? null : base64Decode(suiPrivateKey),
    );
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    await _recoverPendingWalletMutation();
    final now = _clock();
    await _passwordAttemptLimiter.assertAllowed(walletId: walletId, now: now);
    final record = _walletRecord(walletId);
    final encryptedWalletDek = _payloadCodec.fromJson(
      record['encryptedWalletDek'] as Map,
    );
    late final List<int> walletDek;
    try {
      walletDek = await _walletCryptoService.decryptWithPassword(
        payload: encryptedWalletDek,
        password: password,
      );
    } catch (_) {
      await _passwordAttemptLimiter.recordFailure(walletId: walletId, now: now);
      rethrow;
    }
    await _passwordAttemptLimiter.recordSuccess(walletId);
    var account = _accountFromStoredRecord(record);
    var keyMaterial = await _decryptKeyMaterial(
      walletId: walletId,
      walletDek: walletDek,
    );
    if (!_hasCurrentKeyMaterialSchema(record)) {
      final upgraded = await _maybeBackfillMnemonicMetadata(
        walletId: walletId,
        record: record,
        account: account,
        walletDek: walletDek,
        keyMaterial: keyMaterial,
      );
      account = upgraded.account;
      keyMaterial = upgraded.keyMaterial;
      await _markKeyMaterialSchemaCurrent(walletId);
    }
    await _assertKeyMaterialMatchesAccount(
      walletId: walletId,
      account: account,
      keyMaterial: keyMaterial,
    );
    await _ensureKeyMaterialAadCurrent(
      walletId: walletId,
      account: account,
      walletDek: walletDek,
      keyMaterial: keyMaterial,
    );

    return WalletUnlockResult(account: account, walletDek: walletDek);
  }

  String debugStoredWalletText(String walletId) {
    return _registry.walletsBox.get(walletId).toString();
  }

  void _assertGlobalPasswordAvailable(String? password) {
    if (password != null && password.isNotEmpty) {
      return;
    }
    throw const WalletError.walletLocked();
  }

  Future<String> _resolveGlobalPassword(String? password) async {
    await _recoverPendingWalletMutation();
    if (password == null || password.isEmpty) {
      throw const WalletError.walletLocked();
    }
    await _verifyOrStoreGlobalPassword(password);
    return password;
  }

  Future<void> _verifyOrStoreGlobalPassword(String password) async {
    final now = _clock();
    await _passwordAttemptLimiter.assertAllowed(
      walletId: _globalPasswordAttemptKey,
      now: now,
    );
    final storedVerifier = _registry.settingsBox.get(
      StorageKeys.globalPasswordVerifier,
    );
    if (storedVerifier == null) {
      _assertNewWalletPasswordAllowed(password);
      await _passwordAttemptLimiter.recordSuccess(_globalPasswordAttemptKey);
      return;
    }
    try {
      final payload = _payloadCodec.fromJson(storedVerifier as Map);
      await _walletCryptoService.decryptWithPassword(
        payload: payload,
        password: password,
      );
      await _passwordAttemptLimiter.recordSuccess(_globalPasswordAttemptKey);
    } catch (_) {
      await _passwordAttemptLimiter.recordFailure(
        walletId: _globalPasswordAttemptKey,
        now: now,
      );
      rethrow;
    }
  }

  void _assertNewWalletPasswordAllowed(String password) {
    switch (WalletPasswordPolicy.issueFor(password)) {
      case WalletPasswordIssue.tooShort:
        throw const WalletError.passwordTooShort();
      case WalletPasswordIssue.tooCommon:
        throw const WalletError.weakPassword();
      case null:
        return;
    }
  }

  Future<EncryptedPayload> _buildGlobalPasswordVerifier(String password) {
    return _walletCryptoService.encryptWithPassword(
      plaintext: _globalPasswordVerifierPlaintext,
      password: password,
    );
  }

  Future<void> _persistEncryptedWallet({
    required WalletAccount account,
    required Map<String, Object?> keyMaterial,
    required String password,
  }) async {
    final walletDek = SecretKeyData.random(length: 32).bytes;
    final encryptedKeyMaterial = await _encryptKeyMaterial(
      keyMaterial: keyMaterial,
      walletDek: walletDek,
      account: account,
    );
    final encryptedWalletDek = await _walletCryptoService.encryptWithPassword(
      plaintext: walletDek,
      password: password,
    );

    final record = <String, Object?>{
      'account': _accountToJson(account),
      'encryptedKeyMaterial': _payloadCodec.toJson(encryptedKeyMaterial),
      'encryptedWalletDek': _payloadCodec.toJson(encryptedWalletDek),
      _keyMaterialSchemaVersionKey: _currentKeyMaterialSchemaVersion,
      _keyMaterialAadVersionKey: _currentKeyMaterialAadVersion,
    };
    final hasGlobalVerifier = _registry.settingsBox.containsKey(
      StorageKeys.globalPasswordVerifier,
    );
    if (hasGlobalVerifier) {
      await _registry.walletsBox.put(account.id, record);
      return;
    }
    final verifier = await _buildGlobalPasswordVerifier(password);
    await _commitWalletMutation(
      walletPuts: {account.id: record},
      globalPasswordVerifier: _payloadCodec.toJson(verifier),
    );
  }

  Future<void> _commitWalletMutation({
    Map<dynamic, dynamic> walletPuts = const {},
    List<String> walletDeletes = const [],
    Object? globalPasswordVerifier,
    bool deleteGlobalPasswordVerifier = false,
  }) async {
    final journal = <String, Object?>{
      'version': 1,
      'walletPuts': Map<dynamic, dynamic>.from(walletPuts),
      'walletDeletes': List<String>.from(walletDeletes),
      'globalPasswordVerifier': ?globalPasswordVerifier,
      'deleteGlobalPasswordVerifier': deleteGlobalPasswordVerifier,
    };
    await _registry.settingsBox.put(StorageKeys.pendingWalletMutation, journal);
    await _recoverPendingWalletMutation();
  }

  Future<void> _recoverPendingWalletMutation() async {
    final rawJournal = _registry.settingsBox.get(
      StorageKeys.pendingWalletMutation,
    );
    if (rawJournal == null) {
      return;
    }
    if (rawJournal is! Map || rawJournal['version'] != 1) {
      throw StateError('Unsupported pending wallet mutation');
    }
    final walletPuts = rawJournal['walletPuts'];
    final walletDeletes = rawJournal['walletDeletes'];
    final deleteGlobalPasswordVerifier =
        rawJournal['deleteGlobalPasswordVerifier'];
    if (walletPuts is! Map ||
        walletDeletes is! List ||
        !walletDeletes.every((value) => value is String) ||
        deleteGlobalPasswordVerifier is! bool) {
      throw StateError('Invalid pending wallet mutation');
    }
    if (walletPuts.isNotEmpty) {
      await _registry.walletsBox.putAll(Map<dynamic, dynamic>.from(walletPuts));
    }
    if (walletDeletes.isNotEmpty) {
      await _registry.walletsBox.deleteAll(walletDeletes.cast<String>());
    }
    if (rawJournal.containsKey('globalPasswordVerifier')) {
      await _registry.settingsBox.put(
        StorageKeys.globalPasswordVerifier,
        rawJournal['globalPasswordVerifier'],
      );
    } else if (deleteGlobalPasswordVerifier) {
      await _registry.settingsBox.delete(StorageKeys.globalPasswordVerifier);
    }
    await _registry.settingsBox.delete(StorageKeys.pendingWalletMutation);
  }

  bool _hasCurrentKeyMaterialSchema(Map<dynamic, dynamic> record) {
    final version = record[_keyMaterialSchemaVersionKey];
    return version is int && version >= _currentKeyMaterialSchemaVersion;
  }

  bool _hasCurrentKeyMaterialAad(Map<dynamic, dynamic> record) {
    final version = record[_keyMaterialAadVersionKey];
    return version is int && version >= _currentKeyMaterialAadVersion;
  }

  Future<void> _markKeyMaterialSchemaCurrent(String walletId) async {
    final latestRecord = Map<dynamic, dynamic>.from(_walletRecord(walletId));
    if (_hasCurrentKeyMaterialSchema(latestRecord)) {
      return;
    }
    await _registry.walletsBox.put(walletId, {
      ...latestRecord,
      _keyMaterialSchemaVersionKey: _currentKeyMaterialSchemaVersion,
    });
  }

  Future<Map<String, dynamic>> _decryptKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    final record = _walletRecord(walletId);
    try {
      final account = _accountFromStoredRecord(record);
      final encryptedKeyMaterial = _payloadCodec.fromJson(
        record['encryptedKeyMaterial'] as Map,
      );
      final plaintext = await _aesGcmService.decrypt(
        ciphertext: encryptedKeyMaterial.ciphertext,
        nonce: encryptedKeyMaterial.nonce,
        authTag: encryptedKeyMaterial.authTag,
        keyBytes: walletDek,
        aad: _hasCurrentKeyMaterialAad(record)
            ? _keyMaterialAad(walletId: walletId, account: account)
            : const [],
      );
      return jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (_) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  Future<({WalletAccount account, Map<String, dynamic> keyMaterial})>
  _maybeBackfillMnemonicMetadata({
    required String walletId,
    required Map<dynamic, dynamic> record,
    required WalletAccount account,
    required List<int> walletDek,
    Map<String, dynamic>? keyMaterial,
  }) async {
    final existingKeyMaterial =
        keyMaterial ??
        await _decryptKeyMaterial(walletId: walletId, walletDek: walletDek);
    final hasBitcoinAddress = account.btcAddress.trim().isNotEmpty;
    final hasTronAddress = account.tronAddress.trim().isNotEmpty;
    final hasSuiAddress = account.suiAddress.trim().isNotEmpty;
    final hasSuiPublicKey = account.suiPublicKey.trim().isNotEmpty;
    final bitcoinPrivateKey = existingKeyMaterial['btcPrivateKey'];
    final tronPrivateKey = existingKeyMaterial['tronPrivateKey'];
    final suiPrivateKey = existingKeyMaterial['suiPrivateKey'];
    final hasBitcoinPrivateKey =
        bitcoinPrivateKey is String && bitcoinPrivateKey.trim().isNotEmpty;
    final hasTronPrivateKey =
        tronPrivateKey is String && tronPrivateKey.trim().isNotEmpty;
    final hasSuiPrivateKey =
        suiPrivateKey is String && suiPrivateKey.trim().isNotEmpty;
    if (account.source != WalletAccountSource.mnemonic) {
      if (!hasSuiPublicKey && hasSuiAddress && hasSuiPrivateKey) {
        final upgradedAccount = WalletAccount(
          id: account.id,
          name: account.name,
          evmAddress: account.evmAddress,
          tronAddress: account.tronAddress,
          solanaAddress: account.solanaAddress,
          btcAddress: account.btcAddress,
          suiAddress: account.suiAddress,
          suiPublicKey: _suiPublicKeyFromPrivateKey(
            base64Decode(suiPrivateKey),
          ),
          source: account.source,
          createdAt: account.createdAt,
          updatedAt: account.updatedAt,
        );
        await _registry.walletsBox.put(walletId, {
          ...record,
          'account': _accountToJson(upgradedAccount),
          _keyMaterialSchemaVersionKey: _currentKeyMaterialSchemaVersion,
        });
        return (account: upgradedAccount, keyMaterial: existingKeyMaterial);
      }
      return (account: account, keyMaterial: existingKeyMaterial);
    }

    if (hasBitcoinAddress &&
        hasBitcoinPrivateKey &&
        hasTronAddress &&
        hasTronPrivateKey &&
        hasSuiAddress &&
        hasSuiPrivateKey &&
        hasSuiPublicKey) {
      return (account: account, keyMaterial: existingKeyMaterial);
    }

    final mnemonic = existingKeyMaterial['mnemonic'];
    if (mnemonic is! String || mnemonic.trim().isEmpty) {
      return (account: account, keyMaterial: existingKeyMaterial);
    }

    final parsedMnemonic = _mnemonicService.parseMnemonic(mnemonic);
    final bitcoinAccount = _keyDerivationService.deriveBitcoinAccount(
      parsedMnemonic,
    );
    final tronAccount = _keyDerivationService.deriveTronAccount(parsedMnemonic);
    final suiAccount = _keyDerivationService.deriveSuiAccount(parsedMnemonic);
    final upgradedAccount =
        hasBitcoinAddress && hasTronAddress && hasSuiAddress && hasSuiPublicKey
        ? account
        : WalletAccount(
            id: account.id,
            name: account.name,
            evmAddress: account.evmAddress,
            tronAddress: hasTronAddress
                ? account.tronAddress
                : tronAccount.address,
            solanaAddress: account.solanaAddress,
            btcAddress: hasBitcoinAddress
                ? account.btcAddress
                : bitcoinAccount.address,
            suiAddress: hasSuiAddress ? account.suiAddress : suiAccount.address,
            suiPublicKey: hasSuiPublicKey
                ? account.suiPublicKey
                : _suiPublicKeyFromPrivateKey(suiAccount.privateKey),
            source: account.source,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt,
          );
    final upgradedKeyMaterial = <String, Object?>{
      ...existingKeyMaterial,
      if (!hasBitcoinPrivateKey) ...{
        'btcPrivateKey': _bytesToHex(bitcoinAccount.privateKey),
        'btcDerivationPath': bitcoinAccount.derivationPath,
      },
      if (!hasTronPrivateKey) ...{
        'tronPrivateKey': _bytesToHex(tronAccount.privateKey),
        'tronDerivationPath': tronAccount.derivationPath,
      },
      if (!hasSuiPrivateKey) ...{
        'suiPrivateKey': base64Encode(suiAccount.privateKey),
        'suiDerivationPath': suiAccount.derivationPath,
      },
    };
    final encryptedKeyMaterial = await _encryptKeyMaterial(
      keyMaterial: upgradedKeyMaterial,
      walletDek: walletDek,
      account: upgradedAccount,
    );
    await _registry.walletsBox.put(walletId, {
      ...record,
      'account': _accountToJson(upgradedAccount),
      'encryptedKeyMaterial': _payloadCodec.toJson(encryptedKeyMaterial),
      _keyMaterialSchemaVersionKey: _currentKeyMaterialSchemaVersion,
      _keyMaterialAadVersionKey: _currentKeyMaterialAadVersion,
    });
    return (
      account: upgradedAccount,
      keyMaterial: Map<String, dynamic>.from(upgradedKeyMaterial),
    );
  }

  Future<EncryptedPayload> _encryptKeyMaterial({
    required Map<String, Object?> keyMaterial,
    required List<int> walletDek,
    required WalletAccount account,
  }) async {
    final encrypted = await _aesGcmService.encrypt(
      plaintext: utf8.encode(jsonEncode(keyMaterial)),
      keyBytes: walletDek,
      aad: _keyMaterialAad(walletId: account.id, account: account),
    );
    return EncryptedPayload(
      version: WalletCryptoService.payloadVersion,
      algorithm: AesGcmService.algorithmName,
      kdf: 'none',
      kdfParams: const {},
      salt: const [],
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      authTag: encrypted.authTag,
      createdAt: _clock(),
    );
  }

  Future<void> _ensureKeyMaterialAadCurrent({
    required String walletId,
    required WalletAccount account,
    required List<int> walletDek,
    required Map<String, dynamic> keyMaterial,
  }) async {
    final latestRecord = Map<dynamic, dynamic>.from(_walletRecord(walletId));
    if (_hasCurrentKeyMaterialAad(latestRecord)) {
      return;
    }
    final encryptedKeyMaterial = await _encryptKeyMaterial(
      keyMaterial: keyMaterial,
      walletDek: walletDek,
      account: account,
    );
    await _registry.walletsBox.put(walletId, {
      ...latestRecord,
      'encryptedKeyMaterial': _payloadCodec.toJson(encryptedKeyMaterial),
      _keyMaterialAadVersionKey: _currentKeyMaterialAadVersion,
    });
  }

  List<int> _keyMaterialAad({
    required String walletId,
    required WalletAccount account,
  }) {
    return utf8.encode(
      jsonEncode({
        'walletId': walletId,
        'source': account.source.name,
        'evmAddress': account.evmAddress.toLowerCase(),
        'tronAddress': account.tronAddress,
        'solanaAddress': account.solanaAddress,
        'btcAddress': account.btcAddress.toLowerCase(),
        'suiAddress': account.suiAddress.toLowerCase(),
        'suiPublicKey': account.suiPublicKey,
      }),
    );
  }

  Future<void> _assertKeyMaterialMatchesAccount({
    required String walletId,
    required WalletAccount account,
    required Map<String, dynamic> keyMaterial,
  }) async {
    try {
      if (account.id != walletId) {
        throw const WalletError.dataIntegrityFailed();
      }
      _assertEvmKeyMatches(account, keyMaterial['evmPrivateKey']);
      _assertTronKeyMatches(account, keyMaterial['tronPrivateKey']);
      _assertSolanaKeyMatches(account, keyMaterial['solanaPrivateKey']);
      _assertBitcoinKeyMatches(account, keyMaterial['btcPrivateKey']);
      _assertSuiKeyMatches(account, keyMaterial['suiPrivateKey']);
    } on WalletError {
      rethrow;
    } catch (_) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  void _assertEvmKeyMatches(WalletAccount account, Object? privateKey) {
    final encoded = _matchingPrivateKey(account.evmAddress, privateKey);
    if (encoded == null) {
      return;
    }
    final expected = EthPrivateKey.fromHex(encoded).address.with0x;
    if (expected.toLowerCase() != account.evmAddress.toLowerCase()) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  void _assertTronKeyMatches(WalletAccount account, Object? privateKey) {
    final encoded = _matchingPrivateKey(account.tronAddress, privateKey);
    if (encoded == null) {
      return;
    }
    final expected = _tronAddressFromPrivateKey(
      _hexToBytes(_normalizePrivateKey(encoded)),
    );
    if (expected != account.tronAddress) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  void _assertSolanaKeyMatches(WalletAccount account, Object? privateKey) {
    final encoded = _matchingPrivateKey(account.solanaAddress, privateKey);
    if (encoded == null) {
      return;
    }
    final expected = Account(
      privateKey: Uint8List.fromList(base64Decode(encoded)),
    ).publicKeyStr;
    if (expected != account.solanaAddress) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  void _assertBitcoinKeyMatches(WalletAccount account, Object? privateKey) {
    final encoded = _matchingPrivateKey(account.btcAddress, privateKey);
    if (encoded == null) {
      return;
    }
    final keyBytes = _validatedBitcoinPrivateKeyBytes(
      _hexToBytes(_normalizePrivateKey(encoded)),
    );
    final publicKey = wallet.bitcoinbech32.createPublicKey(
      wallet.PrivateKey(_bigIntFromBytes(keyBytes)),
    );
    final expected = wallet.bitcoinbech32.createAddress(publicKey);
    if (expected.toLowerCase() != account.btcAddress.toLowerCase()) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  void _assertSuiKeyMatches(WalletAccount account, Object? privateKey) {
    final encoded = _matchingPrivateKey(account.suiAddress, privateKey);
    final hasPublicKey = account.suiPublicKey.trim().isNotEmpty;
    if (encoded == null) {
      if (hasPublicKey) {
        throw const WalletError.dataIntegrityFailed();
      }
      return;
    }
    if (!hasPublicKey) {
      throw const WalletError.dataIntegrityFailed();
    }
    final derived = sui.SuiAccount.fromPrivateKey(
      _bytesToHex(base64Decode(encoded)),
      sui.SignatureScheme.Ed25519,
    );
    if (derived.getAddress().toLowerCase() !=
            account.suiAddress.toLowerCase() ||
        base64Encode(derived.getPublicKey()) != account.suiPublicKey) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  String? _matchingPrivateKey(String address, Object? privateKey) {
    final hasAddress = address.trim().isNotEmpty;
    final hasPrivateKey = privateKey is String && privateKey.trim().isNotEmpty;
    if (hasAddress != hasPrivateKey) {
      throw const WalletError.dataIntegrityFailed();
    }
    return hasPrivateKey ? privateKey.trim() : null;
  }

  Map<dynamic, dynamic> _walletRecord(String walletId) {
    final record = _registry.walletsBox.get(walletId);
    if (record is! Map) {
      throw StateError('Wallet not found: $walletId');
    }
    return record;
  }

  WalletAccount _accountFromStoredRecord(Map<dynamic, dynamic> record) {
    try {
      return _accountFromJson(record['account'] as Map);
    } catch (_) {
      throw const WalletError.dataIntegrityFailed();
    }
  }

  Map<String, Object?> _accountToJson(WalletAccount account) {
    return {
      'id': account.id,
      'name': account.name,
      'evmAddress': account.evmAddress,
      'tronAddress': account.tronAddress,
      'solanaAddress': account.solanaAddress,
      'btcAddress': account.btcAddress,
      'suiAddress': account.suiAddress,
      'suiPublicKey': account.suiPublicKey,
      'source': account.source.name,
      'createdAt': account.createdAt.toIso8601String(),
      'updatedAt': account.updatedAt.toIso8601String(),
    };
  }

  WalletAccount _accountFromJson(Map<dynamic, dynamic> json) {
    return WalletAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      evmAddress: json['evmAddress'] as String,
      tronAddress: json['tronAddress'] as String? ?? '',
      solanaAddress: json['solanaAddress'] as String,
      btcAddress: json['btcAddress'] as String? ?? '',
      suiAddress: json['suiAddress'] as String? ?? '',
      suiPublicKey: json['suiPublicKey'] as String? ?? '',
      source: _accountSourceFromJson(
        source: json['source'],
        solanaAddress: json['solanaAddress'] as String,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  WalletAccountSource _accountSourceFromJson({
    required Object? source,
    required String solanaAddress,
  }) {
    if (source is String) {
      return WalletAccountSource.values.firstWhere(
        (value) => value.name == source,
        orElse: () => WalletAccountSource.mnemonic,
      );
    }
    if (solanaAddress.isEmpty) {
      return WalletAccountSource.privateKey;
    }
    return WalletAccountSource.mnemonic;
  }

  String _newWalletId(DateTime now) {
    final entropy = base64UrlEncode(
      SecretKeyData.random(length: 12).bytes,
    ).replaceAll('=', '');
    return 'wallet-${now.microsecondsSinceEpoch}-$entropy';
  }

  EthPrivateKey _parsePrivateKey(String privateKey) {
    final normalizedPrivateKey = _normalizePrivateKey(privateKey);
    try {
      return EthPrivateKey.fromHex(normalizedPrivateKey);
    } catch (_) {
      throw const WalletError.invalidPrivateKey();
    }
  }

  Mnemonic _parseMnemonic(String mnemonic) {
    try {
      return _mnemonicService.parseMnemonic(mnemonic);
    } on ArgumentError {
      throw const WalletError.invalidMnemonic();
    }
  }

  Account _parseSolanaPrivateKey(String privateKey) {
    try {
      return Account(privateKeyStr: privateKey.trim());
    } catch (_) {
      throw const WalletError.invalidPrivateKey();
    }
  }

  sui.SuiAccount _parseSuiPrivateKey(String privateKey) {
    final normalized = privateKey.trim();
    try {
      if (normalized.startsWith('suiprivkey')) {
        final (scheme, _) = sui.decodeSuiPrivateKey(normalized);
        if (scheme != sui.SignatureScheme.Ed25519) {
          throw const WalletError.invalidPrivateKey();
        }
        return sui.SuiAccount.fromPrivateKey(normalized);
      }
      final hex = _normalizePrivateKey(normalized).toLowerCase();
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
        throw const WalletError.invalidPrivateKey();
      }
      return sui.SuiAccount.fromPrivateKey(hex, sui.SignatureScheme.Ed25519);
    } catch (_) {
      throw const WalletError.invalidPrivateKey();
    }
  }

  String _tronAddressFromPrivateKey(List<int> privateKey) {
    final tronPrivateKey = wallet.tron.createPrivateKey(
      Uint8List.fromList(privateKey),
    );
    final publicKey = wallet.tron.createPublicKey(tronPrivateKey);
    return wallet.tron.createAddress(publicKey);
  }

  Future<List<int>> _parseBitcoinPrivateKey(String privateKey) async {
    final normalizedPrivateKey = _normalizePrivateKey(privateKey).toLowerCase();
    if (RegExp(r'^[0-9a-f]{64}$').hasMatch(normalizedPrivateKey)) {
      return _validatedBitcoinPrivateKeyBytes(
        _hexToBytes(normalizedPrivateKey),
      );
    }

    return _parseBitcoinWif(privateKey);
  }

  Future<List<int>> _parseBitcoinWif(String privateKey) async {
    try {
      final decoded = _decodeBase58(privateKey.trim());
      if (decoded.length != 37 && decoded.length != 38) {
        throw const WalletError.invalidPrivateKey();
      }
      final payload = decoded.sublist(0, decoded.length - 4);
      final checksum = decoded.sublist(decoded.length - 4);
      final expectedChecksum = (await _hash256(payload)).sublist(0, 4);
      for (var index = 0; index < checksum.length; index += 1) {
        if (checksum[index] != expectedChecksum[index]) {
          throw const WalletError.invalidPrivateKey();
        }
      }
      final version = payload.first;
      if (version != 0x80) {
        throw const WalletError.invalidPrivateKey();
      }
      if (payload.length == 34 && payload.last != 0x01) {
        throw const WalletError.invalidPrivateKey();
      }
      final keyBytes = payload.sublist(1, 33);
      return _validatedBitcoinPrivateKeyBytes(keyBytes);
    } catch (_) {
      throw const WalletError.invalidPrivateKey();
    }
  }

  List<int> _validatedBitcoinPrivateKeyBytes(List<int> bytes) {
    if (bytes.length != 32) {
      throw const WalletError.invalidPrivateKey();
    }
    try {
      final value = _bigIntFromBytes(bytes);
      if (value <= BigInt.zero) {
        throw const WalletError.invalidPrivateKey();
      }
      wallet.bitcoinbech32.createPublicKey(wallet.PrivateKey(value));
      return bytes;
    } catch (_) {
      throw const WalletError.invalidPrivateKey();
    }
  }

  String _normalizePrivateKey(String privateKey) {
    final trimmed = privateKey.trim();
    return trimmed.startsWith('0x') ? trimmed.substring(2) : trimmed;
  }
}

BigInt _bigIntFromBytes(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

List<int> _hexToBytes(String value) {
  final bytes = <int>[];
  for (var index = 0; index < value.length; index += 2) {
    bytes.add(int.parse(value.substring(index, index + 2), radix: 16));
  }
  return bytes;
}

List<int> _decodeBase58(String value) {
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw const WalletError.invalidPrivateKey();
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final leadingZeroes = value.codeUnits
      .takeWhile((unit) => unit == 0x31)
      .length;
  return [
    ...List<int>.filled(leadingZeroes, 0),
    ..._unsignedIntToBytes(decoded),
  ];
}

String _encodeBase58(List<int> bytes) {
  var value = _bigIntFromBytes(bytes);
  final buffer = StringBuffer();
  while (value > BigInt.zero) {
    final remainder = value % BigInt.from(58);
    value = value ~/ BigInt.from(58);
    buffer.write(_base58Alphabet[remainder.toInt()]);
  }
  final leadingZeroes = bytes.takeWhile((byte) => byte == 0).length;
  final encoded = buffer.toString().split('').reversed.join();
  return '${List<String>.filled(leadingZeroes, '1').join()}$encoded';
}

List<int> _unsignedIntToBytes(BigInt value) {
  if (value == BigInt.zero) {
    return const [];
  }
  final bytes = <int>[];
  var remaining = value;
  while (remaining > BigInt.zero) {
    bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
    remaining >>= 8;
  }
  return bytes;
}

Future<List<int>> _hash256(List<int> bytes) async {
  final sha256 = Sha256();
  final first = await sha256.hash(bytes);
  final second = await sha256.hash(first.bytes);
  return second.bytes;
}

String _bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String _suiPublicKeyFromPrivateKey(List<int> privateKey) {
  final account = sui.SuiAccount.fromPrivateKey(
    _bytesToHex(privateKey),
    sui.SignatureScheme.Ed25519,
  );
  return base64Encode(account.getPublicKey());
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
