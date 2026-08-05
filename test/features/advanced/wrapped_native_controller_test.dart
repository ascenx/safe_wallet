import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/application/wrapped_native_controller.dart';
import 'package:safe_wallet/features/advanced/data/evm_wrapped_native_gateway.dart';
import 'package:safe_wallet/features/advanced/data/solana_wrapped_native_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/wrapped_native_models.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;
import 'package:web3dart/web3dart.dart' as web3;

void main() {
  final ethereum = defaultChains.firstWhere((chain) => chain.chainId == '1');
  final solanaMainnet = defaultChains.firstWhere(
    (chain) => chain.chainId == 'mainnet-beta',
  );
  const evmPrivateKey =
      '4f3edf983ac63ad7c19c5878a1f4c8f365f46b29a6606658049c3d7ad4a3d0a1';
  final evmAddress = web3.EthPrivateKey.fromHex(evmPrivateKey).address.with0x;
  final solanaKeypair = solana.Keypair.generate();
  late WalletAccount wallet;

  setUp(() {
    wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: evmAddress,
      solanaAddress: solanaKeypair.publicKey.toBase58(),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  });

  ProviderContainer buildContainer({
    required _FakeEvmWrappedNativeGateway evmGateway,
    required _FakeSolanaWrappedNativeGateway solanaGateway,
    String? defaultNetworkId,
    _MemoryTransactionHistoryRepository? history,
    InMemorySecurityLogRepository? securityLogs,
    bool unlockFails = false,
    bool missingEvmKey = false,
  }) {
    final historyRepository = history ?? _MemoryTransactionHistoryRepository();
    final securityRepository = securityLogs ?? InMemorySecurityLogRepository();
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _FakeWalletRepository(
            wallets: [wallet],
            evmPrivateKey: missingEvmKey ? null : evmPrivateKey,
            solanaPrivateKey: solanaKeypair.secretKey,
            unlockFails: unlockFails,
          ),
        ),
        selectedWalletStoreProvider.overrideWithValue(
          _SelectedWalletStore(wallet.id),
        ),
        chainRepositoryProvider.overrideWithValue(
          _FakeChainRepository([ethereum, solanaMainnet]),
        ),
        wrappedNativeDefaultNetworkIdProvider.overrideWithValue(
          () async => defaultNetworkId ?? ethereum.id,
        ),
        wrappedNativeRpcNodeResolverProvider.overrideWithValue(
          (chain) async => RpcNode(
            id: 'node-${chain.id}',
            chainId: chain.chainId,
            name: chain.name,
            url: chain.rpcUrls.first,
            nodeType: RpcNodeType.defaultNode,
            isSelected: true,
            lastTestStatus: RpcNodeTestStatus.available,
          ),
        ),
        evmWrappedNativeGatewayProvider.overrideWithValue(evmGateway),
        solanaWrappedNativeGatewayProvider.overrideWithValue(solanaGateway),
        transactionHistoryRepositoryProvider.overrideWithValue(
          historyRepository,
        ),
        securityLogRepositoryProvider.overrideWithValue(securityRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads balances for the current supported wallet and network', () async {
    final evmGateway = _FakeEvmWrappedNativeGateway(
      balances: EvmWrappedNativeBalances(
        nativeBalance: BigInt.from(10),
        wrappedBalance: BigInt.from(4),
      ),
    );
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
    );

    final state = await container.read(wrappedNativeControllerProvider.future);

    expect(state.status, WrappedNativeStatus.ready);
    expect(state.selectedWalletId, wallet.id);
    expect(state.selectedNetworkId, ethereum.id);
    expect(state.nativeBalanceInBaseUnits, BigInt.from(10));
    expect(state.wrappedBalanceInBaseUnits, BigInt.from(4));
  });

  test(
    'clears previous network balances when the new network load fails',
    () async {
      final evmGateway = _FakeEvmWrappedNativeGateway(
        balances: EvmWrappedNativeBalances(
          nativeBalance: BigInt.parse('19336009684868670'),
          wrappedBalance: BigInt.parse('2102181364932900'),
        ),
      );
      final container = buildContainer(
        evmGateway: evmGateway,
        solanaGateway: _FakeSolanaWrappedNativeGateway(
          loadError: StateError('rpc_unavailable'),
        ),
      );
      await container.read(wrappedNativeControllerProvider.future);

      await container
          .read(wrappedNativeControllerProvider.notifier)
          .selectNetwork(solanaMainnet.id);

      final state = container
          .read(wrappedNativeControllerProvider)
          .requireValue;
      expect(state.selectedNetworkId, solanaMainnet.id);
      expect(state.nativeBalanceInBaseUnits, BigInt.zero);
      expect(state.wrappedBalanceInBaseUnits, BigInt.zero);
      expect(state.error, WrappedNativeError.balanceLoadFailed);
    },
  );

  test('wrap preparation reserves the maximum EVM fee', () async {
    final evmGateway = _FakeEvmWrappedNativeGateway(
      balances: EvmWrappedNativeBalances(
        nativeBalance: BigInt.from(1000),
        wrappedBalance: BigInt.zero,
      ),
      preparation: EvmWrappedNativePreparation(
        call: EvmWrappedNativeCall(
          contractAddress: wrappedNativeConfigFor(
            ethereum,
          )!.wrappedAssetAddress,
          calldata: '0xd0e30db0',
          valueWei: BigInt.from(800),
        ),
        feeModel: EvmWrappedNativeFeeModel.legacy,
        gasLimit: BigInt.from(10),
        gasPriceWei: BigInt.from(30),
      ),
    );
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
    );
    await container.read(wrappedNativeControllerProvider.future);

    await container
        .read(wrappedNativeControllerProvider.notifier)
        .prepareBaseUnits(BigInt.from(800));

    final state = container.read(wrappedNativeControllerProvider).requireValue;
    expect(state.status, WrappedNativeStatus.ready);
    expect(state.error, WrappedNativeError.insufficientNativeBalance);
    expect(state.preparation, isNull);
  });

  test('maximum wrap amount reserves the estimated EVM fee', () async {
    final evmGateway = _FakeEvmWrappedNativeGateway(
      balances: EvmWrappedNativeBalances(
        nativeBalance: BigInt.from(1000),
        wrappedBalance: BigInt.zero,
      ),
      preparation: EvmWrappedNativePreparation(
        call: EvmWrappedNativeCall(
          contractAddress: wrappedNativeConfigFor(
            ethereum,
          )!.wrappedAssetAddress,
          calldata: '0xd0e30db0',
          valueWei: BigInt.one,
        ),
        feeModel: EvmWrappedNativeFeeModel.legacy,
        gasLimit: BigInt.from(10),
        gasPriceWei: BigInt.from(30),
      ),
    );
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
    );
    await container.read(wrappedNativeControllerProvider.future);

    final maximum = await container
        .read(wrappedNativeControllerProvider.notifier)
        .prepareMaximum();

    expect(maximum, BigInt.from(700));
    expect(evmGateway.prepareCalls, 2);
    expect(
      container
          .read(wrappedNativeControllerProvider)
          .requireValue
          .amountInBaseUnits,
      BigInt.from(700),
    );
  });

  test('routes Solana preparation through the WSOL gateway', () async {
    final solanaGateway = _FakeSolanaWrappedNativeGateway(
      balances: SolanaWrappedNativeBalances(
        solBalanceLamports: BigInt.from(5000000),
        wrappedAccounts: const [],
        associatedTokenAccountExists: false,
      ),
      preparation: SolanaWrappedNativePreparation(
        operation: WrappedNativeOperation.wrap,
        amountLamports: BigInt.from(1000000),
        networkFeeLamports: BigInt.from(5000),
        accountRentLamports: BigInt.from(2039280),
        solBalanceLamports: BigInt.from(5000000),
        wrappedBalanceLamports: BigInt.zero,
        associatedTokenAccountExists: false,
        isFullUnwrap: false,
      ),
    );
    final container = buildContainer(
      evmGateway: _FakeEvmWrappedNativeGateway(),
      solanaGateway: solanaGateway,
      defaultNetworkId: solanaMainnet.id,
    );
    await container.read(wrappedNativeControllerProvider.future);

    await container
        .read(wrappedNativeControllerProvider.notifier)
        .prepareBaseUnits(BigInt.from(1000000));

    final state = container.read(wrappedNativeControllerProvider).requireValue;
    expect(state.preparation?.networkFeeInBaseUnits, BigInt.from(5000));
    expect(state.preparation?.accountRentInBaseUnits, BigInt.from(2039280));
    expect(solanaGateway.prepareCalls, 1);
  });

  test(
    'deduplicates submit and records wrap history and security log',
    () async {
      final submitCompleter = Completer<String>();
      final history = _MemoryTransactionHistoryRepository();
      final securityLogs = InMemorySecurityLogRepository();
      final evmGateway = _FakeEvmWrappedNativeGateway(
        balances: EvmWrappedNativeBalances(
          nativeBalance: BigInt.from(1000),
          wrappedBalance: BigInt.zero,
        ),
        preparation: EvmWrappedNativePreparation(
          call: EvmWrappedNativeCall(
            contractAddress: wrappedNativeConfigFor(
              ethereum,
            )!.wrappedAssetAddress,
            calldata: '0xd0e30db0',
            valueWei: BigInt.from(500),
          ),
          feeModel: EvmWrappedNativeFeeModel.legacy,
          gasLimit: BigInt.from(10),
          gasPriceWei: BigInt.from(10),
        ),
        submitHandler: () => submitCompleter.future,
      );
      final container = buildContainer(
        evmGateway: evmGateway,
        solanaGateway: _FakeSolanaWrappedNativeGateway(),
        history: history,
        securityLogs: securityLogs,
      );
      await container.read(wrappedNativeControllerProvider.future);
      final controller = container.read(
        wrappedNativeControllerProvider.notifier,
      );
      await controller.prepareBaseUnits(BigInt.from(500));

      final first = controller.submit(signingPassword: 'password');
      final second = controller.submit(signingPassword: 'password');
      await Future<void>.delayed(Duration.zero);
      expect(evmGateway.submitCalls, 1);
      submitCompleter.complete('0xhash');
      expect(await first, '0xhash');
      expect(await second, '0xhash');

      expect(history.records.single.operation, TransactionOperation.wrap);
      expect(history.records.single.resource, 'WETH');
      final logs = await securityLogs.listEntries();
      expect(logs.single.type, SecurityLogEventType.wrapNative);
      expect(
        container.read(wrappedNativeControllerProvider).requireValue.status,
        WrappedNativeStatus.success,
      );
    },
  );

  test('unwrap preparation requires native balance for fees', () async {
    final evmGateway = _FakeEvmWrappedNativeGateway(
      balances: EvmWrappedNativeBalances(
        nativeBalance: BigInt.from(50),
        wrappedBalance: BigInt.from(1000),
      ),
      preparation: EvmWrappedNativePreparation(
        call: EvmWrappedNativeCall(
          contractAddress: wrappedNativeConfigFor(
            ethereum,
          )!.wrappedAssetAddress,
          calldata:
              '0x2e1a7d4d${BigInt.from(500).toRadixString(16).padLeft(64, '0')}',
          valueWei: BigInt.zero,
        ),
        feeModel: EvmWrappedNativeFeeModel.legacy,
        gasLimit: BigInt.from(10),
        gasPriceWei: BigInt.from(10),
      ),
    );
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
    );
    await container.read(wrappedNativeControllerProvider.future);
    final controller = container.read(wrappedNativeControllerProvider.notifier);
    controller.selectOperation(WrappedNativeOperation.unwrap);

    await controller.prepareBaseUnits(BigInt.from(500));

    final result = container.read(wrappedNativeControllerProvider).requireValue;
    expect(result.error, WrappedNativeError.insufficientNativeBalance);
    expect(result.preparation, isNull);
  });

  test('rejects zero amount without calling the gateway', () async {
    final evmGateway = _FakeEvmWrappedNativeGateway();
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
    );
    await container.read(wrappedNativeControllerProvider.future);

    await container
        .read(wrappedNativeControllerProvider.notifier)
        .prepareBaseUnits(BigInt.zero);

    expect(evmGateway.prepareCalls, 0);
    expect(
      container.read(wrappedNativeControllerProvider).requireValue.error,
      WrappedNativeError.invalidAmount,
    );
  });

  test('maps wallet unlock failure without broadcasting', () async {
    final evmGateway = _submittableGateway(ethereum);
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
      unlockFails: true,
    );
    await container.read(wrappedNativeControllerProvider.future);
    final controller = container.read(wrappedNativeControllerProvider.notifier);
    await controller.prepareBaseUnits(BigInt.from(500));

    final hash = await controller.submit(signingPassword: 'wrong');

    expect(hash, isNull);
    expect(evmGateway.submitCalls, 0);
    expect(
      container.read(wrappedNativeControllerProvider).requireValue.error,
      WrappedNativeError.walletLocked,
    );
  });

  test('rejects a wallet without an EVM signing key', () async {
    final evmGateway = _submittableGateway(ethereum);
    final container = buildContainer(
      evmGateway: evmGateway,
      solanaGateway: _FakeSolanaWrappedNativeGateway(),
      missingEvmKey: true,
    );
    await container.read(wrappedNativeControllerProvider.future);
    final controller = container.read(wrappedNativeControllerProvider.notifier);
    await controller.prepareBaseUnits(BigInt.from(500));

    final hash = await controller.submit(signingPassword: 'password');

    expect(hash, isNull);
    expect(evmGateway.submitCalls, 0);
    expect(
      container.read(wrappedNativeControllerProvider).requireValue.error,
      WrappedNativeError.signingKeyUnavailable,
    );
  });

  test(
    'keeps broadcast success when local history persistence fails',
    () async {
      final evmGateway = _submittableGateway(ethereum);
      final container = buildContainer(
        evmGateway: evmGateway,
        solanaGateway: _FakeSolanaWrappedNativeGateway(),
        history: _ThrowingTransactionHistoryRepository(),
      );
      await container.read(wrappedNativeControllerProvider.future);
      final controller = container.read(
        wrappedNativeControllerProvider.notifier,
      );
      await controller.prepareBaseUnits(BigInt.from(500));

      final hash = await controller.submit(signingPassword: 'password');

      expect(hash, '0xhash');
      expect(evmGateway.submitCalls, 1);
      expect(
        container.read(wrappedNativeControllerProvider).requireValue.status,
        WrappedNativeStatus.success,
      );
    },
  );
}

