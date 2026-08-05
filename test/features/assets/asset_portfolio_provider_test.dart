import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/application/asset_refresh_controller.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  test(
    'portfolio provider loads selected wallet without signing unlock',
    () async {
      final repository = _RecordingAssetRepository();
      final container = ProviderContainer(
        overrides: [
          chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
          rpcNodeRepositoryProvider.overrideWithValue(_FakeRpcNodeRepository()),
          walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
          tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
          assetRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(selectedWalletIdProvider.notifier).select(_account.id);
      final portfolio = await container.read(assetPortfolioProvider.future);

      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(repository.requests.single.account.id, _account.id);
      expect(
        repository.requests.single.chain.chainId,
        defaultChains.first.chainId,
      );
    },
  );

  test('portfolio request uses the resolved private RPC endpoint', () async {
    const privateNode = RpcNode(
      id: 'alchemy',
      chainId: '1',
      name: 'Alchemy',
      url: 'https://eth-mainnet.g.alchemy.com/v2',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      provider: RpcProvider.alchemy,
      credentialMode: RpcCredentialMode.pathSegment,
      credentialRef: 'rpc-node.alchemy',
    );
    final credentials = _MemoryRpcCredentialStore()
      ..values['rpc-node.alchemy'] = 'private-key';
    final container = ProviderContainer(
      overrides: [
        chainRepositoryProvider.overrideWithValue(_FakeChainRepository()),
        rpcNodeRepositoryProvider.overrideWithValue(
          _FakeRpcNodeRepository(node: privateNode),
        ),
        rpcCredentialStoreProvider.overrideWithValue(credentials),
        walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedWalletIdProvider.notifier).select(_account.id);

    final request = await container.read(assetPortfolioRequestProvider);

    expect(
      request?.rpcNode.endpointUrl,
      'https://eth-mainnet.g.alchemy.com/v2/private-key',
    );
    expect(request?.rpcNode.url, isNot(contains('private-key')));
  });

  test(
    'portfolio provider exposes loading while repository is pending',
    () async {
      final completer = Completer<AssetPortfolio>();
      final container = _containerWithRequest(
        repository: _CompleterAssetRepository(completer),
      );
      addTearDown(container.dispose);

      expect(container.read(assetPortfolioProvider).isLoading, isTrue);

      completer.complete(AssetPortfolio.empty());
      final portfolio = await container.read(assetPortfolioProvider.future);

      expect(portfolio.status, AssetPortfolioStatus.empty);
    },
  );

  test(
    'portfolio provider keeps empty error and data states distinct',
    () async {
      final emptyContainer = _containerWithRequest(
        repository: _StaticAssetRepository(AssetPortfolio.empty()),
      );
      addTearDown(emptyContainer.dispose);

      expect(
        (await emptyContainer.read(assetPortfolioProvider.future)).status,
        AssetPortfolioStatus.empty,
      );

      final errorContainer = _containerWithRequest(
        repository: _StaticAssetRepository(AssetPortfolio.error('rpc failed')),
      );
      addTearDown(errorContainer.dispose);

      expect(
        (await errorContainer.read(assetPortfolioProvider.future)).status,
        AssetPortfolioStatus.error,
      );

      final dataContainer = _containerWithRequest(
        repository: _StaticAssetRepository(
          AssetPortfolio.loaded([
            const AssetBalance(
              chainId: '1',
              token: TokenInfo(
                chainId: '1',
                contractAddress: null,
                symbol: 'ETH',
                name: 'Ethereum',
                decimals: 18,
                source: TokenSource.builtIn,
                isHidden: false,
              ),
              balance: '1',
              formattedBalance: '1',
              status: AssetBalanceStatus.loaded,
            ),
          ]),
        ),
      );
      addTearDown(dataContainer.dispose);

      final portfolio = await dataContainer.read(assetPortfolioProvider.future);

      expect(portfolio.status, AssetPortfolioStatus.loaded);
      expect(portfolio.balances.single.formattedBalance, '1');
    },
  );

  test(
    'portfolio provider does not load balances without a chain address',
    () async {
      final ethereum = defaultChains.firstWhere(
        (chain) => chain.id == 'ethereum',
      );
      final repository = _RecordingAssetRepository();
      final container = ProviderContainer(
        overrides: [
          assetPortfolioRequestProvider.overrideWithValue(
            Future.value(
              AssetPortfolioRequest(
                account: _bitcoinOnlyAccount,
                chain: ethereum,
                rpcNode: _node,
              ),
            ),
          ),
          assetRepositoryProvider.overrideWithValue(repository),
          tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
        ],
      );
      addTearDown(container.dispose);

      final portfolio = await container.read(assetPortfolioProvider.future);

      expect(portfolio.status, AssetPortfolioStatus.empty);
      expect(portfolio.account, _bitcoinOnlyAccount);
      expect(repository.requests, isEmpty);
    },
  );

  test(
    'portfolio provider returns cached balances before live refresh finishes',
    () async {
      final liveCompleter = Completer<AssetPortfolio>();
      final repository = _CachedThenLiveAssetRepository(
        cachedPortfolio: _portfolioWithAmount('1'),
        livePortfolio: _portfolioWithAmount('2'),
        liveCompleter: liveCompleter,
      );
      final container = _containerWithRequest(repository: repository);
      addTearDown(container.dispose);

      final cached = await container.read(assetPortfolioProvider.future);

      expect(cached.balances.single.formattedBalance, '1');
      expect(repository.liveRequestCount, 1);

      liveCompleter.complete(repository.livePortfolio);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final refreshed = await container.read(assetPortfolioProvider.future);

      expect(refreshed.balances.single.formattedBalance, '2');
    },
  );

  test('portfolio provider refreshes fresh cached balances once', () async {
    final livePortfolio = _portfolioWithAmount('1');
    final liveCompleter = Completer<AssetPortfolio>();
    final repository = _CachedThenLiveAssetRepository(
      cachedPortfolio: livePortfolio,
      livePortfolio: livePortfolio,
      liveCompleter: liveCompleter,
    );
    final container = _containerWithRequest(repository: repository);
    addTearDown(container.dispose);

    final cached = await container.read(assetPortfolioProvider.future);

    expect(cached.balances.single.formattedBalance, '1');
    expect(repository.liveRequestCount, 1);

    liveCompleter.complete(livePortfolio);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await container.read(assetPortfolioProvider.future);

    expect(repository.liveRequestCount, 1);
  });

  test(
    'portfolio provider refreshes immediately after the selected RPC changes',
    () async {
      final clock = _MutableClock(DateTime.utc(2026, 6, 9, 1));
      final livePortfolio = _portfolioWithAmount('1');
      final liveCompleter = Completer<AssetPortfolio>()
        ..complete(livePortfolio);
      final repository = _CachedThenLiveAssetRepository(
        cachedPortfolio: livePortfolio,
        livePortfolio: livePortfolio,
        liveCompleter: liveCompleter,
      );
      var request = AssetPortfolioRequest(
        account: _account,
        chain: defaultChains.first,
        rpcNode: _node,
      );
      final container = _containerWithMutableRequest(
        repository: repository,
        request: () => request,
        now: clock.now,
      );
      addTearDown(container.dispose);

      await container.read(assetPortfolioProvider.future);

      expect(repository.liveRequestCount, 1);

      request = AssetPortfolioRequest(
        account: _sameEvmAddressAccount,
        chain: defaultChains.first,
        rpcNode: _otherNode,
      );
      container.invalidate(assetPortfolioRequestProvider);
      container.invalidate(assetPortfolioProvider);

      await container.read(assetPortfolioProvider.future);

      expect(repository.liveRequestCount, 2);

      clock.advance(const Duration(seconds: 61));
      container.invalidate(assetPortfolioRequestProvider);
      container.invalidate(assetPortfolioProvider);

      await container.read(assetPortfolioProvider.future);

      expect(repository.liveRequestCount, 3);
    },
  );

  test(
    'portfolio provider reuses the last live result during the throttle window',
    () async {
      final clock = _MutableClock(DateTime.utc(2026, 6, 9, 2));
      final repository = _NoCacheAssetRepository();
      final container = _containerWithMutableRequest(
        repository: repository,
        request: () => AssetPortfolioRequest(
          account: _account,
          chain: defaultChains.first,
          rpcNode: _node,
        ),
        now: clock.now,
      );
      addTearDown(container.dispose);

      final first = await container.read(assetPortfolioProvider.future);

      expect(first.balances.single.formattedBalance, '1');
      expect(repository.liveRequestCount, 1);

      container.invalidate(assetPortfolioRequestProvider);
      container.invalidate(assetPortfolioProvider);

      final throttled = await container.read(assetPortfolioProvider.future);

      expect(throttled.balances.single.formattedBalance, '1');
      expect(repository.liveRequestCount, 1);

      clock.advance(const Duration(seconds: 61));
      container.invalidate(assetPortfolioRequestProvider);
      container.invalidate(assetPortfolioProvider);

      final refreshed = await container.read(assetPortfolioProvider.future);

      expect(refreshed.balances.single.formattedBalance, '2');
      expect(repository.liveRequestCount, 2);
    },
  );

  test(
    'asset refresh controller forces a live load inside the throttle window',
    () async {
      final repository = _RefreshingCachedAssetRepository();
      final container = _containerWithRequest(repository: repository);
      addTearDown(container.dispose);

      await container.read(assetPortfolioProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(repository.liveRequestCount, 1);

      await container.read(assetRefreshControllerProvider.notifier).refresh();

      expect(repository.liveRequestCount, 2);
      expect(
        container
            .read(assetPortfolioProvider)
            .value
            ?.balances
            .single
            .formattedBalance,
        '2',
      );
    },
  );
}

ProviderContainer _containerWithRequest({required AssetRepository repository}) {
  return ProviderContainer(
    overrides: [
      assetPortfolioRequestProvider.overrideWithValue(
        Future.value(
          AssetPortfolioRequest(
            account: _account,
            chain: defaultChains.first,
            rpcNode: _node,
          ),
        ),
      ),
      assetRepositoryProvider.overrideWithValue(repository),
      tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
    ],
  );
}

ProviderContainer _containerWithMutableRequest({
  required AssetRepository repository,
  required AssetPortfolioRequest Function() request,
  required DateTime Function() now,
}) {
  return ProviderContainer(
    overrides: [
      assetPortfolioRequestProvider.overrideWith(
        (ref) => Future.value(request()),
      ),
      assetPortfolioRefreshClockProvider.overrideWithValue(now),
      assetRepositoryProvider.overrideWithValue(repository),
      tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
    ],
  );
}

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: 'So11111111111111111111111111111111111111112',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _sameEvmAddressAccount = WalletAccount(
  id: 'wallet-2',
  name: 'Wallet 2',
  evmAddress: _account.evmAddress,
  solanaAddress: 'So22222222222222222222222222222222222222222',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final _bitcoinOnlyAccount = WalletAccount(
  id: 'wallet-btc',
  name: 'BTC Wallet',
  evmAddress: '',
  solanaAddress: '',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  source: WalletAccountSource.privateKey,
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

const _node = RpcNode(
  id: 'node-1',
  chainId: '1',
  name: 'Default Ethereum',
  url: 'https://rpc.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

const _otherNode = RpcNode(
  id: 'node-2',
  chainId: '1',
  name: 'Backup Ethereum',
  url: 'https://backup-rpc.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

final class _MutableClock {
  _MutableClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

final class _StaticAssetRepository implements AssetRepository {
  const _StaticAssetRepository(this.portfolio);

  final AssetPortfolio portfolio;

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    return portfolio;
  }
}

final class _CompleterAssetRepository implements AssetRepository {
  const _CompleterAssetRepository(this.completer);

  final Completer<AssetPortfolio> completer;

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) {
    return completer.future;
  }
}

final class _CachedThenLiveAssetRepository
    implements AssetRepository, CachedAssetRepository {
  _CachedThenLiveAssetRepository({
    required AssetPortfolio cachedPortfolio,
    required this.livePortfolio,
    required this.liveCompleter,
  }) : _cachedPortfolio = cachedPortfolio;

  AssetPortfolio _cachedPortfolio;
  final AssetPortfolio livePortfolio;
  final Completer<AssetPortfolio> liveCompleter;
  int liveRequestCount = 0;

  @override
  Future<CachedAssetPortfolio?> loadCachedPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    List<TokenInfo> tokens = const [],
  }) async {
    return CachedAssetPortfolio(
      portfolio: _cachedPortfolio,
      isFresh: _cachedPortfolio == livePortfolio,
    );
  }

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    liveRequestCount += 1;
    final portfolio = await liveCompleter.future;
    _cachedPortfolio = portfolio;
    return portfolio;
  }
}

final class _NoCacheAssetRepository
    implements AssetRepository, CachedAssetRepository {
  int liveRequestCount = 0;

  @override
  Future<CachedAssetPortfolio?> loadCachedPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    List<TokenInfo> tokens = const [],
  }) async {
    return null;
  }

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    liveRequestCount += 1;
    return _portfolioWithAmount(liveRequestCount.toString());
  }
}

