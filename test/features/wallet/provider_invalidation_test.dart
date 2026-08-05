import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/assets/application/token_repository_provider.dart';
import 'package:safe_wallet/features/assets/data/asset_repository.dart';
import 'package:safe_wallet/features/assets/data/token_repository.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/application/selected_chain_controller.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/application/dapp_permission_controller.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_broadcast_controller.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/evm_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/evm_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/solana_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  test('manual lock keeps assets available and blocks signing without password',
      () async {
    final assetRepository = _RecordingAssetRepository();
    final transactionService = _RecordingEvmTransactionService();
    final permissionRepository = InMemoryDappPermissionRepository();
    final container = _container(
      assetRepository: assetRepository,
      evmTransactionService: transactionService,
      dappPermissionRepository: permissionRepository,
    );
    container.read(selectedWalletIdProvider.notifier).select(_account.id);
    await _unlock(container);

    final loadedPortfolio = await container.read(assetPortfolioProvider.future);
    expect(loadedPortfolio.status, AssetPortfolioStatus.loaded);

    await container.read(dappPermissionControllerProvider.notifier).approve(
          domain: 'app.uniswap.org',
          walletId: _account.id,
          chainId: _ethereum.chainId,
          address: _account.evmAddress,
          now: _now,
        );
    container.read(walletSessionControllerProvider.notifier).lock();

    final portfolioAfterLock =
        await container.read(assetPortfolioProvider.future);
    expect(portfolioAfterLock.status, AssetPortfolioStatus.loaded);

    final transferResult = await container
        .read(transactionBroadcastControllerProvider.notifier)
        .submit(_broadcastRequest());
    expect(transferResult.status, TransactionBroadcastStatus.failure);
    expect(transferResult.error?.safeMessageKey, 'errors.walletLocked');
    expect(transactionService.calls, isEmpty);

    final dappResult =
        await container.read(dappRequestControllerProvider.notifier).handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'personal_sign',
                params: ['hello', _account.evmAddress],
              ),
              now: _now,
            );
    expect(dappResult.status, DappRequestResultStatus.confirmationRequired);
    final approvedDappResult =
        await container.read(dappRequestControllerProvider.notifier).handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'personal_sign',
                params: ['hello', _account.evmAddress],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              now: _now,
            );
    expect(approvedDappResult.status, DappRequestResultStatus.walletLocked);
  });

  test('chain switch invalidates active fee estimates', () async {
    final chainRepository = _FakeChainRepository();
    final feeService = _RecordingEvmFeeService();
    final container = _container(
      chainRepository: chainRepository,
      evmFeeService: feeService,
    );
    final provider = feeEstimateProvider(_feeRequest());

    await container.read(provider.future);
    expect(feeService.calls, hasLength(1));

    await container
        .read(selectedChainControllerProvider.notifier)
        .selectChain('solana-mainnet');
    await container.read(provider.future);

    expect(feeService.calls, hasLength(2));
  });

  test('node switch invalidates asset portfolio RPC context', () async {
    final rpcRepository = _FakeRpcNodeRepository();
    final assetRepository = _RecordingAssetRepository();
    final container = _container(
      rpcNodeRepository: rpcRepository,
      assetRepository: assetRepository,
    );
    container.read(selectedWalletIdProvider.notifier).select(_account.id);
    await _unlock(container);

    await container.read(assetPortfolioProvider.future);
    expect(assetRepository.nodes.single.id, 'node-1');

    rpcRepository.selectedNode = _node2;
    container.invalidate(selectedRpcNodeProvider(_ethereum));
    await container.read(assetPortfolioProvider.future);

    expect(assetRepository.nodes.map((node) => node.id), ['node-1', 'node-2']);
  });

  test('chain switch to Bitcoin uses Bitcoin address and node context',
      () async {
    final chainRepository = _FakeChainRepository();
    final rpcRepository = _FakeRpcNodeRepository();
    final assetRepository = _RecordingAssetRepository();
    final container = _container(
      chainRepository: chainRepository,
      rpcNodeRepository: rpcRepository,
      assetRepository: assetRepository,
    );
    container.read(selectedWalletIdProvider.notifier).select(_account.id);
    await _unlock(container);

    await container.read(assetPortfolioProvider.future);
    await container
        .read(selectedChainControllerProvider.notifier)
        .selectChain('bitcoin-mainnet');
    await container.read(assetPortfolioProvider.future);

    expect(assetRepository.requests, hasLength(2));
    expect(assetRepository.requests.first.chain.id, 'ethereum');
    expect(assetRepository.requests.first.rpcNode.chainId, '1');
    expect(assetRepository.requests.first.walletAddress, _account.evmAddress);
    expect(assetRepository.requests.last.chain.id, 'bitcoin-mainnet');
    expect(assetRepository.requests.last.rpcNode.chainId, 'bitcoin-mainnet');
    expect(assetRepository.requests.last.walletAddress, _account.btcAddress);
  });
}