_FakeEvmWrappedNativeGateway _submittableGateway(ChainConfig chain) {
  return _FakeEvmWrappedNativeGateway(
    balances: EvmWrappedNativeBalances(
      nativeBalance: BigInt.from(1000),
      wrappedBalance: BigInt.zero,
    ),
    preparation: EvmWrappedNativePreparation(
      call: EvmWrappedNativeCall(
        contractAddress: wrappedNativeConfigFor(chain)!.wrappedAssetAddress,
        calldata: '0xd0e30db0',
        valueWei: BigInt.from(500),
      ),
      feeModel: EvmWrappedNativeFeeModel.legacy,
      gasLimit: BigInt.from(10),
      gasPriceWei: BigInt.from(10),
    ),
  );
}

final class _FakeEvmWrappedNativeGateway implements EvmWrappedNativeGateway {
  _FakeEvmWrappedNativeGateway({
    EvmWrappedNativeBalances? balances,
    this.preparation,
    this.submitHandler,
  }) : balances =
           balances ??
           EvmWrappedNativeBalances(
             nativeBalance: BigInt.zero,
             wrappedBalance: BigInt.zero,
           );

  final EvmWrappedNativeBalances balances;
  final EvmWrappedNativePreparation? preparation;
  final Future<String> Function()? submitHandler;
  int prepareCalls = 0;
  int submitCalls = 0;

