import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';

void main() {
  test('resolved node keeps display URL safe and exposes runtime endpoint',
      () async {
    final chain =
        defaultChains.firstWhere((item) => item.id == 'solana-mainnet');
    const node = RpcNode(
      id: 'helius',
      chainId: 'mainnet-beta',
      name: 'Helius',
      url: 'https://mainnet.helius-rpc.com/',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      provider: RpcProvider.helius,
      credentialMode: RpcCredentialMode.queryParameter,
      credentialParameter: 'api-key',
      credentialRef: 'rpc-node.helius',
    );
    final credentials = _MemoryRpcCredentialStore()
      ..values['rpc-node.helius'] = 'secret-key';
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider
            .overrideWithValue(_SingleNodeRepository(node)),
        rpcCredentialStoreProvider.overrideWithValue(credentials),
      ],
    );
    addTearDown(container.dispose);

    final safeNode =
        await container.read(selectedRpcNodeProvider(chain).future);
    final resolvedNode =
        await container.read(selectedResolvedRpcNodeProvider(chain).future);

    expect(safeNode.url, isNot(contains('secret-key')));
    expect(resolvedNode.url, isNot(contains('secret-key')));
    expect(
      resolvedNode.endpointUrl,
      'https://mainnet.helius-rpc.com/?api-key=secret-key',
    );
  });
}

final class _MemoryRpcCredentialStore implements RpcCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String credentialRef) async =>
      values.remove(credentialRef);

  @override
  Future<String?> read(String credentialRef) async => values[credentialRef];

  @override
  Future<void> write(String credentialRef, String credential) async {
    values[credentialRef] = credential;
  }
}

final class _SingleNodeRepository implements RpcNodeRepository {
  const _SingleNodeRepository(this.node);

  final RpcNode node;

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async => [node];

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async => node;

  @override
  Future<RpcNode> addCustomNode({
    required ChainConfig chain,
    required String name,
    required String url,
    String? note,
    RpcProvider provider = RpcProvider.custom,
    RpcCredentialMode credentialMode = RpcCredentialMode.none,
    String? credentialParameter,
    String? credential,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) =>
      throw UnimplementedError();

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) =>
      throw UnimplementedError();

  @override
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
  }) =>
      throw UnimplementedError();

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) =>
      throw UnimplementedError();
}
