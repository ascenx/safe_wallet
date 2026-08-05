import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final biometricPasswordStoreProvider = Provider<BiometricPasswordStore>((ref) {
  return BiometricPasswordStore(
    authenticator: LocalAuthBiometricAuthenticator(),
    storage: FlutterSecurePasswordStorage(),
  );
});

abstract interface class BiometricAuthenticator {
  Future<bool> canAuthenticateWithBiometrics();

  Future<bool> authenticate({required String reason});
}

abstract interface class SecurePasswordStorage {
  Future<String?> readPassword();

  Future<void> savePassword(String password);

  Future<void> deletePassword();
}

final class BiometricPasswordStore {
  const BiometricPasswordStore({
    required BiometricAuthenticator authenticator,
    required SecurePasswordStorage storage,
  }) : _authenticator = authenticator,
       _storage = storage;

  final BiometricAuthenticator _authenticator;
  final SecurePasswordStorage _storage;

  Future<bool> canUseBiometrics() {
    return _authenticator.canAuthenticateWithBiometrics();
  }

  Future<bool> hasSavedPassword() async {
    if (_isWidgetTestBinding && _storage is FlutterSecurePasswordStorage) {
      return false;
    }
    await _deleteLegacyCredential();
    final storage = _storage;
    if (storage is FlutterSecurePasswordStorage) {
      return storage.containsCredential();
    }
    return await _readStoredCredential() != null;
  }

  Future<BiometricPasswordReadResult> readPasswordWithStatus({
    required String reason,
  }) async {
    final canUseBiometrics = await this.canUseBiometrics();
    final hasCredential = canUseBiometrics && await hasSavedPassword();
    return BiometricPasswordReadResult(
      canUseBiometrics: canUseBiometrics,
      hasSavedPassword: hasCredential,
    );
  }

  Future<String?> readPassword({required String reason}) async {
    final result = await readPasswordWithStatus(reason: reason);
    return result.password;
  }

  Future<BiometricUnlockReadResult> readUnlockMaterialWithStatus({
    required String walletId,
    required String reason,
  }) async {
    final canUseBiometrics = await this.canUseBiometrics();
    if (!canUseBiometrics) {
      return const BiometricUnlockReadResult(
        canUseBiometrics: false,
        hasSavedCredential: false,
      );
    }

    await _deleteLegacyCredential();
    final credential = await _readStoredCredential();
    if (credential == null || !credential.walletDeks.containsKey(walletId)) {
      return const BiometricUnlockReadResult(
        canUseBiometrics: true,
        hasSavedCredential: false,
      );
    }

    try {
      final authenticated = await _authenticator.authenticate(reason: reason);
      if (!authenticated) {
        return const BiometricUnlockReadResult(
          canUseBiometrics: true,
          hasSavedCredential: true,
        );
      }
      return BiometricUnlockReadResult(
        canUseBiometrics: true,
        hasSavedCredential: true,
        walletDek: credential.walletDeks[walletId],
        walletDeks: credential.walletDeks,
      );
    } catch (_) {
      return const BiometricUnlockReadResult(
        canUseBiometrics: true,
        hasSavedCredential: true,
      );
    }
  }

  Future<void> savePassword(String password) async {
    if (password.isEmpty) {
      await _storage.deletePassword();
      return;
    }
    await _deleteLegacyCredential();
  }

  Future<void> saveWalletKey({
    required String walletId,
    required List<int> walletDek,
  }) {
    return saveWalletKeys({walletId: walletDek});
  }

  Future<void> saveWalletKeys(Map<String, List<int>> walletDeks) async {
    for (final entry in walletDeks.entries) {
      if (entry.value.length != 32) {
        throw ArgumentError.value(
          entry.value.length,
          'walletDeks[${entry.key}].length',
        );
      }
    }
    await _storage.savePassword(
      _StoredBiometricCredential(walletDeks: walletDeks).encode(),
    );
  }

  Future<void> clearPassword() {
    return _storage.deletePassword();
  }

  Future<void> clearWallet(String walletId) async {
    if (walletId.isEmpty) {
      return;
    }
    // The secure store intentionally contains at most one wallet credential.
    // Deletion must not read the protected value first because that can trigger
    // an interactive biometric prompt while the user is deleting a wallet.
    await _storage.deletePassword();
  }

  Future<_StoredBiometricCredential?> _readStoredCredential() async {
    final storedValue = await _storage.readPassword();
    if (storedValue == null || storedValue.isEmpty) {
      return null;
    }
    final credential = _StoredBiometricCredential.decode(storedValue);
    if (credential == null) {
      await _storage.deletePassword();
    }
    return credential;
  }

  Future<void> _deleteLegacyCredential() async {
    if (_isWidgetTestBinding) {
      return;
    }
    final storage = _storage;
    if (storage is FlutterSecurePasswordStorage) {
      await storage.deleteLegacyCredential();
    }
  }
}

final class BiometricUnlockReadResult {
  const BiometricUnlockReadResult({
    required this.canUseBiometrics,
    required this.hasSavedCredential,
    this.password,
    this.walletDek,
    this.walletDeks = const {},
  });

  final bool canUseBiometrics;
  final bool hasSavedCredential;
  final String? password;
  final List<int>? walletDek;
  final Map<String, List<int>> walletDeks;
}