final class _RefreshingCachedAssetRepository
    implements AssetRepository, CachedAssetRepository {
  AssetPortfolio _cachedPortfolio = _portfolioWithAmount('0');
  int liveRequestCount = 0;

  @override
  Future<CachedAssetPortfolio?> loadCachedPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    List<TokenInfo> tokens = const [],
  }) async {
    return CachedAssetPortfolio(portfolio: _cachedPortfolio, isFresh: true);
  }

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    liveRequestCount += 1;
    _cachedPortfolio = _portfolioWithAmount(liveRequestCount.toString());
    return _cachedPortfolio;
  }
}

final class _RecordingAssetRepository implements AssetRepository {
  final requests = <AssetPortfolioRequest>[];

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    requests.add(
      AssetPortfolioRequest(account: account, chain: chain, rpcNode: rpcNode),
    );
    return AssetPortfolio.loaded([
      AssetBalance(
        chainId: chain.chainId,
        token: TokenInfo(
          chainId: chain.chainId,
          contractAddress: null,
          symbol: chain.symbol,
          name: chain.name,
          decimals: 18,
          source: TokenSource.builtIn,
          isHidden: false,
        ),
        balance: '1',
        formattedBalance: '1',
        status: AssetBalanceStatus.loaded,
      ),
    ]);
  }
}

