import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/presentation/signing_password_sheet.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  group('SigningPasswordSheet', () {
    testWidgets('uses 12px vertical drag handle spacing', (tester) async {
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: false,
          authenticateResult: false,
        ),
        storage: _FakeSecurePasswordStorage(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
            walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () => showSigningPasswordSheet(context),
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appDragHandle')), findsOneWidget);
      final handlePadding = tester.widget<Padding>(
        find.byKey(const Key('appDragHandle')),
      );
      expect(handlePadding.padding, const EdgeInsets.symmetric(vertical: 12));
    });

    testWidgets('biometric wallet key authorizes signing without password', (
      tester,
    ) async {
      SigningPasswordAuthorization? authorization;
      final walletDek = List<int>.filled(32, 7);
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: _FakeSecurePasswordStorage(),
      );
      await biometricStore.saveWalletKeys({_account.id: walletDek});
      final cache = SessionKeyCache();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
            walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
            sessionKeyCacheProvider.overrideWithValue(cache),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        authorization = await showSigningPasswordSheet(context);
                      },
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(authorization?.password, isEmpty);
      expect(authorization?.rememberPassword, isTrue);
      expect(cache.readKey(_account.id, now: DateTime.now().toUtc()), walletDek);
      expect(find.byKey(const Key('signingPasswordInput')), findsNothing);
    });

    testWidgets('removes remember-password option and validates password', (
      tester,
    ) async {
      SigningPasswordAuthorization? authorization;
      final repository = _FakeWalletRepository();
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: false,
          authenticateResult: false,
        ),
        storage: _FakeSecurePasswordStorage(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
            walletRepositoryProvider.overrideWithValue(repository),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        authorization = await showSigningPasswordSheet(context);
                      },
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text(t.wallet.rememberSigningPassword), findsNothing);

      await tester.enterText(
        find.byKey(const Key('signingPasswordInput')),
        'wrong-password',
      );
      await tester.tap(find.text(t.actions.confirm));
      await tester.pumpAndSettle();

      expect(authorization, isNull);
      expect(repository.unlockPasswords, ['wrong-password']);

      await tester.enterText(
        find.byKey(const Key('signingPasswordInput')),
        'correct-password',
      );
      await tester.tap(find.text(t.actions.confirm));
      await tester.pumpAndSettle();

      expect(authorization?.password, 'correct-password');
      expect(authorization?.rememberPassword, isTrue);
    });
  });
}

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '11111111111111111111111111111111',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

final class _FakeWalletRepository implements WalletRepository {
  final List<String> unlockPasswords = [];

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockPasswords.add(password);
    if (password != 'correct-password') {
      throw StateError('invalid password');
    }
    return WalletUnlockResult(
      account: _account,
      walletDek: List<int>.filled(32, 7),
    );
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) => throw UnimplementedError();

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) => throw UnimplementedError();
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
