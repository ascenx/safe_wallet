import 'dart:io';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_status_refresh_controller.dart';
import 'package:safe_wallet/features/transfer/data/hive_transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/data/transaction_status_lookup_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_history_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/network/external_url_launcher.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';
import 'package:safe_wallet/shared/storage/json_codec.dart';

void main() {
  group('HiveTransactionHistoryRepository', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_transactions_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('saves local transaction records after broadcast', () async {
      final repository = await _createRepository(tempDirectory);
      final record = _record(id: 'tx-1', hash: '0xabc');

      await repository.save(record);

      final records = await repository.list();

      expect(records, [record]);
      expect(records.single.fromAddress, '0xsender');
      expect(records.single.toAddress, '0xreceiver');
    });

    test('recent returns newest four records', () async {
      final repository = await _createRepository(tempDirectory);
      for (var index = 0; index < 5; index += 1) {
        await repository.save(
          _record(
            id: 'tx-$index',
            hash: '0x$index',
            createdAt: DateTime.utc(2026, 6, 6, 0, index),
          ),
        );
      }

      final recent = await repository.recent(limit: 4);

      expect(recent.map((record) => record.id), [
        'tx-4',
        'tx-3',
        'tx-2',
        'tx-1',
      ]);
    });

    test('wallet-scoped history excludes records from other wallets', () async {
      final repository = await _createRepository(tempDirectory);
      await repository.save(_record(id: 'wallet-1-tx', walletId: 'wallet-1'));
      await repository.save(_record(id: 'wallet-2-tx', walletId: 'wallet-2'));

      final scoped = repository as WalletScopedTransactionHistoryRepository;
      final records = await scoped.listForWallet(walletId: 'wallet-1');

      expect(records.map((record) => record.id), ['wallet-1-tx']);
    });

    test('updates an existing transaction status', () async {
      final repository = await _createRepository(tempDirectory);
      final record = _record(id: 'tx-1', hash: '0xabc');
      await repository.save(record);

      await repository.updateStatus(
        id: record.id,
        status: TransactionStatus.success,
      );

      final records = await repository.list();
      expect(records.single.status, TransactionStatus.success);
      expect(records.single.transactionHash, '0xabc');
    });

    test('persists staking operation and resource metadata', () async {
      final repository = await _createRepository(tempDirectory);
      final record = TransactionRecord(
        id: 'stake-1',
        chainId: 'tron-mainnet',
        chainType: ChainType.tron,
        assetSymbol: 'TRX',
        direction: TransactionDirection.outgoing,
        amount: '5',
        status: TransactionStatus.submitted,
        transactionHash: 'tron-tx-id',
        createdAt: DateTime.utc(2026, 8, 2),
        operation: TransactionOperation.stake,
        resource: 'ENERGY',
        fromAddress: 'TFrom',
      );

      await repository.save(record);
      await repository.updateStatus(
        id: record.id,
        status: TransactionStatus.success,
      );

      final restored = (await repository.list()).single;
      expect(restored.operation, TransactionOperation.stake);
      expect(restored.resource, 'ENERGY');
      expect(restored.status, TransactionStatus.success);
    });

    test('persists wrapped native operation metadata', () async {
      final repository = await _createRepository(tempDirectory);
      final record = TransactionRecord(
        id: 'wrap-1',
        chainId: '1',
        chainType: ChainType.evm,
        assetSymbol: 'ETH',
        direction: TransactionDirection.outgoing,
        amount: '1',
        status: TransactionStatus.submitted,
        transactionHash: '0xwrap',
        createdAt: DateTime.utc(2026, 8, 4),
        operation: TransactionOperation.wrap,
        resource: 'WETH',
      );

      await repository.save(record);

      final restored = (await repository.list()).single;
      expect(restored.operation, TransactionOperation.wrap);
      expect(restored.resource, 'WETH');
    });

    test('defaults missing or unknown operation fields to transfer', () async {
      final initializer = StorageInitializer(path: tempDirectory.path);
      final registry = await initializer.initialize();
      const codec = StorageJsonCodec();
      final base = <String, Object?>{
        'id': 'old-1',
        'chainId': '1',
        'chainType': 'evm',
        'assetSymbol': 'ETH',
        'direction': 'outgoing',
        'amount': '0.1',
        'status': 'submitted',
        'transactionHash': '0xold',
        'createdAt': DateTime.utc(2026, 6, 6).toIso8601String(),
      };
      await registry.transactionsBox.put('old-1', codec.encode(base));
      await registry.transactionsBox.put(
        'old-2',
        codec.encode({...base, 'id': 'old-2', 'operation': 'futureOperation'}),
      );
      final repository = HiveTransactionHistoryRepository(registry: registry);

      final records = await repository.list();

      expect(
        records.map((record) => record.operation),
        everyElement(TransactionOperation.transfer),
      );
    });
  });

  testWidgets('transaction history page renders distinct status labels', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(id: 'submitting', status: TransactionStatus.submitting),
      _record(id: 'submitted', status: TransactionStatus.submitted),
      _record(id: 'success', status: TransactionStatus.success),
      _record(id: 'failed', status: TransactionStatus.failed),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('提交中'), findsOneWidget);
    expect(find.text('已提交'), findsOneWidget);
    expect(find.text('成功'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('成功')).style?.color,
      AppColors.success,
    );
  });

  testWidgets('transaction history page shows the record chain', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(id: 'submitted', status: TransactionStatus.submitted),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('网络: 1'), findsOneWidget);
  });

  testWidgets('transaction history shows local month-day time with seconds', (
    tester,
  ) async {
    final createdAt = DateTime.utc(2026, 6, 7, 20, 9, 10);
    final repository = _FakeTransactionHistoryRepository([
      _record(id: 'submitted', createdAt: createdAt),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_localTransactionTimestamp(createdAt)), findsOneWidget);
    expect(find.text('2026-06-07'), findsNothing);
  });

  testWidgets('transaction history can switch the network filter', (
    tester,
  ) async {
    final ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final bnb = defaultChains.firstWhere(
      (chain) => chain.id == 'bnb-smart-chain',
    );
    final repository = _FakeTransactionHistoryRepository([
      _record(id: 'ethereum', hash: '0xethereum'),
      _record(
        id: 'bnb',
        hash: '0xbnb',
        chainId: bnb.chainId,
        assetSymbol: bnb.symbol,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(
            _FakeChainRepository(selectedChain: ethereum),
          ),
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: TransactionHistoryPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final networkFilter = find.byKey(
      const Key('transactionHistoryNetworkFilter'),
    );
    expect(networkFilter, findsOneWidget);
    expect(
      find.descendant(of: networkFilter, matching: find.text('Ethereum')),
      findsOneWidget,
    );
    expect(find.text('0xethereum'), findsOneWidget);
    expect(find.text('0xbnb'), findsNothing);

    await tester.tap(networkFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BNB Smart Chain'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: networkFilter,
        matching: find.text('BNB Smart Chain'),
      ),
      findsOneWidget,
    );
    expect(find.text('0xethereum'), findsNothing);
    expect(find.text('0xbnb'), findsOneWidget);
  });

  testWidgets('transaction history renders staking operations distinctly', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(
        id: 'tron-stake',
        chainId: 'tron-mainnet',
        chainType: ChainType.tron,
        assetSymbol: 'TRX',
        operation: TransactionOperation.stake,
        resource: 'ENERGY',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('质押 TRX'), findsOneWidget);
    expect(find.textContaining('Energy'), findsOneWidget);
    expect(find.text('发送'), findsNothing);
  });

  testWidgets('transaction history renders wrapped native operations distinctly',
      (tester) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(
        id: 'wrap-1',
        assetSymbol: 'ETH',
        amount: '0.5',
        operation: TransactionOperation.wrap,
        resource: 'WETH',
      ),
      _record(
        id: 'unwrap-1',
        assetSymbol: 'WETH',
        amount: '0.25',
        operation: TransactionOperation.unwrap,
        resource: 'ETH',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('封装原生币'), findsOneWidget);
    expect(find.text('解封装原生币'), findsOneWidget);
    expect(find.text('0.5 ETH → WETH'), findsOneWidget);
    expect(find.text('0.25 WETH → ETH'), findsOneWidget);
  });

  testWidgets('transaction history page refreshes submitted statuses', (
    tester,
  ) async {
    final chain = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeTransactionHistoryRepository([
      _record(id: 'submitted', hash: '0xsubmitted'),
    ]);
    final lookupService = _FakeTransactionStatusLookupService({
      '0xsubmitted': const TransactionStatusUpdate(
        status: TransactionStatus.success,
      ),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(
            _FakeChainRepository(selectedChain: chain),
          ),
          rpcNodeRepositoryProvider.overrideWithValue(_FakeRpcNodeRepository()),
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
          transactionStatusLookupServiceProvider.overrideWithValue(
            lookupService,
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已提交'), findsOneWidget);

    await tester.tap(find.byKey(const Key('refreshTransactionStatusButton')));
    await tester.pump();

    final spinner = find.byKey(const Key('transactionHistoryRefreshSpinner'));
    expect(spinner, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 450));
    final halfTurn = tester.widget<RotationTransition>(spinner);
    expect(halfTurn.turns.value, closeTo(0.5, 0.05));

    await tester.pump(const Duration(milliseconds: 449));
    expect(spinner, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pumpAndSettle();

    expect(spinner, findsNothing);
    expect(find.text('成功'), findsOneWidget);
    expect(lookupService.calls, ['0xsubmitted']);
  });

  testWidgets('transaction history explorer action opens external URL', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(id: 'submitted', hash: '0xsubmitted'),
    ]);
    final launcher = _FakeExternalUrlLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
          externalUrlLauncherProvider.overrideWithValue(launcher),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(
              blockExplorerUrl: 'https://etherscan.io',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, AppIcons.externalLink));

    expect(launcher.urls, ['https://etherscan.io/tx/0xsubmitted']);
  });

  testWidgets('transaction history explorer action uses each record chain', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(
        id: 'bitcoin-submitted',
        hash: 'btctxid',
        chainId: 'bitcoin-mainnet',
        chainType: ChainType.bitcoin,
        assetSymbol: 'BTC',
      ),
      _record(id: 'evm-submitted', hash: '0xsubmitted'),
    ]);
    final launcher = _FakeExternalUrlLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(
            _FakeChainRepository(selectedChain: defaultChains.first),
          ),
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
          externalUrlLauncherProvider.overrideWithValue(launcher),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(
              blockExplorerUrl: 'https://etherscan.io',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final explorerButtons = find.widgetWithIcon(
      IconButton,
      AppIcons.externalLink,
    );
    expect(explorerButtons, findsNWidgets(2));

    await tester.tap(explorerButtons.first);
    await tester.tap(explorerButtons.last);

    expect(launcher.urls, [
      'https://blockstream.info/tx/btctxid',
      'https://etherscan.io/tx/0xsubmitted',
    ]);
  });

  testWidgets('transaction history uses the chain explorer URL builder', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(
        id: 'tron-submitted',
        hash: 'tron-tx-id',
        chainId: 'tron-mainnet',
        chainType: ChainType.tron,
        assetSymbol: 'TRX',
      ),
    ]);
    final launcher = _FakeExternalUrlLauncher();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
          externalUrlLauncherProvider.overrideWithValue(launcher),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransactionHistoryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, AppIcons.externalLink));

    expect(launcher.urls, ['https://tronscan.org/#/transaction/tron-tx-id']);
  });

  testWidgets('view more uses the configured EVM explorer address page', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(
        id: 'bnb-submitted',
        chainId: '56',
        assetSymbol: 'BNB',
        fromAddress: '0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc',
      ),
    ]);
    final urls = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: TransactionHistoryPage(
              chainId: '56',
              blockExplorerUrl: 'https://bscscan.com',
              onOpenExplorer: urls.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('viewMoreTransactionsOnExplorerButton')),
    );

    expect(urls, [
      'https://bscscan.com/address/'
          '0x9659B6Ed9FAFfa7f3f04E3B0aD5EeE214162acfc#transactions',
    ]);
  });

  testWidgets('view more uses Solscan for Solana address history', (
    tester,
  ) async {
    final repository = _FakeTransactionHistoryRepository([
      _record(
        id: 'solana-submitted',
        chainId: 'mainnet-beta',
        chainType: ChainType.solana,
        assetSymbol: 'SOL',
        fromAddress: '8xV2M7Yk3SolanaWalletAddress',
      ),
    ]);
    final urls = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: TransactionHistoryPage(
              chainId: 'mainnet-beta',
              blockExplorerUrl: 'https://explorer.solana.com',
              onOpenExplorer: urls.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('viewMoreTransactionsOnExplorerButton')),
    );

    expect(urls, ['https://solscan.io/account/8xV2M7Yk3SolanaWalletAddress']);
  });
}

