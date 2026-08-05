import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/onboarding/presentation/set_password_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';

void main() {
  group('SetPasswordPage', () {
    testWidgets('accepts an eight-character password', (tester) async {
      var submitCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: SetPasswordPage(
                progressLabel: 'Creating',
                onSubmit: (_) async {
                  submitCalls += 1;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'A3!xyz78',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'A3!xyz78',
      );
      await tester.tap(find.text(t.actions.done));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitCalls, 1);
      expect(find.textContaining('钱包密码至少需要'), findsNothing);
    });

    testWidgets('renders progress before invoking password submission', (
      tester,
    ) async {
      final submitCompleter = Completer<void>();
      var submitCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: SetPasswordPage(
                progressLabel: 'Importing',
                onSubmit: (_) {
                  submitCalls += 1;
                  return submitCompleter.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'A3!xyz78',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'A3!xyz78',
      );

      final submitButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, t.actions.done),
      );
      submitButton.onPressed!();

      expect(submitCalls, 0);

      await tester.pump();

      expect(find.text('Importing'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(submitCalls, 1);

      submitCompleter.complete();
      await tester.pump();
    });

    testWidgets('rejects passwords shorter than eight characters', (
      tester,
    ) async {
      var submitCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: SetPasswordPage(
                progressLabel: 'Creating',
                onSubmit: (_) async {
                  submitCalls += 1;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('passwordInput')), 'A3!xyz7');
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'A3!xyz7',
      );
      await tester.tap(find.text(t.actions.done));
      await tester.pump();

      expect(submitCalls, 0);
      expect(find.text('钱包密码至少需要 8 个字符'), findsOneWidget);
    });

    testWidgets('rejects common weak passwords', (tester) async {
      var submitCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: SetPasswordPage(
                progressLabel: 'Creating',
                onSubmit: (_) async {
                  submitCalls += 1;
                },
              ),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'password2026',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'password2026',
      );
      await tester.tap(find.text(t.actions.done));
      await tester.pump();

      expect(submitCalls, 0);
      expect(find.text('该密码过于常见，请使用更难猜的密码'), findsOneWidget);
    });

    testWidgets('offers biometric setup after password submit succeeds', (
      tester,
    ) async {
      final storage = _FakeSecurePasswordStorage();
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: storage,
      );
      final repository = _BiometricSetupWalletRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biometricPasswordStoreProvider.overrideWithValue(biometricStore),
            walletRepositoryProvider.overrideWithValue(repository),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: SetPasswordPage(
                progressLabel: 'Creating',
                onSubmit: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('passwordInput')),
        'global-password',
      );
      await tester.enterText(
        find.byKey(const Key('confirmPasswordInput')),
        'global-password',
      );
      await tester.tap(find.text(t.actions.done));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(t.wallet.biometricSetupTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('enableBiometricPasswordButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(storage.password, contains('"version":3'));
      expect(storage.password, contains('"wallet-1"'));
      expect(storage.password, isNot(contains('global-password')));
    });
  });
}

final class _BiometricSetupWalletRepository implements WalletRepository {
  final account = WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '',
    createdAt: DateTime.utc(2026, 8, 2),
    updatedAt: DateTime.utc(2026, 8, 2),
  );

  @override
  Future<List<WalletAccount>> getWallets() async => [account];

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    return WalletUnlockResult(
      account: account,
      walletDek: List<int>.generate(32, (index) => index),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
