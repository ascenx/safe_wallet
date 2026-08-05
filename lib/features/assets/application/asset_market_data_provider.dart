import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/domain/chain_config.dart';
import '../data/asset_market_data_repository.dart';

final assetMarketDataRepositoryProvider = Provider<AssetMarketDataRepository>((
  ref,
) {
  final repository = DexScreenerAssetMarketDataRepository();
  ref.onDispose(repository.close);
  return repository;
});

final assetMarketDataProvider =
    FutureProvider.family<AssetMarketData?, AssetMarketDataRequest>((
  ref,
  request,
) {
  return ref.watch(assetMarketDataRepositoryProvider).getMarketData(
        chain: request.chain,
        contractAddress: request.contractAddress,
      );
});

final class AssetMarketDataRequest {
  const AssetMarketDataRequest({
    required this.chain,
    required this.contractAddress,
  });

  final ChainConfig chain;
  final String contractAddress;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AssetMarketDataRequest &&
            other.chain == chain &&
            other.contractAddress == contractAddress;
  }

  @override
  int get hashCode => Object.hash(chain, contractAddress);
}
