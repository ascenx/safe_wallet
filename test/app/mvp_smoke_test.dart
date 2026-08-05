import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/features/address_book/application/address_book_controller.dart';
import 'package:safe_wallet/features/address_book/data/address_book_repository.dart';
import 'package:safe_wallet/features/address_book/domain/address_book_contact.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/browser/data/hive_browser_state_repository.dart';
import 'package:safe_wallet/features/browser/presentation/browser_home_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/home/application/home_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/features/settings/presentation/settings_page.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/app_error.dart';

void main() {
  group('MVP smoke', () {
    testWidgets('create wallet flow reaches home shell', (tester) async {
      final walletRepository = _FakeWalletRepository();

      await tester.pumpWidget(_safeWalletApp(walletRepository));
      await tester.pumpAndSettle();

      expect(find.text('创建钱包'), findsOneWidget);
      expect(find.text('导入钱包'), findsOneWidget);

      await tester.tap(find.text('创建钱包'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '应用会生成一组新的助记词，并派生默认 EVM、Bitcoin、Tron、Solana 和 Sui 地址。',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();

      expect(find.text('助记词丢失后无法找回钱包'), findsOneWidget);

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

      expect(walletRepository.createWalletCalls, 1);
      expect(find.text('总资产估值'), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('浏览器'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('import mnemonic flow reaches home shell', (tester) async {
      final walletRepository = _FakeWalletRepository();

      await tester.pumpWidget(_safeWalletApp(walletRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('助记词钱包'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('mnemonicInput')),
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
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

      final wallets = await walletRepository.getWallets();
      expect(wallets, hasLength(1));
      expect(find.text('总资产估值'), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('浏览器'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('import private key flow reaches home shell', (tester) async {
      final walletRepository = _FakeWalletRepository();

      await tester.pumpWidget(_safeWalletApp(walletRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('私钥钱包'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EVM'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('privateKeyInput')),
        _privateKey,
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

      final wallets = await walletRepository.getWallets();
      expect(wallets, hasLength(1));
      expect(wallets.single.solanaAddress, isEmpty);
      expect(find.text('总资产估值'), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('浏览器'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('invalid private key import shows a localized error', (
      tester,
    ) async {
      final walletRepository = _FakeWalletRepository();

      await tester.pumpWidget(_safeWalletApp(walletRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('导入钱包'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('私钥钱包'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EVM'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('privateKeyInput')),
        'not-a-private-key',
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

      expect(await walletRepository.getWallets(), isEmpty);
      expect(find.text('私钥格式无效'), findsOneWidget);
      expect(find.text('总资产估值'), findsNothing);
    });

    testWidgets(
      'settings address book contact can be picked on transfer',
      (tester) async {
        final walletRepository = _FakeWalletRepository.withAccount(_account);
        final addressBookRepository = _FakeAddressBookRepository();

        await tester.pumpWidget(
          _safeWalletApp(
            walletRepository,
            addressBookRepository: addressBookRepository,
            assetPortfolio: AssetPortfolio.loaded([_oneEthBalance]),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('设置'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('地址簿'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('新增联系人'));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.widgetWithText(TextField, '联系人名称'), 'Alice');
        await tester.enterText(
          find.widgetWithText(TextField, '钱包地址'),
          _contactAddress,
        );
        await tester.enterText(
            find.widgetWithText(TextField, '备注'), 'DEX friend');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(addressBookRepository.contacts, hasLength(1));
        expect(find.text('Alice'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('首页'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('转账'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('选择联系人'));
        await tester.pumpAndSettle();

        expect(find.text('选择联系人'), findsAtLeastNWidgets(1));
        await tester.tap(find.text('Alice').last);
        await tester.pumpAndSettle();

        final recipientField = tester.widget<TextField>(
          find.widgetWithText(TextField, '收款地址'),
        );
        expect(recipientField.controller?.text, _contactAddress);
      },
    );

    testWidgets('browser opens default Swap dApp and approval is persisted', (
      tester,
    ) async {
      final openedUrls = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserStateRepositoryProvider.overrideWithValue(
              InMemoryBrowserStateRepository(),
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Scaffold(
                body: BrowserHomePage(onOpenUrl: openedUrls.add),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Swap'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'uniswap');
      await tester.pump();

      await tester.tap(find.text('Uniswap'));
      await tester.pumpAndSettle();

      expect(openedUrls, isEmpty);
      expect(find.text('确认打开网站'), findsOneWidget);
      expect(find.text('app.uniswap.org'), findsOneWidget);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(openedUrls, ['https://app.uniswap.org']);

      final permissionRepository = InMemoryDappPermissionRepository();
      final container = ProviderContainer(
        overrides: [
          dappPermissionRepositoryProvider.overrideWithValue(
            permissionRepository,
          ),
          walletRepositoryProvider.overrideWithValue(
            _FakeWalletRepository.withAccount(_account),
          ),
          chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedWalletIdProvider.notifier).select(_account.id);

      final result =
          await container.read(dappRequestControllerProvider.notifier).handle(
                const DappRpcRequest(
                  origin: 'https://app.uniswap.org/swap',
                  method: 'eth_requestAccounts',
                ),
                authorizationDecision: DappAuthorizationDecision.approved,
                now: _now,
              );

      final stored = await permissionRepository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: _account.id,
        chainId: '1',
      );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, [_account.evmAddress]);
      expect(stored?.address, _account.evmAddress);
    });

    testWidgets('transfer validates invalid address and insufficient balance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _safeWalletApp(
          _FakeWalletRepository.withAccount(_account),
          assetPortfolio: AssetPortfolio.loaded([_oneEthBalance]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('转账'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '收款地址'),
        'not-an-address',
      );
      await tester.enterText(find.widgetWithText(TextField, '金额'), '0.1');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('收款地址格式无效'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '收款地址'),
        _contactAddress,
      );
      await tester.enterText(find.widgetWithText(TextField, '金额'), '1.01');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('余额不足'), findsOneWidget);
    });

    testWidgets('settings language switch updates visible app copy', (
      tester,
    ) async {
      final store =
          InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh);

      await tester.pumpWidget(
        _safeWalletApp(
          _FakeWalletRepository.withAccount(_account),
          localePreferenceStore: store,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      await tester.drag(
        find.descendant(
          of: find.byType(SettingsPage),
          matching: find.byType(ListView),
        ),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('偏好设置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('多语言设置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(await store.readLocaleMode(), AppLocaleMode.en);
      expect(find.text('Preferences'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(find.text('Wallet Management'), findsOneWidget);
    });

    testWidgets('system locale mode follows an English device locale', (
      tester,
    ) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

      await tester.pumpWidget(
        _safeWalletApp(
          _FakeWalletRepository.withAccount(_account),
          localePreferenceStore: InMemoryLocalePreferenceStore(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('首页'), findsNothing);
    });
  });
}

Widget _safeWalletApp(
  _FakeWalletRepository walletRepository, {
  _FakeAddressBookRepository? addressBookRepository,
  AssetPortfolio? assetPortfolio,
  LocalePreferenceStore? localePreferenceStore,
}) {
  return ProviderScope(
    overrides: [
      walletRepositoryProvider.overrideWithValue(walletRepository),
      homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
      browserStateRepositoryProvider.overrideWithValue(
        InMemoryBrowserStateRepository(),
      ),
      localePreferenceStoreProvider.overrideWithValue(
        localePreferenceStore ??
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
      ),
      if (walletRepository.hasWalletsAtLaunch)
        launchLockSettingStoreProvider.overrideWithValue(
          InMemoryLaunchLockSettingStore(requirePasswordOnLaunch: false),
        ),
      if (addressBookRepository != null)
        addressBookRepositoryProvider.overrideWithValue(addressBookRepository),
      if (assetPortfolio != null) ...[
        assetPortfolioRequestProvider.overrideWithValue(
          Future.value(_assetPortfolioRequest),
        ),
        assetPortfolioProvider.overrideWith((ref) async => assetPortfolio),
      ],
    ],
    child: const SafeWalletApp(),
  );
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository();

  _FakeWalletRepository.withAccount(WalletAccount account) {
    _wallets.add(account);
  }

  final List<WalletAccount> _wallets = [];
  int createWalletCalls = 0;

  bool get hasWalletsAtLaunch => _wallets.isNotEmpty;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) async {
    createWalletCalls += 1;
    final account = _wallet(id: 'wallet-${_wallets.length + 1}', name: name);
    _wallets.add(account);
    return account;
  }

  @override
  Future<List<WalletAccount>> getWallets() async {
    return List.unmodifiable(_wallets);
  }

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
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) async {
    final account = _wallet(id: 'wallet-${_wallets.length + 1}', name: name);
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
    if (privateKey == 'not-a-private-key') {
      throw const _InvalidPrivateKeyError();
    }
    final account = _wallet(
      id: 'wallet-${_wallets.length + 1}',
      name: name,
      solanaAddress: '',
    );
    _wallets.add(account);
    return account;
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
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    return WalletUnlockResult(account: _wallets.first, walletDek: const [1]);
  }
}

final class _FakeAddressBookRepository implements AddressBookRepository {
  final contacts = <AddressBookContact>[];

  @override
  Future<void> deleteContact(String contactId) async {
    contacts.removeWhere((contact) => contact.id == contactId);
  }

  @override
  Future<List<AddressBookContact>> listContacts() async {
    return List.unmodifiable(contacts);
  }

  @override
  Future<AddressBookContact> saveContact(AddressBookContact contact) async {
    contacts.removeWhere((existing) => existing.id == contact.id);
    contacts.add(contact);
    return contact;
  }
}

final class _FakeChainRepository implements ChainRepository {
  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChainConfig> getSelectedChain() async => _ethereum;

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    return defaultChains.firstWhere((chain) => chain.id == chainId);
  }
}

WalletAccount _wallet({
  required String id,
  required String name,
  String solanaAddress = 'So11111111111111111111111111111111111111112',
}) {
  return WalletAccount(
    id: id,
    name: name,
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: solanaAddress,
    createdAt: _now,
    updatedAt: _now,
  );
}

final class _InvalidPrivateKeyError implements AppError {
  const _InvalidPrivateKeyError();

  @override
  String get code => 'invalid_private_key';

  @override
  String get safeMessageKey => 'errors.invalidPrivateKey';

  @override
  String get debugMessage => 'Private key format is invalid';
}

final _now = DateTime.utc(2026, 6, 6, 12);
final _account = _wallet(id: 'wallet-1', name: 'Wallet 1');
final _ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
const _contactAddress = '0x2222222222222222222222222222222222222222';
const _privateKey =
    '4c0883a69102937d6231471b5dbb6204fe512961708279ded5b205db7368a7f5';
const _rpcNode = RpcNode(
  id: 'node-1',
  chainId: '1',
  name: 'Default Ethereum',
  url: 'https://rpc.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);
final _assetPortfolioRequest = AssetPortfolioRequest(
  account: _account,
  chain: _ethereum,
  rpcNode: _rpcNode,
);
final _oneEthBalance = AssetBalance(
  chainId: _ethereum.chainId,
  token: TokenInfo(
    chainId: _ethereum.chainId,
    contractAddress: null,
    symbol: _ethereum.symbol,
    name: _ethereum.name,
    decimals: 18,
    source: TokenSource.builtIn,
    isHidden: false,
  ),
  balance: BigInt.from(10).pow(18).toString(),
  formattedBalance: '1',
  status: AssetBalanceStatus.loaded,
);