  @override
  Future<EvmWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    Map<String, String> headers = const {},
  }) async => balances;

  @override
  Future<EvmWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    required WrappedNativeOperation operation,
    required BigInt amountInBaseUnits,
    Map<String, String> headers = const {},
  }) async {
    prepareCalls += 1;
    return preparation!;
  }

  @override
  Future<String> submit({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String privateKey,
    required EvmWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  }) async {
    submitCalls += 1;
    return submitHandler?.call() ?? '0xhash';
  }
}

final class _FakeSolanaWrappedNativeGateway
    implements SolanaWrappedNativeGateway {
  _FakeSolanaWrappedNativeGateway({
    SolanaWrappedNativeBalances? balances,
    this.preparation,
    this.loadError,
  }) : balances =
           balances ??
           SolanaWrappedNativeBalances(
             solBalanceLamports: BigInt.zero,
             wrappedAccounts: const [],
             associatedTokenAccountExists: false,
           );

  final SolanaWrappedNativeBalances balances;
  final SolanaWrappedNativePreparation? preparation;
  final Object? loadError;
  int prepareCalls = 0;

  @override
  Future<SolanaWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String ownerAddress,
    Map<String, String> headers = const {},
  }) async {
    if (loadError case final error?) {
      throw error;
    }
    return balances;
  }

  @override
  Future<SolanaWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String ownerAddress,
    required WrappedNativeOperation operation,
    required BigInt amountLamports,
    Map<String, String> headers = const {},
  }) async {
    prepareCalls += 1;
    return preparation!;
  }

  @override
  Future<String> submit({
    required String rpcUrl,
    required String ownerAddress,
    required List<int> privateKey,
    required SolanaWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  }) async => 'signature';
}

