import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/application/asset_market_data_provider.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_market_data_repository.dart';
import 'package:safe_wallet/features/assets/presentation/asset_detail_page.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/network/external_url_launcher.dart';

void main() {
  testWidgets('shows DexScreener market overview and opens the primary pair', (
    tester,
  ) async {
    final launcher = _FakeExternalUrlLauncher();
    await tester.pumpWidget(
      _buildPage(
        repository: _FakeAssetMarketDataRepository(_marketData),
        externalUrlLauncher: launcher,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'$1.00'), findsNWidgets(2));
    expect(find.text('+2.48%'), findsOneWidget);
    expect(find.text('市场概览'), findsOneWidget);
    expect(find.text('24h 成交额'), findsOneWidget);
    expect(find.text(r'$12.50M'), findsOneWidget);
    expect(find.text('流动性'), findsOneWidget);
    expect(find.text(r'$4.20M'), findsOneWidget);
    expect(find.text('市值'), findsOneWidget);
    expect(find.text(r'$510.00M'), findsOneWidget);
    expect(find.text('FDV'), findsOneWidget);
    expect(find.text(r'$520.00M'), findsOneWidget);
    expect(find.text('24h 买入 / 卖出'), findsOneWidget);
    expect(find.text('1,234 / 987'), findsOneWidget);
    expect(find.text('主要交易对'), findsOneWidget);
    expect(find.text('Uniswap · TEST/USDC'), findsOneWidget);

    await tester.ensureVisible(find.text('在 DexScreener 查看'));
    await tester.pump();
    await tester.tap(find.text('在 DexScreener 查看'));
    await tester.pump();

    expect(launcher.openedUrls, [_marketData.externalUrl]);
  });

  testWidgets('keeps core asset actions when market data is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(repository: _FakeAssetMarketDataRepository(null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无市场数据'), findsOneWidget);
    expect(find.text('1.0000 TEST'), findsWidgets);
    expect(find.text('转账'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('管理代币'), 200);
    expect(find.text('管理代币'), findsOneWidget);
  });

  testWidgets('warns when the primary pair has low liquidity', (tester) async {
    await tester.pumpWidget(
      _buildPage(
        repository: _FakeAssetMarketDataRepository(
          _testMarketData(liquidityUsd: 5000),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该交易池流动性较低，市场价格可能出现较大波动。'), findsOneWidget);
  });

  testWidgets('warns when wallet and DEX prices differ by over five percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(
        repository: _FakeAssetMarketDataRepository(
          _testMarketData(priceUsd: 1.2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('钱包估值价格与 DEX 市场价格存在明显偏差。'), findsOneWidget);
  });

  testWidgets('shows staking only for the native TRX asset', (tester) async {
    final tron = defaultChains.firstWhere(
      (chain) => chain.id == 'tron-mainnet',
    );
    final account = WalletAccount(
      id: 'tron-wallet',
      name: 'Tron Wallet',
      evmAddress: '',
      solanaAddress: '',
      tronAddress: 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
      createdAt: DateTime.utc(2026, 8, 2),
      updatedAt: DateTime.utc(2026, 8, 2),
    );
    const node = RpcNode(
      id: 'tron-node',
      chainId: 'tron-mainnet',
      name: 'TronGrid',
      url: 'https://api.trongrid.io',
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
    );

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('native-trx'),
        overrides: [
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(
              AssetPortfolioRequest(
                account: account,
                chain: tron,
                rpcNode: node,
              ),
            ),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AssetDetailPage(
              name: 'TRON',
              symbol: 'TRX',
              amount: '10 TRX',
              fiatValue: r'$3.00',
              chainName: 'Tron',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assetTronStakingButton')), findsOneWidget);
    expect(find.text('质押'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('trc20-token'),
        overrides: [
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(
              AssetPortfolioRequest(
                account: account,
                chain: tron,
                rpcNode: node,
              ),
            ),
          ),
          assetMarketDataRepositoryProvider.overrideWithValue(
            const _FakeAssetMarketDataRepository(null),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AssetDetailPage(
              name: 'Tether USD',
              symbol: 'USDT',
              amount: '10 USDT',
              fiatValue: r'$10.00',
              chainName: 'Tron',
              contractAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assetTronStakingButton')), findsNothing);

    final accountWithoutTron = WalletAccount(
      id: 'wallet-without-tron',
      name: 'Wallet',
      evmAddress: '',
      solanaAddress: '',
      tronAddress: '',
      createdAt: DateTime.utc(2026, 8, 2),
      updatedAt: DateTime.utc(2026, 8, 2),
    );
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('wallet-without-tron'),
        overrides: [
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(
              AssetPortfolioRequest(
                account: accountWithoutTron,
                chain: tron,
                rpcNode: node,
              ),
            ),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const AssetDetailPage(
              name: 'TRON',
              symbol: 'TRX',
              amount: '10 TRX',
              fiatValue: r'$3.00',
              chainName: 'Tron',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assetTronStakingButton')), findsNothing);
  });
}

Widget _buildPage({
  required AssetMarketDataRepository repository,
  ExternalUrlLauncher? externalUrlLauncher,
}) {
  final ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
  return ProviderScope(
    overrides: [
      assetPortfolioRequestProvider.overrideWithValue(
        Future.value(
          AssetPortfolioRequest(
            account: _account,
            chain: ethereum,
            rpcNode: _rpcNode,
          ),
        ),
      ),
      assetMarketDataRepositoryProvider.overrideWithValue(repository),
      if (externalUrlLauncher != null)
        externalUrlLauncherProvider.overrideWithValue(externalUrlLauncher),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const AssetDetailPage(
          name: 'Test Token',
          symbol: 'TEST',
          amount: '1.0000 TEST',
          fiatValue: r'$1.00',
          price: r'$1.00',
          priceUsd: 1,
          chainName: 'Ethereum',
          contractAddress: _tokenAddress,
        ),
      ),
    ),
  );
}

final _marketData = _testMarketData();

AssetMarketData _testMarketData({
  double priceUsd = 1.02,
  double liquidityUsd = 4200000,
}) {
  return AssetMarketData(
    priceUsd: priceUsd,
    priceChange24h: 2.48,
    volume24hUsd: 12500000,
    liquidityUsd: liquidityUsd,
    marketCapUsd: 510000000,
    fdvUsd: 520000000,
    buys24h: 1234,
    sells24h: 987,
    dexId: 'uniswap',
    baseSymbol: 'TEST',
    quoteSymbol: 'USDC',
    pairAddress: '0xpair',
    pairCreatedAt: DateTime.utc(2024, 1, 1),
    externalUrl: 'https://dexscreener.com/ethereum/test',
    updatedAt: DateTime.utc(2026, 7, 18, 8, 30),
  );
}

final class _FakeAssetMarketDataRepository
    implements AssetMarketDataRepository {
  const _FakeAssetMarketDataRepository(this.marketData);

  final AssetMarketData? marketData;

  @override
  Future<AssetMarketData?> getMarketData({
    required chain,
    required String contractAddress,
  }) async {
    return marketData;
  }
}

final class _FakeExternalUrlLauncher implements ExternalUrlLauncher {
  final openedUrls = <String>[];

  @override
  Future<bool> openExternal(String url) async {
    openedUrls.add(url);
    return true;
  }
}

const _tokenAddress = '0x0000000000000000000000000000000000000001';

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '',
  createdAt: DateTime.utc(2026, 7, 18),
  updatedAt: DateTime.utc(2026, 7, 18),
);

const _rpcNode = RpcNode(
  id: 'node-1',
  chainId: '1',
  name: 'Ethereum RPC',
  url: 'https://rpc.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);
