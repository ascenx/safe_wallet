import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/chain_clients/bitcoin_client_factory.dart';
import '../../../shared/chain_clients/evm_client_factory.dart';
import '../../../shared/chain_clients/solana_client_factory.dart';
import '../../../shared/chain_clients/sui_client_factory.dart';
import '../../../shared/chain_clients/tron_client_factory.dart';
import '../../../shared/errors/rpc_error.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/rpc_node.dart';
import 'selected_rpc_node_provider.dart';

final evmClientFactoryProvider = Provider<EvmClientFactory>((ref) {
  final factory = HttpEvmClientFactory();
  ref.onDispose(factory.close);
  return factory;
});

final solanaClientFactoryProvider = Provider<SolanaClientFactory>((ref) {
  final factory = HttpSolanaClientFactory();
  ref.onDispose(factory.close);
  return factory;
});

final bitcoinClientFactoryProvider = Provider<BitcoinClientFactory>((ref) {
  final factory = HttpBitcoinClientFactory();
  ref.onDispose(factory.close);
  return factory;
});

final tronClientFactoryProvider = Provider<TronClientFactory>((ref) {
  final factory = HttpTronClientFactory();
  ref.onDispose(factory.close);
  return factory;
});

final suiClientFactoryProvider = Provider<SuiClientFactory>((ref) {
  return const GrpcSuiClientFactory();
});

final rpcNodeTestControllerProvider =
    AsyncNotifierProvider<RpcNodeTestController, RpcNode?>(
      RpcNodeTestController.new,
    );

final class RpcNodeTestController extends AsyncNotifier<RpcNode?> {
  @override
  RpcNode? build() {
    return null;
  }

  Future<RpcNode> testNode({
    required ChainConfig chain,
    required RpcNode node,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(rpcNodeRepositoryProvider);
    final testedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();

    try {
      final endpoint = await ref
          .read(rpcEndpointResolverProvider)
          .resolve(node);
      final endpointUrl = endpoint.url;
      int? blockHeight;
      switch (chain.chainType) {
        case ChainType.evm:
          final evmClient = ref.read(evmClientFactoryProvider);
          final actualChainId = await evmClient.readChainId(
            endpointUrl,
            headers: endpoint.headers,
          );
          if (actualChainId != chain.chainId) {
            throw RpcError.chainMismatch(
              expectedChainId: chain.chainId,
              actualChainId: actualChainId,
            );
          }
          blockHeight = await evmClient.readBlockNumber(
            endpointUrl,
            headers: endpoint.headers,
          );
        case ChainType.bitcoin:
          blockHeight = await ref
              .read(bitcoinClientFactoryProvider)
              .readBlockHeight(endpointUrl);
        case ChainType.tron:
          blockHeight = await ref
              .read(tronClientFactoryProvider)
              .readBlockHeight(endpointUrl, headers: endpoint.headers);
        case ChainType.solana:
          final solanaClient = ref.read(solanaClientFactoryProvider);
          await solanaClient.checkHealth(
            endpointUrl,
            headers: endpoint.headers,
          );
          final expectedGenesisHashPrefix = expectedSolanaGenesisHashPrefix(
            chain.chainId,
          );
          if (expectedGenesisHashPrefix != null) {
            final actualGenesisHash = await solanaClient.readGenesisHash(
              endpointUrl,
              headers: endpoint.headers,
            );
            if (!matchesExpectedSolanaGenesisHash(
              chain.chainId,
              actualGenesisHash,
            )) {
              throw RpcError.chainMismatch(
                expectedChainId: expectedGenesisHashPrefix,
                actualChainId: actualGenesisHash,
              );
            }
          }
        case ChainType.sui:
          final info = await ref
              .read(suiClientFactoryProvider)
              .getServiceInfo(endpointUrl, headers: endpoint.headers);
          final expectedIdentifier = expectedSuiChainIdentifier(chain.chainId);
          final expectedNetwork = chain.chainId.split(':').last;
          final networkMatches =
              info.network == expectedNetwork ||
              (expectedNetwork == 'devnet' && info.network == 'unknown');
          if ((expectedIdentifier != null &&
                  info.chainIdentifier != expectedIdentifier) ||
              !networkMatches) {
            throw RpcError.chainMismatch(
              expectedChainId: expectedIdentifier ?? expectedNetwork,
              actualChainId: info.chainIdentifier,
            );
          }
          blockHeight = info.checkpointHeight;
      }
      stopwatch.stop();

      final available = await repository.updateTestStatus(
        nodeId: node.id,
        status: RpcNodeTestStatus.available,
        testedAt: testedAt,
        blockHeight: blockHeight,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
      ref.invalidate(rpcNodesForChainProvider(chain));
      ref.invalidate(selectedRpcNodeProvider(chain));
      state = AsyncData(available);
      return available;
    } on RpcError catch (error, stackTrace) {
      stopwatch.stop();
      if (state.value?.lastTestStatus != RpcNodeTestStatus.unavailable) {
        final unavailable = await repository.updateTestStatus(
          nodeId: node.id,
          status: RpcNodeTestStatus.unavailable,
          testedAt: testedAt,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
        ref.invalidate(rpcNodesForChainProvider(chain));
        ref.invalidate(selectedRpcNodeProvider(chain));
        state = AsyncData(unavailable);
      }
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      stopwatch.stop();
      final unavailable = await repository.updateTestStatus(
        nodeId: node.id,
        status: RpcNodeTestStatus.unavailable,
        testedAt: testedAt,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
      ref.invalidate(rpcNodesForChainProvider(chain));
      ref.invalidate(selectedRpcNodeProvider(chain));
      state = AsyncData(unavailable);
      Error.throwWithStackTrace(
        RpcError.unavailable(debugMessage: error.toString()),
        stackTrace,
      );
    }
  }
}
