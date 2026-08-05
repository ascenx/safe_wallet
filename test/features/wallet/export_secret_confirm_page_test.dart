import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/presentation/export_secret_confirm_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/biometric_password_store.dart';
import 'package:safe_wallet/shared/security/sensitive_clipboard.dart';

void main() {
  group('ExportSecretConfirmPage', () {
    final account = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      solanaAddress: '11111111111111111111111111111111',
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );

    testWidgets('legacy biometric passwords are not used for secret export', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(account: account);
      final biometricStore = BiometricPasswordStore(
        authenticator: _FakeBiometricAuthenticator(
          canAuthenticate: true,
          authenticateResult: true,
        ),
        storage: _FakeSecurePasswordStorage()..password = 'saved-password',
      );

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: biometricStore,
          home: _ExportLauncher(
            wallet: account,
            secretType: WalletSecretType.mnemonic,
          ),
        ),
      );
      await tester.tap(find.text('Open export'));
      await tester.pumpAndSettle();

      expect(repository.exportCallCount, 0);
      expect(
        find.byKey(const Key('exportSecretPasswordInput')),
        findsOneWidget,
      );
    });

    testWidgets('password is requested in an autofocus bottom sheet', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(account: account);

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: _manualPasswordStore(),
          home: _ExportLauncher(
            wallet: account,
            secretType: WalletSecretType.mnemonic,
          ),
        ),
      );
      await tester.tap(find.text('Open export'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ExportSecretConfirmPage), findsNothing);
      expect(find.text('验证钱包密码'), findsOneWidget);
      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('exportSecretPasswordInput')),
      );
      expect(passwordField.autofocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text(_FakeWalletRepository.mnemonic), findsNothing);
    });

    testWidgets('mnemonic result has copy action and mnemonic risk warning', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(account: account);
      final securityLogs = InMemorySecurityLogRepository();
      String? clipboardText;
      const sensitiveClipboardChannel = MethodChannel(
        'safe_wallet/sensitive_clipboard',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        sensitiveClipboardChannel,
        (call) async {
          if (call.method == 'copySensitiveText') {
            final arguments = call.arguments as Map<Object?, Object?>;
            clipboardText = arguments['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          sensitiveClipboardChannel,
          null,
        );
        SensitiveClipboardService.instance.dispose();
      });

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: _manualPasswordStore(),
          securityLogRepository: securityLogs,
          home: _ExportLauncher(
            wallet: account,
            secretType: WalletSecretType.mnemonic,
          ),
        ),
      );
      await tester.tap(find.text('Open export'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('exportSecretPasswordInput')),
        'password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ExportSecretConfirmPage), findsOneWidget);
      expect(find.byKey(const Key('exportSecretPasswordInput')), findsNothing);
      expect(find.text(_FakeWalletRepository.mnemonic), findsOneWidget);
      expect(
        tester.widget(find.byKey(const Key('exportSecretValue'))),
        isA<Text>(),
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(
        find.text('助记词可恢复钱包并控制全部资产。请勿截图、上传云端或发送给任何人；复制后请及时清理剪贴板。'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('exportSecretCopyButton')));
      await tester.pump();

      expect(clipboardText, _FakeWalletRepository.mnemonic);
      expect(find.text('助记词已复制'), findsOneWidget);
      final copyEntry = (await securityLogs.listEntries()).single;
      expect(copyEntry.type, SecurityLogEventType.copyMnemonic);
      expect(copyEntry.walletName, 'Main Wallet');
      expect(copyEntry.chainName, isNull);
      await tester.pump(const Duration(seconds: 2));
      SensitiveClipboardService.instance.dispose();
    });

    testWidgets('private key result has a private key risk warning', (
      tester,
    ) async {
      final repository = _FakeWalletRepository(account: account);
      final securityLogs = InMemorySecurityLogRepository();
      const sensitiveClipboardChannel = MethodChannel(
        'safe_wallet/sensitive_clipboard',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        sensitiveClipboardChannel,
        (_) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          sensitiveClipboardChannel,
          null,
        );
        SensitiveClipboardService.instance.dispose();
      });

      await tester.pumpWidget(
        _walletApp(
          repository: repository,
          biometricStore: _manualPasswordStore(),
          securityLogRepository: securityLogs,
          home: _ExportLauncher(
            wallet: account,
            secretType: WalletSecretType.evmPrivateKey,
          ),
        ),
      );
      await tester.tap(find.text('Open export'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('exportSecretPasswordInput')),
        'password',
      );
      await tester.tap(find.widgetWithText(FilledButton, '确认'));
      await tester.pumpAndSettle();

      expect(find.text(_FakeWalletRepository.privateKey), findsOneWidget);
      expect(
        find.text('私钥可直接控制对应网络资产。请勿截图、粘贴到不可信应用或发送给任何人；复制后请及时清理剪贴板。'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('exportSecretCopyButton')));
      await tester.pump();

      final copyEntry = (await securityLogs.listEntries()).single;
      expect(copyEntry.type, SecurityLogEventType.copyPrivateKey);
      expect(copyEntry.walletName, 'Main Wallet');
      expect(copyEntry.chainName, 'EVM');
      await tester.pump(const Duration(seconds: 2));
      SensitiveClipboardService.instance.dispose();
    });
  });
}

final class _ExportLauncher extends StatelessWidget {
  const _ExportLauncher({required this.wallet, required this.secretType});

  final WalletAccount wallet;
  final WalletSecretType secretType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => showExportSecretFlow(
            context,
            wallet: wallet,
            secretType: secretType,
          ),
          child: const Text('Open export'),
        ),
      ),
    );
  }
}

BiometricPasswordStore _manualPasswordStore() {
  return BiometricPasswordStore(
    authenticator: _FakeBiometricAuthenticator(
      canAuthenticate: false,
      authenticateResult: false,
    ),
    storage: _FakeSecurePasswordStorage(),
  );
}

Widget _walletApp({
  required WalletRepository repository,
  required BiometricPasswordStore biometricStore,
  required Widget home,
  SecurityLogRepository? securityLogRepository,
}) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      biometricPasswordStoreProvider.overrideWithValue(biometricStore),
      if (securityLogRepository != null)
        securityLogRepositoryProvider.overrideWithValue(securityLogRepository),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({required this.account});

  static const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  static const privateKey =
      '0x1111111111111111111111111111111111111111111111111111111111111111';

  final WalletAccount account;
  int exportCallCount = 0;
  String? lastExportPassword;

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) async {
    exportCallCount += 1;
    lastExportPassword = password;
    return secretType == WalletSecretType.mnemonic ? mnemonic : privateKey;
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
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
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