final class BiometricPasswordReadResult {
  const BiometricPasswordReadResult({
    required this.canUseBiometrics,
    required this.hasSavedPassword,
    this.password,
  });

  final bool canUseBiometrics;
  final bool hasSavedPassword;
  final String? password;
}

final class _StoredBiometricCredential {
  _StoredBiometricCredential({
    required Map<String, List<int>> walletDeks,
  }) : walletDeks = Map.unmodifiable(
         walletDeks.map(
           (walletId, walletDek) => MapEntry(
             walletId,
             List<int>.unmodifiable(walletDek),
           ),
         ),
       );

  static const _version = 3;
  static const _kind = 'safe_wallet_biometric_credential';

  final Map<String, List<int>> walletDeks;

  static _StoredBiometricCredential? decode(String storedValue) {
    try {
      final json = jsonDecode(storedValue);
      if (json is! Map || json['kind'] != _kind) {
        return null;
      }
      if (json['version'] == 2) {
        final walletId = json['walletId'];
        final encodedWalletDek = json['walletDek'];
        if (walletId is String && encodedWalletDek is String) {
          final walletDek = base64Decode(encodedWalletDek);
          if (walletDek.length != 32) {
            return null;
          }
          return _StoredBiometricCredential(
            walletDeks: {walletId: walletDek},
          );
        }
      }
      if (json['version'] == _version) {
        final encodedWalletDeks = json['walletDeks'];
        if (encodedWalletDeks is! Map) {
          return null;
        }
        final walletDeks = <String, List<int>>{};
        for (final entry in encodedWalletDeks.entries) {
          if (entry.key is! String || entry.value is! String) {
            return null;
          }
          final walletDek = base64Decode(entry.value as String);
          if (walletDek.length != 32) {
            return null;
          }
          walletDeks[entry.key as String] = walletDek;
        }
        if (walletDeks.isEmpty) {
          return null;
        }
        return _StoredBiometricCredential(walletDeks: walletDeks);
      }
    } catch (_) {}
    return null;
  }

  String encode() {
    return jsonEncode({
      'kind': _kind,
      'version': _version,
      'walletDeks': walletDeks.map(
        (walletId, walletDek) => MapEntry(walletId, base64Encode(walletDek)),
      ),
    });
  }
}

final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;
  static const _platformTimeout = Duration(seconds: 5);

  @override
  Future<bool> canAuthenticateWithBiometrics() async {
    if (_isWidgetTestBinding) {
      return false;
    }
    try {
      final deviceSupported = await _localAuthentication
          .isDeviceSupported()
          .timeout(_platformTimeout);
      final canCheck = await _localAuthentication.canCheckBiometrics.timeout(
        _platformTimeout,
      );
      final biometrics = await _localAuthentication
          .getAvailableBiometrics()
          .timeout(_platformTimeout);
      return deviceSupported && canCheck && biometrics.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    if (_isWidgetTestBinding) {
      return false;
    }
    try {
      return _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}

bool get _isWidgetTestBinding {
  try {
    final binding = WidgetsBinding.instance;
    return binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  } catch (_) {
    return false;
  }
}

final class FlutterSecurePasswordStorage implements SecurePasswordStorage {
  FlutterSecurePasswordStorage({
    FlutterSecureStorage? secureStorage,
    FlutterSecureStorage? legacySecureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _legacySecureStorage =
           legacySecureStorage ?? const FlutterSecureStorage();

  static const _credentialKey = 'safe_wallet_biometric_wallet_key_v2';
  static const _legacyPasswordKey = 'safe_wallet_global_biometric_password';
  static const _platformTimeout = Duration(seconds: 60);
  static const _androidOptions = AndroidOptions.biometric(
    enforceBiometrics: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    synchronizable: false,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  );
  static const _macosOptions = MacOsOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  );

  final FlutterSecureStorage _secureStorage;
  final FlutterSecureStorage _legacySecureStorage;

  @override
  Future<String?> readPassword() async {
    try {
      return await _secureStorage
          .read(
            key: _credentialKey,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
            mOptions: _macosOptions,
          )
          .timeout(_platformTimeout);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> savePassword(String password) {
    return _secureStorage
        .write(
          key: _credentialKey,
          value: password,
          aOptions: _androidOptions,
          iOptions: _iosOptions,
          mOptions: _macosOptions,
        )
        .timeout(_platformTimeout);
  }

  @override
  Future<void> deletePassword() {
    return Future.wait([
      _secureStorage.delete(
        key: _credentialKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
        mOptions: _macosOptions,
      ),
      deleteLegacyCredential(),
    ]).timeout(_platformTimeout);
  }

  Future<bool> containsCredential() async {
    try {
      return await _secureStorage
          .containsKey(
            key: _credentialKey,
            aOptions: _androidOptions,
            iOptions: _iosOptions,
            mOptions: _macosOptions,
          )
          .timeout(_platformTimeout);
    } on Object {
      return false;
    }
  }

  Future<void> deleteLegacyCredential() async {
    try {
      await _legacySecureStorage
          .delete(key: _legacyPasswordKey)
          .timeout(_platformTimeout);
    } on Object {
      // Legacy cleanup must not prevent normal wallet use.
    }
  }
}
