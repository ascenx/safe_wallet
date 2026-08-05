import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';

void main() {
  group('BiometricPasswordStore', () {
    test('reports unavailable when biometric auth is not supported', () async {
      final store = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(canAuthenticate: false),
        storage: _FakeSecurePasswordStorage(),
      );

      expect(await store.canUseBiometrics(), isFalse);
      expect(await store.readPassword(reason: 'Unlock wallet'), isNull);
    });

    test(
      'does not authenticate when no biometric wallet key is saved',
      () async {
        final authenticator = _FakeBiometricAuthenticator(
          canAuthenticate: true,
        );
        final store = BiometricPasswordStore(
          authenticator: authenticator,
          storage: _FakeSecurePasswordStorage(),
        );

        expect(await store.hasSavedPassword(), isFalse);
        expect(await store.readPassword(reason: 'Unlock wallet'), isNull);
        expect(authenticator.authenticateCallCount, 0);
      },
    );

    test('never persists or returns the wallet password', () async {
      final authenticator = _FakeBiometricAuthenticator(
        canAuthenticate: true,
        authenticateResult: true,
      );
      final storage = _FakeSecurePasswordStorage();
      final store = BiometricPasswordStore(
        authenticator: authenticator,
        storage: storage,
      );

      await store.savePassword('global-password');

      expect(storage.password, isNull);
      expect(await store.hasSavedPassword(), isFalse);
      expect(await store.readPassword(reason: 'Unlock wallet'), isNull);
      expect(authenticator.authenticateCallCount, 0);
    });

    test('deletes legacy credentials that contain a wallet password', () async {
      final storage = _FakeSecurePasswordStorage()
        ..password = jsonEncode({
          'kind': 'safe_wallet_biometric_credential',
          'version': 1,
          'password': 'saved-password',
          'walletId': 'wallet-1',
          'walletDek': base64Encode(List<int>.generate(32, (index) => index)),
        });
      final store = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );

      expect(await store.readPassword(reason: 'Unlock wallet'), isNull);
      expect(storage.password, isNull);
    });

    test('deletes legacy unversioned password values', () async {
      const legacyPassword =
          '{"version":1,"password":"this-is-the-real-password"}';
      final store = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: _FakeSecurePasswordStorage()..password = legacyPassword,
      );

      expect(await store.readPassword(reason: 'Unlock wallet'), isNull);
    });

    test('returns a saved wallet DEK only after biometric auth', () async {
      final authenticator = _FakeBiometricAuthenticator(
        canAuthenticate: true,
        authenticateResult: true,
      );
      final storage = _FakeSecurePasswordStorage();
      final store = BiometricPasswordStore(
        authenticator: authenticator,
        storage: storage,
      );
      final walletDek = List<int>.generate(32, (index) => index);

      await store.saveWalletKey(walletId: 'wallet-1', walletDek: walletDek);

      expect(storage.password, isNot(contains('password')));
      final result = await store.readUnlockMaterialWithStatus(
        walletId: 'wallet-1',
        reason: 'Unlock wallet',
      );
      expect(result.password, isNull);
      expect(result.walletDek, walletDek);
      expect(authenticator.lastReason, 'Unlock wallet');
    });

    test('returns every saved wallet DEK after biometric auth', () async {
      final authenticator = _FakeBiometricAuthenticator(
        canAuthenticate: true,
        authenticateResult: true,
      );
      final store = BiometricPasswordStore(
        authenticator: authenticator,
        storage: _FakeSecurePasswordStorage(),
      );
      final firstWalletDek = List<int>.filled(32, 1);
      final secondWalletDek = List<int>.filled(32, 2);

      await store.saveWalletKeys({
        'wallet-1': firstWalletDek,
        'wallet-2': secondWalletDek,
      });

      final result = await store.readUnlockMaterialWithStatus(
        walletId: 'wallet-2',
        reason: 'Unlock wallet',
      );

      expect(result.walletDek, secondWalletDek);
      expect(result.walletDeks, {
        'wallet-1': firstWalletDek,
        'wallet-2': secondWalletDek,
      });
      expect(authenticator.authenticateCallCount, 1);
    });

    test('reads a version 2 single-wallet credential', () async {
      final walletDek = List<int>.generate(32, (index) => index);
      final storage = _FakeSecurePasswordStorage()
        ..password = jsonEncode({
          'kind': 'safe_wallet_biometric_credential',
          'version': 2,
          'walletId': 'wallet-1',
          'walletDek': base64Encode(walletDek),
        });
      final store = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );

      final result = await store.readUnlockMaterialWithStatus(
        walletId: 'wallet-1',
        reason: 'Unlock wallet',
      );

      expect(result.walletDek, walletDek);
      expect(result.walletDeks, {'wallet-1': walletDek});
    });

    test(
      'does not return a wallet DEK when biometric auth is cancelled',
      () async {
        final storage = _FakeSecurePasswordStorage();
        final store = BiometricPasswordStore(
          authenticator: _FakeBiometricAuthenticator(
            canAuthenticate: true,
            authenticateResult: false,
          ),
          storage: storage,
        );
        await store.saveWalletKey(
          walletId: 'wallet-1',
          walletDek: List<int>.filled(32, 7),
        );

        final result = await store.readUnlockMaterialWithStatus(
          walletId: 'wallet-1',
          reason: 'Unlock wallet',
        );
        expect(result.walletDek, isNull);
      },
    );

    test(
      'production secure storage cannot bypass explicit biometric auth',
      () async {
        final walletDek = List<int>.filled(32, 7);
        FlutterSecureStorage.setMockInitialValues({
          'safe_wallet_biometric_wallet_key_v2': jsonEncode({
            'kind': 'safe_wallet_biometric_credential',
            'version': 2,
            'walletId': 'wallet-1',
            'walletDek': base64Encode(walletDek),
          }),
        });
        addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
        final authenticator = _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: false,
        );
        final store = BiometricPasswordStore(
          authenticator: authenticator,
          storage: FlutterSecurePasswordStorage(),
        );

        final result = await store.readUnlockMaterialWithStatus(
          walletId: 'wallet-1',
          reason: 'Unlock wallet',
        );

        expect(authenticator.authenticateCallCount, 1);
        expect(result.walletDek, isNull);
      },
    );

    test(
      'credential for another wallet is unavailable without prompting',
      () async {
        final authenticator = _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        );
        final store = BiometricPasswordStore(
          authenticator: authenticator,
          storage: _FakeSecurePasswordStorage(),
        );
        await store.saveWalletKey(
          walletId: 'wallet-1',
          walletDek: List<int>.filled(32, 7),
        );

        final result = await store.readUnlockMaterialWithStatus(
          walletId: 'wallet-2',
          reason: 'Unlock wallet',
        );

        expect(result.hasSavedCredential, isFalse);
        expect(result.walletDek, isNull);
        expect(authenticator.authenticateCallCount, 0);
      },
    );

    test('wallet deletion clears the credential without reading it', () async {
      final storage = _FakeSecurePasswordStorage()
        ..password = jsonEncode({
          'kind': 'safe_wallet_biometric_credential',
          'version': 2,
          'walletId': 'wallet-1',
          'walletDek': base64Encode(List<int>.filled(32, 7)),
        })
        ..throwOnRead = true;
      final store = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(canAuthenticate: true),
        storage: storage,
      );

      await store.clearWallet('wallet-1');

      expect(storage.password, isNull);
      expect(storage.readCallCount, 0);
    });

    test('production secure storage requires hardware-backed biometrics', () {
      final source = File(
        'lib/shared/security/biometric_password_store.dart',
      ).readAsStringSync();

      expect(source, contains('AndroidOptions.biometric'));
      expect(source, contains('enforceBiometrics: true'));
      expect(source, contains('AccessControlFlag.biometryCurrentSet'));
      expect(source, contains('KeychainAccessibility.passcode'));
    });
  });

  test('interactive biometric authentication waits for the plugin result', () {
    final source = File(
      'lib/shared/security/biometric_password_store.dart',
    ).readAsStringSync();
    final classStart = source.indexOf(
      'final class LocalAuthBiometricAuthenticator',
    );
    final classEnd = source.indexOf(
      'final class FlutterSecurePasswordStorage',
      classStart,
    );
    final authenticatorSource = source.substring(classStart, classEnd);
    final methodStart = authenticatorSource.indexOf(
      'Future<bool> authenticate({required String reason})',
    );
    final methodEnd = authenticatorSource.indexOf('\n  }\n}', methodStart);
    final authenticateMethod = authenticatorSource.substring(
      methodStart,
      methodEnd,
    );

    expect(
      authenticateMethod,
      isNot(contains('.timeout(')),
      reason: 'Biometric prompts must allow time for the user to respond.',
    );
  });

  test('cold-start biometric capability checks allow plugin startup time', () {
    final source = File(
      'lib/shared/security/biometric_password_store.dart',
    ).readAsStringSync();
    final classStart = source.indexOf(
      'final class LocalAuthBiometricAuthenticator',
    );
    final classEnd = source.indexOf(
      'final class FlutterSecurePasswordStorage',
      classStart,
    );
    final authenticatorSource = source.substring(classStart, classEnd);

    expect(
      authenticatorSource,
      contains('Duration(seconds: 5)'),
      reason: 'Cold-start plugin initialization can exceed 500ms.',
    );
    expect(authenticatorSource, isNot(contains('Duration(milliseconds: 500)')));
  });

  test(
    'password-only flows do not call the retired biometric password API',
    () {
      const paths = [
        'lib/features/wallet/presentation/signing_password_sheet.dart',
        'lib/features/wallet/presentation/export_secret_confirm_page.dart',
        'lib/features/wallet/presentation/wallet_management_page.dart',
        'lib/features/settings/presentation/security_settings_page.dart',
      ];

      for (final path in paths) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('readBiometricPassword')),
          reason: path,
        );
      }
    },
  );
}

final class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    required this.canAuthenticate,
    this.authenticateResult = true,
  });

  final bool canAuthenticate;
  final bool authenticateResult;
  int authenticateCallCount = 0;
  String? lastReason;

  @override
  Future<bool> canAuthenticateWithBiometrics() async {
    return canAuthenticate;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCallCount += 1;
    lastReason = reason;
    return authenticateResult;
  }
}

final class _FakeSecurePasswordStorage implements SecurePasswordStorage {
  String? password;
  bool throwOnRead = false;
  int readCallCount = 0;

  @override
  Future<String?> readPassword() async {
    readCallCount += 1;
    if (throwOnRead) {
      throw StateError('read requires user authentication');
    }
    return password;
  }

  @override
  Future<void> savePassword(String password) async {
    this.password = password;
  }

  @override
  Future<void> deletePassword() async {
    password = null;
  }
}
