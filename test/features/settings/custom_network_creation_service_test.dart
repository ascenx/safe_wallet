import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/application/custom_network_creation_service.dart';
import 'package:safe_wallet/features/settings/data/custom_network_data_cleaner.dart';

void main() {
  test(
    'private initial RPC is split between chain metadata and node credential',
    () async {
      final chains = _RecordingChainRepository();
      final nodes = _RecordingNodeRepository();
      final service = CustomNetworkCreationService(
        chainRepository: chains,
        rpcNodeRepository: nodes,
        dataCleaner: const NoopCustomNetworkDataCleaner(),
      );

      final chain = await service.createEvmNetwork(
        name: 'Private EVM',
        chainId: '9999',
        rpcUrl: 'https://quiet-name.quiknode.pro/private-token/',
        symbol: 'PRV',
      );

      expect(chain.rpcUrls, isEmpty);
      expect(chains.lastRpcUrl, 'https://quiet-name.quiknode.pro/');
      expect(nodes.lastUrl, 'https://quiet-name.quiknode.pro/');
      expect(nodes.lastProvider, RpcProvider.quickNode);
      expect(nodes.lastCredentialMode, RpcCredentialMode.fullEndpoint);
      expect(
        nodes.lastCredential,
        'https://quiet-name.quiknode.pro/private-token/',
      );
      expect(nodes.selectedNodeId, 'private-node');
    },
  );

  test('public initial RPC is stored as the selected custom node', () async {
    final chains = _RecordingChainRepository();
    final nodes = _RecordingNodeRepository();
    final service = CustomNetworkCreationService(
      chainRepository: chains,
      rpcNodeRepository: nodes,
      dataCleaner: const NoopCustomNetworkDataCleaner(),
    );

    final chain = await service.createEvmNetwork(
      name: 'Local Testnet',
      chainId: '31337',
      rpcUrl: 'http://127.0.0.1:8545',
      symbol: 'ETH',
    );

    expect(chain.rpcUrls, isEmpty);
    expect(nodes.lastUrl, 'http://127.0.0.1:8545');
    expect(nodes.lastProvider, RpcProvider.custom);
    expect(nodes.lastCredentialMode, RpcCredentialMode.none);
    expect(nodes.lastCredential, isNull);
    expect(nodes.selectedNodeId, 'private-node');
  });

  test('selection failure rolls back the created node and chain', () async {
    final selectionError = StateError('selection failed');
    final chains = _RecordingChainRepository();
    final nodes = _RecordingNodeRepository(selectError: selectionError);
    final service = CustomNetworkCreationService(
      chainRepository: chains,
      rpcNodeRepository: nodes,
      dataCleaner: const NoopCustomNetworkDataCleaner(),
    );

    await expectLater(
      service.createEvmNetwork(
        name: 'Private EVM',
        chainId: '9999',
        rpcUrl: 'https://quiet-name.quiknode.pro/private-token/',
        symbol: 'PRV',
      ),
      throwsA(same(selectionError)),
    );

    expect(nodes.deletedNodeIds, ['private-node']);
    expect(chains.deletedChainIds, ['custom-evm-9999']);
  });

  test(
    'network deletion cleans chain-scoped data before chain metadata',
    () async {
      final events = <String>[];
      final chains = _RecordingChainRepository(onDelete: events.add);
      final nodes = _RecordingNodeRepository();
      final cleaner = _RecordingDataCleaner(events);
      final service = CustomNetworkCreationService(
        chainRepository: chains,
        rpcNodeRepository: nodes,
        dataCleaner: cleaner,
      );
      const chain = ChainConfig(
        id: 'custom-evm-31337',
        chainType: ChainType.evm,
        name: 'Local Testnet',
        chainId: '31337',
        symbol: 'ETH',
        rpcUrls: [],
        blockExplorerUrl: null,
        isTestnet: true,
      );

      await service.deleteNetwork(chain);

      expect(events, ['clean:31337', 'delete:custom-evm-31337']);
      expect(nodes.deletedNodeIds, isEmpty);
    },
  );
}

final class _RecordingChainRepository
    implements ChainRepository, RemovableChainRepository {
  _RecordingChainRepository({this.onDelete});

  final void Function(String event)? onDelete;
  String? lastRpcUrl;
  final deletedChainIds = <String>[];

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) async {
    lastRpcUrl = rpcUrl;
    return ChainConfig(
      id: 'custom-evm-$chainId',
      chainType: ChainType.evm,
      name: name,
      chainId: chainId,
      symbol: symbol,
      rpcUrls: const [],
      blockExplorerUrl: blockExplorerUrl,
      isTestnet: isTestnet,
    );
  }

  @override
  Future<List<ChainConfig>> getChains() => throw UnimplementedError();

  @override
  Future<ChainConfig> getSelectedChain() => throw UnimplementedError();

  @override
  Future<ChainConfig> selectChain(String chainId) => throw UnimplementedError();

  @override
  Future<void> deleteChain(String chainId) async {
    onDelete?.call('delete:$chainId');
    deletedChainIds.add(chainId);
  }
}

final class _RecordingDataCleaner implements CustomNetworkDataCleaner {
  _RecordingDataCleaner(this.events);

  final List<String> events;

  @override
  Future<void> deleteForChain(ChainConfig chain) async {
    events.add('clean:${chain.chainId}');
  }
}

final class _RecordingNodeRepository implements RpcNodeRepository {
  _RecordingNodeRepository({this.selectError});

  final Object? selectError;
  String? lastUrl;
  RpcProvider? lastProvider;
  RpcCredentialMode? lastCredentialMode;
  String? lastCredential;
  String? selectedNodeId;
  final deletedNodeIds = <String>[];

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
  }) async {
    lastUrl = url;
    lastProvider = provider;
    lastCredentialMode = credentialMode;
    lastCredential = credential;
    return RpcNode(
      id: 'private-node',
      chainId: chain.chainId,
      name: name,
      url: url,
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: provider,
      credentialMode: credentialMode,
      credentialParameter: credentialParameter,
      credentialRef: 'rpc-node.private-node',
    );
  }

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    final error = selectError;
    if (error != null) {
      throw error;
    }
    selectedNodeId = nodeId;
    return (await getNodesForChain(chain)).first;
  }

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async => [
    RpcNode(
      id: selectedNodeId ?? 'private-node',
      chainId: chain.chainId,
      name: 'Private RPC',
      url: lastUrl!,
      nodeType: RpcNodeType.custom,
      isSelected: selectedNodeId != null,
      lastTestStatus: RpcNodeTestStatus.untested,
    ),
  ];

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async =>
      (await getNodesForChain(chain)).first;

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    deletedNodeIds.add(nodeId);
  }

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
  }) => throw UnimplementedError();

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) => throw UnimplementedError();
}
