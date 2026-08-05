import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_status_refresh_controller.dart';
import 'package:safe_wallet/features/transfer/data/transaction_status_lookup_service.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';

void main() {
  test(
    'refresh updates submitted current-chain transaction statuses',
    () async {
      final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final repository = _RecordingTransactionHistoryRepository([
        _record(id: 'tx-1', chain: chain, status: TransactionStatus.submitted),
        _record(id: 'tx-2', chain: chain, status: TransactionStatus.success),
      ]);
      final lookupService = _FakeTransactionStatusLookupService({
        '0xhash-tx-1': const TransactionStatusUpdate(
          status: TransactionStatus.success,
        ),
      });
      final container = _container(
        chain: chain,
        repository: repository,
        lookupService: lookupService,
      );

      await container
          .read(transactionStatusRefreshControllerProvider.notifier)
          .refreshCurrentChain();

      final records = await repository.list(chainId: chain.chainId);
      expect(
        records.firstWhere((record) => record.id == 'tx-1').status,
        TransactionStatus.success,
      );
      expect(lookupService.calls, ['0xhash-tx-1']);
    },
  );

  test('refresh uses the selected Bitcoin chain and node', () async {
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    final repository = _RecordingTransactionHistoryRepository([
      _record(
        id: 'btc-tx',
        chain: bitcoin,
        status: TransactionStatus.submitted,
      ),
      _record(
        id: 'evm-tx',
        chain: ethereum,
        status: TransactionStatus.submitted,
      ),
    ]);
    final lookupService = _FakeTransactionStatusLookupService({
      '0xhash-btc-tx': const TransactionStatusUpdate(
        status: TransactionStatus.success,
      ),
    });
    final container = _container(
      chain: bitcoin,
      repository: repository,
      lookupService: lookupService,
    );

    await container
        .read(transactionStatusRefreshControllerProvider.notifier)
        .refreshCurrentChain();

    final records = await repository.list();
    expect(
      records.firstWhere((record) => record.id == 'btc-tx').status,
      TransactionStatus.success,
    );
    expect(
      records.firstWhere((record) => record.id == 'evm-tx').status,
      TransactionStatus.submitted,
    );
    expect(lookupService.calls, ['0xhash-btc-tx']);
    expect(lookupService.lookupChains.single.id, 'bitcoin-mainnet');
    expect(lookupService.lookupNodes.single.chainId, 'bitcoin-mainnet');
  });

  test('one failed status lookup does not block later records', () async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _RecordingTransactionHistoryRepository([
      _record(id: 'bad', chain: chain, status: TransactionStatus.submitted),
      _record(id: 'good', chain: chain, status: TransactionStatus.submitted),
    ]);
    final lookupService = _SelectiveFailingTransactionStatusLookupService();
    final container = _container(
      chain: chain,
      repository: repository,
      lookupService: lookupService,
    );

    await container
        .read(transactionStatusRefreshControllerProvider.notifier)
        .refreshCurrentChain();

    final records = await repository.list(chainId: chain.chainId);
    expect(
      records.firstWhere((record) => record.id == 'bad').status,
      TransactionStatus.submitted,
    );
    expect(
      records.firstWhere((record) => record.id == 'good').status,
      TransactionStatus.success,
    );
  });

  test(
    'refreshes pending records with at most four concurrent lookups',
    () async {
      final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      final repository = _RecordingTransactionHistoryRepository([
        for (var index = 0; index < 8; index += 1)
          _record(
            id: 'tx-$index',
            chain: chain,
            status: TransactionStatus.submitted,
          ),
      ]);
      final lookupService =
          _ConcurrencyTrackingTransactionStatusLookupService();
      final container = _container(
        chain: chain,
        repository: repository,
        lookupService: lookupService,
      );

      await container
          .read(transactionStatusRefreshControllerProvider.notifier)
          .refreshCurrentChain();

      expect(lookupService.maximumActive, 4);
      expect(lookupService.calls, 8);
    },
  );
}

