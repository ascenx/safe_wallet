import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/application/available_chains_provider.dart';
import '../../chains/data/chain_repository.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../nodes/data/rpc_credential_migration.dart';
import '../../nodes/data/rpc_node_repository.dart';
import '../../nodes/domain/rpc_node.dart';
import '../data/custom_network_data_cleaner.dart';

final customNetworkDataCleanerProvider = Provider<CustomNetworkDataCleaner>(
  (ref) => RepositoryCustomNetworkDataCleaner(
    rpcNodeRepository: ref.watch(rpcNodeRepositoryProvider),
  ),
);

final customNetworkCreationServiceProvider =
    Provider<CustomNetworkCreationService>((ref) {
      return CustomNetworkCreationService(
        chainRepository: ref.watch(chainRepositoryProvider),
        rpcNodeRepository: ref.watch(rpcNodeRepositoryProvider),
        dataCleaner: ref.watch(customNetworkDataCleanerProvider),
      );
    });

final class CustomNetworkCreationService {
  const CustomNetworkCreationService({
    required ChainRepository chainRepository,
    required RpcNodeRepository rpcNodeRepository,
    required CustomNetworkDataCleaner dataCleaner,
  }) : _chainRepository = chainRepository,
       _rpcNodeRepository = rpcNodeRepository,
       _dataCleaner = dataCleaner;

  final ChainRepository _chainRepository;
  final RpcNodeRepository _rpcNodeRepository;
  final CustomNetworkDataCleaner _dataCleaner;

  Future<ChainConfig> createEvmNetwork({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) async {
    final parsedEndpoint = parsePrivateRpcEndpoint(rpcUrl);
    final safeRpcUrl = parsedEndpoint?.safeUrl ?? rpcUrl;
    final chain = await _chainRepository.addCustomEvmChain(
      name: name,
      chainId: chainId,
      rpcUrl: safeRpcUrl,
      symbol: symbol,
      blockExplorerUrl: blockExplorerUrl,
      isTestnet: isTestnet,
    );
    RpcNode? createdNode;
    try {
      final provider = parsedEndpoint?.provider ?? RpcProvider.custom;
      createdNode = await _rpcNodeRepository.addCustomNode(
        chain: chain,
        name: '${_providerName(provider)} RPC',
        url: safeRpcUrl,
        provider: provider,
        credentialMode: parsedEndpoint?.mode ?? RpcCredentialMode.none,
        credentialParameter: parsedEndpoint?.parameter,
        credential: parsedEndpoint?.credential,
      );
      await _rpcNodeRepository.selectNode(chain: chain, nodeId: createdNode.id);
      return chain;
    } catch (error, stackTrace) {
      if (createdNode != null) {
        try {
          await _rpcNodeRepository.deleteNode(
            chain: chain,
            nodeId: createdNode.id,
          );
        } catch (_) {
          // Continue the best-effort rollback so chain metadata is not left
          // behind when node cleanup also fails.
        }
      }
      final repository = _chainRepository;
      if (repository is RemovableChainRepository) {
        try {
          await (repository as RemovableChainRepository).deleteChain(chain.id);
        } catch (_) {
          // Preserve the creation failure that triggered this rollback.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deleteNetwork(ChainConfig chain) async {
    final repository = _chainRepository;
    if (repository is! RemovableChainRepository) {
      throw StateError('Chain repository does not support network deletion');
    }

    await _dataCleaner.deleteForChain(chain);
    await (repository as RemovableChainRepository).deleteChain(chain.id);
  }
}

String _providerName(RpcProvider provider) {
  return switch (provider) {
    RpcProvider.public => 'Public',
    RpcProvider.custom => 'Custom',
    RpcProvider.helius => 'Helius',
    RpcProvider.quickNode => 'QuickNode',
    RpcProvider.alchemy => 'Alchemy',
    RpcProvider.infura => 'Infura',
    RpcProvider.tronGrid => 'TronGrid',
  };
}