ProviderContainer _container({
  ChainRepository? chainRepository,
  RpcNodeRepository? rpcNodeRepository,
  AssetRepository? assetRepository,
  EvmFeeService? evmFeeService,
  EvmTransactionService? evmTransactionService,
  DappPermissionRepository? dappPermissionRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      chainRepositoryProvider.overrideWithValue(
        chainRepository ?? _FakeChainRepository(),
      ),
      rpcNodeRepositoryProvider.overrideWithValue(
        rpcNodeRepository ?? _FakeRpcNodeRepository(),
      ),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      sessionKeyCacheProvider.overrideWithValue(SessionKeyCache()),
      tokenRepositoryProvider.overrideWithValue(_EmptyTokenRepository()),
      assetRepositoryProvider.overrideWithValue(
        assetRepository ?? _RecordingAssetRepository(),
      ),
      evmFeeServiceProvider.overrideWithValue(
        evmFeeService ?? _RecordingEvmFeeService(),
      ),
      evmTransactionServiceProvider.overrideWithValue(
        evmTransactionService ?? _RecordingEvmTransactionService(),
      ),
      solanaTransactionServiceProvider.overrideWithValue(
        _NeverCalledSolanaTransactionService(),
      ),
      transactionHistoryRepositoryProvider.overrideWithValue(
        _RecordingTransactionHistoryRepository(),
      ),
      transactionBroadcastClockProvider.overrideWithValue(() => _now),
      dappPermissionRepositoryProvider.overrideWithValue(
        dappPermissionRepository ?? InMemoryDappPermissionRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _unlock(ProviderContainer container) async {
  await container.read(walletSessionControllerProvider.notifier).unlock(
        walletId: _account.id,
        password: 'password',
        now: _now,
      );
}

FeeEstimateRequest _feeRequest() {
  return FeeEstimateRequest(
    chain: _ethereum,
    rpcNode: _node1,
    fromAddress: _account.evmAddress,
    request: _transactionRequest(),
  );
}

TransactionBroadcastRequest _broadcastRequest() {
  return TransactionBroadcastRequest(
    chain: _ethereum,
    rpcNode: _node1,
    account: _account,
    transaction: _transactionRequest(),
    feeEstimate: FeeEstimate.eip1559(
      feeAssetSymbol: _ethereum.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    ),
  );
}

TransactionRequest _transactionRequest() {
  return TransactionRequest(
    chainId: _ethereum.chainId,
    chainType: _ethereum.chainType,
    assetSymbol: _ethereum.symbol,
    toAddress: '0x2222222222222222222222222222222222222222',
    amount: '0.1',
    amountInBaseUnits: '100000000000000000',
    tokenDecimals: 18,
    transactionType: TransactionType.nativeTransfer,
  );
}

final _now = DateTime.now().toUtc();
final _ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Main Wallet',
  evmAddress: '0x1111111111111111111111111111111111111111',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  solanaAddress: '11111111111111111111111111111111',
  createdAt: _now,
  updatedAt: _now,
);

const _node1 = RpcNode(
  id: 'node-1',
  chainId: '1',
  name: 'RPC 1',
  url: 'https://rpc-1.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

const _node2 = RpcNode(
  id: 'node-2',
  chainId: '1',
  name: 'RPC 2',
  url: 'https://rpc-2.example.com',
  nodeType: RpcNodeType.custom,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

const _bitcoinNode1 = RpcNode(
  id: 'bitcoin-node-1',
  chainId: 'bitcoin-mainnet',
  name: 'Bitcoin RPC 1',
  url: 'https://bitcoin-rpc-1.example.com',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

const _bitcoinNode2 = RpcNode(
  id: 'bitcoin-node-2',
  chainId: 'bitcoin-mainnet',
  name: 'Bitcoin RPC 2',
  url: 'https://bitcoin-rpc-2.example.com',
  nodeType: RpcNodeType.custom,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

final class _FakeChainRepository implements ChainRepository {
  String selectedChainId = 'ethereum';

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

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
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
  RpcNode selectedNode = _node1;
  final _selectedNodesByChainId = <String, RpcNode>{};

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    return switch (chain.chainType) {
      ChainType.bitcoin => [_bitcoinNode1, _bitcoinNode2],
      _ => [_node1, _node2],
    };
  }

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async {
    return _selectedNodesByChainId[chain.chainId] ??
        switch (chain.chainType) {
          ChainType.bitcoin => _bitcoinNode1,
          _ => selectedNode,
        };
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
  }) async {
    final nodes = await getNodesForChain(chain);
    final selected = nodes.firstWhere((node) => node.id == nodeId);
    _selectedNodesByChainId[chain.chainId] = selected;
    if (chain.chainType != ChainType.bitcoin) {
      selectedNode = selected;
    }
    return selected;
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

final class _RecordingAssetRepository implements AssetRepository {
  final nodes = <RpcNode>[];
  final requests = <_RecordedAssetRequest>[];

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    nodes.add(rpcNode);
    requests.add(
      _RecordedAssetRequest(
        chain: chain,
        rpcNode: rpcNode,
        walletAddress: account.addressForChainType(chain.chainType),
      ),
    );
    return AssetPortfolio.loaded([
      AssetBalance(
        chainId: chain.chainId,
        token: TokenInfo(
          chainId: chain.chainId,
          contractAddress: null,
          symbol: chain.symbol,
          name: chain.name,
          decimals: switch (chain.chainType) {
            ChainType.evm => 18,
            ChainType.bitcoin => 8,
            ChainType.tron => 6,
            ChainType.solana => 9,
            ChainType.sui => 9,
          },
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

final class _RecordedAssetRequest {
  const _RecordedAssetRequest({
    required this.chain,
    required this.rpcNode,
    required this.walletAddress,
  });

  final ChainConfig chain;
  final RpcNode rpcNode;
  final String walletAddress;
}

final class _RecordingEvmFeeService implements EvmFeeService {
  final calls = <String>[];

  @override
  Future<EvmFeeEstimate> estimateTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required TransactionType transactionType,
    required BigInt amountInWei,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  }) async {
    calls.add(rpcUrl);
    return EvmFeeEstimate.eip1559(
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    );
  }
}

final class _RecordingEvmTransactionService implements EvmTransactionService {
  final calls = <EvmTransactionBroadcastInput>[];

  @override
  Future<String> signAndBroadcast(EvmTransactionBroadcastInput input) async {
    calls.add(input);
    return '0xhash';
  }
}

final class _NeverCalledSolanaTransactionService
    implements SolanaTransactionService {
  @override
  Future<String> signAndBroadcast(SolanaTransactionBroadcastInput input) {
    throw StateError('Solana service should not be called');
  }
}

final class _RecordingTransactionHistoryRepository
    implements TransactionHistoryRepository {
  final savedRecords = <TransactionRecord>[];

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return savedRecords;
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return savedRecords.take(limit).toList(growable: false);
  }

  @override
  Future<void> save(TransactionRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {
    final index = savedRecords.indexWhere((record) => record.id == id);
    if (index == -1) {
      return;
    }
    final previous = savedRecords[index];
    savedRecords[index] = TransactionRecord(
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

final class _FakeWalletRepository implements WalletRepository {
  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

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
  }) async {
    return WalletKeyMaterial(
      evmPrivateKey:
          '1111111111111111111111111111111111111111111111111111111111111111',
    );
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
  }) async {
    return WalletUnlockResult(account: _account, walletDek: [1, 2, 3, 4]);
  }
}
