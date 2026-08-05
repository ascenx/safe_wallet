import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/app/shell/main_shell_page.dart';
import 'package:safe_wallet/features/browser/presentation/browser_home_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/home/application/home_controller.dart';
import 'package:safe_wallet/features/home/presentation/home_page.dart';
import 'package:safe_wallet/features/home/presentation/widgets/quick_action_card.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/features/settings/application/theme_mode_setting.dart';
import 'package:safe_wallet/features/settings/presentation/settings_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';

void main() {
  testWidgets('shows home by default and switches main shell tabs', (
    tester,
  ) async {
    final chainRepository = _CountingChainRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _ExistingWalletRepository(),
          ),
          homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
          chainRepositoryProvider.overrideWithValue(chainRepository),
          launchLockSettingStoreProvider.overrideWithValue(
            InMemoryLaunchLockSettingStore(requirePasswordOnLaunch: false),
          ),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MainShellPage), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(BrowserHomePage), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);
    expect(chainRepository.getSelectedChainCalls, 0);

    await tester.tap(find.byKey(const Key('mainShellBrowserTab')));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(BrowserHomePage), findsOneWidget);
    expect(find.byKey(const Key('browserSearchField')), findsOneWidget);
    expect(chainRepository.getSelectedChainCalls, 0);

    await tester.tap(find.byKey(const Key('browserSwapCategoryTab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('browserSearchField')),
      'uniswap',
    );
    await tester.pump();

    expect(find.text('Uniswap'), findsOneWidget);

    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mainShellSettingsTab')));
    await tester.pumpAndSettle();

    expect(find.byType(BrowserHomePage), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Uniswap'), findsNothing);
    expect(chainRepository.getSelectedChainCalls, 1);
  });

  testWidgets('floating navigation hides and returns with vertical scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _ExistingWalletRepository(),
          ),
          homeControllerProvider.overrideWithValue(_scrollableHomeState),
          launchLockSettingStoreProvider.overrideWithValue(
            InMemoryLaunchLockSettingStore(requirePasswordOnLaunch: false),
          ),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    final navigation = find.byKey(const Key('mainShellFloatingNavigation'));
    expect(navigation, findsOneWidget);
    _expectVisibleListViewBottomPadding(tester, 32);
    final visibleTop = tester.getTopLeft(navigation).dy;

    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(navigation).dy, greaterThanOrEqualTo(844));

    await tester.drag(find.byType(ListView).first, const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(navigation).dy, closeTo(visibleTop, 1));
  });

  testWidgets('floating navigation stays fixed when the keyboard appears', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _ExistingWalletRepository(),
          ),
          homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
          launchLockSettingStoreProvider.overrideWithValue(
            InMemoryLaunchLockSettingStore(requirePasswordOnLaunch: false),
          ),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mainShellBrowserTab')));
    await tester.pumpAndSettle();

    final navigation = find.byKey(const Key('mainShellFloatingNavigation'));
    final topBeforeKeyboard = tester.getTopLeft(navigation).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(navigation).dy, closeTo(topBeforeKeyboard, 1));
  });

  testWidgets('dark mode styles home cards and floating navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _ExistingWalletRepository(),
          ),
          homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
          launchLockSettingStoreProvider.overrideWithValue(
            InMemoryLaunchLockSettingStore(requirePasswordOnLaunch: false),
          ),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
          themeModeSettingStoreProvider.overrideWithValue(
            InMemoryThemeModeSettingStore(themeModeId: AppThemeMode.dark.name),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    final quickActionDecoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(QuickActionCard).first,
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(quickActionDecoration.color, AppColors.darkSurface);
    expect(quickActionDecoration.border?.top.color, AppColors.darkBorder);

    final navigationDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('mainShellFloatingNavigation')),
                )
                .decoration
            as BoxDecoration;
    expect(
      navigationDecoration.color,
      AppColors.darkSurface.withValues(alpha: 0.96),
    );
    expect(navigationDecoration.border?.top.color, AppColors.darkBorder);
  });
}

void _expectVisibleListViewBottomPadding(
  WidgetTester tester,
  double expectedBottom,
) {
  final listView = tester.widget<ListView>(find.byType(ListView).first);
  final padding = listView.padding;

  expect(padding, isA<EdgeInsets>());
  expect((padding! as EdgeInsets).bottom, expectedBottom);

  final safeArea = tester.widget<SafeArea>(
    find.ancestor(
      of: find.byType(ListView).first,
      matching: find.byType(SafeArea),
    ),
  );
  expect(safeArea.bottom, isFalse);
}

final _scrollableHomeState = HomeState.loaded(
  assets: List.generate(
    18,
    (index) => HomeAssetPreview(
      name: 'Token $index',
      symbol: 'T$index',
      amount: '$index',
      fiatValue: '--',
    ),
  ),
);

final class _ExistingWalletRepository implements WalletRepository {
  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

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

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    return WalletUnlockResult(account: _account, walletDek: const [1, 2, 3, 4]);
  }

  static final _account = WalletAccount(
    id: 'wallet-1',
    name: 'Wallet 1',
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: 'So11111111111111111111111111111111111111112',
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  );
}

final class _CountingChainRepository implements ChainRepository {
  int getSelectedChainCalls = 0;

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    getSelectedChainCalls += 1;
    return defaultChains.firstWhere((chain) => chain.id == 'ethereum');
  }

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
  Future<ChainConfig> selectChain(String chainId) {
    throw UnimplementedError();
  }
}
