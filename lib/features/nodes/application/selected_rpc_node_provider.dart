import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/domain/chain_config.dart';
import '../data/rpc_node_repository.dart';
import '../data/rpc_credential_store.dart';
import '../domain/rpc_endpoint.dart';
import '../domain/rpc_node.dart';

final rpcCredentialStoreProvider = Provider<RpcCredentialStore>((ref) {
  return FlutterSecureRpcCredentialStore();
});

final rpcEndpointResolverProvider = Provider<RpcEndpointResolver>((ref) {
  return RpcEndpointResolver(
    credentialStore: ref.watch(rpcCredentialStoreProvider),
  );
});

final rpcNodeRepositoryProvider = Provider<RpcNodeRepository>((ref) {
  throw UnimplementedError('rpcNodeRepositoryProvider must be overridden');
});

final rpcNodesForChainProvider =
    FutureProvider.family<List<RpcNode>, ChainConfig>((ref, chain) {
  return ref.watch(rpcNodeRepositoryProvider).getNodesForChain(chain);
});

final selectedRpcNodeProvider =
    FutureProvider.family<RpcNode, ChainConfig>((ref, chain) {
  return ref.watch(rpcNodeRepositoryProvider).getSelectedNode(chain);
});

final selectedResolvedRpcNodeProvider =
    FutureProvider.family<RpcNode, ChainConfig>((ref, chain) async {
  final node = await ref.watch(selectedRpcNodeProvider(chain).future);
  final endpoint = await ref.watch(rpcEndpointResolverProvider).resolve(node);
  return RpcNode(
    id: node.id,
    chainId: node.chainId,
    name: node.name,
    url: node.url,
    nodeType: node.nodeType,
    isSelected: node.isSelected,
    lastTestStatus: node.lastTestStatus,
    lastTestedAt: node.lastTestedAt,
    lastBlockHeight: node.lastBlockHeight,
    lastLatencyMs: node.lastLatencyMs,
    note: node.note,
    provider: node.provider,
    credentialMode: node.credentialMode,
    credentialParameter: node.credentialParameter,
    credentialRef: node.credentialRef,
    resolvedUrl: endpoint.url,
    resolvedHeaders: endpoint.headers,
  );
});
