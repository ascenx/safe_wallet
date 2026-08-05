import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/domain/chain_config.dart';
import '../data/evm_token_discovery_service.dart';
import 'token_repository_provider.dart';

final evmTokenDiscoveryClientProvider = Provider<EvmTokenDiscoveryClient>((
  ref,
) {
  return const Web3EvmTokenDiscoveryClient();
});

final evmTokenDiscoveryServiceProvider = Provider<EvmTokenDiscoveryService>((
  ref,
) {
  return EvmTokenDiscoveryService(
    client: ref.watch(evmTokenDiscoveryClientProvider),
  );
});

final tokenDiscoveryControllerProvider =
    AsyncNotifierProvider<TokenDiscoveryController, EvmTokenDiscoveryResult?>(
      TokenDiscoveryController.new,
    );

final class TokenDiscoveryController
    extends AsyncNotifier<EvmTokenDiscoveryResult?> {
  @override
  EvmTokenDiscoveryResult? build() {
    return null;
  }

  Future<EvmTokenDiscoveryResult> discover({
    required ChainConfig chain,
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> rpcHeaders = const {},
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(tokenRepositoryProvider);
    final lastScannedBlock = await repository.getLastScannedBlock(
      chainId: chain.chainId,
      walletAddress: walletAddress,
    );
    final result = await ref
        .read(evmTokenDiscoveryServiceProvider)
        .discover(
          chain: chain,
          rpcUrl: rpcUrl,
          walletAddress: walletAddress,
          fromBlock: lastScannedBlock == null ? 0 : lastScannedBlock + 1,
          rpcHeaders: rpcHeaders,
        );
    for (final token in result.tokens) {
      await repository.saveToken(token);
    }
    final scannedBlock = result.lastScannedBlock;
    if (scannedBlock != null) {
      await repository.setLastScannedBlock(
        chainId: chain.chainId,
        walletAddress: walletAddress,
        blockNumber: scannedBlock,
      );
    }
    ref.invalidate(tokensForChainProvider(chain.chainId));
    ref.invalidate(allTokensForChainProvider(chain.chainId));
    state = AsyncData(result);
    return result;
  }
}
