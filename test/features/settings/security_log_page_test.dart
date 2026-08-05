import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/settings/presentation/security_settings_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  group('security log UI', () {
    testWidgets(
      'shows a password-protected log entry without an enable switch',
      (tester) async {
        final logs = InMemorySecurityLogRepository();
        final walletRepository = _FakeWalletRepository();
        await tester.pumpWidget(_app(logs, walletRepository));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('安全日志'),
          300,
          scrollable: find.byType(Scrollable),
        );

        expect(find.byKey(const Key('securityLogSwitch')), findsNothing);
        expect(find.byKey(const Key('viewSecurityLogsRow')), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
      },
    );

    testWidgets('requires a password then shows local operation-only logs', (
      tester,
    ) async {
      final logs = InMemorySecurityLogRepository();
      await logs.record(
        SecurityLogEventType.viewMnemonic,
        walletName: 'Main Wallet',
        occurredAt: DateTime.utc(2026, 7, 31, 12, 30),
      );
      await logs.record(
        SecurityLogEventType.signTransaction,
        walletName: 'Trading Wallet',
        chainName: 'Ethereum',
        assetSymbol: 'ETH',
        amount: '0.1',
        address: '0x1111111111111111111111111111111111111111',
        occurredAt: DateTime.utc(2026, 7, 31, 13, 45),
      );
      await logs.record(
        SecurityLogEventType.wrapNative,
        walletName: 'Trading Wallet',
        chainName: 'Ethereum',
        assetSymbol: 'WETH',
        amount: '0.25',
        occurredAt: DateTime.utc(2026, 7, 31, 14),
      );
      final walletRepository = _FakeWalletRepository();
      await tester.pumpWidget(_app(logs, walletRepository));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('安全日志'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('viewSecurityLogsRow')));
      await tester.pumpAndSettle();

      expect(find.text('验证钱包密码'), findsOneWidget);
      expect(find.text('交易签名'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('securityLogPasswordInput')),
        'wallet-password',
      );
      await tester.tap(
        find.byKey(const Key('confirmSecurityLogPasswordButton')),
      );
      await tester.pumpAndSettle();

      expect(find.text('交易签名'), findsOneWidget);
      expect(find.text('封装原生币'), findsOneWidget);
      expect(find.text('查看助记词'), findsOneWidget);
      expect(find.text('钱包：Trading Wallet'), findsNWidgets(2));
      expect(find.text('链：Ethereum'), findsNWidgets(2));
      expect(find.text('金额：0.1 ETH'), findsOneWidget);
      expect(
        find.text('公开地址：0x1111111111111111111111111111111111111111'),
        findsOneWidget,
      );
      expect(find.text('钱包：Main Wallet'), findsOneWidget);
      expect(
        find.text(_formatLocalTime(DateTime.utc(2026, 7, 31, 13, 45))),
        findsOneWidget,
      );
      expect(
        find.text(
          '安全日志仅记录操作类型、钱包名称、链、公开地址、币种、数量和时间，并只存储在您的设备本地，不会保存私钥、助记词、密码或签名内容。',
        ),
        findsOneWidget,
      );
    });
  });
}

String _formatLocalTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

Widget _app(SecurityLogRepository logs, WalletRepository walletRepository) {
  LocaleSettings.setLocale(AppLocale.zh);
  return ProviderScope(
    overrides: [
      securityLogRepositoryProvider.overrideWithValue(logs),
      walletRepositoryProvider.overrideWithValue(walletRepository),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const SecuritySettingsPage(),
      ),
    ),
  );
}

final class _FakeWalletRepository implements WalletRepository {
  String? lastUnlockPassword;

  static final account = WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '11111111111111111111111111111111',
    createdAt: DateTime.utc(2026, 7, 31),
    updatedAt: DateTime.utc(2026, 7, 31),
  );

  @override
  Future<List<WalletAccount>> getWallets() async => [account];

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    lastUnlockPassword = password;
    return WalletUnlockResult(account: account, walletDek: const [1, 2, 3]);
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
