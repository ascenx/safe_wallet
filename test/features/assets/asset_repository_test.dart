import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/data/asset_market_data_repository.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/data/bitcoin_asset_service.dart';
import 'package:safe_wallet/features/assets/data/evm_asset_service.dart';
import 'package:safe_wallet/features/assets/data/solana_asset_service.dart';
import 'package:safe_wallet/features/assets/data/sui_asset_service.dart';
import 'package:safe_wallet/features/assets/data/token_balance_store.dart';
import 'package:safe_wallet/features/assets/data/token_price_repository.dart';
import 'package:safe_wallet/features/assets/data/token_universe_repository.dart';
import 'package:safe_wallet/features/assets/data/tron_asset_service.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  group('DefaultAssetRepository', () {
    test('loads EVM native and ERC20 balances', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(
          nativeBalance: BigInt.parse('1500000000000000000'),
          erc20Balances: {
            '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': BigInt.from(1234500),
          },
        ),
        solanaAssetService: _FakeSolanaAssetService(),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: ethereum,
        rpcNode: _node(chainId: ethereum.chainId),
        tokens: const [
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
      );

      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances, hasLength(2));
      expect(portfolio.balances[0].token.symbol, 'ETH');
      expect(portfolio.balances[0].token.logoUri, isNotNull);
      expect(portfolio.balances[0].formattedBalance, '1.5');
      expect(portfolio.balances[1].token.symbol, 'USDC');
      expect(portfolio.balances[1].formattedBalance, '1.2345');
    });

    test('loads Bitcoin native balance in satoshis', () async {
      final bitcoin = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );
      final bitcoinService = _FakeBitcoinAssetService(
        balance: BigInt.from(123456789),
      );
      final repository = DefaultAssetRepository(
        bitcoinAssetService: bitcoinService,
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: bitcoin,
        rpcNode: _node(chainId: bitcoin.chainId),
      );

      expect(bitcoinService.requests.single.walletAddress, _account.btcAddress);
      expect(
        bitcoinService.requests.single.apiBaseUrl,
        'https://rpc.example.com',
      );
      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances.single.token.symbol, 'BTC');
      expect(portfolio.balances.single.token.decimals, 8);
      expect(
        portfolio.balances.single.token.logoUri,
        'asset:assets/chain_logos/bitcoin.svg',
      );
      expect(portfolio.balances.single.balance, '123456789');
      expect(portfolio.balances.single.formattedBalance, '1.23456789');
    });

    test('loads Tron native balance in sun', () async {
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );
      final tronService = _FakeTronAssetService(balance: BigInt.from(1234567));
      final repository = DefaultAssetRepository(
        tronAssetService: tronService,
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: tron,
        rpcNode: _node(chainId: tron.chainId),
      );

      expect(tronService.requests.single.walletAddress, _account.tronAddress);
      expect(tronService.requests.single.apiBaseUrl, 'https://rpc.example.com');
      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances.single.token.symbol, 'TRX');
      expect(portfolio.balances.single.token.decimals, 6);
      expect(
        portfolio.balances.single.token.logoUri,
        'asset:assets/chain_logos/tron.svg',
      );
      expect(portfolio.balances.single.balance, '1234567');
      expect(portfolio.balances.single.formattedBalance, '1.23456');
    });

    test('loads native SUI and arbitrary discovered Coin balances', () async {
      final sui = defaultChains.firstWhere(
        (chain) => chain.id == 'sui-mainnet',
      );
      final suiService = _FakeSuiAssetService(
        nativeBalance: BigInt.from(1500000000),
        balances: [
          SuiCoinBalance(
            coinType: suiNativeCoinType,
            coinObjectCount: 2,
            totalBalance: BigInt.from(1500000000),
          ),
          SuiCoinBalance(
            coinType: '0xabc::usdc::USDC',
            coinObjectCount: 1,
            totalBalance: BigInt.from(1234500),
          ),
        ],
        metadata: const {
          '0xabc::usdc::USDC': SuiCoinMetadata(
            decimals: 6,
            name: 'USD Coin',
            symbol: 'USDC',
            description: 'Test coin',
            iconUrl: 'https://example.com/usdc.png',
          ),
        },
      );
      final repository = DefaultAssetRepository(
        suiAssetService: suiService,
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(),
        tokenUniverseRepository: const _StaticTokenUniverseRepository([]),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: sui,
        rpcNode: _node(chainId: sui.chainId),
      );

      expect(suiService.balanceOwners, [_account.suiAddress]);
      expect(suiService.allBalanceOwners, [_account.suiAddress]);
      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances.map((balance) => balance.token.symbol), [
        'SUI',
        'USDC',
      ]);
      expect(portfolio.balances.first.formattedBalance, '1.5');
      expect(portfolio.balances.last.formattedBalance, '1.2345');
      expect(
        portfolio.balances.last.token.contractAddress,
        '0xabc::usdc::USDC',
      );
      expect(
        portfolio.balances.last.token.logoUri,
        'https://example.com/usdc.png',
      );
    });

    test('keeps an unknown Sui Coin visible with its full Coin type', () async {
      final sui = defaultChains.firstWhere(
        (chain) => chain.id == 'sui-mainnet',
      );
      const unknownCoinType = '0xabc::unknown::UNKNOWN';
      final repository = DefaultAssetRepository(
        suiAssetService: _FakeSuiAssetService(
          nativeBalance: BigInt.zero,
          balances: [
            SuiCoinBalance(
              coinType: unknownCoinType,
              coinObjectCount: 1,
              totalBalance: BigInt.from(42),
            ),
          ],
        ),
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(),
        tokenUniverseRepository: const _StaticTokenUniverseRepository([]),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: sui,
        rpcNode: _node(chainId: sui.chainId),
      );

      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances.last.token.symbol, 'UNKNOWN');
      expect(portfolio.balances.last.token.name, unknownCoinType);
      expect(portfolio.balances.last.balance, '42');
    });

    test('loads visible Tron contract token balances', () async {
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );
      final tronService = _FakeTronAssetService(
        balance: BigInt.from(5000000),
        trc20Balances: {_trc20ContractAddress: BigInt.from(123456789)},
      );
      final repository = DefaultAssetRepository(
        tronAssetService: tronService,
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(),
      );
      const token = TokenInfo(
        chainId: 'tron-mainnet',
        contractAddress: _trc20ContractAddress,
        symbol: 'USDT',
        name: 'Tether USD',
        decimals: 6,
        source: TokenSource.userAdded,
        isHidden: false,
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: tron,
        rpcNode: _node(chainId: tron.chainId),
        tokens: const [token],
      );

      expect(tronService.trc20Requests, hasLength(1));
      expect(
        tronService.trc20Requests.single.apiBaseUrl,
        'https://rpc.example.com',
      );
      expect(
        tronService.trc20Requests.single.walletAddress,
        _account.tronAddress,
      );
      expect(tronService.trc20Requests.single.contractAddresses, [
        _trc20ContractAddress,
      ]);
      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances.map((balance) => balance.token.symbol), [
        'TRX',
        'USDT',
      ]);
      expect(portfolio.balances.last.balance, '123456789');
      expect(portfolio.balances.last.formattedBalance, '123.456');
    });

    test(
      'does not query balances when the wallet lacks the chain address',
      () async {
        final ethereum = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final bitcoin = defaultChains.firstWhere(
          (chain) => chain.id == 'bitcoin-mainnet',
        );
        final solana = defaultChains.firstWhere(
          (chain) => chain.id == 'solana-mainnet',
        );
        final evmService = _FakeEvmAssetService(nativeBalance: BigInt.one);
        final bitcoinService = _FakeBitcoinAssetService(balance: BigInt.one);
        final solanaService = _FakeSolanaAssetService(solBalance: BigInt.one);
        final repository = DefaultAssetRepository(
          evmAssetService: evmService,
          bitcoinAssetService: bitcoinService,
          solanaAssetService: solanaService,
          tokenUniverseRepository: const _StaticTokenUniverseRepository([]),
        );

        final evmPortfolio = await repository.loadPortfolio(
          account: _bitcoinOnlyAccount,
          chain: ethereum,
          rpcNode: _node(chainId: ethereum.chainId),
        );
        final bitcoinPortfolio = await repository.loadPortfolio(
          account: _evmOnlyAccount,
          chain: bitcoin,
          rpcNode: _node(chainId: bitcoin.chainId),
        );
        final solanaPortfolio = await repository.loadPortfolio(
          account: _bitcoinOnlyAccount,
          chain: solana,
          rpcNode: _node(chainId: solana.chainId),
        );

        expect(evmPortfolio.status, AssetPortfolioStatus.empty);
        expect(bitcoinPortfolio.status, AssetPortfolioStatus.empty);
        expect(solanaPortfolio.status, AssetPortfolioStatus.empty);
        expect(evmService.nativeBalanceRequests, isEmpty);
        expect(evmService.erc20BalanceBatches, isEmpty);
        expect(bitcoinService.requests, isEmpty);
        expect(solanaService.solBalanceRequests, isEmpty);
        expect(solanaService.ownerBalanceRequestCount, 0);
      },
    );

    test('writes loaded balances into the token balance cache pool', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final now = DateTime.utc(2026, 6, 9, 1);
      final balanceStore = InMemoryTokenBalanceStore();
      final repository = DefaultAssetRepository(
        now: () => now,
        balanceStore: balanceStore,
        balanceCacheTtl: const Duration(minutes: 1),
        evmAssetService: _FakeEvmAssetService(
          nativeBalance: BigInt.parse('1500000000000000000'),
          erc20Balances: {
            '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': BigInt.from(1234500),
          },
        ),
        solanaAssetService: _FakeSolanaAssetService(),
      );
      final usdc = _usdcToken;

      await repository.loadPortfolio(
        account: _account,
        chain: ethereum,
        rpcNode: _node(chainId: ethereum.chainId),
        tokens: [usdc],
      );
      final cached = await balanceStore.getAll([
        tokenBalanceKey(
          chain: ethereum,
          walletAddress: _account.evmAddress,
          token: _nativeToken(ethereum),
        ),
        tokenBalanceKey(
          chain: ethereum,
          walletAddress: _account.evmAddress,
          token: usdc,
        ),
      ]);

      expect(cached.values.map((entry) => entry.rawBalance), [
        '1500000000000000000',
        '1234500',
      ]);
      expect(cached.values.map((entry) => entry.expiresAt).toSet(), {
        now.add(const Duration(minutes: 1)),
      });
    });

    test(
      'queries EVM top token universe balances in batches and caches zero balances',
      () async {
        final ethereum = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final topTokens = List.generate(
          21,
          (index) => _evmToken(
            chainId: ethereum.chainId,
            address: _addressFor(index + 1),
            symbol: 'TOP${index + 1}',
          ),
        );
        final balanceStore = InMemoryTokenBalanceStore();
        final evmService = _FakeEvmAssetService(
          nativeBalance: BigInt.zero,
          erc20Balances: {
            topTokens.last.contractAddress!.toLowerCase(): BigInt.from(5000000),
          },
        );
        final repository = DefaultAssetRepository(
          balanceStore: balanceStore,
          tokenUniverseRepository: _StaticTokenUniverseRepository(topTokens),
          evmAssetService: evmService,
          solanaAssetService: _FakeSolanaAssetService(),
        );

        final portfolio = await repository.loadPortfolio(
          account: _account,
          chain: ethereum,
          rpcNode: _node(chainId: ethereum.chainId),
          tokens: const [],
        );
        final cached = await balanceStore.getAll([
          tokenBalanceKey(
            chain: ethereum,
            walletAddress: _account.evmAddress,
            token: topTokens.first,
          ),
          tokenBalanceKey(
            chain: ethereum,
            walletAddress: _account.evmAddress,
            token: topTokens.last,
          ),
        ]);

        expect(evmService.erc20BalanceBatches.map((batch) => batch.length), [
          20,
          1,
        ]);
        expect(portfolio.balances.map((balance) => balance.token.symbol), [
          'ETH',
          'TOP21',
        ]);
        expect(
          cached[tokenBalanceKey(
                chain: ethereum,
                walletAddress: _account.evmAddress,
                token: topTokens.first,
              )]
              ?.rawBalance,
          '0',
        );
        expect(
          cached[tokenBalanceKey(
                chain: ethereum,
                walletAddress: _account.evmAddress,
                token: topTokens.last,
              )]
              ?.rawBalance,
          '5000000',
        );
      },
    );

    test('loads cached balances for the active wallet and chain', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final now = DateTime.utc(2026, 6, 9, 1);
      final balanceStore = InMemoryTokenBalanceStore({
        tokenBalanceKey(
          chain: ethereum,
          walletAddress: _account.evmAddress,
          token: _nativeToken(ethereum),
        ): TokenBalanceCacheEntry(
          rawBalance: '1500000000000000000',
          formattedBalance: '1.5',
          updatedAt: now.subtract(const Duration(minutes: 2)),
          expiresAt: now.subtract(const Duration(minutes: 1)),
        ),
      });
      final repository = DefaultAssetRepository(
        now: () => now,
        balanceStore: balanceStore,
        evmAssetService: _FakeEvmAssetService(shouldFail: true),
        solanaAssetService: _FakeSolanaAssetService(),
      );

      final cached = await repository.loadCachedPortfolio(
        account: _account,
        chain: ethereum,
        tokens: const [],
      );

      expect(cached?.portfolio.status, AssetPortfolioStatus.loaded);
      expect(cached?.portfolio.balances.single.formattedBalance, '1.5');
      expect(cached?.isFresh, isFalse);
    });

    test('attaches USD values from token prices', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(
          nativeBalance: BigInt.parse('1500000000000000000'),
          erc20Balances: {
            '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': BigInt.from(1234500),
          },
        ),
        solanaAssetService: _FakeSolanaAssetService(),
        priceRepository: _StaticTokenPriceRepository(
          prices: {
            '1:native': 3000,
            '1:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': 1,
          },
        ),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: ethereum,
        rpcNode: _node(chainId: ethereum.chainId),
        tokens: const [
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
      );

      expect(portfolio.balances[0].fiatValueUsd, 4500);
      expect(portfolio.balances[0].fiatValue, '\$4,500.00');
      expect(portfolio.balances[1].fiatValueUsd, 1.2345);
      expect(portfolio.balances[1].fiatValue, '\$1.23');
    });

    test('refreshes displayed asset prices in batches of 20', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final tokens = List.generate(
        21,
        (index) => _evmToken(
          chainId: ethereum.chainId,
          address: _addressFor(index + 1),
          symbol: 'TOK${index + 1}',
        ),
      );
      final priceRepository = _RecordingTokenPriceRepository();
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(
          nativeBalance: BigInt.one,
          erc20Balances: {
            for (final token in tokens)
              token.contractAddress!.toLowerCase(): BigInt.one,
          },
        ),
        solanaAssetService: _FakeSolanaAssetService(),
        tokenUniverseRepository: const _StaticTokenUniverseRepository([]),
        priceRepository: priceRepository,
      );

      await repository.loadPortfolio(
        account: _account,
        chain: ethereum,
        rpcNode: _node(chainId: ethereum.chainId),
        tokens: tokens,
      );

      expect(priceRepository.usdPriceRequestSizes, isEmpty);
      expect(priceRepository.refreshUsdPriceRequestSizes, [20, 2]);
    });

    test('attaches USD values from the token price cache pool', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final now = DateTime.utc(2026, 6, 8, 1);
      final nativeToken = _nativeToken(ethereum);
      final repository = DefaultAssetRepository(
        now: () => now,
        evmAssetService: _FakeEvmAssetService(
          nativeBalance: BigInt.parse('1500000000000000000'),
        ),
        solanaAssetService: _FakeSolanaAssetService(),
        balanceStore: InMemoryTokenBalanceStore({
          tokenBalanceKey(
            chain: ethereum,
            walletAddress: _account.evmAddress,
            token: nativeToken,
          ): TokenBalanceCacheEntry(
            rawBalance: '1500000000000000000',
            formattedBalance: '1.5',
            updatedAt: now,
            expiresAt: now.add(const Duration(minutes: 1)),
          ),
        }),
        priceRepository: DefaultTokenPriceRepository(
          now: () => now,
          store: InMemoryTokenPriceStore({
            tokenPriceKey(
              chain: ethereum,
              token: nativeToken,
            ): TokenPriceCacheEntry(
              quote: TokenPriceQuote(
                priceUsd: 3000,
                source: TokenPriceSource.coinGecko,
                updatedAt: now,
              ),
              expiresAt: now.add(const Duration(minutes: 2)),
            ),
          }),
        ),
      );

      final cached = await repository.loadCachedPortfolio(
        account: _account,
        chain: ethereum,
        tokens: const [],
      );

      final portfolio = cached!.portfolio;
      expect(portfolio.balances.single.fiatValueUsd, 4500);
      expect(portfolio.balances.single.priceUsd, 3000);
    });

    test('loads Solana SOL balance', () async {
      final solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(
          solBalance: BigInt.from(2500000000),
          splTokenBalances: {'usdc-solana-mint': BigInt.from(42000000)},
        ),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: solana,
        rpcNode: _node(chainId: solana.chainId),
        tokens: const [
          TokenInfo(
            chainId: 'mainnet-beta',
            contractAddress: 'usdc-solana-mint',
            symbol: 'USDC',
            name: 'USD Coin',
            decimals: 6,
            source: TokenSource.builtIn,
            isHidden: false,
          ),
        ],
      );

      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances, hasLength(2));
      expect(portfolio.balances[0].token.symbol, 'SOL');
      expect(portfolio.balances[0].token.logoUri, isNotNull);
      expect(portfolio.balances[0].formattedBalance, '2.5');
      expect(portfolio.balances[1].token.symbol, 'USDC');
      expect(portfolio.balances[1].formattedBalance, '42');
    });

    test(
      'loads Solana SPL balances by owner instead of querying each mint',
      () async {
        final solana = defaultChains.firstWhere(
          (chain) => chain.id == 'solana-mainnet',
        );
        const usdc = TokenInfo(
          chainId: 'mainnet-beta',
          contractAddress: 'usdc-solana-mint',
          symbol: 'USDC',
          name: 'USD Coin',
          decimals: 6,
          source: TokenSource.builtIn,
          isHidden: false,
        );
        const missingVisibleToken = TokenInfo(
          chainId: 'mainnet-beta',
          contractAddress: 'missing-solana-mint',
          symbol: 'PYUSD',
          name: 'PayPal USD',
          decimals: 6,
          source: TokenSource.builtIn,
          isHidden: false,
        );
        final solanaService = _FakeSolanaAssetService(
          solBalance: BigInt.from(2500000000),
          ownerTokenBalances: [
            SolanaTokenBalance(
              mintAddress: 'usdc-solana-mint',
              rawBalance: BigInt.from(42000000),
              decimals: 6,
            ),
            SolanaTokenBalance(
              mintAddress: 'unknown-solana-mint',
              rawBalance: BigInt.from(7),
              decimals: 0,
            ),
          ],
        );
        final repository = DefaultAssetRepository(
          evmAssetService: _FakeEvmAssetService(),
          solanaAssetService: solanaService,
          tokenUniverseRepository: const _StaticTokenUniverseRepository([]),
        );

        final portfolio = await repository.loadPortfolio(
          account: _account,
          chain: solana,
          rpcNode: _node(chainId: solana.chainId),
          tokens: const [usdc, missingVisibleToken],
        );
        final balancesByContract = {
          for (final balance in portfolio.balances)
            if (balance.token.contractAddress != null)
              balance.token.contractAddress!: balance,
        };

        expect(solanaService.ownerBalanceRequestCount, 1);
        expect(solanaService.splMintBalanceRequests, isEmpty);
        expect(balancesByContract['usdc-solana-mint']?.token.symbol, 'USDC');
        expect(balancesByContract['usdc-solana-mint']?.formattedBalance, '42');
        expect(
          balancesByContract['missing-solana-mint']?.formattedBalance,
          '0',
        );
        expect(
          balancesByContract['unknown-solana-mint']?.formattedBalance,
          '7',
        );
      },
    );

    test('enriches unknown Solana tokens with DexScreener metadata', () async {
      final solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      final marketDataRepository = _FakeAssetMarketDataRepository(
        AssetMarketData(
          dexId: 'raydium',
          baseName: 'Unknown Token',
          baseSymbol: 'UNKNOWN',
          tokenLogoUri: 'https://cdn.dexscreener.com/unknown.png',
          quoteSymbol: 'SOL',
          pairAddress: 'unknown-pair',
          updatedAt: _testDate,
        ),
      );
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(),
        solanaAssetService: _FakeSolanaAssetService(
          ownerTokenBalances: [
            SolanaTokenBalance(
              mintAddress: 'unknown-solana-mint',
              rawBalance: BigInt.from(123456),
              decimals: 6,
            ),
          ],
        ),
        tokenUniverseRepository: const _StaticTokenUniverseRepository([]),
        marketDataRepository: marketDataRepository,
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: solana,
        rpcNode: _node(chainId: solana.chainId),
      );
      final token = portfolio.balances
          .singleWhere(
            (balance) => balance.token.contractAddress == 'unknown-solana-mint',
          )
          .token;

      expect(token.name, 'Unknown Token');
      expect(token.symbol, 'UNKNOWN');
      expect(token.logoUri, 'https://cdn.dexscreener.com/unknown.png');
      expect(token.decimals, 6);
      expect(marketDataRepository.requestedAddresses, ['unknown-solana-mint']);
    });

    test('RPC failure returns error without displaying zero balance', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(shouldFail: true),
        solanaAssetService: _FakeSolanaAssetService(),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: ethereum,
        rpcNode: _node(chainId: ethereum.chainId),
      );

      expect(portfolio.status, AssetPortfolioStatus.error);
      expect(portfolio.balances, isEmpty);
      expect(
        portfolio.balances.any((balance) => balance.formattedBalance == '0'),
        isFalse,
      );
    });

    test('formats loaded balances with six significant digits', () async {
      final bnb = defaultChains.firstWhere(
        (chain) => chain.id == 'bnb-smart-chain',
      );
      final repository = DefaultAssetRepository(
        evmAssetService: _FakeEvmAssetService(
          nativeBalance: BigInt.parse('3153812554769415'),
          erc20Balances: {
            '0x55d398326f99059ff775485246999027b3197955': BigInt.parse(
              '1142641667426672895',
            ),
          },
        ),
        solanaAssetService: _FakeSolanaAssetService(),
      );

      final portfolio = await repository.loadPortfolio(
        account: _account,
        chain: bnb,
        rpcNode: _node(chainId: bnb.chainId),
        tokens: const [
          TokenInfo(
            chainId: '56',
            contractAddress: '0x55d398326f99059ff775485246999027b3197955',
            symbol: 'USDT',
            name: 'Tether USD',
            decimals: 18,
            source: TokenSource.builtIn,
            isHidden: false,
          ),
        ],
      );

      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances[0].formattedBalance, '0.00315381');
      expect(portfolio.balances[1].formattedBalance, '1.14264');
    });

    test(
      'sorts native asset first and non-zero token balances before zero',
      () async {
        final ethereum = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final repository = DefaultAssetRepository(
          evmAssetService: _FakeEvmAssetService(
            nativeBalance: BigInt.zero,
            erc20Balances: {
              '0x0000000000000000000000000000000000000001': BigInt.zero,
              '0x0000000000000000000000000000000000000002': BigInt.from(1),
            },
          ),
          solanaAssetService: _FakeSolanaAssetService(),
        );

        final portfolio = await repository.loadPortfolio(
          account: _account,
          chain: ethereum,
          rpcNode: _node(chainId: ethereum.chainId),
          tokens: const [
            TokenInfo(
              chainId: '1',
              contractAddress: '0x0000000000000000000000000000000000000001',
              symbol: 'ZERO',
              name: 'Zero Token',
              decimals: 18,
              source: TokenSource.builtIn,
              isHidden: false,
            ),
            TokenInfo(
              chainId: '1',
              contractAddress: '0x0000000000000000000000000000000000000002',
              symbol: 'ONE',
              name: 'One Token',
              decimals: 18,
              source: TokenSource.builtIn,
              isHidden: false,
            ),
          ],
        );

        expect(portfolio.balances.map((balance) => balance.token.symbol), [
          'ETH',
          'ONE',
          'ZERO',
        ]);
      },
    );
  });
}

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  tronAddress: 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj',
  solanaAddress: 'So11111111111111111111111111111111111111112',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  suiAddress:
      '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _testDate = DateTime.utc(2026, 8, 3);

