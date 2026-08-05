import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/presentation/unlock_wallet_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  group('UnlockWalletPage', () {
    final account = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      solanaAddress: '11111111111111111111111111111111',
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    testWidgets('uses saved biometric wallet key without password derivation', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(account: account);
      final cache = SessionKeyCache();
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: _FakeSecurePasswordStorage()
          ..password = jsonEncode({
            'kind': 'safe_wallet_biometric_credential',
            'version': 3,
            'walletDeks': {
              account.id: base64Encode(List<int>.filled(32, 9)),
              'wallet-2': base64Encode(List<int>.filled(32, 8)),
            },
          }),
      );

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: biometricStore,
          cache: cache,
          home: UnlockWalletPage(account: account),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.unlockCallCount, 0);
      expect(
        cache.readKey('wallet-2', now: DateTime.now().toUtc()),
        List<int>.filled(32, 8),
      );
    });
  });
}

Widget _walletApp({
  required WalletRepository repository,
  required BiometricPasswordStore biometricStore,
  required SessionKeyCache cache,
  required Widget home,
}) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      biometricPasswordStoreProvider.overrideWithValue(biometricStore),
      sessionKeyCacheProvider.overrideWithValue(cache),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({required this.account});

  final WalletAccount account;
  int unlockCallCount = 0;
  String? lastUnlockWalletId;
  String? lastUnlockPassword;

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCallCount += 1;
    lastUnlockWalletId = walletId;
    lastUnlockPassword = password;
    return WalletUnlockResult(account: account, walletDek: [1, 2, 3]);
  }

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => [account];

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({
    required this.canAuthenticate,
    required this.authenticateResult,
  });

  final bool canAuthenticate;
  final bool authenticateResult;

  @override
  Future<bool> canAuthenticateWithBiometrics() async => canAuthenticate;

  @override
  Future<bool> authenticate({required String reason}) async {
    return authenticateResult;
  }
}

final class _FakeSecurePasswordStorage implements SecurePasswordStorage {
  String? password;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> savePassword(String password) async {
    this.password = password;
  }

  @override
  Future<void> deletePassword() async {
    password = null;
  }
}
