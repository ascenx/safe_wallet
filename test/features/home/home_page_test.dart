// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:reel_text/reel_text.dart';
import 'package:safe_wallet/app/app.dart';
import 'package:safe_wallet/app/shell/main_shell_tab.dart';
import 'package:safe_wallet/features/assets/application/asset_market_data_provider.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_market_data_repository.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/browser/presentation/dapp_browser_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/home/application/home_controller.dart';
import 'package:safe_wallet/features/home/presentation/home_page.dart';
import 'package:safe_wallet/features/home/presentation/widgets/asset_list_card.dart';
import 'package:safe_wallet/features/home/presentation/widgets/balance_summary_card.dart';
import 'package:safe_wallet/features/home/presentation/widgets/quick_action_card.dart';
import 'package:safe_wallet/features/home/presentation/widgets/recent_transactions_card.dart';
import 'package:safe_wallet/features/home/presentation/widgets/wallet_top_bar.dart';
import 'package:safe_wallet/features/i18n/application/locale_controller.dart';
import 'package:safe_wallet/features/i18n/application/locale_preference_store.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/application/launch_lock_setting.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_history_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_text_styles.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  testWidgets('shows quick actions and recent transactions before asset list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          recentTransactions: [
            HomeTransactionPreview(
              title: '接收',
              subtitle: '0x2222222222222222222222222222222222222222',
              amount: '+1.0000 ETH',
              timestamp: '06-06 08:09:10',
              isIncoming: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('接收'), findsWidgets);
    expect(find.text('转账'), findsOneWidget);
    expect(find.text('扫码'), findsOneWidget);
    expect(find.text('06-06 08:09:10'), findsOneWidget);

    final recentTop = tester.getTopLeft(find.text('交易记录')).dy;
    final assetTop = tester.getTopLeft(find.text('资产列表')).dy;

    expect(recentTop, lessThan(assetTop));
  });

  testWidgets(
    'keeps recent transactions module without empty copy when there are no records',
    (tester) async {
      await tester.pumpWidget(_buildHome(HomeState.emptyAssets()));
      await tester.pumpAndSettle();

      expect(find.byType(RecentTransactionsCard), findsOneWidget);
      expect(find.text('交易记录'), findsOneWidget);
      expect(find.text('暂无交易'), findsNothing);
      expect(find.text('资产列表'), findsOneWidget);
    },
  );

  testWidgets(
    'view all opens the explorer directly when there are no records',
    (tester) async {
      WebViewPlatform.instance = _HomeTestWebViewPlatform();

      await tester.pumpWidget(
        _buildHome(
          HomeState.emptyAssets(chain: _ethereum),
          assetRequest: _assetPortfolioRequest,
          chainRepository: _FakeChainRepository(),
          transactionHistoryRepository: _EmptyTransactionHistoryRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看全部'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TransactionHistoryPage), findsNothing);
      final browser = tester.widget<DappBrowserPage>(
        find.byType(DappBrowserPage),
      );
      expect(
        browser.initialUrl,
        'https://etherscan.io/address/'
        '0x1111111111111111111111111111111111111111#transactions',
      );
    },
  );

  testWidgets('recent transaction address stays complete when it fits', (
    tester,
  ) async {
    const address = '0x1234567890abcdef';
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          recentTransactions: [
            HomeTransactionPreview(
              title: '接收',
              subtitle: address,
              subtitleIsAddress: true,
              amount: '+1.0000 ETH',
              timestamp: '06-06 08:09:10',
              isIncoming: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final renderedTexts = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(RecentTransactionsCard),
            matching: find.byType(RichText),
          ),
        )
        .map((widget) => widget.text.toPlainText());

    expect(renderedTexts, contains(address));
  });

  testWidgets('recent transaction address keeps as much text as fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const address = '0x1234567890abcdef1234567890abcdef12345678';
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          recentTransactions: [
            HomeTransactionPreview(
              title: '接收',
              subtitle: address,
              subtitleIsAddress: true,
              amount: '+1.0000 ETH',
              timestamp: '06-06 08:09:10',
              isIncoming: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final renderedAddress = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(RecentTransactionsCard),
            matching: find.byType(RichText),
          ),
        )
        .map((widget) => widget.text.toPlainText())
        .singleWhere((text) => text.contains('…'));

    expect(renderedAddress, startsWith(address.substring(0, 4)));
    expect(renderedAddress, endsWith(address.substring(address.length - 5)));
    expect(renderedAddress.length, greaterThan(10));
    expect(renderedAddress, isNot(address));
  });

  testWidgets('wrapped asset amount and pair use separate single-line rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const amount = '0.001102 WBNB → BNB';
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          recentTransactions: [
            HomeTransactionPreview(
              title: '解封装原生币',
              subtitle: '0xhash',
              amount: amount,
              timestamp: '08-05 01:49:32',
              isIncoming: false,
              operation: TransactionOperation.unwrap,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final valueFinder = find.byKey(
      const Key('recentTransactionAmountValue'),
    );
    final pairFinder = find.byKey(
      const Key('recentTransactionAssetPair'),
    );
    final valueLabel = tester.widget<Text>(valueFinder);
    final pairLabel = tester.widget<Text>(pairFinder);

    expect(valueLabel.data, '0.001102');
    expect(pairLabel.data, 'WBNB → BNB');
    expect(valueLabel.maxLines, 1);
    expect(pairLabel.maxLines, 1);
    expect(pairLabel.softWrap, isFalse);
    expect(valueLabel.textAlign, TextAlign.end);
    expect(pairLabel.textAlign, TextAlign.end);
    expect(
      tester.getTopLeft(pairFinder).dy,
      greaterThan(tester.getTopLeft(valueFinder).dy),
    );
    expect(tester.getSize(pairFinder).width, lessThanOrEqualTo(160));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scan quick action opens the scanner flow', (tester) async {
    final originalPlatform = MobileScannerPlatform.instance;
    final platform = _PermissionDeniedScannerPlatform();
    MobileScannerPlatform.instance = platform;
    addTearDown(() async {
      MobileScannerPlatform.instance = originalPlatform;
      await platform.close();
    });

    await tester.pumpWidget(_buildHome(HomeState.emptyAssets()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('扫码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('扫描钱包地址二维码，识别后会填入转账收款地址。'), findsOneWidget);
    expect(find.text('需要相机权限才能扫码'), findsOneWidget);
  });

  testWidgets('home cards follow wallet visual geometry', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildHome(HomeState.emptyAssets()));
    await tester.pumpAndSettle();

    final balanceCard = find
        .descendant(
          of: find.byType(BalanceSummaryCard),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(tester.getSize(balanceCard).height, inInclusiveRange(136, 148));

    expect(find.byType(QuickActionCard), findsNWidgets(3));
    for (var index = 0; index < 3; index += 1) {
      final actionCard = find
          .descendant(
            of: find.byType(QuickActionCard).at(index),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final size = tester.getSize(actionCard);

      expect(size.height, inInclusiveRange(82, 92));
      expect(size.width, closeTo((390 - 32 - 24) / 3, 1));
    }
  });

  testWidgets('balance summary toggles amount visibility', (tester) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          totalValue: '\$123.45',
          nativeEquivalent: '≈ 1.2345 ETH',
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.2345 ETH',
              fiatValue: '--',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_totalValueReelText('\$123.45'), findsOneWidget);
    expect(find.text('≈ \$123.45 USD'), findsOneWidget);
    expect(find.text('≈ 1.2345 ETH'), findsNothing);

    await tester.tap(find.byIcon(AppIcons.visible));
    await tester.pumpAndSettle();

    expect(_totalValueReelText('\$123.45'), findsNothing);
    expect(find.text('≈ \$123.45 USD'), findsNothing);
    expect(find.text('≈ 1.2345 ETH'), findsNothing);
    expect(_totalValueReelText('****'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BalanceSummaryCard),
        matching: find.text('****'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(AppIcons.hidden));
    await tester.pumpAndSettle();

    expect(_totalValueReelText('\$123.45'), findsOneWidget);
    expect(find.text('≈ \$123.45 USD'), findsOneWidget);
    expect(find.text('≈ 1.2345 ETH'), findsNothing);
  });

  testWidgets('amount visibility hides asset balances and fiat values', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          totalValue: '\$123.45',
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.2345 ETH',
              fiatValue: '\$3,703.50',
              price: '\$3,000.00',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final assetList = find.byType(AssetListCard);
    expect(
      find.descendant(of: assetList, matching: find.text('1.2345')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: assetList, matching: find.text('\$3,703.50')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(AppIcons.visible));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: assetList, matching: find.text('1.2345')),
      findsNothing,
    );
    expect(
      find.descendant(of: assetList, matching: find.text('\$3,703.50')),
      findsNothing,
    );
    expect(
      find.descendant(of: assetList, matching: find.text('****')),
      findsNWidgets(2),
    );
    expect(find.text('\$3,000.00'), findsOneWidget);
  });

  testWidgets('balance summary shows fixed USD total and fiat equivalent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          totalValue: '\$123.45',
          nativeEquivalent: '≈ 1.2345 ETH',
          fiatEquivalent: '≈ ¥834.52 CNY',
          assets: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_totalValueReelText('\$123.45'), findsOneWidget);
    expect(find.text('≈ ¥834.52 CNY'), findsOneWidget);
    expect(find.text('≈ 1.2345 ETH'), findsNothing);
    expect(find.byIcon(AppIcons.swap), findsNothing);
  });

  testWidgets('balance summary uses reel text for primary total value', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          totalValue: '\$123.45',
          nativeEquivalent: '≈ 1.2345 ETH',
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.2345 ETH',
              fiatValue: '--',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final totalValue = _totalValueReelText('\$123.45');

    expect(totalValue, findsOneWidget);
    expect(
      tester.widget<ReelText>(totalValue).style,
      AppTextStyles.displayAmount,
    );
  });

  testWidgets('asset rows keep long names and amounts on one line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          chainName: 'BNB Smart Chain',
          assets: const [
            HomeAssetPreview(
              name: 'BNB Smart Chain',
              symbol: 'BNB',
              amount: '0.00315381 BNB',
              fiatValue: '--',
              price: '\$842.12',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final price = tester.widget<Text>(find.text('\$842.12'));
    final amount = tester.widget<Text>(find.text('0.00315381'));

    expect(price.maxLines, 1);
    expect(price.overflow, TextOverflow.ellipsis);
    expect(amount.maxLines, 1);
    expect(amount.overflow, TextOverflow.ellipsis);
  });

  testWidgets('asset rows show symbol and token price with amount only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          chainName: 'BNB Smart Chain',
          assets: const [
            HomeAssetPreview(
              name: 'Tether USD',
              symbol: 'USDT',
              amount: '1.14264 USDT',
              fiatValue: '--',
              price: '\$1.00',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('USDT'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AssetListCard),
        matching: find.text('BNB Smart Chain'),
      ),
      findsNothing,
    );
    expect(find.text('\$1.00'), findsOneWidget);
    expect(find.text('1.14264'), findsOneWidget);
    expect(find.text('1.14264 USDT'), findsNothing);
    expect(find.text('Tether USD'), findsNothing);
  });

  testWidgets('asset rows show placeholder when token price is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          assets: const [
            HomeAssetPreview(
              name: 'Tether USD',
              symbol: 'USDT',
              amount: '1.14264 USDT',
              fiatValue: '\$1.14',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('--'), findsOneWidget);
    expect(find.text('\$1.14'), findsOneWidget);
  });

  testWidgets(
    'asset rows render token logo when available and fallback initial',
    (tester) async {
      await tester.pumpWidget(
        _buildHome(
          HomeState.loaded(
            assets: const [
              HomeAssetPreview(
                name: 'USD Coin',
                symbol: 'USDC',
                amount: '12.3456 USDC',
                fiatValue: '--',
                logoUri: 'asset:assets/token_logos/usdt.svg',
              ),
              HomeAssetPreview(
                name: 'Ethereum',
                symbol: 'ETH',
                amount: '1.0000 ETH',
                fiatValue: '--',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assetLogo.USDC')), findsOneWidget);
      expect(find.byKey(const Key('assetLogoFallback.ETH')), findsOneWidget);
    },
  );

  testWidgets('shows bottom navigation in the main shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _ExistingWalletRepository(),
          ),
          homeControllerProvider.overrideWithValue(HomeState.emptyAssets()),
          localePreferenceStoreProvider.overrideWithValue(
            InMemoryLocalePreferenceStore(initialMode: AppLocaleMode.zh),
          ),
          launchLockSettingStoreProvider.overrideWithValue(
            InMemoryLaunchLockSettingStore(requirePasswordOnLaunch: false),
          ),
        ],
        child: const SafeWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('浏览器'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('shows distinct loading empty and error asset states', (
    tester,
  ) async {
    await tester.pumpWidget(_buildHome(HomeState.loadingAssets()));
    await tester.pump();

    expect(find.text('资产加载中'), findsOneWidget);
    expect(find.text('暂无资产'), findsNothing);
    expect(find.text('资产加载失败'), findsNothing);

    await tester.pumpWidget(_buildHome(HomeState.emptyAssets()));
    await tester.pump();

    expect(find.text('暂无资产'), findsOneWidget);
    expect(find.text('资产加载中'), findsNothing);
    expect(find.text('资产加载失败'), findsNothing);

    await tester.pumpWidget(_buildHome(HomeState.errorAssets()));
    await tester.pump();

    expect(find.text('资产加载失败'), findsOneWidget);
    expect(find.text('资产加载中'), findsNothing);
    expect(find.text('暂无资产'), findsNothing);
  });

  testWidgets('asset list renders loading-state assets without loading copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.loading,
          assets: [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '-- ETH',
              fiatValue: '--',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('ETH'), findsOneWidget);
    expect(find.text('--'), findsWidgets);
    expect(find.text('资产加载中'), findsNothing);
  });

  testWidgets('manage tokens opens token management for current chain', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.emptyAssets(),
        assetRequest: _assetPortfolioRequest,
        tokenRepository: _FakeTokenRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('管理代币'));
    await tester.pumpAndSettle();

    expect(find.text('代币管理'), findsOneWidget);
    expect(find.text('添加代币'), findsOneWidget);
  });

  testWidgets('top bar opens wallet management and chain selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          walletName: 'Wallet 1',
          chainName: 'Ethereum',
        ),
        walletRepository: _ExistingWalletRepository(),
        chainRepository: _FakeChainRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wallet 1'));
    await tester.pumpAndSettle();

    expect(find.text('钱包管理'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ethereum'));
    await tester.pumpAndSettle();

    expect(find.text('选择网络'), findsOneWidget);
  });

  testWidgets('top bar wallet avatar opens wallet management', (tester) async {
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          walletName: 'Wallet 1',
          chainName: 'Ethereum',
        ),
        walletRepository: _ExistingWalletRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final walletAvatar = find.ancestor(
      of: find.byIcon(AppIcons.wallet),
      matching: find.byType(CircleAvatar),
    );
    await tester.tap(walletAvatar);
    await tester.pumpAndSettle();

    expect(find.text('钱包管理'), findsOneWidget);
  });

  testWidgets('top bar chain selector can switch to Bitcoin', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final chainRepository = _FakeChainRepository();

    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          walletName: 'Wallet 1',
          chainName: 'Ethereum',
        ),
        chainRepository: chainRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ethereum'));
    await tester.pumpAndSettle();
    final chainSheet = find.byType(BottomSheet);
    await tester.scrollUntilVisible(
      find.text('Bitcoin'),
      200,
      scrollable: find.descendant(
        of: chainSheet,
        matching: find.byType(Scrollable),
      ),
    );
    final bitcoinOption = find.descendant(
      of: chainSheet,
      matching: find.text('Bitcoin'),
    );
    await tester.tap(bitcoinOption);
    await tester.pumpAndSettle();

    expect(chainRepository.selectedChainId, 'bitcoin-mainnet');
    expect(find.text('选择网络'), findsNothing);
  });

  testWidgets('top bar shows chain svg icon and keeps short wallet names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          walletName: 'Wallet 99',
          chainName: 'BNB Smart Chain',
          chainSymbol: 'BNB',
          chainLogoUri: 'asset:assets/chain_logos/bnb-smart-chain.svg',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeChainLogo.BNB')), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Wallet 99'), findsOneWidget);
  });

  testWidgets('top bar middle-ellipsizes longer wallet names', (tester) async {
    await tester.pumpWidget(
      _buildHome(
        const HomeState(
          assetStatus: HomeAssetStatus.empty,
          walletName: 'Wallet 100',
          chainName: 'Ethereum',
          chainSymbol: 'ETH',
          chainLogoUri: 'asset:assets/chain_logos/ethereum.svg',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wal...100'), findsOneWidget);
    expect(find.text('Wallet 100'), findsNothing);
  });

  testWidgets('top bar stays pinned while the home list scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          walletName: 'Wallet 1',
          assets: List.generate(
            20,
            (index) => HomeAssetPreview(
              name: 'Token $index',
              symbol: 'T$index',
              amount: '$index',
              fiatValue: '--',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final topBar = find.byType(WalletTopBar);
    expect(topBar, findsOneWidget);
    final initialTop = tester.getTopLeft(topBar).dy;

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(topBar).dy, closeTo(initialTop, 1));
  });

  testWidgets('view all recent transactions opens transaction history', (
    tester,
  ) async {
    final historyRepository = _StaticTransactionHistoryRepository([
      TransactionRecord(
        id: 'tx-1',
        chainId: _ethereum.chainId,
        chainType: _ethereum.chainType,
        assetSymbol: _ethereum.symbol,
        direction: TransactionDirection.outgoing,
        amount: '0.1',
        status: TransactionStatus.submitted,
        transactionHash: '0xhash',
        createdAt: DateTime.utc(2026, 6, 6),
        fromAddress: '0xsender',
        toAddress: '0xreceiver',
      ),
      TransactionRecord(
        id: 'tx-2',
        chainId: '56',
        chainType: ChainType.evm,
        assetSymbol: 'BNB',
        direction: TransactionDirection.outgoing,
        amount: '0.2',
        status: TransactionStatus.submitted,
        transactionHash: '0xbnbhash',
        createdAt: DateTime.utc(2026, 6, 5),
        fromAddress: '0xsender',
        toAddress: '0xreceiver',
      ),
    ]);

    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.0000 ETH',
              fiatValue: '--',
            ),
          ],
          recentTransactions: const [
            HomeTransactionPreview(
              title: '接收',
              subtitle: '0x2222222222222222222222222222222222222222',
              amount: '+1.0000 ETH',
              timestamp: '2026-06-06',
              isIncoming: true,
            ),
          ],
        ),
        assetRequest: _assetPortfolioRequest,
        chainRepository: _FakeChainRepository(),
        transactionHistoryRepository: historyRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();

    expect(find.text('交易历史'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('transactionHistoryNetworkFilter')),
        matching: find.text('Ethereum'),
      ),
      findsOneWidget,
    );
    expect(find.text('0xhash'), findsOneWidget);
    expect(find.text('0xbnbhash'), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, AppIcons.externalLink),
      findsOneWidget,
    );
  });

  testWidgets('tapping asset row whitespace opens asset detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          chainName: 'Ethereum',
          totalValue: '\$0.00',
          nativeEquivalent: '≈ 1.0000 ETH',
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.0000 ETH',
              fiatValue: '--',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final assetSymbol = find.descendant(
      of: find.byType(AssetListCard),
      matching: find.text('ETH'),
    );
    await tester.ensureVisible(assetSymbol);
    await tester.pump();
    final assetRow = find.ancestor(
      of: assetSymbol,
      matching: find.byType(GestureDetector),
    );
    final rowRect = tester.getRect(assetRow);
    await tester.tapAt(Offset(rowRect.left + 1, rowRect.top + 1));
    await tester.pumpAndSettle();

    expect(find.text('资产详情'), findsOneWidget);
    expect(find.text('Ethereum'), findsWidgets);
    expect(find.text('ETH'), findsOneWidget);
    expect(find.text('1.0000 ETH'), findsWidgets);
    expect(find.text('转账'), findsOneWidget);
  });

  testWidgets('asset detail transfer action preselects the opened asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          chainName: 'Ethereum',
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.0000 ETH',
              fiatValue: '--',
            ),
            HomeAssetPreview(
              name: 'USD Coin',
              symbol: 'USDC',
              amount: '250.00 USDC',
              fiatValue: '--',
              contractAddress: _usdcContractAddress,
            ),
          ],
        ),
        assetPortfolio: _portfolioWithEthAndUsdc(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('USDC'));
    await tester.pump();
    await tester.tap(find.text('USDC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();

    expect(find.text('余额: 250.00 USDC'), findsOneWidget);
  });

  testWidgets('Bitcoin asset detail transfer opens with BTC selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          chainName: 'Bitcoin',
          chainSymbol: 'BTC',
          assets: const [
            HomeAssetPreview(
              name: 'Bitcoin',
              symbol: 'BTC',
              amount: '1.0000 BTC',
              fiatValue: '--',
            ),
          ],
        ),
        assetRequest: _bitcoinAssetPortfolioRequest,
        assetPortfolio: _portfolioWithBtc(),
      ),
    );
    await tester.pumpAndSettle();

    final assetSymbol = find.descendant(
      of: find.byType(AssetListCard),
      matching: find.text('BTC'),
    );
    await tester.ensureVisible(assetSymbol);
    await tester.pump();
    await tester.tap(assetSymbol);
    await tester.pumpAndSettle();
    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();

    final selector = find.byKey(const Key('transferAssetSelector'));
    expect(
      find.descendant(of: selector, matching: find.text('BTC')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selector, matching: find.text('1.0000')),
      findsOneWidget,
    );
    expect(find.text('余额: 1.0000 BTC'), findsOneWidget);
  });

  testWidgets('asset list removes refresh button and right aligns management', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHome(
        HomeState.loaded(
          assets: const [
            HomeAssetPreview(
              name: 'Ethereum',
              symbol: 'ETH',
              amount: '1.0000 ETH',
              fiatValue: r'$2,500.00',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('homeAssetRefreshButton')), findsNothing);
    expect(find.byKey(const Key('homeAssetRefreshSpinner')), findsNothing);

    final cardRect = tester.getRect(find.byType(AssetListCard));
    final manageRect = tester.getRect(find.text('管理代币'));
    expect(manageRect.center.dx, greaterThan(cardRect.center.dx));
  });

  testWidgets('pull to refresh reloads the live portfolio provider', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async {
            loadCount += 1;
            return _portfolioWithEthAmount('$loadCount.0000');
          }),
          transactionHistoryRepositoryProvider.overrideWithValue(
            _EmptyTransactionHistoryRepository(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.0000'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(find.text('2.0000'), findsOneWidget);
    expect(loadCount, 2);
  });

  testWidgets('staying on home polls assets every ten seconds', (tester) async {
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async {
            loadCount += 1;
            return _portfolioWithEthAmount('$loadCount.0000');
          }),
          transactionHistoryRepositoryProvider.overrideWithValue(
            _EmptyTransactionHistoryRepository(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);

    await tester.pump(const Duration(seconds: 9));
    expect(loadCount, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(loadCount, 2);
    expect(find.text('2.0000'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(loadCount, 3);
  });

  testWidgets('pull refresh restarts the ten second polling countdown', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async {
            loadCount += 1;
            return _portfolioWithEthAmount('$loadCount.0000');
          }),
          transactionHistoryRepositoryProvider.overrideWithValue(
            _EmptyTransactionHistoryRepository(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 6));
    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(loadCount, 2);

    await tester.pump(const Duration(seconds: 9));
    expect(loadCount, 2);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(loadCount, 3);
  });

  testWidgets('polling pauses off home and returning refreshes immediately', (
    tester,
  ) async {
    var loadCount = 0;
    final container = ProviderContainer(
      overrides: [
        assetPortfolioProvider.overrideWith((ref) async {
          loadCount += 1;
          return _portfolioWithEthAmount('$loadCount.0000');
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(mainShellTabProvider.notifier).select(MainShellTab.browser);
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(loadCount, 1);

    container.read(mainShellTabProvider.notifier).select(MainShellTab.home);
    await tester.pumpAndSettle();
    expect(loadCount, 2);

    container.read(mainShellTabProvider.notifier).select(MainShellTab.settings);
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(loadCount, 2);

    container.read(mainShellTabProvider.notifier).select(MainShellTab.home);
    await tester.pumpAndSettle();
    expect(loadCount, 3);
  });

  testWidgets('chain border is red while node is unavailable and recovers', (
    tester,
  ) async {
    var nodeAvailable = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async {
            if (!nodeAvailable) {
              return AssetPortfolio.error('rpc unavailable');
            }
            return _portfolioWithEthAmount('1.0000');
          }),
          transactionHistoryRepositoryProvider.overrideWithValue(
            _EmptyTransactionHistoryRepository(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final unavailableDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('homeChainSelector')),
                )
                .decoration
            as BoxDecoration;
    expect(
      (unavailableDecoration.border! as Border).top.color,
      AppColors.danger,
    );

    nodeAvailable = true;
    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    final availableDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('homeChainSelector')),
                )
                .decoration
            as BoxDecoration;
    expect(
      (availableDecoration.border! as Border).top.color,
      isNot(AppColors.danger),
    );
  });

  testWidgets('pull refresh keeps current list after load failure', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPortfolioProvider.overrideWith((ref) async {
            loadCount += 1;
            if (loadCount == 1) {
              return _portfolioWithEthAmount('1.0000');
            }
            throw Exception('asset refresh failed');
          }),
          transactionHistoryRepositoryProvider.overrideWithValue(
            _EmptyTransactionHistoryRepository(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1.0000'), findsOneWidget);
    expect(find.text('资产加载失败'), findsNothing);
  });

  testWidgets('home shell visual snapshot matches 390x844 reference viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    LocaleSettings.setLocaleSync(AppLocale.zh);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeControllerProvider.overrideWithValue(_visualHomeState)],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const _HomeVisualShell(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(_HomeVisualShell),
      matchesGoldenFile('goldens/home_shell_390x844.png'),
    );
  });
}

Finder _totalValueReelText(String value) {
  return find.descendant(
    of: find.byType(BalanceSummaryCard),
    matching: find.byWidgetPredicate(
      (widget) => widget is ReelText && widget.text == value,
    ),
  );
}

Widget _buildHome(
  HomeState state, {
  AssetPortfolioRequest? assetRequest,
  AssetPortfolio? assetPortfolio,
  TokenRepository? tokenRepository,
  WalletRepository? walletRepository,
  ChainRepository? chainRepository,
  TransactionHistoryRepository? transactionHistoryRepository,
}) {
  return ProviderScope(
    overrides: [
      homeControllerProvider.overrideWithValue(state),
      assetMarketDataRepositoryProvider.overrideWithValue(
        const _EmptyAssetMarketDataRepository(),
      ),
      if (assetRequest != null)
        assetPortfolioRequestProvider.overrideWithValue(
          Future.value(assetRequest),
        ),
      if (assetPortfolio != null)
        assetPortfolioProvider.overrideWith((ref) async => assetPortfolio),
      if (tokenRepository != null)
        tokenRepositoryProvider.overrideWithValue(tokenRepository),
      if (walletRepository != null)
        walletRepositoryProvider.overrideWithValue(walletRepository),
      if (chainRepository != null)
        chainRepositoryProvider.overrideWithValue(chainRepository),
      if (transactionHistoryRepository != null)
        transactionHistoryRepositoryProvider.overrideWithValue(
          transactionHistoryRepository,
        ),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
    ),
  );
}

final class _EmptyAssetMarketDataRepository
    implements AssetMarketDataRepository {
  const _EmptyAssetMarketDataRepository();

  @override
  Future<AssetMarketData?> getMarketData({
    required ChainConfig chain,
    required String contractAddress,
  }) async {
    return null;
  }
}

final class _PermissionDeniedScannerPlatform extends MobileScannerPlatform
    with MockPlatformInterfaceMixin {
  final StreamController<BarcodeCapture?> _barcodesController =
      StreamController<BarcodeCapture?>.broadcast();

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodesController.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream<TorchState>.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream<double>.empty();

  @override
  Widget buildCameraView() => const SizedBox.shrink();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    throw const MobileScannerException(
      errorCode: MobileScannerErrorCode.permissionDenied,
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  Future<void> close() async {
    await _barcodesController.close();
  }
}

final _ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
final _bitcoin = defaultChains.firstWhere(
  (chain) => chain.id == 'bitcoin-mainnet',
);
const _usdcContractAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _visualHomeState = HomeState(
  assetStatus: HomeAssetStatus.loaded,
  walletName: 'My Wallet',
  chainName: 'Ethereum',
  totalValue: '\$12,345.67',
  nativeEquivalent: '≈ 3.4567 ETH',
  recentTransactions: [
    HomeTransactionPreview(
      title: '接收',
      subtitle: 'From: 0x8a3...5f2e',
      amount: '+0.85 ETH',
      timestamp: '2024-05-20',
      isIncoming: true,
    ),
    HomeTransactionPreview(
      title: '转账',
      subtitle: 'To: 0x7b2...1d4c',
      amount: '-1.20 ETH',
      timestamp: '2024-05-20',
      isIncoming: false,
    ),
    HomeTransactionPreview(
      title: '接收',
      subtitle: 'From: 0x9c1...a8e7',
      amount: '+0.50 ETH',
      timestamp: '2024-05-19',
      isIncoming: true,
    ),
  ],
  assets: [
    HomeAssetPreview(
      name: 'Ethereum',
      symbol: 'ETH',
      amount: '3.4567 ETH',
      fiatValue: '\$7,890.12',
    ),
    HomeAssetPreview(
      name: 'Tether USD',
      symbol: 'USDT',
      amount: '2,450.00 USDT',
      fiatValue: '\$2,450.00',
    ),
    HomeAssetPreview(
      name: 'USD Coin',
      symbol: 'USDC',
      amount: '1,250.00 USDC',
      fiatValue: '\$1,250.00',
    ),
  ],
);
final _assetPortfolioRequest = AssetPortfolioRequest(
  account: _ExistingWalletRepository._account,
  chain: _ethereum,
  rpcNode: const RpcNode(
    id: 'node-1',
    chainId: '1',
    name: 'Default Ethereum',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  ),
);
final _bitcoinAssetPortfolioRequest = AssetPortfolioRequest(
  account: _bitcoinAccount,
  chain: _bitcoin,
  rpcNode: const RpcNode(
    id: 'bitcoin-node-1',
    chainId: 'bitcoin-mainnet',
    name: 'Bitcoin RPC',
    url: 'https://blockstream.info/api',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  ),
);

final _bitcoinAccount = WalletAccount(
  id: 'wallet-btc',
  name: 'BTC Wallet',
  evmAddress: '',
  solanaAddress: '',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

AssetPortfolio _portfolioWithEthAmount(String amount) {
  return AssetPortfolio.loaded([
    AssetBalance(
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
      balance: '0',
      formattedBalance: amount,
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

AssetPortfolio _portfolioWithEthAndUsdc() {
  return AssetPortfolio.loaded([
    AssetBalance(
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
      balance: '1000000000000000000',
      formattedBalance: '1.0000',
      status: AssetBalanceStatus.loaded,
    ),
    AssetBalance(
      chainId: _ethereum.chainId,
      token: const TokenInfo(
        chainId: '1',
        contractAddress: _usdcContractAddress,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: '250000000',
      formattedBalance: '250.00',
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

AssetPortfolio _portfolioWithBtc() {
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: _bitcoin.chainId,
      token: TokenInfo(
        chainId: _bitcoin.chainId,
        contractAddress: null,
        symbol: _bitcoin.symbol,
        name: _bitcoin.name,
        decimals: 8,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: '100000000',
      formattedBalance: '1.0000',
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

final class _FakeTokenRepository implements TokenRepository {
  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return const [];
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) {
    throw UnimplementedError();
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> unhideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeChainRepository implements ChainRepository {
  String selectedChainId = 'ethereum';

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
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }
}

final class _EmptyTransactionHistoryRepository
    implements TransactionHistoryRepository {
  @override
  Future<List<TransactionRecord>> list({String? chainId}) async => const [];

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async => const [];

  @override
  Future<void> save(TransactionRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _StaticTransactionHistoryRepository
    implements TransactionHistoryRepository {
  const _StaticTransactionHistoryRepository(this.records);

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return records
        .where((record) => chainId == null || record.chainId == chainId)
        .toList(growable: false);
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return (await list(chainId: chainId)).take(limit).toList(growable: false);
  }

  @override
  Future<void> save(TransactionRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

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

final class _HomeTestWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _HomeTestWebViewController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _HomeTestNavigationDelegate(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _HomeTestWebViewWidget(params);
  }
}

final class _HomeTestWebViewController extends PlatformWebViewController {
  _HomeTestWebViewController(super.params) : super.implementation();

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<String?> currentUrl() async => null;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage consoleMessage) onConsoleMessage,
  ) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

final class _HomeTestNavigationDelegate extends PlatformNavigationDelegate {
  _HomeTestNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}

final class _HomeTestWebViewWidget extends PlatformWebViewWidget {
  _HomeTestWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final class _HomeVisualShell extends StatelessWidget {
  const _HomeVisualShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const HomePage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (_) {},
        destinations: [
          NavigationDestination(
            icon: const Icon(AppIcons.home),
            selectedIcon: const Icon(Icons.home),
            label: t.tabs.home,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.globe),
            selectedIcon: const Icon(AppIcons.globe),
            label: t.tabs.browser,
          ),
          NavigationDestination(
            icon: const Icon(AppIcons.settings),
            selectedIcon: const Icon(AppIcons.settingsSelected),
            label: t.tabs.settings,
          ),
        ],
      ),
    );
  }
}