final class _MemoryTransactionHistoryRepository
    implements TransactionHistoryRepository {
  final records = <TransactionRecord>[];

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async => records;

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return records.take(limit).toList();
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
  }) async {}
}

final class _ThrowingTransactionHistoryRepository
    extends _MemoryTransactionHistoryRepository {
  @override
  Future<void> save(TransactionRecord record) async {
    throw StateError('storage_unavailable');
  }
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({
    required this.wallets,
    required this.evmPrivateKey,
    required this.solanaPrivateKey,
    this.unlockFails = false,
  });

  final List<WalletAccount> wallets;
  final String? evmPrivateKey;
  final List<int> solanaPrivateKey;
  final bool unlockFails;

  @override
  Future<List<WalletAccount>> getWallets() async => wallets;

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    if (unlockFails) throw StateError('invalid_password');
    return WalletUnlockResult(account: wallets.single, walletDek: [1, 2, 3]);
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    return WalletKeyMaterial(
      evmPrivateKey: evmPrivateKey,
      solanaPrivateKey: solanaPrivateKey,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SelectedWalletStore implements SelectedWalletStore {
  const _SelectedWalletStore(this.walletId);

  final String walletId;

  @override
  String? readSelectedWalletId() => walletId;

  @override
  Future<void> writeSelectedWalletId(String? walletId) async {}
}

final class _FakeChainRepository implements ChainRepository {
  const _FakeChainRepository(this.chains);

  final List<ChainConfig> chains;

  @override
  Future<List<ChainConfig>> getChains() async => chains;

  @override
  Future<ChainConfig> getSelectedChain() async => chains.first;

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    return chains.firstWhere((chain) => chain.id == chainId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