final _bitcoinOnlyAccount = WalletAccount(
  id: 'wallet-btc',
  name: 'BTC Wallet',
  evmAddress: '',
  solanaAddress: '',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  source: WalletAccountSource.privateKey,
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _evmOnlyAccount = WalletAccount(
  id: 'wallet-evm',
  name: 'EVM Wallet',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '',
  btcAddress: '',
  source: WalletAccountSource.privateKey,
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

RpcNode _node({required String chainId}) {
  return RpcNode(
    id: 'node-$chainId',
    chainId: chainId,
    name: 'Default',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  );
}

TokenInfo _nativeToken(ChainConfig chain) {
  return TokenInfo(
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
  );
}

TokenInfo _evmToken({
  required String chainId,
  required String address,
  required String symbol,
}) {
  return TokenInfo(
    chainId: chainId,
    contractAddress: address,
    symbol: symbol,
    name: '$symbol Token',
    decimals: 6,
    source: TokenSource.builtIn,
    isHidden: false,
  );
}

String _addressFor(int value) {
  return '0x${value.toRadixString(16).padLeft(40, '0')}';
}

const _usdcToken = TokenInfo(
  chainId: '1',
  contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  source: TokenSource.builtIn,
  isHidden: false,
);

const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';

final class _FakeEvmAssetService implements EvmAssetService {
  _FakeEvmAssetService({
    BigInt? nativeBalance,
    this.erc20Balances = const {},
    this.shouldFail = false,
  }) : nativeBalance = nativeBalance ?? BigInt.zero;

  final BigInt nativeBalance;
  final Map<String, BigInt> erc20Balances;
  final bool shouldFail;
  final nativeBalanceRequests = <String>[];
  final erc20BalanceBatches = <List<String>>[];

  @override
  Future<BigInt> getErc20Balance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    if (shouldFail) {
      throw const RpcError.unavailable();
    }
    return erc20Balances[contractAddress.toLowerCase()] ?? BigInt.zero;
  }

  @override
  Future<Map<String, BigInt>> getErc20Balances({
    required String rpcUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    if (shouldFail) {
      throw const RpcError.unavailable();
    }
    erc20BalanceBatches.add(List.unmodifiable(contractAddresses));
    return {
      for (final contractAddress in contractAddresses)
        contractAddress.toLowerCase():
            erc20Balances[contractAddress.toLowerCase()] ?? BigInt.zero,
    };
  }

  @override
  Future<BigInt> getNativeBalance({
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    if (shouldFail) {
      throw const RpcError.unavailable();
    }
    nativeBalanceRequests.add(walletAddress);
    return nativeBalance;
  }
}

final class _FakeBitcoinAssetService implements BitcoinAssetService {
  _FakeBitcoinAssetService({required this.balance});

  final BigInt balance;
  final requests = <({String apiBaseUrl, String walletAddress})>[];

  @override
  Future<BigInt> getBtcBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    requests.add((apiBaseUrl: apiBaseUrl, walletAddress: walletAddress));
    return balance;
  }
}

final class _FakeTronAssetService implements TronAssetService {
  _FakeTronAssetService({required this.balance, this.trc20Balances = const {}});

  final BigInt balance;
  final Map<String, BigInt> trc20Balances;
  final requests = <({String apiBaseUrl, String walletAddress})>[];
  final trc20Requests =
      <
        ({
          String apiBaseUrl,
          String walletAddress,
          List<String> contractAddresses,
        })
      >[];

  @override
  Future<BigInt> getTrxBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    requests.add((apiBaseUrl: apiBaseUrl, walletAddress: walletAddress));
    return balance;
  }

  @override
  Future<Map<String, BigInt>> getTrc20Balances({
    required String apiBaseUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    trc20Requests.add((
      apiBaseUrl: apiBaseUrl,
      walletAddress: walletAddress,
      contractAddresses: contractAddresses,
    ));
    return {
      for (final contractAddress in contractAddresses)
        contractAddress: trc20Balances[contractAddress] ?? BigInt.zero,
    };
  }
}

final class _FakeSolanaAssetService implements SolanaAssetService {
  _FakeSolanaAssetService({
    BigInt? solBalance,
    this.splTokenBalances = const {},
    this.ownerTokenBalances = const [],
  }) : solBalance = solBalance ?? BigInt.zero;

  final BigInt solBalance;
  final Map<String, BigInt> splTokenBalances;
  final List<SolanaTokenBalance> ownerTokenBalances;
  final solBalanceRequests = <String>[];
  final splMintBalanceRequests = <String>[];
  var ownerBalanceRequestCount = 0;

  @override
  Future<BigInt> getSolBalance({
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    solBalanceRequests.add(walletAddress);
    return solBalance;
  }

  @override
  Future<BigInt> getSplTokenBalance({
    required String rpcUrl,
    required String ownerAddress,
    required String mintAddress,
    Map<String, String> headers = const {},
  }) async {
    splMintBalanceRequests.add(mintAddress);
    return splTokenBalances[mintAddress] ?? BigInt.zero;
  }

  @override
  Future<List<SolanaTokenBalance>> getTokenBalancesByOwner({
    required String rpcUrl,
    required String ownerAddress,
    Map<String, String> headers = const {},
  }) async {
    ownerBalanceRequestCount += 1;
    if (ownerTokenBalances.isNotEmpty) {
      return ownerTokenBalances;
    }
    return [
      for (final entry in splTokenBalances.entries)
        SolanaTokenBalance(
          mintAddress: entry.key,
          rawBalance: entry.value,
          decimals: 6,
        ),
    ];
  }
}

final class _FakeAssetMarketDataRepository
    implements AssetMarketDataRepository {
  _FakeAssetMarketDataRepository(this.marketData);

  final AssetMarketData? marketData;
  final requestedAddresses = <String>[];

  @override
  Future<AssetMarketData?> getMarketData({
    required ChainConfig chain,
    required String contractAddress,
  }) async {
    requestedAddresses.add(contractAddress);
    return marketData;
  }
}

final class _FakeSuiAssetService implements SuiAssetService {
  _FakeSuiAssetService({
    required this.nativeBalance,
    this.balances = const [],
    this.metadata = const {},
  });

  final BigInt nativeBalance;
  final List<SuiCoinBalance> balances;
  final Map<String, SuiCoinMetadata> metadata;
  final balanceOwners = <String>[];
  final allBalanceOwners = <String>[];

  @override
  Future<List<SuiCoinBalance>> getAllBalances({
    required String rpcUrl,
    required String owner,
    Map<String, String> headers = const {},
  }) async {
    allBalanceOwners.add(owner);
    return balances;
  }

  @override
  Future<SuiCoinBalance> getBalance({
    required String rpcUrl,
    required String owner,
    String coinType = suiNativeCoinType,
    Map<String, String> headers = const {},
  }) async {
    balanceOwners.add(owner);
    return SuiCoinBalance(
      coinType: coinType,
      coinObjectCount: 1,
      totalBalance: nativeBalance,
    );
  }

  @override
  Future<SuiCoinMetadata?> getCoinMetadata({
    required String rpcUrl,
    required String coinType,
    Map<String, String> headers = const {},
  }) async {
    return metadata[coinType];
  }
}

final class _StaticTokenPriceRepository implements TokenPriceRepository {
  const _StaticTokenPriceRepository({required this.prices});

  final Map<String, double> prices;

  @override
  Future<Map<String, TokenPriceQuote>> getCachedUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) {
    return getUsdPrices(chain: chain, tokens: tokens);
  }

  @override
  Future<Map<String, TokenPriceQuote>> getUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    return {
      for (final token in tokens)
        if (prices[tokenPriceKey(chain: chain, token: token)] != null)
          tokenPriceKey(chain: chain, token: token): TokenPriceQuote(
            priceUsd: prices[tokenPriceKey(chain: chain, token: token)]!,
            source: TokenPriceSource.coinGecko,
            updatedAt: DateTime.utc(2026, 6, 8),
          ),
    };
  }

  @override
  Future<Map<String, TokenPriceQuote>> refreshUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) {
    return getUsdPrices(chain: chain, tokens: tokens);
  }
}

final class _RecordingTokenPriceRepository implements TokenPriceRepository {
  final usdPriceRequestSizes = <int>[];
  final refreshUsdPriceRequestSizes = <int>[];

  @override
  Future<Map<String, TokenPriceQuote>> getCachedUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    return const {};
  }

  @override
  Future<Map<String, TokenPriceQuote>> getUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    usdPriceRequestSizes.add(tokens.length);
    return const {};
  }

  @override
  Future<Map<String, TokenPriceQuote>> refreshUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    refreshUsdPriceRequestSizes.add(tokens.length);
    return const {};
  }
}

final class _StaticTokenUniverseRepository implements TokenUniverseRepository {
  const _StaticTokenUniverseRepository(this.tokens);

  final List<TokenInfo> tokens;

  @override
  Future<List<TokenInfo>> getTopTokens({
    required ChainConfig chain,
    int limit = 100,
  }) async {
    return tokens
        .where((token) => token.chainId == chain.chainId)
        .take(limit)
        .toList(growable: false);
  }
}
