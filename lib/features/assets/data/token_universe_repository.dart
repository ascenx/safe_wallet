import 'dart:convert';

import 'package:flutter/services.dart';

import '../../chains/domain/chain_config.dart';
import '../domain/token_info.dart';
import 'token_repository.dart';

abstract interface class TokenUniverseRepository {
  Future<List<TokenInfo>> getTopTokens({
    required ChainConfig chain,
    int limit = 100,
  });
}

typedef TokenUniverseAssetLoader = Future<String> Function(String path);

final class JsonTokenUniverseRepository implements TokenUniverseRepository {
  const JsonTokenUniverseRepository({
    this.assetBasePath = 'assets/token_universe',
    TokenUniverseAssetLoader? loadString,
    this.fallbackTokens = builtInTokens,
  }) : _loadString = loadString;

  final String assetBasePath;
  final TokenUniverseAssetLoader? _loadString;
  final List<TokenInfo> fallbackTokens;

  @override
  Future<List<TokenInfo>> getTopTokens({
    required ChainConfig chain,
    int limit = 100,
  }) async {
    if (limit <= 0) {
      return const [];
    }

    try {
      final rawJson = await (_loadString ?? rootBundle.loadString)(
        '$assetBasePath/${_assetChainId(chain)}.json',
      );
      return _tokensFromJson(rawJson: rawJson, chain: chain)
          .take(limit)
          .toList(growable: false);
    } catch (_) {
      return _fallbackTokens(chain: chain, limit: limit);
    }
  }

  List<TokenInfo> _tokensFromJson({
    required String rawJson,
    required ChainConfig chain,
  }) {
    final decoded = jsonDecode(rawJson);
    final tokenEntries = switch (decoded) {
      {'tokens': final List<Object?> tokens} => tokens,
      final List<Object?> tokens => tokens,
      _ => const <Object?>[],
    };

    final tokens = <TokenInfo>[];
    for (final entry in tokenEntries) {
      final token = _tokenFromJson(entry);
      if (token == null ||
          !_matchesChainId(token.chainId, chain) ||
          token.contractAddress == null ||
          token.isHidden) {
        continue;
      }
      tokens.add(_tokenForChain(token: token, chain: chain));
    }
    return tokens;
  }

  TokenInfo? _tokenFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final chainId = value['chainId'];
    final contractAddress = value['contractAddress'];
    final symbol = value['symbol'];
    final name = value['name'];
    final decimals = value['decimals'];
    final logoUri = value['logoUri'];
    final requiresMemo = value['requiresMemo'] ?? value['requiresTag'];
    final memoLabel = value['memoLabel'] ?? value['tagLabel'];
    if (chainId is! String ||
        contractAddress is! String ||
        contractAddress.isEmpty ||
        symbol is! String ||
        symbol.isEmpty ||
        name is! String ||
        name.isEmpty ||
        decimals is! num) {
      return null;
    }

    return TokenInfo(
      chainId: chainId,
      contractAddress: contractAddress,
      symbol: symbol,
      name: name,
      decimals: decimals.toInt(),
      logoUri: logoUri is String && logoUri.isNotEmpty ? logoUri : null,
      source: TokenSource.builtIn,
      isHidden: false,
      requiresMemo: requiresMemo == true,
      memoLabel: memoLabel is String && memoLabel.trim().isNotEmpty
          ? memoLabel.trim()
          : null,
    );
  }

  String _assetChainId(ChainConfig chain) {
    if (chain.chainType == ChainType.solana &&
        chain.chainId == 'mainnet-beta') {
      return 'solana';
    }
    if (chain.chainType == ChainType.sui) {
      return 'sui';
    }
    return chain.chainId;
  }

  bool _matchesChainId(String tokenChainId, ChainConfig chain) {
    return tokenChainId == chain.chainId ||
        (chain.chainType == ChainType.solana &&
            chain.chainId == 'mainnet-beta' &&
            tokenChainId == 'solana') ||
        (chain.chainType == ChainType.sui && tokenChainId == 'sui');
  }

  TokenInfo _tokenForChain({
    required TokenInfo token,
    required ChainConfig chain,
  }) {
    if (token.chainId == chain.chainId) {
      return token;
    }
    return TokenInfo(
      chainId: chain.chainId,
      contractAddress: token.contractAddress,
      symbol: token.symbol,
      name: token.name,
      decimals: token.decimals,
      logoUri: token.logoUri,
      source: token.source,
      isHidden: token.isHidden,
      requiresMemo: token.requiresMemo,
      memoLabel: token.memoLabel,
    );
  }

  List<TokenInfo> _fallbackTokens({
    required ChainConfig chain,
    required int limit,
  }) {
    return fallbackTokens
        .where(
          (token) =>
              token.chainId == chain.chainId &&
              token.contractAddress != null &&
              !token.isHidden,
        )
        .take(limit)
        .toList(growable: false);
  }
}

final class BuiltInTokenUniverseRepository implements TokenUniverseRepository {
  const BuiltInTokenUniverseRepository({this.tokens = builtInTokens});

  final List<TokenInfo> tokens;

  @override
  Future<List<TokenInfo>> getTopTokens({
    required ChainConfig chain,
    int limit = 100,
  }) async {
    if (limit <= 0) {
      return const [];
    }
    return tokens
        .where(
          (token) =>
              token.chainId == chain.chainId &&
              token.contractAddress != null &&
              !token.isHidden,
        )
        .take(limit)
        .toList(growable: false);
  }
}
