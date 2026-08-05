import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../../chains/domain/chain_config.dart';

abstract interface class AssetMarketDataRepository {
  Future<AssetMarketData?> getMarketData({
    required ChainConfig chain,
    required String contractAddress,
  });
}

final class DexScreenerAssetMarketDataRepository
    implements AssetMarketDataRepository {
  DexScreenerAssetMarketDataRepository({
    http.Client? client,
    Duration cacheTtl = const Duration(minutes: 1),
    Duration requestTimeout = const Duration(seconds: 8),
    DateTime Function()? now,
  }) : _client = client ?? BoundedHttpClient(),
       _cacheTtl = cacheTtl,
       _requestTimeout = requestTimeout,
       _now = now ?? DateTime.now;

  final http.Client _client;
  final Duration _cacheTtl;
  final Duration _requestTimeout;
  final DateTime Function() _now;
  final _cache = <String, _AssetMarketDataCacheEntry>{};

  void close() {
    _client.close();
  }

  @override
  Future<AssetMarketData?> getMarketData({
    required ChainConfig chain,
    required String contractAddress,
  }) async {
    final chainSlug = _dexScreenerChainSlug(chain);
    final normalizedAddress = _normalizedAddress(chain, contractAddress);
    if (chainSlug == null || normalizedAddress.isEmpty || chain.isTestnet) {
      return null;
    }

    final cacheKey = '$chainSlug:$normalizedAddress';
    final now = _now().toUtc();
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.marketData;
    }

    final uri = Uri.https(
      'api.dexscreener.com',
      '/token-pairs/v1/$chainSlug/$normalizedAddress',
    );
    try {
      final response = await _client.get(uri).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List<dynamic>) {
        return null;
      }
      final marketData = _selectPrimaryPair(
        decoded,
        chain: chain,
        contractAddress: normalizedAddress,
        updatedAt: now,
      );
      if (marketData != null) {
        _cache[cacheKey] = _AssetMarketDataCacheEntry(
          marketData: marketData,
          expiresAt: now.add(_cacheTtl),
        );
      }
      return marketData;
    } catch (_) {
      return null;
    }
  }
}

final class AssetMarketData {
  const AssetMarketData({
    required this.dexId,
    required this.baseSymbol,
    required this.quoteSymbol,
    required this.pairAddress,
    required this.updatedAt,
    this.baseName,
    this.tokenLogoUri,
    this.priceUsd,
    this.priceChange24h,
    this.volume24hUsd,
    this.liquidityUsd,
    this.marketCapUsd,
    this.fdvUsd,
    this.buys24h,
    this.sells24h,
    this.pairCreatedAt,
    this.externalUrl,
  });

  final double? priceUsd;
  final double? priceChange24h;
  final double? volume24hUsd;
  final double? liquidityUsd;
  final double? marketCapUsd;
  final double? fdvUsd;
  final int? buys24h;
  final int? sells24h;
  final String dexId;
  final String? baseName;
  final String baseSymbol;
  final String? tokenLogoUri;
  final String quoteSymbol;
  final String pairAddress;
  final DateTime? pairCreatedAt;
  final String? externalUrl;
  final DateTime updatedAt;
}

final class _AssetMarketDataCacheEntry {
  const _AssetMarketDataCacheEntry({
    required this.marketData,
    required this.expiresAt,
  });

  final AssetMarketData marketData;
  final DateTime expiresAt;
}

AssetMarketData? _selectPrimaryPair(
  List<dynamic> values, {
  required ChainConfig chain,
  required String contractAddress,
  required DateTime updatedAt,
}) {
  Map<String, dynamic>? selected;
  var selectedLiquidity = -1.0;
  for (final value in values) {
    if (value is! Map<String, dynamic>) {
      continue;
    }
    final baseToken = _jsonObject(value['baseToken']);
    final baseAddress = _stringValue(baseToken?['address']);
    if (baseAddress == null ||
        _normalizedAddress(chain, baseAddress) != contractAddress) {
      continue;
    }
    final liquidity =
        _numberValue(_jsonObject(value['liquidity'])?['usd']) ?? 0;
    if (selected == null || liquidity > selectedLiquidity) {
      selected = value;
      selectedLiquidity = liquidity;
    }
  }
  if (selected == null) {
    return null;
  }

  final baseToken = _jsonObject(selected['baseToken']);
  final quoteToken = _jsonObject(selected['quoteToken']);
  final liquidity = _jsonObject(selected['liquidity']);
  final volume = _jsonObject(selected['volume']);
  final priceChange = _jsonObject(selected['priceChange']);
  final transactions24h = _jsonObject(_jsonObject(selected['txns'])?['h24']);
  final info = _jsonObject(selected['info']);
  final pairCreatedAtMs = _integerValue(selected['pairCreatedAt']);

  return AssetMarketData(
    priceUsd: _numberValue(selected['priceUsd']),
    priceChange24h: _numberValue(priceChange?['h24']),
    volume24hUsd: _numberValue(volume?['h24']),
    liquidityUsd: _numberValue(liquidity?['usd']),
    marketCapUsd: _numberValue(selected['marketCap']),
    fdvUsd: _numberValue(selected['fdv']),
    buys24h: _integerValue(transactions24h?['buys']),
    sells24h: _integerValue(transactions24h?['sells']),
    dexId: _stringValue(selected['dexId']) ?? '--',
    baseName: _stringValue(baseToken?['name']),
    baseSymbol: _stringValue(baseToken?['symbol']) ?? '--',
    tokenLogoUri: _stringValue(info?['imageUrl']),
    quoteSymbol: _stringValue(quoteToken?['symbol']) ?? '--',
    pairAddress: _stringValue(selected['pairAddress']) ?? '--',
    pairCreatedAt: pairCreatedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(pairCreatedAtMs, isUtc: true),
    externalUrl: _stringValue(selected['url']),
    updatedAt: updatedAt,
  );
}

String? _dexScreenerChainSlug(ChainConfig chain) {
  return switch (chain.id) {
    'ethereum' => 'ethereum',
    'bnb-smart-chain' => 'bsc',
    'polygon' => 'polygon',
    'arbitrum' => 'arbitrum',
    'optimism' => 'optimism',
    'base' => 'base',
    'hyperevm' => 'hyperevm',
    'tron-mainnet' => 'tron',
    'solana-mainnet' => 'solana',
    _ => null,
  };
}

String _normalizedAddress(ChainConfig chain, String value) {
  final trimmed = value.trim();
  return chain.chainType == ChainType.evm ? trimmed.toLowerCase() : trimmed;
}

Map<String, dynamic>? _jsonObject(Object? value) {
  return value is Map<String, dynamic> ? value : null;
}

String? _stringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

double? _numberValue(Object? value) {
  return switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value),
    _ => null,
  };
}

int? _integerValue(Object? value) {
  return switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };
}
