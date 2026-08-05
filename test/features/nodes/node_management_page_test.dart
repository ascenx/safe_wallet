import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/rpc_node_test_controller.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/chainlist_rpc_repository.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_endpoint.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/nodes/presentation/edit_rpc_node_page.dart';
import 'package:safe_wallet/features/nodes/presentation/node_management_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/chain_clients/evm_client_factory.dart';
import 'package:safe_wallet/shared/chain_clients/solana_client_factory.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  testWidgets('node management uses a subtle circular add button', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.isExtended, isFalse);
    expect(fab.shape, isA<CircleBorder>());
    expect(fab.elevation, 0);
    expect(fab.focusElevation, 2);
    expect(fab.hoverElevation, 3);
    expect(fab.highlightElevation, 3);
    expect(fab.tooltip, t.nodes.addNode);
    expect(find.text(t.nodes.addNode), findsNothing);
    expect(find.byIcon(AppIcons.add), findsOneWidget);
  });

  testWidgets('custom node delete requires confirmation', (tester) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom Ethereum'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    expect(repository.deletedNodeIds, isEmpty);
    expect(find.text('删除节点'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(repository.deletedNodeIds, isEmpty);
    expect(find.text('Custom Ethereum'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(repository.deletedNodeIds, ['custom-ethereum']);
    expect(find.text('Custom Ethereum'), findsNothing);
  });

  testWidgets('deleting selected custom node falls back to default node', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(
      ethereum,
      selectedNodeId: 'custom-ethereum',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.selectedNodeId, 'custom-ethereum');
    expect(find.text('已选'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(repository.deletedNodeIds, ['custom-ethereum']);
    expect(repository.selectedNodeId, 'default-ethereum');
    expect(find.text('Default Ethereum'), findsOneWidget);
    expect(find.text('Custom Ethereum'), findsNothing);
    expect(find.text('已选'), findsOneWidget);
  });

  testWidgets('RPC test rejects a node from a different EVM chain', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    final evmClient = _FakeEvmClientFactory(chainId: '56');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(evmClient),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '测试').at(1));
    await tester.pumpAndSettle();

    expect(repository.nodes.last.lastTestStatus, RpcNodeTestStatus.unavailable);
    expect(evmClient.readChainIdCalls, isNotEmpty);
    expect(evmClient.readBlockNumberCalls, isEmpty);
    expect(find.text('RPC 节点与当前链不匹配'), findsOneWidget);
  });

  testWidgets('RPC test success stores block height and latency', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1', blockHeight: 19000000),
          ),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '测试').first);
    await tester.pumpAndSettle();

    expect(repository.nodes.first.lastBlockHeight, 19000000);
    expect(repository.nodes.first.lastLatencyMs, isNonNegative);
    expect(find.text('区块 19000000'), findsAtLeastNWidgets(1));
    expect(find.textContaining('ms'), findsAtLeastNWidgets(1));
  });

  testWidgets('node management displays and selects Chainlist RPC nodes', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);
    final chainlistRepository = _FakeChainlistRpcRepository([
      RpcNode(
        id: 'chainlist-1-publicnode',
        chainId: ethereum.chainId,
        name: 'ethereum-rpc.publicnode.com',
        url: 'https://ethereum-rpc.publicnode.com',
        nodeType: RpcNodeType.chainlist,
        isSelected: false,
        lastTestStatus: RpcNodeTestStatus.untested,
        note: 'tracking:none',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(chainlistRepository),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ethereum-rpc.publicnode.com'), findsOneWidget);
    expect(find.text('Chainlist'), findsOneWidget);
    expect(find.text('无追踪'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('selectRpcNode:chainlist-1-publicnode')),
    );
    await tester.pumpAndSettle();

    expect(repository.addedNodeUrls, ['https://ethereum-rpc.publicnode.com']);
    expect(repository.selectedNodeId, 'custom-added-1');
  });

  testWidgets('Chainlist node without tracking metadata hides tracking badge', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);
    final chainlistRepository = _FakeChainlistRpcRepository([
      RpcNode(
        id: 'chainlist-1-unknown-tracking',
        chainId: ethereum.chainId,
        name: 'unknown-tracking.example.com',
        url: 'https://unknown-tracking.example.com',
        nodeType: RpcNodeType.chainlist,
        isSelected: false,
        lastTestStatus: RpcNodeTestStatus.untested,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(chainlistRepository),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('unknown-tracking.example.com'), findsOneWidget);
    expect(find.text('追踪未知'), findsNothing);
  });

  testWidgets('node management ignores Chainlist refresh after unmount', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(
      ethereum,
      nodes: [
        RpcNode(
          id: 'default-ethereum',
          chainId: ethereum.chainId,
          name: 'Default Ethereum',
          url: ethereum.rpcUrls.first,
          nodeType: RpcNodeType.defaultNode,
          isSelected: true,
          lastTestStatus: RpcNodeTestStatus.available,
          lastTestedAt: DateTime.now().toUtc(),
          lastLatencyMs: 1,
        ),
      ],
    );
    const chainlistUrl = 'https://slow-chainlist.example.com';
    final chainlistRepository = _FakeChainlistRpcRepository([
      RpcNode(
        id: 'chainlist-1-slow',
        chainId: ethereum.chainId,
        name: 'slow-chainlist.example.com',
        url: chainlistUrl,
        nodeType: RpcNodeType.chainlist,
        isSelected: false,
        lastTestStatus: RpcNodeTestStatus.untested,
      ),
    ]);
    final evmClientFactory = _FakeEvmClientFactory(
      chainId: '1',
      delaysByUrl: const {
        chainlistUrl: Duration(milliseconds: 100),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(chainlistRepository),
          evmClientFactoryProvider.overrideWithValue(evmClientFactory),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
  });

  testWidgets('node management auto tests stale nodes and sorts by latency', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(
      ethereum,
      nodes: [
        RpcNode(
          id: 'selected-ethereum',
          chainId: ethereum.chainId,
          name: 'Selected Ethereum',
          url: 'https://selected.example.com',
          nodeType: RpcNodeType.defaultNode,
          isSelected: true,
          lastTestStatus: RpcNodeTestStatus.untested,
        ),
        RpcNode(
          id: 'slow-ethereum',
          chainId: ethereum.chainId,
          name: 'Slow Ethereum',
          url: 'https://slow.example.com',
          nodeType: RpcNodeType.custom,
          isSelected: false,
          lastTestStatus: RpcNodeTestStatus.untested,
        ),
        RpcNode(
          id: 'fast-ethereum',
          chainId: ethereum.chainId,
          name: 'Fast Ethereum',
          url: 'https://fast.example.com',
          nodeType: RpcNodeType.custom,
          isSelected: false,
          lastTestStatus: RpcNodeTestStatus.untested,
        ),
      ],
      selectedNodeId: 'selected-ethereum',
    );
    final evmClientFactory = _FakeEvmClientFactory(
      chainId: '1',
      delaysByUrl: const {
        'https://selected.example.com': Duration(milliseconds: 30),
        'https://slow.example.com': Duration(milliseconds: 20),
        'https://fast.example.com': Duration(milliseconds: 1),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(evmClientFactory),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(evmClientFactory.readBlockNumberCalls, hasLength(3));
    expect(
      tester.getTopLeft(find.text('Selected Ethereum')).dy,
      lessThan(tester.getTopLeft(find.text('Fast Ethereum')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Fast Ethereum')).dy,
      lessThan(tester.getTopLeft(find.text('Slow Ethereum')).dy),
    );
  });

  testWidgets('node management reuses latency cache for five minutes', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final now = DateTime.now().toUtc();
    final repository = _FakeRpcNodeRepository(
      ethereum,
      nodes: [
        RpcNode(
          id: 'default-ethereum',
          chainId: ethereum.chainId,
          name: 'Default Ethereum',
          url: ethereum.rpcUrls.first,
          nodeType: RpcNodeType.defaultNode,
          isSelected: true,
          lastTestStatus: RpcNodeTestStatus.available,
          lastTestedAt: now.subtract(const Duration(minutes: 4)),
          lastLatencyMs: 40,
        ),
      ],
    );
    final evmClientFactory = _FakeEvmClientFactory(chainId: '1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(evmClientFactory),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(evmClientFactory.readBlockNumberCalls, isEmpty);
    expect(find.text('40 ms'), findsOneWidget);
  });

  testWidgets('refresh button force tests cached nodes and shows spinner', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final now = DateTime.now().toUtc();
    final repository = _FakeRpcNodeRepository(
      ethereum,
      nodes: [
        RpcNode(
          id: 'default-ethereum',
          chainId: ethereum.chainId,
          name: 'Default Ethereum',
          url: ethereum.rpcUrls.first,
          nodeType: RpcNodeType.defaultNode,
          isSelected: true,
          lastTestStatus: RpcNodeTestStatus.available,
          lastTestedAt: now,
          lastLatencyMs: 40,
        ),
      ],
    );
    final evmClientFactory = _FakeEvmClientFactory(
      chainId: '1',
      delaysByUrl: {
        ethereum.rpcUrls.first: const Duration(milliseconds: 100),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(evmClientFactory),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(evmClientFactory.readBlockNumberCalls, isEmpty);

    await tester.tap(find.byKey(const Key('nodeManagementRefreshButton')));
    await tester.pump();

    expect(
        find.byKey(const Key('nodeManagementRefreshSpinner')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(evmClientFactory.readBlockNumberCalls, [ethereum.rpcUrls.first]);
  });

  testWidgets('custom node can be edited from node management', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.edit));
    await tester.pumpAndSettle();

    expect(find.text('编辑节点'), findsWidgets);
    expect(find.text('Custom Ethereum'), findsOneWidget);
    expect(find.text('https://custom.example.com'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '节点名称'),
      'Edited Ethereum',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'https://edited.example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, '备注'), 'Primary');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.updatedNodeIds, ['custom-ethereum']);
    expect(repository.nodes.last.note, 'Primary');
    expect(find.text('Edited Ethereum'), findsOneWidget);
    expect(find.text('https://edited.example.com'), findsOneWidget);
    expect(find.text('Custom Ethereum'), findsNothing);
  });

  testWidgets('add EVM node rejects a different chain id', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '56'),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '节点名称'), 'BSC RPC');
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'https://bsc.example.com',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.addedNodeUrls, isEmpty);
    expect(find.text('RPC 节点与当前链不匹配'), findsOneWidget);
  });

  testWidgets('add EVM node rejects invalid RPC URL before probing', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);
    final evmClientFactory = _FakeEvmClientFactory(chainId: '1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          evmClientFactoryProvider.overrideWithValue(evmClientFactory),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '节点名称'),
      'Bad URL',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'not-a-url',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(evmClientFactory.readBlockNumberCalls, isEmpty);
    expect(repository.addedNodeUrls, isEmpty);
    expect(find.text('RPC URL 格式无效'), findsOneWidget);
  });

  testWidgets('add Solana node refuses health failure before saving', (
    tester,
  ) async {
    final solana =
        defaultChains.firstWhere((chain) => chain.id == 'solana-mainnet');
    final repository = _FakeRpcNodeRepository(solana);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(shouldFail: true),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: solana),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '节点名称'),
      'Broken Solana',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'https://solana-broken.example.com',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.addedNodeUrls, isEmpty);
    expect(find.text('RPC 节点不可用，请检查地址或网络'), findsOneWidget);
  });

  testWidgets('Helius preset stores only its API key as a credential', (
    tester,
  ) async {
    final solana =
        defaultChains.firstWhere((chain) => chain.id == 'solana-mainnet');
    final repository = _FakeRpcNodeRepository(solana);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          solanaClientFactoryProvider.overrideWithValue(
            const _FakeSolanaClientFactory(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: solana),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<dynamic>), findsNothing);
    await tester.tap(find.byKey(const Key('rpcProviderSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Helius').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '节点名称'), 'Helius');
    await tester.enterText(
        find.widgetWithText(TextField, 'API Key'), 'secret-key');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.addedNodeUrls, ['https://mainnet.helius-rpc.com/']);
    expect(repository.addedProviders, [RpcProvider.helius]);
    expect(repository.addedCredentialModes, [RpcCredentialMode.queryParameter]);
    expect(repository.addedCredentials, ['secret-key']);
  });

  testWidgets('retesting Helius keeps its stored credential', (tester) async {
    final solana = defaultChains.firstWhere(
      (chain) => chain.id == 'solana-mainnet',
    );
    const credentialRef = 'rpc-node.helius';
    final helius = RpcNode(
      id: 'helius',
      chainId: solana.chainId,
      name: 'helius',
      url: 'https://mainnet.helius-rpc.com/',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      lastTestedAt: DateTime.now().toUtc(),
      lastLatencyMs: 373,
      provider: RpcProvider.helius,
      credentialMode: RpcCredentialMode.queryParameter,
      credentialParameter: 'api-key',
      credentialRef: credentialRef,
    );
    final repository = _FakeRpcNodeRepository(
      solana,
      selectedNodeId: helius.id,
      nodes: [helius],
    );
    final credentialStore = _MemoryRpcCredentialStore()
      ..values[credentialRef] = 'secret-key';
    final solanaClient = _RecordingSolanaClientFactory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          rpcEndpointResolverProvider.overrideWithValue(
            RpcEndpointResolver(credentialStore: credentialStore),
          ),
          solanaClientFactoryProvider.overrideWithValue(solanaClient),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: solana),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final testButton = find.widgetWithText(TextButton, '测试');
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    await tester.tap(testButton);
    await tester.pumpAndSettle();

    const resolvedUrl = 'https://mainnet.helius-rpc.com/?api-key=secret-key';
    expect(solanaClient.checkHealthUrls, [resolvedUrl, resolvedUrl]);
    expect(solanaClient.readGenesisHashUrls, [resolvedUrl, resolvedUrl]);
    expect(
      find.text('https://mainnet.helius-rpc.com/?api-key=••••••••'),
      findsOneWidget,
    );
  });

  testWidgets('failed Helius retest replaces the cached available status', (
    tester,
  ) async {
    final solana = defaultChains.firstWhere(
      (chain) => chain.id == 'solana-mainnet',
    );
    const credentialRef = 'rpc-node.helius';
    final helius = RpcNode(
      id: 'helius',
      chainId: solana.chainId,
      name: 'helius',
      url: 'https://mainnet.helius-rpc.com/',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      lastTestedAt: DateTime.now().toUtc(),
      lastLatencyMs: 373,
      provider: RpcProvider.helius,
      credentialMode: RpcCredentialMode.queryParameter,
      credentialParameter: 'api-key',
      credentialRef: credentialRef,
    );
    final repository = _FakeRpcNodeRepository(
      solana,
      selectedNodeId: helius.id,
      nodes: [helius],
    );
    final credentialStore = _MemoryRpcCredentialStore()
      ..values[credentialRef] = 'secret-key';
    final solanaClient = _FailingSecondSolanaClientFactory();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository([]),
          ),
          rpcEndpointResolverProvider.overrideWithValue(
            RpcEndpointResolver(credentialStore: credentialStore),
          ),
          solanaClientFactoryProvider.overrideWithValue(solanaClient),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: NodeManagementPage(chain: solana),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final testButton = find.widgetWithText(TextButton, '测试');
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    expect(find.text('可用'), findsOneWidget);

    await tester.tap(testButton);
    await tester.pumpAndSettle();

    expect(find.text('不可用'), findsOneWidget);
    expect(find.text('RPC 凭据无效或已失效'), findsOneWidget);
  });

  testWidgets('QuickNode asks for one URL without exposing auth internals', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = _FakeRpcNodeRepository(ethereum);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rpcProviderSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QuickNode').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rpcAuthModeSelector')), findsNothing);
    expect(find.widgetWithText(TextField, 'HTTP Endpoint'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, 'URL'),
      'https://quiet-name.quiknode.pro/private-token/',
    );
    expect(find.widgetWithText(TextField, 'API Key'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextField, '节点名称'),
      'QuickNode',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      repository.addedNodeUrls,
      ['https://quiet-name.quiknode.pro/private-token/'],
    );
    expect(repository.addedProviders, [RpcProvider.quickNode]);
    expect(repository.addedCredentialModes, [RpcCredentialMode.none]);
    expect(repository.addedCredentials, [isNull]);
  });

  testWidgets('custom auth choices use user-facing parameter names', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(
            _FakeRpcNodeRepository(ethereum),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: ethereum),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无需参数'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rpcAuthModeSelector')));
    await tester.pumpAndSettle();

    expect(find.text('无需参数'), findsWidgets);
    expect(find.text('Query 参数'), findsOneWidget);
    expect(find.text('Path 参数'), findsOneWidget);
    expect(find.text('完整私有 Endpoint'), findsNothing);
  });

  testWidgets('editing a stored private endpoint keeps its URL when blank', (
    tester,
  ) async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    const credentialRef = 'rpc-node.quicknode';
    final node = RpcNode(
      id: 'quicknode',
      chainId: ethereum.chainId,
      name: 'QuickNode',
      url: 'https://quiet-name.quiknode.pro/',
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.quickNode,
      credentialMode: RpcCredentialMode.fullEndpoint,
      credentialRef: credentialRef,
    );
    final repository = _FakeRpcNodeRepository(ethereum, nodes: [node]);
    final credentialStore = _MemoryRpcCredentialStore()
      ..values[credentialRef] =
          'https://quiet-name.quiknode.pro/private-token/';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rpcNodeRepositoryProvider.overrideWithValue(repository),
          rpcEndpointResolverProvider.overrideWithValue(
            RpcEndpointResolver(credentialStore: credentialStore),
          ),
          evmClientFactoryProvider.overrideWithValue(
            _FakeEvmClientFactory(chainId: '1'),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: EditRpcNodePage(chain: ethereum, node: node),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final urlField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'URL'),
    );
    expect(urlField.controller!.text, isEmpty);
    expect(find.text('留空则保留现有 URL'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.updatedNodeUrls, ['https://quiet-name.quiknode.pro/']);
    expect(
      repository.updatedCredentialModes,
      [RpcCredentialMode.fullEndpoint],
    );
    expect(repository.updatedCredentials, [isNull]);
  });
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
  _FakeRpcNodeRepository(
    ChainConfig chain, {
    this.selectedNodeId = 'default-ethereum',
    List<RpcNode>? nodes,
  }) : nodes = nodes ??
            [
              RpcNode(
                id: 'default-ethereum',
                chainId: chain.chainId,
                name: 'Default Ethereum',
                url: chain.rpcUrls.first,
                nodeType: RpcNodeType.defaultNode,
                isSelected: selectedNodeId == 'default-ethereum',
                lastTestStatus: RpcNodeTestStatus.untested,
              ),
              RpcNode(
                id: 'custom-ethereum',
                chainId: chain.chainId,
                name: 'Custom Ethereum',
                url: 'https://custom.example.com',
                nodeType: RpcNodeType.custom,
                isSelected: selectedNodeId == 'custom-ethereum',
                lastTestStatus: RpcNodeTestStatus.available,
              ),
            ];

  final List<RpcNode> nodes;
  String selectedNodeId;
  final deletedNodeIds = <String>[];
  final addedNodeUrls = <String>[];
  final addedProviders = <RpcProvider>[];
  final addedCredentialModes = <RpcCredentialMode>[];
  final addedCredentials = <String?>[];
  final updatedNodeIds = <String>[];
  final updatedNodeUrls = <String>[];
  final updatedCredentialModes = <RpcCredentialMode?>[];
  final updatedCredentials = <String?>[];

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
    addedNodeUrls.add(url);
    addedProviders.add(provider);
    addedCredentialModes.add(credentialMode);
    addedCredentials.add(credential);
    final node = RpcNode(
      id: 'custom-added-${addedNodeUrls.length}',
      chainId: chain.chainId,
      name: name,
      url: url,
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      note: note,
      provider: provider,
      credentialMode: credentialMode,
      credentialParameter: credentialParameter,
      credentialRef: credentialMode == RpcCredentialMode.none
          ? null
          : 'rpc-node.custom-added-${addedNodeUrls.length}',
    );
    nodes.add(node);
    return node;
  }

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    deletedNodeIds.add(nodeId);
    nodes.removeWhere((node) => node.id == nodeId);
    if (selectedNodeId == nodeId) {
      final fallback = nodes.firstWhere(
        (node) =>
            node.chainId == chain.chainId &&
            node.nodeType == RpcNodeType.defaultNode,
      );
      _selectOnly(chain: chain, nodeId: fallback.id);
    }
  }

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    return List.unmodifiable(
        nodes.where((node) => node.chainId == chain.chainId));
  }

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async {
    return nodes
        .firstWhere((node) => node.chainId == chain.chainId && node.isSelected);
  }

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    _selectOnly(chain: chain, nodeId: nodeId);
    return getSelectedNode(chain);
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
  }) async {
    updatedNodeIds.add(nodeId);
    updatedNodeUrls.add(url);
    updatedCredentialModes.add(credentialMode);
    updatedCredentials.add(credential);
    final index = nodes.indexWhere(
      (node) => node.id == nodeId && node.chainId == chain.chainId,
    );
    final existing = nodes[index];
    final updated = RpcNode(
      id: existing.id,
      chainId: existing.chainId,
      name: name,
      url: url,
      nodeType: existing.nodeType,
      isSelected: existing.isSelected,
      lastTestStatus: RpcNodeTestStatus.untested,
      note: note,
    );
    nodes[index] = updated;
    return updated;
  }

  void _selectOnly({
    required ChainConfig chain,
    required String nodeId,
  }) {
    selectedNodeId = nodeId;
    for (var index = 0; index < nodes.length; index += 1) {
      final node = nodes[index];
      if (node.chainId != chain.chainId) {
        continue;
      }
      nodes[index] = RpcNode(
        id: node.id,
        chainId: node.chainId,
        name: node.name,
        url: node.url,
        nodeType: node.nodeType,
        isSelected: node.id == nodeId,
        lastTestStatus: node.lastTestStatus,
        lastTestedAt: node.lastTestedAt,
        lastBlockHeight: node.lastBlockHeight,
        lastLatencyMs: node.lastLatencyMs,
        note: node.note,
      );
    }
  }

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) async {
    final index = nodes.indexWhere((node) => node.id == nodeId);
    final existing = nodes[index];
    final updated = RpcNode(
      id: existing.id,
      chainId: existing.chainId,
      name: existing.name,
      url: existing.url,
      nodeType: existing.nodeType,
      isSelected: existing.isSelected,
      lastTestStatus: status,
      lastTestedAt: testedAt,
      lastBlockHeight: blockHeight,
      lastLatencyMs: latencyMs,
      note: existing.note,
      provider: existing.provider,
      credentialMode: existing.credentialMode,
      credentialParameter: existing.credentialParameter,
      credentialRef: existing.credentialRef,
    );
    nodes[index] = updated;
    return updated;
  }
}

