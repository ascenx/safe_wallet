import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sui_dart/types/common.dart' show normalizeStructTagString;

import '../../chains/domain/chain_config.dart';
import '../data/sui_asset_service.dart';
import '../data/tron_asset_service.dart';
import '../domain/token_info.dart';
import 'token_discovery_controller.dart';
import 'token_repository_provider.dart';

final tronAssetServiceProvider = Provider<TronAssetService>((ref) {
  return HttpTronAssetService();
});

final suiAssetServiceProvider = Provider<SuiAssetService>((ref) {
  return GrpcSuiAssetService();
});

final manualTokenAddControllerProvider =
    AsyncNotifierProvider<ManualTokenAddController, void>(
  ManualTokenAddController.new,
);

final class ManualTokenMetadataRequired implements Exception {
  const ManualTokenMetadataRequired();

  @override
  String toString() => 'ManualTokenMetadataRequired';
}

final class ManualTokenAddController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<TokenInfo> addToken({
    required ChainConfig chain,
    required String rpcUrl,
    required String walletAddress,
    required String contractAddress,
    Map<String, String> rpcHeaders = const {},
    String? symbol,
    String? name,
    int? decimals,
  }) async {
    state = const AsyncLoading();
    try {
      final normalizedContract = _normalizeContractAddress(
        chain: chain,
        contractAddress: contractAddress,
      );
      final metadata = switch (chain.chainType) {
        ChainType.bitcoin => throw UnsupportedError(
            'Bitcoin does not support contract tokens',
          ),
        ChainType.tron => await _tronMetadata(
            rpcUrl: rpcUrl,
            walletAddress: walletAddress,
            contractAddress: normalizedContract,
            symbol: symbol,
            name: name,
            decimals: decimals,
            rpcHeaders: rpcHeaders,
          ),
        ChainType.evm => await _evmMetadata(
            rpcUrl: rpcUrl,
            walletAddress: walletAddress,
            contractAddress: normalizedContract,
            symbol: symbol,
            name: name,
            decimals: decimals,
          ),
        ChainType.solana => _manualMetadata(
            symbol: symbol,
            name: name,
            decimals: decimals,
          ),
        ChainType.sui => await _suiMetadata(
            rpcUrl: rpcUrl,
            walletAddress: walletAddress,
            coinType: normalizedContract,
            rpcHeaders: rpcHeaders,
          ),
      };

      final token = TokenInfo(
        chainId: chain.chainId,
        contractAddress: normalizedContract,
        symbol: metadata.symbol.toUpperCase(),
        name: metadata.name,
        decimals: metadata.decimals,
        source: TokenSource.userAdded,
        isHidden: false,
      );
      final saved = await ref.read(tokenRepositoryProvider).saveToken(token);
      ref.invalidate(tokensForChainProvider(chain.chainId));
      ref.invalidate(allTokensForChainProvider(chain.chainId));
      state = const AsyncData(null);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  String _normalizeContractAddress({
    required ChainConfig chain,
    required String contractAddress,
  }) {
    final trimmed = contractAddress.trim();
    return switch (chain.chainType) {
      ChainType.evm => trimmed.toLowerCase(),
      ChainType.sui => normalizeStructTagString(trimmed),
      _ => trimmed,
    };
  }

  Future<_TokenMetadata> _evmMetadata({
    required String rpcUrl,
    required String walletAddress,
    required String contractAddress,
    required String? symbol,
    required String? name,
    required int? decimals,
  }) async {
    final client = ref.read(evmTokenDiscoveryClientProvider);
    await client.readBalance(
      rpcUrl: rpcUrl,
      contractAddress: contractAddress,
      walletAddress: walletAddress,
    );
    try {
      final metadata = await client.readMetadata(
        rpcUrl: rpcUrl,
        contractAddress: contractAddress,
      );
      return _TokenMetadata(
        symbol: metadata.symbol,
        name: metadata.name,
        decimals: metadata.decimals,
      );
    } catch (_) {
      return _manualMetadata(
        symbol: symbol,
        name: name,
        decimals: decimals,
      );
    }
  }

  Future<_TokenMetadata> _tronMetadata({
    required String rpcUrl,
    required String walletAddress,
    required String contractAddress,
    required String? symbol,
    required String? name,
    required int? decimals,
    required Map<String, String> rpcHeaders,
  }) async {
    await ref.read(tronAssetServiceProvider).getTrc20Balances(
          apiBaseUrl: rpcUrl,
          contractAddresses: [contractAddress],
          walletAddress: walletAddress,
          headers: rpcHeaders,
        );
    return _manualMetadata(
      symbol: symbol,
      name: name,
      decimals: decimals,
    );
  }

  Future<_TokenMetadata> _suiMetadata({
    required String rpcUrl,
    required String walletAddress,
    required String coinType,
    required Map<String, String> rpcHeaders,
  }) async {
    final service = ref.read(suiAssetServiceProvider);
    await service.getBalance(
      rpcUrl: rpcUrl,
      owner: walletAddress,
      coinType: coinType,
      headers: rpcHeaders,
    );
    final metadata = await service.getCoinMetadata(
      rpcUrl: rpcUrl,
      coinType: coinType,
      headers: rpcHeaders,
    );
    if (metadata == null) {
      throw const ManualTokenMetadataRequired();
    }
    return _TokenMetadata(
      symbol: metadata.symbol,
      name: metadata.name,
      decimals: metadata.decimals,
    );
  }

  _TokenMetadata _manualMetadata({
    required String? symbol,
    required String? name,
    required int? decimals,
  }) {
    final trimmedSymbol = symbol?.trim();
    final trimmedName = name?.trim();
    final tokenDecimals = decimals;
    if (trimmedSymbol == null ||
        trimmedSymbol.isEmpty ||
        trimmedName == null ||
        trimmedName.isEmpty ||
        tokenDecimals == null ||
        tokenDecimals < 0) {
      throw const ManualTokenMetadataRequired();
    }
    return _TokenMetadata(
      symbol: trimmedSymbol,
      name: trimmedName,
      decimals: tokenDecimals,
    );
  }
}

final class _TokenMetadata {
  const _TokenMetadata({
    required this.symbol,
    required this.name,
    required this.decimals,
  });

  final String symbol;
  final String name;
  final int decimals;
}
