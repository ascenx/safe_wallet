import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/token_info.dart';
import 'token_price_store.dart';

export 'token_price_store.dart';

abstract interface class TokenPriceRepository {
  Future<Map<String, TokenPriceQuote>> getCachedUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  });

  Future<Map<String, TokenPriceQuote>> getUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  });

  Future<Map<String, TokenPriceQuote>> refreshUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  });
}

final class NoopTokenPriceRepository implements TokenPriceRepository {
  const NoopTokenPriceRepository();

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
    return const {};
  }

  @override
  Future<Map<String, TokenPriceQuote>> refreshUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    return const {};
  }
}

final class DefaultTokenPriceRepository implements TokenPriceRepository {
  DefaultTokenPriceRepository({
    http.Client? client,
    TokenPriceStore? store,
    Duration cacheTtl = const Duration(minutes: 2),
    DateTime Function()? now,
  }) : _client = client ?? BoundedHttpClient(),
       _store = store ?? InMemoryTokenPriceStore(),
       _cacheTtl = cacheTtl,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final TokenPriceStore _store;
  final Duration _cacheTtl;
  final DateTime Function() _now;

  void close() {
    _client.close();
  }

  @override
  Future<Map<String, TokenPriceQuote>> getCachedUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    final keys = tokens
        .map((token) => tokenPriceKey(chain: chain, token: token))
        .toSet();
    final cachedEntries = await _store.getAll(keys);
    return {
      for (final entry in cachedEntries.entries) entry.key: entry.value.quote,
    };
  }

  @override
  Future<Map<String, TokenPriceQuote>> getUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    final result = <String, TokenPriceQuote>{};
    final missing = <TokenInfo>[];
    final now = _now();
    final keys = tokens
        .map((token) => tokenPriceKey(chain: chain, token: token))
        .toSet();
    final cachedEntries = await _store.getAll(keys);

    for (final token in tokens) {
      final key = tokenPriceKey(chain: chain, token: token);
      final cached = cachedEntries[key];
      if (cached != null && cached.expiresAt.isAfter(now)) {
        result[key] = cached.quote;
      } else {
        missing.add(token);
      }
    }

    if (missing.isEmpty) {
      return result;
    }

    result.addAll(
      await _fetchAndStorePrices(chain: chain, tokens: missing, now: now),
    );
    return result;
  }

  @override
  Future<Map<String, TokenPriceQuote>> refreshUsdPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) {
    return _fetchAndStorePrices(chain: chain, tokens: tokens, now: _now());
  }

  Future<Map<String, TokenPriceQuote>> _fetchAndStorePrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
    required DateTime now,
  }) async {
    final fetched = <String, TokenPriceQuote>{};
    await _loadCoinGeckoPrices(chain: chain, tokens: tokens, output: fetched);
    await _loadDefiLlamaPrices(
      chain: chain,
      tokens: _missingTokens(chain: chain, tokens: tokens, prices: fetched),
      output: fetched,
    );
    if (chain.chainType == ChainType.solana) {
      await _loadJupiterPrices(
        chain: chain,
        tokens: _missingTokens(chain: chain, tokens: tokens, prices: fetched),
        output: fetched,
      );
    }

    if (fetched.isNotEmpty) {
      await _store.putAll({
        for (final entry in fetched.entries)
          entry.key: TokenPriceCacheEntry(
            quote: entry.value,
            expiresAt: now.add(_cacheTtl),
          ),
      });
    }
    return fetched;
  }

  Future<void> _loadCoinGeckoPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
    required Map<String, TokenPriceQuote> output,
  }) async {
    final nativeIds = tokens
        .where((token) => token.contractAddress == null)
        .map((token) => _coinGeckoNativeId(chain))
        .whereType<String>()
        .toSet();
    if (nativeIds.isNotEmpty) {
      final uri = Uri.https('api.coingecko.com', '/api/v3/simple/price', {
        'ids': nativeIds.join(','),
        'vs_currencies': 'usd',
      });
      final data = await _getJsonObject(uri);
      if (data != null) {
        for (final token in tokens.where(
          (token) => token.contractAddress == null,
        )) {
          final id = _coinGeckoNativeId(chain);
          final price = _readUsdPrice(data[id]);
          if (price != null) {
            output[tokenPriceKey(chain: chain, token: token)] = _quote(
              price,
              TokenPriceSource.coinGecko,
            );
          }
        }
      }
    }

    final platformId = _coinGeckoPlatformId(chain);
    final contractTokens = tokens
        .where((token) => token.contractAddress != null)
        .toList(growable: false);
    if (platformId == null || contractTokens.isEmpty) {
      return;
    }

    final uri = Uri.https(
      'api.coingecko.com',
      '/api/v3/simple/token_price/$platformId',
      {
        'contract_addresses': contractTokens
            .map(
              (token) => chain.chainType == ChainType.evm
                  ? token.contractAddress!.toLowerCase()
                  : token.contractAddress!,
            )
            .join(','),
        'vs_currencies': 'usd',
      },
    );
    final data = await _getJsonObject(uri);
    if (data == null) {
      return;
    }
    for (final token in contractTokens) {
      final contractAddress = chain.chainType == ChainType.evm
          ? token.contractAddress!.toLowerCase()
          : token.contractAddress!;
      final price = _readUsdPrice(data[contractAddress]);
      if (price != null) {
        output[tokenPriceKey(chain: chain, token: token)] = _quote(
          price,
          TokenPriceSource.coinGecko,
        );
      }
    }
  }

  Future<void> _loadDefiLlamaPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
    required Map<String, TokenPriceQuote> output,
  }) async {
    if (tokens.isEmpty) {
      return;
    }

    final ids = tokens
        .map((token) => _defiLlamaCoinId(chain: chain, token: token))
        .whereType<String>()
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }

    final uri = Uri.https('coins.llama.fi', '/prices/current/${ids.join(',')}');
    final data = await _getJsonObject(uri);
    final coins = data?['coins'];
    if (coins is! Map<String, dynamic>) {
      return;
    }

    for (final token in tokens) {
      final id = _defiLlamaCoinId(chain: chain, token: token);
      final price = id == null ? null : _readDefiLlamaPrice(coins[id]);
      if (price != null) {
        output[tokenPriceKey(chain: chain, token: token)] = _quote(
          price,
          TokenPriceSource.defiLlama,
        );
      }
    }
  }

  Future<void> _loadJupiterPrices({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
    required Map<String, TokenPriceQuote> output,
  }) async {
    final mintTokens = tokens
        .where((token) => token.contractAddress != null)
        .toList(growable: false);
    if (mintTokens.isEmpty) {
      return;
    }

    final uri = Uri.https('lite-api.jup.ag', '/price/v3', {
      'ids': mintTokens.map((token) => token.contractAddress!).join(','),
    });
    final data = await _getJsonObject(uri);
    if (data == null) {
      return;
    }
    for (final token in mintTokens) {
      final mint = token.contractAddress!;
      final price = _readJupiterPrice(data[mint]);
      if (price != null) {
        output[tokenPriceKey(chain: chain, token: token)] = _quote(
          price,
          TokenPriceSource.jupiter,
        );
      }
    }
  }

  List<TokenInfo> _missingTokens({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
    required Map<String, TokenPriceQuote> prices,
  }) {
    return tokens
        .where(
          (token) =>
              !prices.containsKey(tokenPriceKey(chain: chain, token: token)),
        )
        .toList(growable: false);
  }

  TokenPriceQuote _quote(double priceUsd, TokenPriceSource source) {
    return TokenPriceQuote(
      priceUsd: priceUsd,
      source: source,
      updatedAt: _now().toUtc(),
    );
  }

  Future<Map<String, dynamic>?> _getJsonObject(Uri uri) async {
    try {
      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

String tokenPriceKey({required ChainConfig chain, required TokenInfo token}) {
  final contractAddress = token.contractAddress;
  if (contractAddress == null) {
    return '${chain.chainId}:native';
  }
  final normalized = chain.chainType == ChainType.evm
      ? contractAddress.toLowerCase()
      : contractAddress;
  return '${chain.chainId}:$normalized';
}

String? _coinGeckoPlatformId(ChainConfig chain) {
  return switch (chain.chainId) {
    '1' => 'ethereum',
    '56' => 'binance-smart-chain',
    '137' => 'polygon-pos',
    '42161' => 'arbitrum-one',
    '10' => 'optimistic-ethereum',
    '8453' => 'base',
    'mainnet-beta' => 'solana',
    'sui:mainnet' => 'sui',
    _ => null,
  };
}

String? _coinGeckoNativeId(ChainConfig chain) {
  return switch (chain.chainId) {
    '1' => 'ethereum',
    '56' => 'binancecoin',
    '137' => 'polygon-ecosystem-token',
    '42161' || '10' || '8453' => 'ethereum',
    'bitcoin-mainnet' => 'bitcoin',
    'tron-mainnet' => 'tron',
    'mainnet-beta' => 'solana',
    'sui:mainnet' => 'sui',
    _ => null,
  };
}

String? _defiLlamaCoinId({
  required ChainConfig chain,
  required TokenInfo token,
}) {
  if (token.contractAddress == null) {
    final coinGeckoId = _coinGeckoNativeId(chain);
    return coinGeckoId == null ? null : 'coingecko:$coinGeckoId';
  }

  final chainSlug = switch (chain.chainId) {
    '1' => 'ethereum',
    '56' => 'bsc',
    '137' => 'polygon',
    '42161' => 'arbitrum',
    '10' => 'optimism',
    '8453' => 'base',
    'mainnet-beta' => 'solana',
    'sui:mainnet' => 'sui',
    _ => null,
  };
  if (chainSlug == null) {
    return null;
  }
  final address = chain.chainType == ChainType.evm
      ? token.contractAddress!.toLowerCase()
      : token.contractAddress!;
  return '$chainSlug:$address';
}

double? _readUsdPrice(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  final usd = value['usd'];
  return usd is num ? usd.toDouble() : null;
}

double? _readDefiLlamaPrice(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  final price = value['price'];
  return price is num ? price.toDouble() : null;
}

double? _readJupiterPrice(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  final price = value['usdPrice'] ?? value['price'];
  return price is num ? price.toDouble() : null;
}