ProviderContainer _container({
  required ChainConfig chain,
  required TransactionHistoryRepository repository,
  required TransactionStatusLookupService lookupService,
}) {
  final container = ProviderContainer(
    overrides: [
      chainRepositoryProvider.overrideWithValue(
        _FakeChainRepository(selectedChain: chain),
      ),
      rpcNodeRepositoryProvider.overrideWithValue(_FakeRpcNodeRepository()),
      transactionHistoryRepositoryProvider.overrideWithValue(repository),
      transactionStatusLookupServiceProvider.overrideWithValue(lookupService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionRecord _record({
  required String id,
  required ChainConfig chain,
  required TransactionStatus status,
}) {
  return TransactionRecord(
    id: id,
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: chain.symbol,
    direction: TransactionDirection.outgoing,
    amount: '0.1',
    status: status,
    transactionHash: '0xhash-$id',
    createdAt: DateTime.utc(2026, 6, 6),
    fromAddress: '0xsender',
    toAddress: '0xreceiver',
  );
}

final class _FakeChainRepository implements ChainRepository {
  const _FakeChainRepository({required this.selectedChain});

  final ChainConfig selectedChain;

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async => selectedChain;

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChainConfig> selectChain(String chainId) {
    throw UnimplementedError();
  }
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async => [
    _node(chain),
  ];

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async => _node(chain);

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
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }
}

RpcNode _node(ChainConfig chain) {
  return RpcNode(
    id: '${chain.id}-node',
    chainId: chain.chainId,
    name: 'RPC',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  );
}

final class _RecordingTransactionHistoryRepository
    implements TransactionHistoryRepository {
  _RecordingTransactionHistoryRepository(List<TransactionRecord> records)
    : records = List.of(records);

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return records
        .where((record) => chainId == null || record.chainId == chainId)
        .toList(growable: false);
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return (await list(chainId: chainId)).take(limit).toList(growable: false);
  }

  @override
  Future<void> save(TransactionRecord record) async {
    records.add(record);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {
    final index = records.indexWhere((record) => record.id == id);
    if (index == -1) {
      return;
    }
    final previous = records[index];
    records[index] = TransactionRecord(
      id: previous.id,
      chainId: previous.chainId,
      chainType: previous.chainType,
      assetSymbol: previous.assetSymbol,
      direction: previous.direction,
      amount: previous.amount,
      status: status,
      transactionHash: previous.transactionHash,
      createdAt: previous.createdAt,
      fromAddress: previous.fromAddress,
      toAddress: previous.toAddress,
      failureReason: failureReason,
    );
  }
}

final class _FakeTransactionStatusLookupService
    implements TransactionStatusLookupService {
  _FakeTransactionStatusLookupService(this.results);

  final Map<String, TransactionStatusUpdate> results;
  final calls = <String>[];
  final lookupChains = <ChainConfig>[];
  final lookupNodes = <RpcNode>[];

  @override
  Future<TransactionStatusUpdate?> lookup({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    lookupChains.add(chain);
    lookupNodes.add(rpcNode);
    calls.add(record.transactionHash);
    return results[record.transactionHash];
  }
}

final class _SelectiveFailingTransactionStatusLookupService
    implements TransactionStatusLookupService {
  @override
  Future<TransactionStatusUpdate?> lookup({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    if (record.id == 'bad') {
      throw StateError('temporary RPC failure');
    }
    return const TransactionStatusUpdate(status: TransactionStatus.success);
  }
}

final class _ConcurrencyTrackingTransactionStatusLookupService
    implements TransactionStatusLookupService {
  int active = 0;
  int maximumActive = 0;
  int calls = 0;

  @override
  Future<TransactionStatusUpdate?> lookup({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    calls += 1;
    active += 1;
    if (active > maximumActive) {
      maximumActive = active;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active -= 1;
    return null;
  }
}