Future<TransactionHistoryRepository> _createRepository(
  Directory directory,
) async {
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveTransactionHistoryRepository(registry: registry);
}

TransactionRecord _record({
  required String id,
  String? walletId,
  String hash = '0xhash',
  TransactionStatus status = TransactionStatus.submitted,
  DateTime? createdAt,
  String chainId = '1',
  ChainType chainType = ChainType.evm,
  String assetSymbol = 'ETH',
  String amount = '0.1',
  String fromAddress = '0xsender',
  TransactionOperation operation = TransactionOperation.transfer,
  String? resource,
}) {
  return TransactionRecord(
    id: id,
    walletId: walletId,
    chainId: chainId,
    chainType: chainType,
    assetSymbol: assetSymbol,
    direction: TransactionDirection.outgoing,
    amount: amount,
    status: status,
    transactionHash: hash,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 6),
    fromAddress: fromAddress,
    toAddress: '0xreceiver',
    operation: operation,
    resource: resource,
  );
}

String _localTransactionTimestamp(DateTime value) {
  final localValue = value.toLocal();
  return '${localValue.month.toString().padLeft(2, '0')}-'
      '${localValue.day.toString().padLeft(2, '0')} '
      '${localValue.hour.toString().padLeft(2, '0')}:'
      '${localValue.minute.toString().padLeft(2, '0')}:'
      '${localValue.second.toString().padLeft(2, '0')}';
}

final class _FakeTransactionHistoryRepository
    implements TransactionHistoryRepository {
  _FakeTransactionHistoryRepository(this.records);

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
  }) {
    final index = records.indexWhere((record) => record.id == id);
    if (index == -1) {
      return Future.value();
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
    return Future.value();
  }
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

final class _FakeTransactionStatusLookupService
    implements TransactionStatusLookupService {
  _FakeTransactionStatusLookupService(this.results);

  final Map<String, TransactionStatusUpdate> results;
  final calls = <String>[];

  @override
  Future<TransactionStatusUpdate?> lookup({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    calls.add(record.transactionHash);
    return results[record.transactionHash];
  }
}

final class _FakeExternalUrlLauncher implements ExternalUrlLauncher {
  final urls = <String>[];

  @override
  Future<bool> openExternal(String url) async {
    urls.add(url);
    return true;
  }
}
