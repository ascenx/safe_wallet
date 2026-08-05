import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chainlist_chain_repository.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/chainlist_rpc_repository.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/presentation/network_management_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_colors.dart';
import 'package:safe_wallet/shared/design/app_radius.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  testWidgets('network management shows chains and opens node management', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EVM 网络'), findsOneWidget);
    expect(find.text('Bitcoin 网络'), findsOneWidget);
    expect(find.text('Solana 网络'), findsOneWidget);
    expect(find.text('Tron 网络'), findsOneWidget);
    expect(find.text('Sui 网络'), findsOneWidget);
    expect(find.text('网络管理'), findsOneWidget);
    expect(find.text('Ethereum'), findsOneWidget);
    expect(find.text('HyperEVM'), findsOneWidget);
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Solana Mainnet'), findsOneWidget);
    expect(find.text('Tron'), findsOneWidget);
    expect(find.text('Sui Mainnet'), findsOneWidget);
    expect(find.text('当前'), findsWidgets);
    expect(find.text('Default Ethereum'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(defaultChains.length));
    expect(find.byType(GridView), findsNWidgets(5));
    final addNetworkButton = find.byTooltip('添加网络');
    expect(addNetworkButton, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: addNetworkButton,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: addNetworkButton,
        matching: find.byIcon(AppIcons.add),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, '新增 EVM 网络'), findsNothing);
    expect(find.byIcon(AppIcons.network), findsNothing);
    expect(find.byIcon(AppIcons.solana), findsNothing);
    final evmGrid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        evmGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.childAspectRatio, greaterThan(1.1));
    expect(
      (tester.getTopLeft(find.text('Ethereum')).dy -
              tester.getTopLeft(find.text('BNB Smart Chain')).dy)
          .abs(),
      lessThan(24),
    );
    expect(
      tester.getTopLeft(find.text('Base')).dy,
      lessThan(tester.getTopLeft(find.text('HyperEVM')).dy),
    );

    final ethereumCard = find.ancestor(
      of: find.text('Ethereum'),
      matching: find.byType(InkWell),
    );
    final ethereumChainId = find.descendant(
      of: ethereumCard,
      matching: find.text('Chain ID: 1'),
    );
    final ethereumNetworkType = find.descendant(
      of: ethereumCard,
      matching: find.text('主网'),
    );
    expect(ethereumChainId, findsOneWidget);
    expect(ethereumNetworkType, findsOneWidget);
    expect(
      tester.getTopLeft(ethereumChainId).dx,
      lessThan(tester.getTopLeft(ethereumNetworkType).dx),
    );

    final solanaDevnetCard = find.ancestor(
      of: find.text('Solana Devnet'),
      matching: find.byType(InkWell),
    );
    expect(
      find.descendant(
        of: solanaDevnetCard,
        matching: find.text('Chain ID: devnet'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: solanaDevnetCard,
        matching: find.text('测试网'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ethereum'));
    await tester.pumpAndSettle();

    expect(find.text('RPC 节点'), findsOneWidget);
    expect(find.text('Default Ethereum'), findsOneWidget);
    expect(find.byTooltip('新增节点'), findsOneWidget);
    expect(find.byKey(const Key('nodeManagementAddButton')), findsOneWidget);
  });

  testWidgets(
      'network management opens Bitcoin nodes without switching network', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bitcoin = find.text('Bitcoin');
    await tester.ensureVisible(bitcoin);
    await tester.tap(bitcoin);
    await tester.pumpAndSettle();

    expect(chainRepository.selectedChainId, 'ethereum');
    expect(find.text('RPC 节点'), findsOneWidget);
    expect(find.text('Bitcoin RPC'), findsOneWidget);
    expect(find.text('https://blockstream.info/api'), findsOneWidget);
    expect(find.byTooltip('新增节点'), findsOneWidget);
    expect(find.byKey(const Key('nodeManagementAddButton')), findsOneWidget);
  });

  testWidgets('network management grid fits long custom network names on phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final chainRepository = _FakeChainRepository();
    chainRepository.chains.add(
      const ChainConfig(
        id: 'custom-evm-641230',
        chainType: ChainType.evm,
        name: 'Bear Network Chain Mainnet',
        chainId: '641230',
        symbol: 'BRNKC',
        rpcUrls: ['https://rpc.bearnetwork.example.com'],
        blockExplorerUrl: null,
        isTestnet: false,
      ),
    );
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bear Network Chain Mainnet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add network page searches and adds Chainlist chain', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    final nodeRepository = _FakeRpcNodeRepository();
    const avalanche = ChainConfig(
      id: 'chainlist-43114',
      chainType: ChainType.evm,
      name: 'Avalanche C-Chain',
      chainId: '43114',
      symbol: 'AVAX',
      rpcUrls: ['https://api.avax.network/ext/bc/C/rpc'],
      blockExplorerUrl: 'https://snowtrace.io',
      isTestnet: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([avalanche]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加网络'));
    await tester.pumpAndSettle();

    expect(find.text('添加网络'), findsOneWidget);
    expect(find.text('Avalanche C-Chain'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '搜索网络'), 'avax');
    await tester.pumpAndSettle();

    expect(find.text('Avalanche C-Chain'), findsOneWidget);
    expect(find.text('Ethereum'), findsNothing);

    await tester.tap(find.text('Avalanche C-Chain'));
    await tester.pumpAndSettle();

    expect(chainRepository.chains.any((chain) => chain.chainId == '43114'),
        isTrue);
    expect(find.text('网络管理'), findsOneWidget);
    expect(find.text('Avalanche C-Chain'), findsOneWidget);
  });

  testWidgets('add network search matches the browser pill input style', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加网络'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, '搜索网络'),
    );
    final decoration = field.decoration!;

    for (final border in [
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
      decoration.errorBorder,
      decoration.focusedErrorBorder,
    ]) {
      expect(border, isA<OutlineInputBorder>());
      expect(
        (border as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
    }
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide.color,
      AppColors.border,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      AppColors.primary,
    );
    expect(
      (decoration.errorBorder! as OutlineInputBorder).borderSide.color,
      AppColors.danger,
    );
    expect((decoration.prefixIcon! as Icon).size, 20);
  });

  testWidgets('add network page virtualizes long Chainlist grids', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    final nodeRepository = _FakeRpcNodeRepository();
    final chainlistChains = List.generate(80, (index) {
      final chainId = (50000 + index).toString();
      return ChainConfig(
        id: 'chainlist-$chainId',
        chainType: ChainType.evm,
        name: 'Chainlist Network $index',
        chainId: chainId,
        symbol: 'T$index',
        rpcUrls: ['https://rpc-$index.example.com'],
        blockExplorerUrl: null,
        isTestnet: false,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            _FakeChainlistChainRepository(chainlistChains),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加网络'));
    await tester.pumpAndSettle();

    final addPageGrid = tester.widget<GridView>(find.byType(GridView));
    expect(addPageGrid.shrinkWrap, isFalse);
    expect(find.text('Chainlist Network 0'), findsOneWidget);
    expect(find.text('Chainlist Network 79'), findsNothing);
  });

  testWidgets('add custom network returns to network management', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加网络'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加自定义'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('新增 EVM 网络'),
      ),
      findsOneWidget,
    );
    final customNetworkScaffold = tester
        .widgetList<Scaffold>(
          find.byType(Scaffold),
        )
        .last;
    expect(customNetworkScaffold.bottomNavigationBar, isNotNull);

    await tester.enterText(
        find.widgetWithText(TextField, '网络名称'), 'Local Testnet');
    await tester.enterText(find.widgetWithText(TextField, 'Chain ID'), '31337');
    await tester.enterText(
      find.widgetWithText(TextField, 'RPC URL'),
      'http://127.0.0.1:8545',
    );
    await tester.enterText(find.widgetWithText(TextField, '原生币符号'), 'ETH');
    await tester.enterText(
      find.widgetWithText(TextField, '区块浏览器 URL'),
      'http://127.0.0.1:4000',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('Local Testnet'), findsOneWidget);
    expect(find.text('添加网络'), findsNothing);
    expect(
      chainRepository.chains.any(
        (chain) => chain.id == 'custom-evm-31337' && chain.isTestnet,
      ),
      isTrue,
    );
  });

  testWidgets('network management shows localized custom chain save errors', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository(
      addCustomChainError: const RpcError.invalidUrl(),
    );
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('添加网络'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加自定义'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '网络名称'), 'Broken RPC');
    await tester.enterText(find.widgetWithText(TextField, 'Chain ID'), '31337');
    await tester.enterText(
      find.widgetWithText(TextField, 'RPC URL'),
      'http://127.0.0.1:8545',
    );
    await tester.enterText(find.widgetWithText(TextField, '原生币符号'), 'ETH');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(chainRepository.addCustomChainCallCount, 1);
    expect(
      chainRepository.chains.any((chain) => chain.id == 'custom-evm-31337'),
      isFalse,
    );
    expect(find.text('RPC URL 格式无效'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsNothing);
  });

  testWidgets('network management can remove non default chains', (
    tester,
  ) async {
    final chainRepository = _FakeChainRepository();
    chainRepository.chains.add(
      const ChainConfig(
        id: 'custom-evm-43114',
        chainType: ChainType.evm,
        name: 'Avalanche C-Chain',
        chainId: '43114',
        symbol: 'AVAX',
        rpcUrls: ['https://api.avax.network/ext/bc/C/rpc'],
        blockExplorerUrl: 'https://snowtrace.io',
        isTestnet: false,
      ),
    );
    final nodeRepository = _FakeRpcNodeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chainRepositoryProvider.overrideWithValue(chainRepository),
          rpcNodeRepositoryProvider.overrideWithValue(nodeRepository),
          chainlistRpcRepositoryProvider.overrideWithValue(
            const _FakeChainlistRpcRepository(),
          ),
          chainlistChainRepositoryProvider.overrideWithValue(
            const _FakeChainlistChainRepository([]),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const NetworkManagementPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avalanche C-Chain'), findsOneWidget);
    expect(find.byTooltip('移除网络'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('移除网络'));
    await tester.tap(find.byTooltip('移除网络'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认移除'));
    await tester.pumpAndSettle();

    expect(chainRepository.deletedChainIds, ['custom-evm-43114']);
    expect(nodeRepository.deletedNodeIds, ['node-custom-evm-43114']);
    expect(find.text('Avalanche C-Chain'), findsNothing);
    expect(find.byTooltip('移除网络'), findsNothing);
  });
}

final class _FakeChainRepository
    implements ChainRepository, RemovableChainRepository {
  _FakeChainRepository({this.addCustomChainError});

  final Object? addCustomChainError;
  final chains = [...defaultChains];
  String selectedChainId = 'ethereum';
  int addCustomChainCallCount = 0;
  final deletedChainIds = <String>[];

  @override
  Future<List<ChainConfig>> getChains() async => List.unmodifiable(chains);

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) async {
    addCustomChainCallCount += 1;
    final error = addCustomChainError;
    if (error != null) {
      throw error;
    }
    final chain = ChainConfig(
      id: 'custom-evm-$chainId',
      chainType: ChainType.evm,
      name: name,
      chainId: chainId,
      symbol: symbol,
      rpcUrls: [rpcUrl],
      blockExplorerUrl: blockExplorerUrl,
      isTestnet: isTestnet,
    );
    chains.add(chain);
    return chain;
  }

  @override
  Future<ChainConfig> getSelectedChain() async {
    return chains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }

  @override
  Future<void> deleteChain(String chainId) async {
    deletedChainIds.add(chainId);
    chains.removeWhere((chain) => chain.id == chainId);
    if (selectedChainId == chainId) {
      selectedChainId = defaultChains.first.id;
    }
  }
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
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
    return RpcNode(
      id: 'custom-node-${chain.id}',
      chainId: chain.chainId,
      name: name,
      url: url,
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: provider,
      credentialMode: credentialMode,
      credentialParameter: credentialParameter,
    );
  }

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    deletedNodeIds.add(nodeId);
  }

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    return [_nodeFor(chain)];
  }

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async {
    return _nodeFor(chain);
  }

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    return RpcNode(
      id: nodeId,
      chainId: chain.chainId,
      name: '${chain.name} RPC',
      url: chain.rpcUrls.first,
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.untested,
    );
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

  RpcNode _nodeFor(ChainConfig chain) {
    return RpcNode(
      id: 'node-${chain.id}',
      chainId: chain.chainId,
      name: chain.chainType == ChainType.evm
          ? 'Default ${chain.name}'
          : '${chain.name} RPC',
      url: chain.rpcUrls.first,
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      lastTestedAt: DateTime.now().toUtc(),
      lastLatencyMs: 1,
    );
  }
}

final class _FakeChainlistRpcRepository implements ChainlistRpcRepository {
  const _FakeChainlistRpcRepository();

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async => const [];
}

final class _FakeChainlistChainRepository implements ChainlistChainRepository {
  const _FakeChainlistChainRepository(this.chains);

  final List<ChainConfig> chains;

  @override
  Future<List<ChainConfig>> getChains() async => chains;
}
