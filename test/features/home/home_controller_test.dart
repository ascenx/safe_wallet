import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/application/selected_chain_controller.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/home/application/home_controller.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/application/fiat_currency_setting.dart';
import 'package:safe_wallet/features/settings/data/fiat_exchange_rate_repository.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  test('home controller displays the active chain name', () async {
    final solana =
        defaultChains.firstWhere((chain) => chain.id == 'solana-mainnet');
    final container = ProviderContainer(
      overrides: [
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([_nativeBalanceFor(solana)]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    final state = container.read(homeControllerProvider);

    expect(state.chainName, solana.name);
    expect(state.chainSymbol, solana.symbol);
    expect(state.assets.single.symbol, solana.symbol);
  });

  test('home controller maps the active chain to a bundled chain logo',
      () async {
    final solana =
        defaultChains.firstWhere((chain) => chain.id == 'solana-mainnet');
    final request = AssetPortfolioRequest(
      account: _wallet(id: 'wallet-1', name: 'Wallet 1'),
      chain: solana,
      rpcNode: _rpcNode,
    );
    final container = ProviderContainer(
      overrides: [
        assetPortfolioRequestValueProvider.overrideWith((ref) async => request),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([_nativeBalanceFor(solana)]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(assetPortfolioRequestValueProvider.future);
    final state = container.read(homeControllerProvider);

    expect(state.chainName, solana.name);
    expect(state.chainSymbol, solana.symbol);
    expect(state.chainLogoUri, 'asset:assets/chain_logos/solana.svg');
  });

  test('home controller displays Bitcoin chain and native BTC asset', () async {
    final bitcoin =
        defaultChains.firstWhere((chain) => chain.id == 'bitcoin-mainnet');
    final request = AssetPortfolioRequest(
      account: WalletAccount(
        id: 'wallet-btc',
        name: 'BTC Wallet',
        evmAddress: '',
        solanaAddress: '',
        btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        source: WalletAccountSource.privateKey,
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
      chain: bitcoin,
      rpcNode: RpcNode(
        id: 'bitcoin-default',
        chainId: bitcoin.chainId,
        name: 'Bitcoin Default',
        url: bitcoin.rpcUrls.first,
        nodeType: RpcNodeType.defaultNode,
        isSelected: true,
        lastTestStatus: RpcNodeTestStatus.available,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        assetPortfolioRequestValueProvider.overrideWith((ref) async => request),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded(
            [
              _nativeBalanceFor(
                bitcoin,
                fiatValueUsd: 42000,
                fiatValue: '\$42,000.00',
                priceUsd: 84000,
              ),
            ],
            account: request.account,
          );
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(assetPortfolioRequestValueProvider.future);
    final state = container.read(homeControllerProvider);

    expect(state.assetStatus, HomeAssetStatus.loaded);
    expect(state.walletName, 'BTC Wallet');
    expect(state.chainName, bitcoin.name);
    expect(state.chainSymbol, bitcoin.symbol);
    expect(state.chainLogoUri, 'asset:assets/chain_logos/bitcoin.svg');
    expect(state.totalValue, '\$42,000.00');
    expect(state.nativeEquivalent, '≈ 0.5 BTC');
    expect(state.assets.single.symbol, 'BTC');
    expect(state.assets.single.amount, '0 BTC');
    expect(state.assets.single.fiatValue, '\$42,000.00');
    expect(state.assets.single.price, '\$84,000.00');
  });

  test('home controller totals asset fiat values', () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final container = ProviderContainer(
      overrides: [
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded(
            [
              _nativeBalanceFor(
                ethereum,
                fiatValueUsd: 4500,
                fiatValue: '\$4,500.00',
                priceUsd: 3000,
              ),
              const AssetBalance(
                chainId: '1',
                token: TokenInfo(
                  chainId: '1',
                  contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
                  symbol: 'USDC',
                  name: 'USD Coin',
                  decimals: 6,
                  source: TokenSource.builtIn,
                  isHidden: false,
                ),
                balance: '1234500',
                formattedBalance: '1.2345',
                status: AssetBalanceStatus.loaded,
                fiatValueUsd: 1.2345,
                fiatValue: '\$1.23',
                priceUsd: 1,
              ),
            ],
          );
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    final state = container.read(homeControllerProvider);

    expect(state.totalValue, '\$4,501.23');
    expect(state.nativeEquivalent, '≈ 1.500411 ETH');
    expect(state.fiatEquivalent, '≈ \$4,501.23 USD');
    expect(state.assets.map((asset) => asset.fiatValue), [
      '\$4,500.00',
      '\$1.23',
    ]);
    expect(state.assets.map((asset) => asset.price), [
      '\$3,000.00',
      '\$1.00',
    ]);
  });

  test('home controller converts USD values to the selected fiat currency',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final container = ProviderContainer(
      overrides: [
        fiatCurrencySettingStoreProvider.overrideWithValue(
          InMemoryFiatCurrencySettingStore(currencyCode: 'CNY'),
        ),
        fiatExchangeRateProvider(AppFiatCurrency.cny).overrideWith(
          (ref) async => 6.76,
        ),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded(
            [
              _nativeBalanceFor(
                ethereum,
                fiatValueUsd: 4500,
                fiatValue: '\$4,500.00',
                priceUsd: 3000,
              ),
              const AssetBalance(
                chainId: '1',
                token: TokenInfo(
                  chainId: '1',
                  contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
                  symbol: 'USDC',
                  name: 'USD Coin',
                  decimals: 6,
                  source: TokenSource.builtIn,
                  isHidden: false,
                ),
                balance: '1234500',
                formattedBalance: '1.2345',
                status: AssetBalanceStatus.loaded,
                fiatValueUsd: 1.2345,
                fiatValue: '\$1.23',
                priceUsd: 1,
              ),
            ],
          );
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(fiatCurrencySettingProvider.future);
    await container.read(fiatExchangeRateProvider(AppFiatCurrency.cny).future);
    final state = container.read(homeControllerProvider);

    expect(state.totalValue, '\$4,501.23');
    expect(state.nativeEquivalent, '≈ 1.500411 ETH');
    expect(state.fiatEquivalent, '≈ ¥30,428.35 CNY');
    expect(state.assets.map((asset) => asset.fiatValue), [
      '¥30,420.00',
      '¥8.35',
    ]);
    expect(state.assets.map((asset) => asset.price), [
      '¥20,280.00',
      '¥6.76',
    ]);
  });

  test('home controller updates empty portfolio fiat after currency changes',
      () async {
    final store = InMemoryFiatCurrencySettingStore();
    final container = ProviderContainer(
      overrides: [
        fiatCurrencySettingStoreProvider.overrideWithValue(store),
        fiatExchangeRateProvider(AppFiatCurrency.cny).overrideWith(
          (ref) async => 6.76,
        ),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.empty();
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(fiatCurrencySettingProvider.future);
    expect(
      container.read(homeControllerProvider).fiatEquivalent,
      '≈ \$0.00 USD',
    );

    await container
        .read(fiatCurrencySettingProvider.notifier)
        .setCurrency(AppFiatCurrency.cny);
    await container.read(fiatExchangeRateProvider(AppFiatCurrency.cny).future);

    final state = container.read(homeControllerProvider);
    expect(state.totalValue, '\$0.00');
    expect(state.fiatEquivalent, '≈ ¥0.00 CNY');
  });

  test('home controller uses placeholder when token price is missing',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final container = ProviderContainer(
      overrides: [
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([
            _nativeBalanceFor(
              ethereum,
              fiatValueUsd: 0,
              fiatValue: '\$0.00',
            ),
          ]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    final state = container.read(homeControllerProvider);

    expect(state.assets.single.price, '--');
  });

  test('home controller displays the active wallet name', () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final account = WalletAccount(
      id: 'wallet-6',
      name: 'test6',
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: '',
      source: WalletAccountSource.privateKey,
      createdAt: DateTime.utc(2026, 6, 6),
      updatedAt: DateTime.utc(2026, 6, 6),
    );
    final container = ProviderContainer(
      overrides: [
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded(
            [_nativeBalanceFor(ethereum)],
            account: account,
          );
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    final state = container.read(homeControllerProvider);

    expect(state.walletName, 'test6');
  });

  test('recent transactions follow the currently selected chain', () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final bnbSmartChain =
        defaultChains.firstWhere((chain) => chain.id == 'bnb-smart-chain');
    final chainRepository = _MutableChainRepository(ethereum);
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(chainRepository),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _StaticTransactionHistoryRepository([
            TransactionRecord(
              id: 'bnb-tx',
              chainId: bnbSmartChain.chainId,
              chainType: ChainType.evm,
              assetSymbol: 'BNB',
              direction: TransactionDirection.outgoing,
              amount: '0.2',
              status: TransactionStatus.submitted,
              transactionHash: '0xbnb',
              createdAt: DateTime.utc(2026, 6, 7),
            ),
            TransactionRecord(
              id: 'eth-tx',
              chainId: ethereum.chainId,
              chainType: ChainType.evm,
              assetSymbol: 'ETH',
              direction: TransactionDirection.outgoing,
              amount: '0.1',
              status: TransactionStatus.submitted,
              transactionHash: '0xeth',
              createdAt: DateTime.utc(2026, 6, 6),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedChainControllerProvider.future);
    final ethereumRecords = await container.read(
      recentTransactionsProvider.future,
    );

    expect(ethereumRecords.map((record) => record.id), ['eth-tx']);

    await container
        .read(selectedChainControllerProvider.notifier)
        .selectChain(bnbSmartChain.id);
    final bnbRecords = await container.read(recentTransactionsProvider.future);

    expect(bnbRecords.map((record) => record.id), ['bnb-tx']);
  });

  test('home controller keeps full recent transaction counterparty addresses',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(
          _StaticChainRepository(ethereum),
        ),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([_nativeBalanceFor(ethereum)]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _StaticTransactionHistoryRepository([
            TransactionRecord(
              id: 'tx-1',
              chainId: '1',
              chainType: ChainType.evm,
              assetSymbol: 'ETH',
              direction: TransactionDirection.outgoing,
              amount: '0.1',
              status: TransactionStatus.submitted,
              transactionHash: '0xhash',
              createdAt: DateTime.utc(2026, 6, 6),
              fromAddress: '0x1111111111111111111111111111111111111111',
              toAddress: '0x2222222222222222222222222222222222222222',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(recentTransactionsProvider.future);
    final state = container.read(homeControllerProvider);

    expect(
      state.recentTransactions.single.subtitle,
      '0x2222222222222222222222222222222222222222',
    );
    expect(state.recentTransactions.single.subtitleIsAddress, isTrue);
  });

  test('home controller renders wrapped native records as conversions',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(
          _StaticChainRepository(ethereum),
        ),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([_nativeBalanceFor(ethereum)]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _StaticTransactionHistoryRepository([
            TransactionRecord(
              id: 'wrap-1',
              chainId: '1',
              chainType: ChainType.evm,
              assetSymbol: 'ETH',
              direction: TransactionDirection.outgoing,
              amount: '0.5',
              status: TransactionStatus.submitted,
              transactionHash: '0xwrap',
              createdAt: DateTime.utc(2026, 6, 6),
              operation: TransactionOperation.wrap,
              resource: 'WETH',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(recentTransactionsProvider.future);
    final preview =
        container.read(homeControllerProvider).recentTransactions.single;

    expect(preview.title, '封装原生币');
    expect(preview.amount, '0.5 ETH → WETH');
    expect(preview.operation, TransactionOperation.wrap);
  });

  test('home controller limits recent transaction amounts to 6 decimals',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(
          _StaticChainRepository(ethereum),
        ),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([_nativeBalanceFor(ethereum)]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _StaticTransactionHistoryRepository([
            TransactionRecord(
              id: 'unwrap-1',
              chainId: '1',
              chainType: ChainType.evm,
              assetSymbol: 'WETH',
              direction: TransactionDirection.outgoing,
              amount: '0.0011021813649329',
              status: TransactionStatus.submitted,
              transactionHash: '0xunwrap',
              createdAt: DateTime.utc(2026, 8, 5),
              operation: TransactionOperation.unwrap,
              resource: 'ETH',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(recentTransactionsProvider.future);
    final preview =
        container.read(homeControllerProvider).recentTransactions.single;

    expect(preview.amount, '0.001102 WETH → ETH');
  });

  test('home controller formats recent transaction time in the local timezone',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final createdAt = DateTime.utc(2026, 6, 7, 20, 9, 10);
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(
          _StaticChainRepository(ethereum),
        ),
        assetPortfolioProvider.overrideWith((ref) async {
          return AssetPortfolio.loaded([_nativeBalanceFor(ethereum)]);
        }),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _StaticTransactionHistoryRepository([
            TransactionRecord(
              id: 'tx-1',
              chainId: '1',
              chainType: ChainType.evm,
              assetSymbol: 'ETH',
              direction: TransactionDirection.outgoing,
              amount: '0.1',
              status: TransactionStatus.submitted,
              transactionHash: '0xhash',
              createdAt: createdAt,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(assetPortfolioProvider.future);
    await container.read(recentTransactionsProvider.future);
    final state = container.read(homeControllerProvider);

    expect(
      state.recentTransactions.single.timestamp,
      _localTransactionTimestamp(createdAt),
    );
  });

  test('home controller updates wallet name while assets are still loading',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final first = _wallet(id: 'wallet-1', name: 'Wallet 1');
    final second = _wallet(id: 'wallet-6', name: 'test6');
    final assetCompleter = Completer<AssetPortfolio>();
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _StaticWalletRepository([first, second]),
        ),
        chainRepositoryProvider.overrideWithValue(
          _StaticChainRepository(ethereum),
        ),
        rpcNodeRepositoryProvider.overrideWithValue(
          _StaticRpcNodeRepository(_rpcNode),
        ),
        tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
        assetRepositoryProvider.overrideWithValue(
          _PendingAssetRepository(assetCompleter),
        ),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedWalletIdProvider.notifier).select(second.id);
    final request = await container.read(assetPortfolioRequestProvider);
    expect(request?.account.name, 'test6');

    container.read(homeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(homeControllerProvider);

    expect(state.assetStatus, HomeAssetStatus.loading);
    expect(state.walletName, 'test6');
  });

  test('home controller exposes placeholder assets while balances are loading',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final wallet = _wallet(id: 'wallet-1', name: 'Wallet 1');
    final assetCompleter = Completer<AssetPortfolio>();
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _StaticWalletRepository([wallet]),
        ),
        chainRepositoryProvider.overrideWithValue(
          _StaticChainRepository(ethereum),
        ),
        rpcNodeRepositoryProvider.overrideWithValue(
          _StaticRpcNodeRepository(_rpcNode),
        ),
        tokenRepositoryProvider.overrideWithValue(
          _StaticTokenRepository(
            const [
              TokenInfo(
                chainId: '1',
                contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
                symbol: 'USDC',
                name: 'USD Coin',
                decimals: 6,
                source: TokenSource.builtIn,
                isHidden: false,
              ),
            ],
          ),
        ),
        assetRepositoryProvider.overrideWithValue(
          _PendingAssetRepository(assetCompleter),
        ),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedWalletIdProvider.notifier).select(wallet.id);
    await container.read(tokensForChainProvider(ethereum.chainId).future);
    container.read(homeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(homeControllerProvider);

    expect(state.assetStatus, HomeAssetStatus.loading);
    expect(
      state.assets.map((asset) => '${asset.symbol}:${asset.amount}'),
      ['ETH:-- ETH', 'USDC:-- USDC'],
    );
  });

  test('home controller swaps chain copy and assets before new balances finish',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final bnbSmartChain =
        defaultChains.firstWhere((chain) => chain.id == 'bnb-smart-chain');
    final wallet = _wallet(id: 'wallet-1', name: 'Wallet 1');
    final bnbPortfolioCompleter = Completer<AssetPortfolio>();
    final chainRepository = _MutableChainRepository(ethereum);
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _StaticWalletRepository([wallet]),
        ),
        chainRepositoryProvider.overrideWithValue(chainRepository),
        rpcNodeRepositoryProvider.overrideWithValue(
          _StaticRpcNodeRepository(_rpcNode),
        ),
        tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
        assetRepositoryProvider.overrideWithValue(
          _ChainSwitchAssetRepository(
            pendingChainId: bnbSmartChain.chainId,
            pendingPortfolioCompleter: bnbPortfolioCompleter,
          ),
        ),
        transactionHistoryRepositoryProvider.overrideWithValue(
          _EmptyTransactionHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(selectedWalletIdProvider.notifier).select(wallet.id);
    await container.read(assetPortfolioProvider.future);
    expect(container.read(homeControllerProvider).assets.single.symbol, 'ETH');

    await container
        .read(selectedChainControllerProvider.notifier)
        .selectChain(bnbSmartChain.id);
    final request = await container.read(assetPortfolioRequestProvider);
    expect(request?.chain.id, bnbSmartChain.id);

    container.read(homeControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(homeControllerProvider);

    expect(state.assetStatus, HomeAssetStatus.loading);
    expect(state.chainName, bnbSmartChain.name);
    expect(state.chainSymbol, bnbSmartChain.symbol);
    expect(state.nativeEquivalent, '≈ 0.0000 BNB');
    expect(state.assets.map((asset) => asset.symbol), ['BNB']);
  });
}

AssetBalance _nativeBalanceFor(
  ChainConfig chain, {
  double? fiatValueUsd,
  String? fiatValue,
  double? priceUsd,
}) {
  return AssetBalance(
    chainId: chain.chainId,
    token: TokenInfo(
      chainId: chain.chainId,
      contractAddress: null,
      symbol: chain.symbol,
      name: chain.name,
      decimals: switch (chain.chainType) {
        ChainType.evm => 18,
        ChainType.bitcoin => 8,
        ChainType.tron => 6,
        ChainType.solana => 9,
        ChainType.sui => 9,
      },
      source: TokenSource.builtIn,
      isHidden: false,
    ),
    balance: '0',
    formattedBalance: '0',
    status: AssetBalanceStatus.loaded,
    fiatValueUsd: fiatValueUsd,
    fiatValue: fiatValue,
    priceUsd: priceUsd,
  );
}

final class _EmptyTransactionHistoryRepository
    implements TransactionHistoryRepository {
  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return const [];
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return const [];
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

final class _StaticTransactionHistoryRepository
    implements TransactionHistoryRepository {
  const _StaticTransactionHistoryRepository(this.records);

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return records;
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return records
        .where((record) => chainId == null || record.chainId == chainId)
        .take(limit)
        .toList();
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

String _localTransactionTimestamp(DateTime value) {
  final localValue = value.toLocal();
  return '${localValue.month.toString().padLeft(2, '0')}-'
      '${localValue.day.toString().padLeft(2, '0')} '
      '${localValue.hour.toString().padLeft(2, '0')}:'
      '${localValue.minute.toString().padLeft(2, '0')}:'
      '${localValue.second.toString().padLeft(2, '0')}';
}

WalletAccount _wallet({required String id, required String name}) {
  return WalletAccount(
    id: id,
    name: name,
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: '',
    source: WalletAccountSource.privateKey,
    createdAt: DateTime.utc(2026, 6, 6),
    updatedAt: DateTime.utc(2026, 6, 6),
  );
}

const _rpcNode = RpcNode(
  id: 'node-1',
  chainId: '1',
  name: 'Default Ethereum',
  url: 'https://rpc.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

final class _StaticWalletRepository implements WalletRepository {
  const _StaticWalletRepository(this.wallets);

  final List<WalletAccount> wallets;

  @override
  Future<List<WalletAccount>> getWallets() async => wallets;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }
}

final class _StaticChainRepository implements ChainRepository {
  const _StaticChainRepository(this.chain);

  final ChainConfig chain;

  @override
  Future<List<ChainConfig>> getChains() async => [chain];

  @override
  Future<ChainConfig> getSelectedChain() async => chain;

  @override
  Future<ChainConfig> selectChain(String chainId) async => chain;

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
}

final class _MutableChainRepository implements ChainRepository {
  _MutableChainRepository(this.selected);

  ChainConfig selected;

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async => selected;

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selected = defaultChains.firstWhere((chain) => chain.id == chainId);
    return selected;
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
}

final class _StaticRpcNodeRepository implements RpcNodeRepository {
  const _StaticRpcNodeRepository(this.node);

  final RpcNode node;

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async => [node];

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async => node;

  @override
  Future<RpcNode> addCustomNode({
    required ChainConfig chain,
    required String name,
    required String url,
    String? note,
    RpcProvider provider = RpcProvider.custom,
    RpcCredentialMode credentialMode = RpcCredentialMode.none,
    String? credentialParameter,
    String? credential,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> updateCustomNode({
    required ChainConfig chain,
    required String nodeId,
    required String name,
    required String url,
    String? note,
    RpcProvider? provider,
    RpcCredentialMode? credentialMode,
    String? credentialParameter,
    String? credential,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) {
    throw UnimplementedError();
  }
}

final class _EmptyTokenRepository implements TokenRepository {
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

final class _StaticTokenRepository implements TokenRepository {
  const _StaticTokenRepository(this.tokens);

  final List<TokenInfo> tokens;

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return tokens
        .where((token) => token.chainId == chainId)
        .where((token) => includeHidden || !token.isHidden)
        .toList(growable: false);
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

final class _PendingAssetRepository implements AssetRepository {
  const _PendingAssetRepository(this.completer);

  final Completer<AssetPortfolio> completer;

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) {
    return completer.future;
  }
}

final class _ChainSwitchAssetRepository implements AssetRepository {
  const _ChainSwitchAssetRepository({
    required this.pendingChainId,
    required this.pendingPortfolioCompleter,
  });

  final String pendingChainId;
  final Completer<AssetPortfolio> pendingPortfolioCompleter;

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) {
    if (chain.chainId == pendingChainId) {
      return pendingPortfolioCompleter.future;
    }
    return Future.value(
      AssetPortfolio.loaded([_nativeBalanceFor(chain)], account: account),
    );
  }
}
