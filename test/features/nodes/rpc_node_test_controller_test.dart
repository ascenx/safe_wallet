import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/rpc_node_test_controller.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/shared/chain_clients/bitcoin_client_factory.dart';
import 'package:safe_wallet/shared/chain_clients/evm_client_factory.dart';
import 'package:safe_wallet/shared/chain_clients/solana_client_factory.dart';
import 'package:safe_wallet/shared/chain_clients/sui_client_factory.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  test('EVM node rejects a different chain id', () async {
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    final node = _node(chain: ethereum, id: 'custom-eth');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        evmClientFactoryProvider.overrideWithValue(
          _FakeEvmClientFactory(chainId: '56'),
        ),
        solanaClientFactoryProvider.overrideWithValue(
          _FakeSolanaClientFactory(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(rpcNodeTestControllerProvider.notifier)
          .testNode(chain: ethereum, node: node),
      throwsA(
        isA<RpcError>().having(
          (error) => error.code,
          'code',
          'rpc_chain_mismatch',
        ),
      ),
    );
    expect(repository.lastStatus, RpcNodeTestStatus.unavailable);
    expect(repository.selectedNodeId, isNull);
  });

  test('Solana health success marks node available', () async {
    final solana = defaultChains.firstWhere(
      (chain) => chain.id == 'solana-mainnet',
    );
    final node = _node(chain: solana, id: 'custom-solana');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        evmClientFactoryProvider.overrideWithValue(_FakeEvmClientFactory()),
        solanaClientFactoryProvider.overrideWithValue(
          _FakeSolanaClientFactory(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tested = await container
        .read(rpcNodeTestControllerProvider.notifier)
        .testNode(chain: solana, node: node);

    expect(tested.lastTestStatus, RpcNodeTestStatus.available);
    expect(repository.lastStatus, RpcNodeTestStatus.available);
  });

  test('Solana node rejects a different genesis hash', () async {
    final solana = defaultChains.firstWhere(
      (chain) => chain.id == 'solana-mainnet',
    );
    final node = _node(chain: solana, id: 'wrong-solana');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        solanaClientFactoryProvider.overrideWithValue(
          _FakeSolanaClientFactory(genesisHash: 'devnet-genesis'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(rpcNodeTestControllerProvider.notifier)
          .testNode(chain: solana, node: node),
      throwsA(
        isA<RpcError>().having(
          (error) => error.code,
          'code',
          'rpc_chain_mismatch',
        ),
      ),
    );
    expect(repository.lastStatus, RpcNodeTestStatus.unavailable);
  });

  test('Solana node accepts the full hash for the expected network', () async {
    final solana = defaultChains.firstWhere(
      (chain) => chain.id == 'solana-mainnet',
    );
    final node = _node(chain: solana, id: 'full-hash-solana');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        solanaClientFactoryProvider.overrideWithValue(
          _FakeSolanaClientFactory(
            genesisHash:
                '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tested = await container
        .read(rpcNodeTestControllerProvider.notifier)
        .testNode(chain: solana, node: node);

    expect(tested.lastTestStatus, RpcNodeTestStatus.available);
  });

  test('Sui gRPC service info stores checkpoint height and latency', () async {
    final sui = defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
    final node = _node(chain: sui, id: 'custom-sui');
    final repository = _FakeRpcNodeRepository(node);
    final suiClient = _FakeSuiClientFactory(
      serviceInfo: const SuiServiceInfo(
        chainIdentifier: suiMainnetChainIdentifier,
        network: 'mainnet',
        checkpointHeight: 305239283,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        suiClientFactoryProvider.overrideWithValue(suiClient),
      ],
    );
    addTearDown(container.dispose);

    final tested = await container
        .read(rpcNodeTestControllerProvider.notifier)
        .testNode(chain: sui, node: node);

    expect(tested.lastTestStatus, RpcNodeTestStatus.available);
    expect(tested.lastBlockHeight, 305239283);
    expect(tested.lastLatencyMs, isNonNegative);
    expect(suiClient.calls, ['https://rpc.example.com']);
  });

  test('Sui node rejects a different network identifier', () async {
    final sui = defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
    final node = _node(chain: sui, id: 'wrong-sui');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        suiClientFactoryProvider.overrideWithValue(
          _FakeSuiClientFactory(
            serviceInfo: const SuiServiceInfo(
              chainIdentifier: suiTestnetChainIdentifier,
              network: 'testnet',
              checkpointHeight: 366511444,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(rpcNodeTestControllerProvider.notifier)
          .testNode(chain: sui, node: node),
      throwsA(
        isA<RpcError>().having(
          (error) => error.code,
          'code',
          'rpc_chain_mismatch',
        ),
      ),
    );
    expect(repository.lastStatus, RpcNodeTestStatus.unavailable);
  });

  test('Bitcoin health success stores block height and latency', () async {
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );
    final node = _node(chain: bitcoin, id: 'custom-bitcoin');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        bitcoinClientFactoryProvider.overrideWithValue(
          _FakeBitcoinClientFactory(blockHeight: 840000),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tested = await container
        .read(rpcNodeTestControllerProvider.notifier)
        .testNode(chain: bitcoin, node: node);

    expect(tested.lastTestStatus, RpcNodeTestStatus.available);
    expect(tested.lastBlockHeight, 840000);
    expect(tested.lastLatencyMs, isNonNegative);
    expect(repository.lastStatus, RpcNodeTestStatus.available);
    expect(repository.lastBlockHeight, 840000);
    expect(repository.lastLatencyMs, isNonNegative);
  });

  test('EVM health success stores block height and latency', () async {
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    final node = _node(chain: ethereum, id: 'custom-eth');
    final repository = _FakeRpcNodeRepository(node);
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        evmClientFactoryProvider.overrideWithValue(
          _FakeEvmClientFactory(chainId: '1', blockHeight: 19000000),
        ),
        solanaClientFactoryProvider.overrideWithValue(
          _FakeSolanaClientFactory(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final tested = await container
        .read(rpcNodeTestControllerProvider.notifier)
        .testNode(chain: ethereum, node: node);

    expect(tested.lastTestStatus, RpcNodeTestStatus.available);
    expect(tested.lastBlockHeight, 19000000);
    expect(tested.lastLatencyMs, isNonNegative);
    expect(repository.lastBlockHeight, 19000000);
    expect(repository.lastLatencyMs, isNonNegative);
  });

  test('private EVM node is tested through its resolved endpoint', () async {
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    const node = RpcNode(
      id: 'alchemy',
      chainId: '1',
      name: 'Alchemy',
      url: 'https://eth-mainnet.g.alchemy.com/v2',
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.alchemy,
      credentialMode: RpcCredentialMode.pathSegment,
      credentialRef: 'rpc-node.alchemy',
    );
    final repository = _FakeRpcNodeRepository(node);
    final credentials = _MemoryRpcCredentialStore()
      ..values['rpc-node.alchemy'] = 'private-key';
    final evmClient = _FakeEvmClientFactory();
    final container = ProviderContainer(
      overrides: [
        rpcNodeRepositoryProvider.overrideWithValue(repository),
        rpcCredentialStoreProvider.overrideWithValue(credentials),
        evmClientFactoryProvider.overrideWithValue(evmClient),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(rpcNodeTestControllerProvider.notifier)
        .testNode(chain: ethereum, node: node);

    expect(
      evmClient.readBlockNumberCalls.single,
      'https://eth-mainnet.g.alchemy.com/v2/private-key',
    );
  });
}

RpcNode _node({required ChainConfig chain, required String id}) {
  return RpcNode(
    id: id,
    chainId: chain.chainId,
    name: 'Custom RPC',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.custom,
    isSelected: false,
    lastTestStatus: RpcNodeTestStatus.untested,
  );
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
  _FakeRpcNodeRepository(this.node);

  final RpcNode node;
  RpcNodeTestStatus? lastStatus;
  String? selectedNodeId;
  int? lastBlockHeight;
  int? lastLatencyMs;

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async => [node];

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async => node;

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    selectedNodeId = nodeId;
    return node;
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) async {
    lastStatus = status;
    lastBlockHeight = blockHeight;
    lastLatencyMs = latencyMs;
    return RpcNode(
      id: node.id,
      chainId: node.chainId,
      name: node.name,
      url: node.url,
      nodeType: node.nodeType,
      isSelected: node.isSelected,
      lastTestStatus: status,
      lastTestedAt: testedAt,
      lastBlockHeight: blockHeight,
      lastLatencyMs: latencyMs,
      note: node.note,
    );
  }
}

final class _FakeEvmClientFactory implements EvmClientFactory {
  _FakeEvmClientFactory({this.chainId = '1', this.blockHeight = 1});

  final String chainId;
  final int blockHeight;
  final readChainIdCalls = <String>[];
  final readBlockNumberCalls = <String>[];

  @override
  Future<String> readChainId(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    readChainIdCalls.add(rpcUrl);
    return chainId;
  }

  @override
  Future<int> readBlockNumber(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    readBlockNumberCalls.add(rpcUrl);
    return blockHeight;
  }
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

final class _FakeSolanaClientFactory implements SolanaClientFactory {
  _FakeSolanaClientFactory({
    this.genesisHash = '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp',
  });

  final String genesisHash;

  @override
  Future<void> checkHealth(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {}

  @override
  Future<String> readGenesisHash(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async => genesisHash;
}

final class _FakeBitcoinClientFactory implements BitcoinClientFactory {
  const _FakeBitcoinClientFactory({required this.blockHeight});

  final int blockHeight;

  @override
  Future<int> readBlockHeight(
    String apiBaseUrl, {
    Map<String, String> headers = const {},
  }) async => blockHeight;
}

final class _FakeSuiClientFactory implements SuiClientFactory {
  _FakeSuiClientFactory({required this.serviceInfo});

  final SuiServiceInfo serviceInfo;
  final calls = <String>[];

  @override
  Future<SuiServiceInfo> getServiceInfo(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    calls.add(rpcUrl);
    return serviceInfo;
  }
}
