import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/application/token_discovery_controller.dart';
import 'package:safe_wallet/features/assets/application/manual_token_add_controller.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/evm_token_discovery_service.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/data/token_universe_repository.dart';
import 'package:safe_wallet/features/assets/data/tron_asset_service.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/assets/presentation/token_management_page.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/errors/asset_error.dart';

void main() {
  testWidgets('add token opens searchable token universe page', (tester) async {
    final repository = _FakeTokenRepository();
    final client = _FakeEvmTokenDiscoveryClient();
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    final universeRepository = _FakeTokenUniverseRepository(const [
      TokenInfo(
        chainId: '1',
        contractAddress: '0x2222222222222222222222222222222222222222',
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      TokenInfo(
        chainId: '1',
        contractAddress: '0x3333333333333333333333333333333333333333',
        symbol: 'LINK',
        name: 'Chainlink',
        decimals: 18,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
    ]);

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
      universeRepository: universeRepository,
    );

    await tester.tap(find.text('添加代币'));
    await tester.pumpAndSettle();

    expect(find.text('添加自定义'), findsOneWidget);
    expect(find.text('USDC'), findsOneWidget);
    expect(find.text('USD Coin'), findsOneWidget);
    expect(find.text('LINK'), findsOneWidget);

    final searchField = find.widgetWithText(TextField, '搜索代币名称、符号或合约地址');
    await tester.enterText(searchField, 'usd');
    await tester.pump();

    expect(find.text('USDC'), findsOneWidget);
    expect(find.text('LINK'), findsNothing);

    await tester.enterText(searchField, '333333');
    await tester.pump();

    expect(find.text('USDC'), findsNothing);
    expect(find.text('LINK'), findsOneWidget);
  });

  testWidgets('selecting a universe token adds it and returns to management', (
    tester,
  ) async {
    final repository = _FakeTokenRepository();
    final client = _FakeEvmTokenDiscoveryClient();
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    const token = TokenInfo(
      chainId: '1',
      contractAddress: '0x2222222222222222222222222222222222222222',
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      source: TokenSource.builtIn,
      isHidden: false,
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
      universeRepository: const _FakeTokenUniverseRepository([token]),
    );

    await tester.tap(find.text('添加代币'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USDC'));
    await tester.pumpAndSettle();

    expect(repository.savedTokens, [token]);
    expect(client.balanceCalls, isEmpty);
    expect(client.metadataCalls, isEmpty);
    expect(find.text('添加自定义'), findsNothing);
    expect(find.text('USD Coin'), findsOneWidget);
  });

  testWidgets('manual token add reads RPC metadata and refreshes list', (
    tester,
  ) async {
    final repository = _FakeTokenRepository();
    final client = _FakeEvmTokenDiscoveryClient();
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
    );

    expect(find.text('暂无代币'), findsOneWidget);

    await tester.tap(find.text('添加代币'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加自定义'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '合约地址'),
      '0x2222222222222222222222222222222222222222',
    );
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(client.balanceCalls, ['0x2222222222222222222222222222222222222222']);
    expect(client.metadataCalls, [
      '0x2222222222222222222222222222222222222222',
    ]);
    expect(repository.savedTokens.single, isA<TokenInfo>());
    expect(repository.savedTokens.single.source, TokenSource.userAdded);
    expect(
      repository.savedTokens.single.contractAddress,
      '0x2222222222222222222222222222222222222222',
    );
    expect(repository.savedTokens.single.decimals, 6);
    expect(find.text('SAFE'), findsOneWidget);
    expect(find.text('Safe Token'), findsOneWidget);
  });

  testWidgets(
    'token discovery checks token universe balances and refreshes list',
    (tester) async {
      final repository = _FakeTokenRepository(lastScannedBlock: 7);
      final client = _FakeEvmTokenDiscoveryClient(
        balance: BigInt.one,
        latestBlock: 10,
        scanContracts: const ['0x3333333333333333333333333333333333333333'],
        metadata: const EvmTokenMetadata(
          name: 'Discovered Token',
          symbol: 'DISC',
          decimals: 18,
        ),
      );
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      const token = TokenInfo(
        chainId: '1',
        contractAddress: '0x3333333333333333333333333333333333333333',
        symbol: 'DISC',
        name: 'Discovered Token',
        decimals: 18,
        source: TokenSource.builtIn,
        isHidden: false,
      );

      await _pumpTokenManagementPage(
        tester,
        repository: repository,
        client: client,
        ethereum: ethereum,
        universeRepository: const _FakeTokenUniverseRepository([token]),
      );

      expect(find.text('暂无代币'), findsOneWidget);

      await tester.tap(find.text('发现代币'));
      await tester.pumpAndSettle();

      expect(client.scanCalls, hasLength(1));
      expect(client.scanCalls.single.fromBlock, 8);
      expect(client.scanCalls.single.toBlock, 10);
      expect(client.balanceCalls, [token.contractAddress]);
      expect(repository.persistedLastScannedBlock, 10);
      expect(repository.savedTokens.single.source, TokenSource.discovered);
      expect(
        repository.savedTokens.single.contractAddress,
        '0x3333333333333333333333333333333333333333',
      );
      expect(find.text('DISC'), findsOneWidget);
      expect(find.text('Discovered Token'), findsOneWidget);
      expect(find.text('发现'), findsOneWidget);
      expect(find.text('已发现 1 个代币'), findsOneWidget);
    },
  );

  testWidgets('token discovery shows progress and empty result feedback', (
    tester,
  ) async {
    final repository = _FakeTokenRepository();
    final balanceCompleter = Completer<BigInt>();
    final client = _FakeEvmTokenDiscoveryClient(
      balanceCompleter: balanceCompleter,
      scanContracts: const ['0x3333333333333333333333333333333333333333'],
    );
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    const token = TokenInfo(
      chainId: '1',
      contractAddress: '0x3333333333333333333333333333333333333333',
      symbol: 'ZERO',
      name: 'Zero Token',
      decimals: 18,
      source: TokenSource.builtIn,
      isHidden: false,
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
      universeRepository: const _FakeTokenUniverseRepository([token]),
    );

    await tester.tap(find.text('发现代币'));
    await tester.pump();

    expect(find.text('发现中'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    balanceCompleter.complete(BigInt.zero);
    await tester.pumpAndSettle();

    expect(find.text('发现代币'), findsOneWidget);
    expect(repository.savedTokens, isEmpty);
    expect(find.text('未发现持有的代币'), findsOneWidget);
  });

  testWidgets('token discovery shows RPC failures', (tester) async {
    final repository = _FakeTokenRepository();
    final client = _FakeEvmTokenDiscoveryClient(
      balanceError: const AssetError.balanceQueryFailed(),
      scanContracts: const ['0x3333333333333333333333333333333333333333'],
    );
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );
    const token = TokenInfo(
      chainId: '1',
      contractAddress: '0x3333333333333333333333333333333333333333',
      symbol: 'FAIL',
      name: 'Failed Token',
      decimals: 18,
      source: TokenSource.builtIn,
      isHidden: false,
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
      universeRepository: const _FakeTokenUniverseRepository([token]),
    );

    await tester.tap(find.text('发现代币'));
    await tester.pumpAndSettle();

    expect(repository.savedTokens, isEmpty);
    expect(find.text('代币发现失败，请检查网络节点'), findsOneWidget);
  });

  testWidgets(
    'Tron manual token add uses supplied metadata and hides discovery',
    (tester) async {
      final repository = _FakeTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient();
      final tronService = _FakeTronAssetService(balance: BigInt.from(123));
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );

      await _pumpTokenManagementPage(
        tester,
        repository: repository,
        client: client,
        ethereum: tron,
        walletAddress: _tronWalletAddress,
        tronService: tronService,
      );

      expect(find.text('暂无代币'), findsOneWidget);
      expect(find.text('添加代币'), findsOneWidget);
      expect(find.text('发现代币'), findsNothing);

      await tester.tap(find.text('添加代币'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加自定义'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '合约地址'),
        _trc20ContractAddress,
      );
      await tester.enterText(find.widgetWithText(TextField, '代币符号'), 'usdt');
      await tester.enterText(
        find.widgetWithText(TextField, '代币名称'),
        'Tether USD',
      );
      await tester.enterText(find.widgetWithText(TextField, '精度'), '6');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(tronService.trc20BalanceCalls, [
        (
          apiBaseUrl: 'https://rpc.example.com',
          walletAddress: _tronWalletAddress,
          contractAddress: _trc20ContractAddress,
        ),
      ]);
      expect(client.balanceCalls, isEmpty);
      expect(client.metadataCalls, isEmpty);
      expect(
        repository.savedTokens.single.contractAddress,
        _trc20ContractAddress,
      );
      expect(repository.savedTokens.single.symbol, 'USDT');
      expect(repository.savedTokens.single.name, 'Tether USD');
      expect(repository.savedTokens.single.decimals, 6);
      expect(find.text('USDT'), findsOneWidget);
      expect(find.text('Tether USD'), findsOneWidget);
    },
  );

  testWidgets('manual token add shows localized balance query failures', (
    tester,
  ) async {
    final repository = _FakeTokenRepository();
    final client = _FakeEvmTokenDiscoveryClient(
      balanceError: const AssetError.balanceQueryFailed(),
    );
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
    );

    await tester.tap(find.text('添加代币'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加自定义'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '合约地址'),
      '0x2222222222222222222222222222222222222222',
    );
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(client.balanceCalls, ['0x2222222222222222222222222222222222222222']);
    expect(repository.savedTokens, isEmpty);
    expect(find.text('余额查询失败，请检查网络节点'), findsOneWidget);
    expect(find.text('操作失败，请稍后重试'), findsNothing);
  });

  testWidgets('Bitcoin token management hides contract token actions', (
    tester,
  ) async {
    final repository = _FakeTokenRepository();
    final client = _FakeEvmTokenDiscoveryClient();
    final bitcoin = defaultChains.firstWhere(
      (chain) => chain.id == 'bitcoin-mainnet',
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: bitcoin,
    );

    expect(find.text('暂无代币'), findsOneWidget);
    expect(find.text('添加代币'), findsNothing);
    expect(find.text('发现代币'), findsNothing);
    expect(client.balanceCalls, isEmpty);
    expect(client.metadataCalls, isEmpty);
    expect(repository.savedTokens, isEmpty);
  });

  testWidgets(
    'token management hides contract actions without wallet address',
    (tester) async {
      final repository = _FakeTokenRepository();
      final client = _FakeEvmTokenDiscoveryClient();
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );

      await _pumpTokenManagementPage(
        tester,
        repository: repository,
        client: client,
        ethereum: ethereum,
        walletAddress: '',
      );

      expect(find.text('暂无代币'), findsOneWidget);
      expect(find.text('添加代币'), findsNothing);
      expect(find.text('发现代币'), findsNothing);
      expect(client.scanCalls, isEmpty);
      expect(repository.savedTokens, isEmpty);
    },
  );

  testWidgets('token management hides and unhides a token', (tester) async {
    final repository = _FakeTokenRepository(
      initialTokens: const [
        TokenInfo(
          chainId: '1',
          contractAddress: '0x2222222222222222222222222222222222222222',
          symbol: 'SAFE',
          name: 'Safe Token',
          decimals: 6,
          source: TokenSource.userAdded,
          isHidden: false,
        ),
      ],
    );
    final client = _FakeEvmTokenDiscoveryClient();
    final ethereum = defaultChains.firstWhere(
      (chain) => chain.id == 'ethereum',
    );

    await _pumpTokenManagementPage(
      tester,
      repository: repository,
      client: client,
      ethereum: ethereum,
    );

    expect(find.text('Safe Token'), findsOneWidget);
    expect(find.text('隐藏'), findsOneWidget);
    expect(find.text('已隐藏'), findsNothing);

    await tester.tap(find.text('隐藏'));
    await tester.pumpAndSettle();

    expect(repository.hiddenTokenContracts, [
      '0x2222222222222222222222222222222222222222',
    ]);
    expect(find.text('已隐藏'), findsOneWidget);
    expect(find.text('取消隐藏'), findsOneWidget);

    await tester.tap(find.text('取消隐藏'));
    await tester.pumpAndSettle();

    expect(repository.unhiddenTokenContracts, [
      '0x2222222222222222222222222222222222222222',
    ]);
    expect(find.text('已隐藏'), findsNothing);
    expect(find.text('隐藏'), findsOneWidget);
  });
}

final class _FakeEvmTokenDiscoveryClient implements EvmTokenDiscoveryClient {
  _FakeEvmTokenDiscoveryClient({
    BigInt? balance,
    this.balanceError,
    this.balanceCompleter,
    this.latestBlock = 0,
    this.scanContracts = const [],
    this.metadata = const EvmTokenMetadata(
      name: 'Safe Token',
      symbol: 'SAFE',
      decimals: 6,
    ),
  }) : balance = balance ?? BigInt.zero;

  final BigInt balance;
  final Object? balanceError;
  final Completer<BigInt>? balanceCompleter;
  final int latestBlock;
  final List<String> scanContracts;
  final EvmTokenMetadata metadata;
  final balanceCalls = <String>[];
  final metadataCalls = <String>[];
  final scanCalls = <_ScanCall>[];

  @override
  Future<int> latestBlockNumber({
    required String rpcUrl,
    Map<String, String> headers = const {},
  }) async {
    return latestBlock;
  }

  @override
  Future<BigInt> readBalance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    balanceCalls.add(contractAddress);
    final error = balanceError;
    if (error != null) {
      throw error;
    }
    final completer = balanceCompleter;
    if (completer != null) {
      return completer.future;
    }
    return balance;
  }

  @override
  Future<EvmTokenMetadata> readMetadata({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async {
    metadataCalls.add(contractAddress);
    return metadata;
  }

  @override
  Future<List<String>> scanTransferContracts({
    required String rpcUrl,
    required String walletAddress,
    required int fromBlock,
    required int toBlock,
    Map<String, String> headers = const {},
  }) async {
    scanCalls.add(
      _ScanCall(
        fromBlock: fromBlock,
        toBlock: toBlock,
        walletAddress: walletAddress,
      ),
    );
    return scanContracts;
  }
}

final class _FakeTronAssetService implements TronAssetService {
  _FakeTronAssetService({required this.balance});

  final BigInt balance;
  final trc20BalanceCalls =
      <({String apiBaseUrl, String walletAddress, String contractAddress})>[];

  @override
  Future<BigInt> getTrxBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, BigInt>> getTrc20Balances({
    required String apiBaseUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    for (final contractAddress in contractAddresses) {
      trc20BalanceCalls.add((
        apiBaseUrl: apiBaseUrl,
        walletAddress: walletAddress,
        contractAddress: contractAddress,
      ));
    }
    return {
      for (final contractAddress in contractAddresses) contractAddress: balance,
    };
  }
}

final class _FakeTokenRepository implements TokenRepository {
  _FakeTokenRepository({
    this.lastScannedBlock,
    List<TokenInfo> initialTokens = const [],
  }) : savedTokens = [...initialTokens];

  final List<TokenInfo> savedTokens;
  final int? lastScannedBlock;
  int? persistedLastScannedBlock;
  final hiddenTokenContracts = <String>[];
  final unhiddenTokenContracts = <String>[];

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return List.unmodifiable(
      savedTokens.where(
        (token) =>
            token.chainId == chainId && (includeHidden || !token.isHidden),
      ),
    );
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) async {
    savedTokens.removeWhere(
      (existing) =>
          existing.chainId == token.chainId &&
          existing.contractAddress == token.contractAddress,
    );
    savedTokens.add(token);
    return token;
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
  }) async {
    hiddenTokenContracts.add(contractAddress);
    _setHidden(
      chainId: chainId,
      contractAddress: contractAddress,
      isHidden: true,
    );
  }

  @override
  Future<void> unhideToken({
    required String chainId,
    required String contractAddress,
  }) async {
    unhiddenTokenContracts.add(contractAddress);
    _setHidden(
      chainId: chainId,
      contractAddress: contractAddress,
      isHidden: false,
    );
  }

  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) async {
    return lastScannedBlock;
  }

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) async {
    persistedLastScannedBlock = blockNumber;
  }

  void _setHidden({
    required String chainId,
    required String contractAddress,
    required bool isHidden,
  }) {
    final index = savedTokens.indexWhere(
      (token) =>
          token.chainId == chainId && token.contractAddress == contractAddress,
    );
    final existing = savedTokens[index];
    savedTokens[index] = TokenInfo(
      chainId: existing.chainId,
      contractAddress: existing.contractAddress,
      symbol: existing.symbol,
      name: existing.name,
      decimals: existing.decimals,
      source: existing.source,
      isHidden: isHidden,
      logoUri: existing.logoUri,
    );
  }
}

Future<void> _pumpTokenManagementPage(
  WidgetTester tester, {
  required _FakeTokenRepository repository,
  required _FakeEvmTokenDiscoveryClient client,
  required ChainConfig ethereum,
  String walletAddress = '0x1111111111111111111111111111111111111111',
  _FakeTronAssetService? tronService,
  _FakeTokenUniverseRepository? universeRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tokenRepositoryProvider.overrideWithValue(repository),
        tokenUniverseRepositoryProvider.overrideWithValue(
          universeRepository ?? const _FakeTokenUniverseRepository([]),
        ),
        evmTokenDiscoveryClientProvider.overrideWithValue(client),
        if (tronService != null)
          tronAssetServiceProvider.overrideWithValue(tronService),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: TokenManagementPage(
            chain: ethereum,
            rpcUrl: 'https://rpc.example.com',
            walletAddress: walletAddress,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeTokenUniverseRepository implements TokenUniverseRepository {
  const _FakeTokenUniverseRepository(this.tokens);

  final List<TokenInfo> tokens;

  @override
  Future<List<TokenInfo>> getTopTokens({
    required ChainConfig chain,
    int limit = 100,
  }) async {
    return tokens
        .where((token) => token.chainId == chain.chainId)
        .take(limit)
        .toList(growable: false);
  }
}

const _tronWalletAddress = 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj';
const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';

final class _ScanCall {
  const _ScanCall({
    required this.fromBlock,
    required this.toBlock,
    required this.walletAddress,
  });

  final int fromBlock;
  final int toBlock;
  final String walletAddress;

  @override
  bool operator ==(Object other) {
    return other is _ScanCall &&
        other.fromBlock == fromBlock &&
        other.toBlock == toBlock &&
        other.walletAddress == walletAddress;
  }

  @override
  int get hashCode => Object.hash(fromBlock, toBlock, walletAddress);
}
