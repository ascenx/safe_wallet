import '../../chains/domain/chain_config.dart';
import '../domain/rpc_node.dart';

abstract interface class RpcNodeRepository {
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain);

  Future<RpcNode> getSelectedNode(ChainConfig chain);

  Future<RpcNode> addCustomNode({
    required ChainConfig chain,
    required String name,
    required String url,
    String? note,
    RpcProvider provider = RpcProvider.custom,
    RpcCredentialMode credentialMode = RpcCredentialMode.none,
    String? credentialParameter,
    String? credential,
  });

  Future<RpcNode> updateCustomNode({
    required ChainConfig chain,
    required String nodeId,
    required String name,
    required String url,
    String? note,
    RpcProvider? provider,
    RpcCredentialMode? credentialMode,
    String? credentialParameter,
    String? credential,
  });

  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  });

  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  });

  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  });
}
