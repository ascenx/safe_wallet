import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/assets/data/token_price_repository.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';

void main() {
  group('DefaultTokenPriceRepository', () {
    test('loads CoinGecko prices first and caches results', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final requests = <Uri>[];
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.path.endsWith('/simple/price')) {
            return http.Response('{"ethereum":{"usd":3000.0}}', 200);
          }
          if (request.url.path.endsWith('/simple/token_price/ethereum')) {
            return http.Response(
              '{"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48":{"usd":1.0}}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final prices = await repository.getUsdPrices(
        chain: ethereum,
        tokens: [_nativeToken(ethereum), _usdc],
      );
      final cachedPrices = await repository.getUsdPrices(
        chain: ethereum,
        tokens: [_nativeToken(ethereum), _usdc],
      );

      expect(
        prices[tokenPriceKey(chain: ethereum, token: _nativeToken(ethereum))]
            ?.priceUsd,
        3000,
      );
      expect(prices[tokenPriceKey(chain: ethereum, token: _usdc)]?.priceUsd, 1);
      expect(cachedPrices, prices);
      expect(requests, hasLength(2));
    });

    test('loads native SUI price using the Sui CoinGecko id', () async {
      final sui = defaultChains.firstWhere(
        (chain) => chain.id == 'sui-mainnet',
      );
      Uri? requestedUrl;
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response('{"sui":{"usd":3.25}}', 200);
        }),
      );
      final token = _nativeToken(sui);

      final prices = await repository.getUsdPrices(chain: sui, tokens: [token]);

      expect(requestedUrl?.queryParameters['ids'], 'sui');
      expect(prices[tokenPriceKey(chain: sui, token: token)]?.priceUsd, 3.25);
    });

    test('loads native TRX price using the Tron CoinGecko id', () async {
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );
      Uri? requestedUrl;
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response('{"tron":{"usd":0.13}}', 200);
        }),
      );
      final token = _nativeToken(tron);

      final prices = await repository.getUsdPrices(
        chain: tron,
        tokens: [token],
      );

      expect(requestedUrl?.queryParameters['ids'], 'tron');
      expect(prices[tokenPriceKey(chain: tron, token: token)]?.priceUsd, 0.13);
    });

    test('does not apply mainnet SUI prices to testnet assets', () async {
      const testnet = ChainConfig(
        id: 'sui-testnet',
        chainType: ChainType.sui,
        name: 'Sui Testnet',
        chainId: 'sui:testnet',
        symbol: 'SUI',
        rpcUrls: ['https://fullnode.testnet.sui.io:443'],
        blockExplorerUrl: 'https://suiscan.xyz/testnet',
        isTestnet: true,
      );
      var requestCount = 0;
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requestCount += 1;
          return http.Response('{"sui":{"usd":3.25}}', 200);
        }),
      );

      final prices = await repository.getUsdPrices(
        chain: testnet,
        tokens: [_nativeToken(testnet)],
      );

      expect(prices, isEmpty);
      expect(requestCount, 0);
    });

    test('Sui Coin price cache keys preserve the complete Move type', () {
      final sui = defaultChains.firstWhere(
        (chain) => chain.id == 'sui-mainnet',
      );
      const coin = TokenInfo(
        chainId: 'sui:mainnet',
        contractAddress: '0xabc::coin::USDC',
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        source: TokenSource.userAdded,
        isHidden: false,
      );

      expect(
        tokenPriceKey(chain: sui, token: coin),
        'sui:mainnet:0xabc::coin::USDC',
      );
    });

    test(
      'loads fresh prices from the persistent cache without network',
      () async {
        final ethereum = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        final now = DateTime.utc(2026, 6, 8, 1);
        final store = _FakeTokenPriceStore({
          tokenPriceKey(
            chain: ethereum,
            token: _nativeToken(ethereum),
          ): TokenPriceCacheEntry(
            quote: TokenPriceQuote(
              priceUsd: 3000,
              source: TokenPriceSource.coinGecko,
              updatedAt: now,
            ),
            expiresAt: now.add(const Duration(minutes: 2)),
          ),
        });
        var requestCount = 0;
        final repository = DefaultTokenPriceRepository(
          now: () => now,
          store: store,
          client: MockClient((request) async {
            requestCount += 1;
            return http.Response('{}', 500);
          }),
        );

        final prices = await repository.getUsdPrices(
          chain: ethereum,
          tokens: [_nativeToken(ethereum)],
        );

        expect(
          prices[tokenPriceKey(chain: ethereum, token: _nativeToken(ethereum))]
              ?.priceUsd,
          3000,
        );
        expect(requestCount, 0);
      },
    );

    test('persists fetched prices into the cache pool', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final now = DateTime.utc(2026, 6, 8, 1);
      final store = _FakeTokenPriceStore();
      final repository = DefaultTokenPriceRepository(
        now: () => now,
        store: store,
        cacheTtl: const Duration(minutes: 2),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/simple/price')) {
            return http.Response('{"ethereum":{"usd":3000.0}}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      final key = tokenPriceKey(chain: ethereum, token: _nativeToken(ethereum));

      await repository.getUsdPrices(
        chain: ethereum,
        tokens: [_nativeToken(ethereum)],
      );
      final cached = await store.getAll([key]);

      expect(cached[key]?.quote.priceUsd, 3000);
      expect(cached[key]?.expiresAt, now.add(const Duration(minutes: 2)));
    });

    test('force refresh bypasses cache and updates the cache pool', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final now = DateTime.utc(2026, 6, 8, 1);
      final key = tokenPriceKey(chain: ethereum, token: _nativeToken(ethereum));
      final store = _FakeTokenPriceStore({
        key: TokenPriceCacheEntry(
          quote: TokenPriceQuote(
            priceUsd: 2990,
            source: TokenPriceSource.coinGecko,
            updatedAt: now,
          ),
          expiresAt: now.add(const Duration(minutes: 2)),
        ),
      });
      var requestCount = 0;
      final repository = DefaultTokenPriceRepository(
        now: () => now,
        store: store,
        client: MockClient((request) async {
          requestCount += 1;
          if (request.url.path.endsWith('/simple/price')) {
            return http.Response('{"ethereum":{"usd":3000.0}}', 200);
          }
          return http.Response('{}', 404);
        }),
      );

      final prices = await repository.refreshUsdPrices(
        chain: ethereum,
        tokens: [_nativeToken(ethereum)],
      );
      final cached = await store.getAll([key]);

      expect(prices[key]?.priceUsd, 3000);
      expect(cached[key]?.quote.priceUsd, 3000);
      expect(requestCount, 1);
    });

    test('falls back to DeFiLlama when CoinGecko has no token price', () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final requests = <Uri>[];
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'api.coingecko.com') {
            return http.Response('{}', 200);
          }
          if (request.url.host == 'coins.llama.fi') {
            return http.Response(
              '{"coins":{"ethereum:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48":{"price":1.01}}}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final prices = await repository.getUsdPrices(
        chain: ethereum,
        tokens: [_usdc],
      );

      final quote = prices[tokenPriceKey(chain: ethereum, token: _usdc)];
      expect(quote?.priceUsd, 1.01);
      expect(quote?.source, TokenPriceSource.defiLlama);
      expect(requests.map((uri) => uri.host), [
        'api.coingecko.com',
        'coins.llama.fi',
      ]);
    });

    test('falls back to Jupiter for Solana token prices', () async {
      final solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      final requests = <Uri>[];
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'api.coingecko.com' ||
              request.url.host == 'coins.llama.fi') {
            return http.Response('{}', 200);
          }
          if (request.url.host == 'lite-api.jup.ag') {
            return http.Response('{"usdc-solana-mint":{"usdPrice":0.99}}', 200);
          }
          return http.Response('{}', 404);
        }),
      );

      final prices = await repository.getUsdPrices(
        chain: solana,
        tokens: [_solanaUsdc],
      );

      final quote = prices[tokenPriceKey(chain: solana, token: _solanaUsdc)];
      expect(quote?.priceUsd, 0.99);
      expect(quote?.source, TokenPriceSource.jupiter);
      expect(requests.map((uri) => uri.host), [
        'api.coingecko.com',
        'coins.llama.fi',
        'lite-api.jup.ag',
      ]);
    });

    test('loads Bitcoin native token prices from CoinGecko', () async {
      final bitcoin = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );
      final requests = <Uri>[];
      final repository = DefaultTokenPriceRepository(
        client: MockClient((request) async {
          requests.add(request.url);
          if (request.url.host == 'api.coingecko.com' &&
              request.url.path.endsWith('/simple/price')) {
            expect(request.url.queryParameters['ids'], 'bitcoin');
            return http.Response('{"bitcoin":{"usd":68000.0}}', 200);
          }
          return http.Response('{}', 404);
        }),
      );

      final token = _nativeToken(bitcoin);
      final prices = await repository.getUsdPrices(
        chain: bitcoin,
        tokens: [token],
      );

      final quote = prices[tokenPriceKey(chain: bitcoin, token: token)];
      expect(quote?.priceUsd, 68000);
      expect(quote?.source, TokenPriceSource.coinGecko);
      expect(requests.map((uri) => uri.host), ['api.coingecko.com']);
    });
  });
}

final class _FakeTokenPriceStore implements TokenPriceStore {
  _FakeTokenPriceStore([Map<String, TokenPriceCacheEntry>? entries])
    : _entries = Map.of(entries ?? const {});

  final Map<String, TokenPriceCacheEntry> _entries;

  @override
  Future<Map<String, TokenPriceCacheEntry>> getAll(
    Iterable<String> keys,
  ) async {
    return {
      for (final key in keys)
        if (_entries[key] != null) key: _entries[key]!,
    };
  }

  @override
  Future<void> putAll(Map<String, TokenPriceCacheEntry> entries) async {
    _entries.addAll(entries);
  }
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

const _usdc = TokenInfo(
  chainId: '1',
  contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  source: TokenSource.builtIn,
  isHidden: false,
);

const _solanaUsdc = TokenInfo(
  chainId: 'mainnet-beta',
  contractAddress: 'usdc-solana-mint',
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  source: TokenSource.builtIn,
  isHidden: false,
);