AssetPortfolio _portfolioWithAmount(String amount) {
  return AssetPortfolio.loaded([
    AssetBalance(
      chainId: '1',
      token: TokenInfo(
        chainId: '1',
        contractAddress: null,
        symbol: 'ETH',
        name: 'Ethereum',
        decimals: 18,
        source: TokenSource.builtIn,
        isHidden: false,
      ),
      balance: amount,
      formattedBalance: amount,
      status: AssetBalanceStatus.loaded,
    ),
  ]);
}

final class _FakeWalletRepository implements WalletRepository {
  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeChainRepository implements ChainRepository {
  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async => defaultChains.first;

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    return defaultChains.firstWhere((chain) => chain.id == chainId);
  }

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
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
  const _FakeRpcNodeRepository({this.node});

  final RpcNode? node;

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    return [_nodeFor(chain)];
  }

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async {
    return _nodeFor(chain);
  }

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

  RpcNode _nodeFor(ChainConfig chain) {
    final configuredNode = node;
    if (configuredNode != null) {
      return configuredNode;
    }
    return RpcNode(
      id: 'node-${chain.chainId}',
      chainId: chain.chainId,
      name: 'Default',
      url: 'https://rpc.example.com',
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
    );
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

final class _EmptyTokenRepository implements TokenRepository {
  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    return const [];
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) {
    throw UnimplementedError();
  }

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> unhideToken({
    required String chainId,
    required String contractAddress,
  }) {
    throw UnimplementedError();
  }
}
