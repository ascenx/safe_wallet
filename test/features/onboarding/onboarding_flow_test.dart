import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/features/home/application/home_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/design/app_spacing.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';

void main() {
  testWidgets(
      'create flow reaches main home without a backup confirmation gate', (
    tester,
  ) async {
    final repository = _FakeWalletRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('创建钱包'), findsOneWidget);
    expect(find.text('导入钱包'), findsOneWidget);

    await tester.tap(find.text('创建钱包'));
    await tester.pumpAndSettle();

    expect(
      find.text('应用会生成一组新的助记词，并派生默认 EVM、Bitcoin、Tron、Solana 和 Sui 地址。'),
      findsOneWidget,
    );

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('助记词丢失后无法找回钱包'), findsOneWidget);
    expect(find.text('备份确认'), findsNothing);

    await tester.tap(find.text('我已了解风险'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('passwordInput')),
      'StrongPass123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordInput')),
      'StrongPass123',
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.createWalletCalls, 1);
    expect(find.text('总资产估值'), findsOneWidget);
  });

  testWidgets('create wallet intro copy starts at the top without an icon', (
    tester,
  ) async {
    final repository = _FakeWalletRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建钱包'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);

    final bodyTop = tester
        .getTopLeft(
          find.text('应用会生成一组新的助记词，并派生默认 EVM、Bitcoin、Tron、Solana 和 Sui 地址。'),
        )
        .dy;
    expect(bodyTop, lessThan(120));
  });

  testWidgets('create wallet continue button fills the content width', (
    tester,
  ) async {
    final repository = _FakeWalletRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建钱包'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, '继续');
    expect(
      tester.getSize(button).width,
      390 - AppSpacing.pageX * 2,
    );
  });

  testWidgets(
      'mnemonic risk copy starts at the top and action is bottom pinned',
      (tester) async {
    final repository = _FakeWalletRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('创建钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.warning), findsNothing);

    final titleTop = tester.getTopLeft(find.text('助记词丢失后无法找回钱包')).dy;
    expect(titleTop, lessThan(120));

    final buttonBottom =
        tester.getBottomLeft(find.widgetWithText(FilledButton, '我已了解风险')).dy;
    expect(buttonBottom, greaterThan(760));
  });

  testWidgets('import invalid mnemonic shows a localized error',
      (tester) async {
    final repository = _FakeWalletRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入钱包'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('助记词钱包'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mnemonicInput')),
      'invalid mnemonic words',
    );
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('passwordInput')),
      'StrongPass123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordInput')),
      'StrongPass123',
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.importMnemonicCalls, 1);
    expect(find.text('助记词格式或校验和无效'), findsOneWidget);
    expect(find.text('总资产估值'), findsNothing);
  });

  testWidgets('import Bitcoin private key forwards the Bitcoin chain',
      (tester) async {
    final repository = _FakeWalletRepository();

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入钱包'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('私钥钱包'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bitcoin'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('privateKeyInput')),
      'bitcoin-private-key',
    );
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('passwordInput')),
      'StrongPass123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordInput')),
      'StrongPass123',
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.importPrivateKeyCalls, 1);
    expect(repository.lastImportedPrivateKey, 'bitcoin-private-key');
    expect(
      repository.lastImportedPrivateKeyChain,
      WalletPrivateKeyChain.bitcoin,
    );
    expect(find.text('总资产估值'), findsOneWidget);
  });

  testWidgets('import Sui private key forwards the Sui chain', (tester) async {
    final repository = _FakeWalletRepository();
    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导入钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('私钥钱包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sui'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('privateKeyInput')),
      'suiprivkey-test-value',
    );
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('passwordInput')),
      'StrongPass123',
    );
    await tester.enterText(
      find.byKey(const Key('confirmPasswordInput')),
      'StrongPass123',
    );
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.lastImportedPrivateKey, 'suiprivkey-test-value');
    expect(
      repository.lastImportedPrivateKeyChain,
      WalletPrivateKeyChain.sui,
    );
  });
}

Widget _buildApp(_FakeWalletRepository repository) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(repository),
      homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
      localePreferenceStoreProvider.overrideWithValue(
        InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
      ),
    ],
    child: const SafeWalletApp(),
  );
}

final class _FakeWalletRepository implements WalletRepository {
  final List<WalletAccount> _wallets = [];
  int createWalletCalls = 0;
  int importMnemonicCalls = 0;
  int importPrivateKeyCalls = 0;
  String? lastImportedPrivateKey;
  WalletPrivateKeyChain? lastImportedPrivateKeyChain;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) async {
    createWalletCalls += 1;
    final account = _account(name: name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<List<WalletAccount>> getWallets() async => List.unmodifiable(_wallets);

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
  }) async {
    importMnemonicCalls += 1;
    if (mnemonic == 'invalid mnemonic words') {
      throw const WalletError.invalidMnemonic();
    }
    final account = _account(name: name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) async {
    importPrivateKeyCalls += 1;
    lastImportedPrivateKey = privateKey;
    lastImportedPrivateKeyChain = chain;
    final account = _account(name: name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    return WalletUnlockResult(account: _wallets.first, walletDek: const [1]);
  }

  WalletAccount _account({required String name}) {
    final now = DateTime.utc(2026, 6, 6);
    return WalletAccount(
      id: 'wallet-${_wallets.length + 1}',
      name: name,
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: 'So11111111111111111111111111111111111111112',
      btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      createdAt: now,
      updatedAt: now,
    );
  }
}
