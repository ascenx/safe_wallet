import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/assets/data/asset_market_data_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';

void main() {
  group('DexScreenerAssetMarketDataRepository', () {
    test('selects the matching pair with the highest USD liquidity', () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final now = DateTime.utc(2026, 7, 18, 8, 30);
      final requests = <Uri>[];
      final repository = DexScreenerAssetMarketDataRepository(
        now: () => now,
        client: MockClient((request) async {
          requests.add(request.url);
          return http.Response(_pairsResponse, 200);
        }),
      );

      final marketData = await repository.getMarketData(
        chain: ethereum,
        contractAddress: _tokenAddress,
      );

      expect(requests, hasLength(1));
      expect(requests.single.host, 'api.dexscreener.com');
      expect(
        requests.single.path,
        '/token-pairs/v1/ethereum/$_tokenAddress',
      );
      expect(marketData?.priceUsd, 1.02);
      expect(marketData?.priceChange24h, 2.48);
      expect(marketData?.volume24hUsd, 12500000);
      expect(marketData?.liquidityUsd, 4200000);
      expect(marketData?.marketCapUsd, 510000000);
      expect(marketData?.fdvUsd, 520000000);
      expect(marketData?.buys24h, 1234);
      expect(marketData?.sells24h, 987);
      expect(marketData?.dexId, 'uniswap');
      expect(marketData?.baseName, 'Test Token');
      expect(marketData?.baseSymbol, 'TEST');
      expect(marketData?.tokenLogoUri, 'https://cdn.dexscreener.com/test.png');
      expect(marketData?.quoteSymbol, 'USDC');
      expect(marketData?.pairAddress, '0xhigh-liquidity-pair');
      expect(marketData?.pairCreatedAt, DateTime.utc(2024, 1, 1));
      expect(marketData?.externalUrl, 'https://dexscreener.com/ethereum/test');
      expect(marketData?.updatedAt, now);
    });

    test('uses the fresh cache instead of requesting the same token twice',
        () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      var requestCount = 0;
      final repository = DexScreenerAssetMarketDataRepository(
        client: MockClient((request) async {
          requestCount += 1;
          return http.Response(_pairsResponse, 200);
        }),
      );

      final first = await repository.getMarketData(
        chain: ethereum,
        contractAddress: _tokenAddress,
      );
      final second = await repository.getMarketData(
        chain: ethereum,
        contractAddress: _tokenAddress,
      );

      expect(second, same(first));
      expect(requestCount, 1);
    });

    test('returns no market data when DexScreener is unavailable', () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final repository = DexScreenerAssetMarketDataRepository(
        client: MockClient((request) async => http.Response('{}', 503)),
      );

      final marketData = await repository.getMarketData(
        chain: ethereum,
        contractAddress: _tokenAddress,
      );

      expect(marketData, isNull);
    });

    test('returns no market data when the request times out', () async {
      final ethereum =
          defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final repository = DexScreenerAssetMarketDataRepository(
        requestTimeout: const Duration(milliseconds: 1),
        client: MockClient((request) => Completer<http.Response>().future),
      );

      final marketData = await repository.getMarketData(
        chain: ethereum,
        contractAddress: _tokenAddress,
      );

      expect(marketData, isNull);
    });
  });
}

const _tokenAddress = '0x0000000000000000000000000000000000000001';

const _pairsResponse = '''
[
  {
    "chainId": "ethereum",
    "dexId": "sushiswap",
    "url": "https://dexscreener.com/ethereum/low",
    "pairAddress": "0xlow-liquidity-pair",
    "baseToken": {
      "address": "$_tokenAddress",
      "name": "Test Token",
      "symbol": "TEST"
    },
    "quoteToken": {
      "address": "0xquote",
      "name": "USD Coin",
      "symbol": "USDC"
    },
    "priceUsd": "1.01",
    "priceChange": {"h24": 1.5},
    "volume": {"h24": 250000},
    "liquidity": {"usd": 100000},
    "marketCap": 500000000,
    "fdv": 500000000,
    "txns": {"h24": {"buys": 200, "sells": 180}},
    "pairCreatedAt": 1704067200000
  },
  {
    "chainId": "ethereum",
    "dexId": "uniswap",
    "url": "https://dexscreener.com/ethereum/test",
    "pairAddress": "0xhigh-liquidity-pair",
    "baseToken": {
      "address": "$_tokenAddress",
      "name": "Test Token",
      "symbol": "TEST"
    },
    "info": {
      "imageUrl": "https://cdn.dexscreener.com/test.png"
    },
    "quoteToken": {
      "address": "0xquote",
      "name": "USD Coin",
      "symbol": "USDC"
    },
    "priceUsd": "1.02",
    "priceChange": {"h24": 2.48},
    "volume": {"h24": 12500000},
    "liquidity": {"usd": 4200000},
    "marketCap": 510000000,
    "fdv": 520000000,
    "txns": {"h24": {"buys": 1234, "sells": 987}},
    "pairCreatedAt": 1704067200000
  },
  {
    "chainId": "ethereum",
    "dexId": "uniswap",
    "url": "https://dexscreener.com/ethereum/reversed",
    "pairAddress": "0xreversed-pair",
    "baseToken": {
      "address": "0xother",
      "name": "Other Token",
      "symbol": "OTHER"
    },
    "quoteToken": {
      "address": "$_tokenAddress",
      "name": "Test Token",
      "symbol": "TEST"
    },
    "priceUsd": "99999",
    "liquidity": {"usd": 999999999}
  }
]
''';