final class _MemoryRpcCredentialStore implements RpcCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String reference) async {
    values.remove(reference);
  }

  @override
  Future<String?> read(String reference) async => values[reference];

  @override
  Future<void> write(String reference, String credential) async {
    values[reference] = credential;
  }
}

final class _FakeEvmClientFactory implements EvmClientFactory {
  _FakeEvmClientFactory({
    required this.chainId,
    this.blockHeight = 1,
    this.delaysByUrl = const {},
  });

  final String chainId;
  final int blockHeight;
  final Map<String, Duration> delaysByUrl;
  final readChainIdCalls = <String>[];
  final readBlockNumberCalls = <String>[];

  @override
  Future<String> readChainId(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    final delay = delaysByUrl[rpcUrl];
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
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

final class _FakeChainlistRpcRepository implements ChainlistRpcRepository {
  const _FakeChainlistRpcRepository(this.nodes);

  final List<RpcNode> nodes;

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    return nodes.where((node) => node.chainId == chain.chainId).toList();
  }
}

final class _FakeSolanaClientFactory implements SolanaClientFactory {
  const _FakeSolanaClientFactory({
    this.shouldFail = false,
  });

  final bool shouldFail;

  @override
  Future<void> checkHealth(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    if (shouldFail) {
      throw StateError('Solana health failed');
    }
  }

  @override
  Future<String> readGenesisHash(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async =>
      '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d';
}

final class _RecordingSolanaClientFactory implements SolanaClientFactory {
  final checkHealthUrls = <String>[];
  final readGenesisHashUrls = <String>[];

  @override
  Future<void> checkHealth(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    checkHealthUrls.add(rpcUrl);
  }

  @override
  Future<String> readGenesisHash(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    readGenesisHashUrls.add(rpcUrl);
    return '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d';
  }
}

final class _FailingSecondSolanaClientFactory implements SolanaClientFactory {
  var _healthCallCount = 0;

  @override
  Future<void> checkHealth(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    _healthCallCount += 1;
    if (_healthCallCount == 2) {
      throw const RpcError.invalidCredential();
    }
  }

  @override
  Future<String> readGenesisHash(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async =>
      '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d';
}
