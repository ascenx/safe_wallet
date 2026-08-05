import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/application/asset_portfolio_provider.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../settings/application/security_log_recorder.dart';
import '../../settings/domain/security_log_entry.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../transfer/domain/transaction_record.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_account.dart';
import '../data/evm_wrapped_native_gateway.dart';
import '../data/solana_wrapped_native_gateway.dart';
import '../domain/wrapped_native_models.dart';

typedef WrappedNativeDefaultNetworkId = Future<String?> Function();
typedef WrappedNativeRpcNodeResolver =
    Future<RpcNode> Function(ChainConfig chain);

final evmWrappedNativeGatewayProvider = Provider<EvmWrappedNativeGateway>(
  (ref) => DefaultEvmWrappedNativeGateway(),
);

final solanaWrappedNativeGatewayProvider = Provider<SolanaWrappedNativeGateway>(
  (ref) => const DefaultSolanaWrappedNativeGateway(),
);

final wrappedNativeDefaultNetworkIdProvider =
    Provider<WrappedNativeDefaultNetworkId>((ref) {
      return () async {
        try {
          return (await ref.read(selectedChainControllerProvider.future)).id;
        } catch (_) {
          return null;
        }
      };
    });

final wrappedNativeRpcNodeResolverProvider =
    Provider<WrappedNativeRpcNodeResolver>((ref) {
      return (chain) => ref.read(selectedResolvedRpcNodeProvider(chain).future);
    });

final wrappedNativeControllerProvider =
    AsyncNotifierProvider<WrappedNativeController, WrappedNativeState>(
      WrappedNativeController.new,
    );

enum WrappedNativeStatus { loading, ready, preparing, submitting, success }

enum WrappedNativeError {
  noWallet,
  noNetwork,
  invalidAmount,
  insufficientNativeBalance,
  insufficientWrappedBalance,
  balanceLoadFailed,
  preparationFailed,
  walletLocked,
  signingKeyUnavailable,
  submissionFailed,
}

final class WrappedNativePreparationSummary {
  const WrappedNativePreparationSummary({
    required this.networkFeeInBaseUnits,
    required this.accountRentInBaseUnits,
  });

  final BigInt networkFeeInBaseUnits;
  final BigInt accountRentInBaseUnits;
}

final class WrappedNativeState {
  WrappedNativeState({
    required List<WalletAccount> wallets,
    required List<ChainConfig> networks,
    required this.selectedWalletId,
    required this.selectedNetworkId,
    this.operation = WrappedNativeOperation.wrap,
    this.status = WrappedNativeStatus.loading,
    BigInt? nativeBalanceInBaseUnits,
    BigInt? wrappedBalanceInBaseUnits,
    this.amountInBaseUnits,
    this.preparation,
    this.transactionHash,
    this.error,
  }) : wallets = List.unmodifiable(wallets),
       networks = List.unmodifiable(networks),
       nativeBalanceInBaseUnits = nativeBalanceInBaseUnits ?? BigInt.zero,
       wrappedBalanceInBaseUnits = wrappedBalanceInBaseUnits ?? BigInt.zero;

  final List<WalletAccount> wallets;
  final List<ChainConfig> networks;
  final String? selectedWalletId;
  final String? selectedNetworkId;
  final WrappedNativeOperation operation;
  final WrappedNativeStatus status;
  final BigInt nativeBalanceInBaseUnits;
  final BigInt wrappedBalanceInBaseUnits;
  final BigInt? amountInBaseUnits;
  final WrappedNativePreparationSummary? preparation;
  final String? transactionHash;
  final WrappedNativeError? error;

  WalletAccount? get selectedWallet =>
      wallets.where((wallet) => wallet.id == selectedWalletId).firstOrNull;

  ChainConfig? get selectedNetwork =>
      networks.where((network) => network.id == selectedNetworkId).firstOrNull;

  WrappedNativeConfig? get config {
    final network = selectedNetwork;
    return network == null ? null : wrappedNativeConfigFor(network);
  }

  BigInt get spendableBalanceInBaseUnits =>
      operation == WrappedNativeOperation.wrap
      ? nativeBalanceInBaseUnits
      : wrappedBalanceInBaseUnits;

  WrappedNativeState copyWith({
    String? selectedWalletId,
    bool clearSelectedWalletId = false,
    String? selectedNetworkId,
    WrappedNativeOperation? operation,
    WrappedNativeStatus? status,
    BigInt? nativeBalanceInBaseUnits,
    BigInt? wrappedBalanceInBaseUnits,
    BigInt? amountInBaseUnits,
    bool clearAmount = false,
    WrappedNativePreparationSummary? preparation,
    bool clearPreparation = false,
    String? transactionHash,
    bool clearTransactionHash = false,
    WrappedNativeError? error,
    bool clearError = false,
  }) {
    return WrappedNativeState(
      wallets: wallets,
      networks: networks,
      selectedWalletId: clearSelectedWalletId
          ? null
          : selectedWalletId ?? this.selectedWalletId,
      selectedNetworkId: selectedNetworkId ?? this.selectedNetworkId,
      operation: operation ?? this.operation,
      status: status ?? this.status,
      nativeBalanceInBaseUnits:
          nativeBalanceInBaseUnits ?? this.nativeBalanceInBaseUnits,
      wrappedBalanceInBaseUnits:
          wrappedBalanceInBaseUnits ?? this.wrappedBalanceInBaseUnits,
      amountInBaseUnits: clearAmount
          ? null
          : amountInBaseUnits ?? this.amountInBaseUnits,
      preparation: clearPreparation ? null : preparation ?? this.preparation,
      transactionHash: clearTransactionHash
          ? null
          : transactionHash ?? this.transactionHash,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final class WrappedNativeController extends AsyncNotifier<WrappedNativeState> {
  Future<String?>? _submissionInFlight;
  int _loadGeneration = 0;
  Object? _gatewayPreparation;
  RpcNode? _preparedRpcNode;

  @override
  Future<WrappedNativeState> build() async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    final networks = (await ref.read(availableChainsProvider.future))
        .where((chain) => wrappedNativeConfigFor(chain) != null)
        .toList(growable: false);
    final selectedWalletId = ref.watch(selectedWalletIdProvider);
    final defaultNetworkId = await ref.read(
      wrappedNativeDefaultNetworkIdProvider,
    )();
    final selectedNetwork =
        networks
            .where((network) => network.id == defaultNetworkId)
            .firstOrNull ??
        networks.where((network) => !network.isTestnet).firstOrNull ??
        networks.firstOrNull;
    final compatibleWallets = selectedNetwork == null
        ? const <WalletAccount>[]
        : wallets
              .where((wallet) => _walletSupports(wallet, selectedNetwork))
              .toList(growable: false);
    final initial = WrappedNativeState(
      wallets: wallets,
      networks: networks,
      selectedWalletId:
          compatibleWallets.any((wallet) => wallet.id == selectedWalletId)
          ? selectedWalletId
          : compatibleWallets.firstOrNull?.id,
      selectedNetworkId: selectedNetwork?.id,
    );
    return _loadBalances(initial);
  }

  Future<void> refresh() async {
    if (!state.hasValue) return;
    final current = state.requireValue;
    if (_isBusy(current)) return;
    _clearPreparation();
    state = AsyncData(current.copyWith(status: WrappedNativeStatus.loading));
    state = AsyncData(await _loadBalances(current));
  }

  Future<void> selectWallet(String walletId) async {
    final current = state.requireValue;
    final network = current.selectedNetwork;
    if (_isBusy(current) ||
        network == null ||
        !current.wallets.any(
          (wallet) => wallet.id == walletId && _walletSupports(wallet, network),
        )) {
      return;
    }
    _clearPreparation();
    final next = current.copyWith(
      selectedWalletId: walletId,
      status: WrappedNativeStatus.loading,
      clearAmount: true,
      clearPreparation: true,
      clearTransactionHash: true,
      clearError: true,
    );
    state = AsyncData(next);
    state = AsyncData(await _loadBalances(next));
  }

  Future<void> selectNetwork(String networkId) async {
    final current = state.requireValue;
    if (_isBusy(current) ||
        !current.networks.any((network) => network.id == networkId)) {
      return;
    }
    final network = current.networks.firstWhere(
      (candidate) => candidate.id == networkId,
    );
    final selectedWalletId =
        current.selectedWallet != null &&
            _walletSupports(current.selectedWallet!, network)
        ? current.selectedWalletId
        : current.wallets
              .where((wallet) => _walletSupports(wallet, network))
              .firstOrNull
              ?.id;
    _clearPreparation();
    final next = current.copyWith(
      selectedNetworkId: networkId,
      selectedWalletId: selectedWalletId,
      clearSelectedWalletId: selectedWalletId == null,
      status: WrappedNativeStatus.loading,
      nativeBalanceInBaseUnits: BigInt.zero,
      wrappedBalanceInBaseUnits: BigInt.zero,
      clearAmount: true,
      clearPreparation: true,
      clearTransactionHash: true,
      clearError: true,
    );
    state = AsyncData(next);
    state = AsyncData(await _loadBalances(next));
  }

  void selectOperation(WrappedNativeOperation operation) {
    final current = state.requireValue;
    if (_isBusy(current) || current.operation == operation) return;
    _clearPreparation();
    state = AsyncData(
      current.copyWith(
        operation: operation,
        status: WrappedNativeStatus.ready,
        clearAmount: true,
        clearPreparation: true,
        clearTransactionHash: true,
        clearError: true,
      ),
    );
  }

  void clearPreparation() {
    final current = state.requireValue;
    if (_isBusy(current) ||
        (current.preparation == null &&
            current.error == null &&
            current.transactionHash == null &&
            current.amountInBaseUnits == null)) {
      return;
    }
    _clearPreparation();
    state = AsyncData(
      current.copyWith(
        status: WrappedNativeStatus.ready,
        clearAmount: true,
        clearPreparation: true,
        clearTransactionHash: true,
        clearError: true,
      ),
    );
  }

  Future<void> prepareBaseUnits(BigInt amountInBaseUnits) async {
    final current = state.requireValue;
    if (_isBusy(current)) return;
    if (amountInBaseUnits <= BigInt.zero) {
      _setError(current, WrappedNativeError.invalidAmount);
      return;
    }
    final wallet = current.selectedWallet;
    final network = current.selectedNetwork;
    final config = current.config;
    if (wallet == null) {
      _setError(current, WrappedNativeError.noWallet);
      return;
    }
    if (network == null || config == null) {
      _setError(current, WrappedNativeError.noNetwork);
      return;
    }
    if (current.operation == WrappedNativeOperation.wrap &&
        amountInBaseUnits > current.nativeBalanceInBaseUnits) {
      _setError(current, WrappedNativeError.insufficientNativeBalance);
      return;
    }
    if (current.operation == WrappedNativeOperation.unwrap &&
        amountInBaseUnits > current.wrappedBalanceInBaseUnits) {
      _setError(current, WrappedNativeError.insufficientWrappedBalance);
      return;
    }
    state = AsyncData(
      current.copyWith(
        status: WrappedNativeStatus.preparing,
        amountInBaseUnits: amountInBaseUnits,
        clearPreparation: true,
        clearTransactionHash: true,
        clearError: true,
      ),
    );
    try {
      final rpcNode = await ref.read(wrappedNativeRpcNodeResolverProvider)(
        network,
      );
      final Object preparation;
      final WrappedNativePreparationSummary summary;
      if (network.chainType == ChainType.evm) {
        final value = await ref
            .read(evmWrappedNativeGatewayProvider)
            .prepare(
              rpcUrl: rpcNode.endpointUrl,
              headers: rpcNode.endpointHeaders,
              fromAddress: wallet.evmAddress,
              config: config,
              operation: current.operation,
              amountInBaseUnits: amountInBaseUnits,
            );
        if (current.operation == WrappedNativeOperation.wrap &&
            amountInBaseUnits + value.maximumFeeWei >
                current.nativeBalanceInBaseUnits) {
          _clearPreparation();
          _setError(current, WrappedNativeError.insufficientNativeBalance);
          return;
        }
        if (current.operation == WrappedNativeOperation.unwrap &&
            value.maximumFeeWei > current.nativeBalanceInBaseUnits) {
          _clearPreparation();
          _setError(current, WrappedNativeError.insufficientNativeBalance);
          return;
        }
        preparation = value;
        summary = WrappedNativePreparationSummary(
          networkFeeInBaseUnits: value.maximumFeeWei,
          accountRentInBaseUnits: BigInt.zero,
        );
      } else {
        final value = await ref
            .read(solanaWrappedNativeGatewayProvider)
            .prepare(
              rpcUrl: rpcNode.endpointUrl,
              headers: rpcNode.endpointHeaders,
              ownerAddress: wallet.solanaAddress,
              operation: current.operation,
              amountLamports: amountInBaseUnits,
            );
        preparation = value;
        summary = WrappedNativePreparationSummary(
          networkFeeInBaseUnits: value.networkFeeLamports,
          accountRentInBaseUnits: value.accountRentLamports,
        );
      }
      _gatewayPreparation = preparation;
      _preparedRpcNode = rpcNode;
      state = AsyncData(
        state.requireValue.copyWith(
          status: WrappedNativeStatus.ready,
          amountInBaseUnits: amountInBaseUnits,
          preparation: summary,
          clearError: true,
        ),
      );
    } catch (_) {
      _clearPreparation();
      _setError(state.requireValue, WrappedNativeError.preparationFailed);
    }
  }

  Future<BigInt?> prepareMaximum() async {
    final current = state.requireValue;
    if (_isBusy(current)) return null;
    if (current.operation == WrappedNativeOperation.unwrap) {
      final maximum = current.wrappedBalanceInBaseUnits;
      await prepareBaseUnits(maximum);
      return state.requireValue.preparation == null ? null : maximum;
    }
    if (current.nativeBalanceInBaseUnits <= BigInt.one) {
      _setError(current, WrappedNativeError.insufficientNativeBalance);
      return null;
    }
    await prepareBaseUnits(BigInt.one);
    final first = state.requireValue;
    final summary = first.preparation;
    if (summary == null) return null;
    final maximum =
        first.nativeBalanceInBaseUnits -
        summary.networkFeeInBaseUnits -
        summary.accountRentInBaseUnits;
    if (maximum <= BigInt.zero) {
      _clearPreparation();
      _setError(first, WrappedNativeError.insufficientNativeBalance);
      return null;
    }
    await prepareBaseUnits(maximum);
    return state.requireValue.preparation == null ? null : maximum;
  }

  Future<String?> submit({
    String? signingPassword,
    bool rememberSigningPassword = true,
  }) {
    final inFlight = _submissionInFlight;
    if (inFlight != null) return inFlight;
    final future = _submit(
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    _submissionInFlight = future;
    unawaited(future.whenComplete(() => _submissionInFlight = null));
    return future;
  }

  Future<String?> _submit({
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    final current = state.requireValue;
    final wallet = current.selectedWallet;
    final network = current.selectedNetwork;
    final config = current.config;
    final amount = current.amountInBaseUnits;
    final rpcNode = _preparedRpcNode;
    final preparation = _gatewayPreparation;
    if (current.preparation == null ||
        wallet == null ||
        network == null ||
        config == null ||
        amount == null ||
        rpcNode == null ||
        preparation == null) {
      return null;
    }
    state = AsyncData(
      current.copyWith(
        status: WrappedNativeStatus.submitting,
        clearError: true,
      ),
    );
    try {
      final WalletKeyMaterial? keyMaterial;
      try {
        keyMaterial = await _readKeyMaterial(
          wallet.id,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
        );
      } catch (_) {
        _setError(current, WrappedNativeError.walletLocked);
        return null;
      }
      if (keyMaterial == null) {
        _setError(current, WrappedNativeError.walletLocked);
        return null;
      }
      final String hash;
      if (network.chainType == ChainType.evm) {
        final privateKey = keyMaterial.evmPrivateKey;
        if (privateKey == null || privateKey.isEmpty) {
          _setError(current, WrappedNativeError.signingKeyUnavailable);
          return null;
        }
        hash = await ref
            .read(evmWrappedNativeGatewayProvider)
            .submit(
              rpcUrl: rpcNode.endpointUrl,
              headers: rpcNode.endpointHeaders,
              chainId: int.parse(network.chainId),
              fromAddress: wallet.evmAddress,
              privateKey: privateKey,
              preparation: preparation as EvmWrappedNativePreparation,
            );
      } else {
        final privateKey = keyMaterial.solanaPrivateKey;
        if (privateKey == null) {
          _setError(current, WrappedNativeError.signingKeyUnavailable);
          return null;
        }
        hash = await ref
            .read(solanaWrappedNativeGatewayProvider)
            .submit(
              rpcUrl: rpcNode.endpointUrl,
              headers: rpcNode.endpointHeaders,
              ownerAddress: wallet.solanaAddress,
              privateKey: privateKey,
              preparation: preparation as SolanaWrappedNativePreparation,
            );
      }
      await _recordResult(
        hash: hash,
        wallet: wallet,
        network: network,
        config: config,
        operation: current.operation,
        amount: amount,
      );
      _clearPreparation();
      state = AsyncData(
        current.copyWith(
          status: WrappedNativeStatus.success,
          transactionHash: hash,
          clearError: true,
        ),
      );
      ref.invalidate(assetPortfolioProvider);
      ref.invalidate(transactionHistoryProvider(network.chainId));
      ref.invalidate(transactionHistoryProvider(null));
      ref.invalidate(recentTransactionsProvider);
      try {
        final refreshed = await _loadBalances(state.requireValue);
        state = AsyncData(
          refreshed.copyWith(
            status: WrappedNativeStatus.success,
            transactionHash: hash,
            clearError: true,
          ),
        );
      } catch (_) {
        // The transaction is already final; keep success visible.
      }
      return hash;
    } catch (_) {
      _setError(current, WrappedNativeError.submissionFailed);
      return null;
    }
  }

  Future<WrappedNativeState> _loadBalances(WrappedNativeState current) async {
    final generation = ++_loadGeneration;
    final wallet = current.selectedWallet;
    final network = current.selectedNetwork;
    final config = current.config;
    if (wallet == null) {
      return current.copyWith(
        status: WrappedNativeStatus.ready,
        error: WrappedNativeError.noWallet,
      );
    }
    if (network == null || config == null) {
      return current.copyWith(
        status: WrappedNativeStatus.ready,
        error: WrappedNativeError.noNetwork,
      );
    }
    try {
      final rpcNode = await ref.read(wrappedNativeRpcNodeResolverProvider)(
        network,
      );
      final BigInt nativeBalance;
      final BigInt wrappedBalance;
      if (network.chainType == ChainType.evm) {
        final balances = await ref
            .read(evmWrappedNativeGatewayProvider)
            .loadBalances(
              rpcUrl: rpcNode.endpointUrl,
              headers: rpcNode.endpointHeaders,
              fromAddress: wallet.evmAddress,
              config: config,
            );
        nativeBalance = balances.nativeBalance;
        wrappedBalance = balances.wrappedBalance;
      } else {
        final balances = await ref
            .read(solanaWrappedNativeGatewayProvider)
            .loadBalances(
              rpcUrl: rpcNode.endpointUrl,
              headers: rpcNode.endpointHeaders,
              ownerAddress: wallet.solanaAddress,
            );
        nativeBalance = balances.solBalanceLamports;
        wrappedBalance = balances.wrappedBalanceLamports;
      }
      if (generation != _loadGeneration) return current;
      return current.copyWith(
        status: WrappedNativeStatus.ready,
        nativeBalanceInBaseUnits: nativeBalance,
        wrappedBalanceInBaseUnits: wrappedBalance,
        clearPreparation: true,
        clearError: true,
      );
    } catch (_) {
      return current.copyWith(
        status: WrappedNativeStatus.ready,
        error: WrappedNativeError.balanceLoadFailed,
      );
    }
  }

  Future<WalletKeyMaterial?> _readKeyMaterial(
    String walletId, {
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    final cache = ref.read(sessionKeyCacheProvider);
    final now = DateTime.now().toUtc();
    var walletDek = cache.readKey(walletId, now: now);
    if (walletDek == null) {
      if (signingPassword == null || signingPassword.isEmpty) return null;
      final unlockResult = await ref
          .read(walletRepositoryProvider)
          .unlock(walletId: walletId, password: signingPassword);
      walletDek = unlockResult.walletDek;
      if (rememberSigningPassword) {
        cache.unlock(walletId: walletId, walletDek: walletDek, now: now);
      }
    } else {
      cache.touch(now: now);
    }
    return ref
        .read(walletRepositoryProvider)
        .readKeyMaterial(walletId: walletId, walletDek: walletDek);
  }

  Future<void> _recordResult({
    required String hash,
    required WalletAccount wallet,
    required ChainConfig network,
    required WrappedNativeConfig config,
    required WrappedNativeOperation operation,
    required BigInt amount,
  }) async {
    final amountText = formatWrappedNativeAmount(
      amount,
      decimals: config.decimals,
    );
    try {
      await ref
          .read(transactionHistoryRepositoryProvider)
          .save(
            TransactionRecord(
              id: '${network.chainId}:$hash',
              walletId: wallet.id,
              chainId: network.chainId,
              chainType: network.chainType,
              assetSymbol: operation == WrappedNativeOperation.wrap
                  ? config.nativeSymbol
                  : config.wrappedSymbol,
              direction: TransactionDirection.outgoing,
              amount: amountText,
              status: network.chainType == ChainType.solana
                  ? TransactionStatus.success
                  : TransactionStatus.submitted,
              transactionHash: hash,
              createdAt: DateTime.now().toUtc(),
              fromAddress: wallet.addressForChainType(network.chainType),
              toAddress: config.wrappedAssetAddress,
              operation: operation == WrappedNativeOperation.wrap
                  ? TransactionOperation.wrap
                  : TransactionOperation.unwrap,
              resource: operation == WrappedNativeOperation.wrap
                  ? config.wrappedSymbol
                  : config.nativeSymbol,
            ),
          );
    } catch (_) {
      // The chain submission is already final. History persistence is
      // best-effort and must never make the user retry a broadcast.
    }
    await ref
        .read(securityLogRecorderProvider)
        .record(
          operation == WrappedNativeOperation.wrap
              ? SecurityLogEventType.wrapNative
              : SecurityLogEventType.unwrapNative,
          walletName: wallet.name,
          chainName: network.name,
          assetSymbol: config.wrappedSymbol,
          amount: amountText,
        );
  }

  void _clearPreparation() {
    _gatewayPreparation = null;
    _preparedRpcNode = null;
  }

  void _setError(WrappedNativeState current, WrappedNativeError error) {
    _clearPreparation();
    state = AsyncData(
      current.copyWith(
        status: WrappedNativeStatus.ready,
        clearPreparation: true,
        error: error,
      ),
    );
  }

  bool _isBusy(WrappedNativeState value) =>
      value.status == WrappedNativeStatus.loading ||
      value.status == WrappedNativeStatus.preparing ||
      value.status == WrappedNativeStatus.submitting;

  bool _walletSupports(WalletAccount wallet, ChainConfig network) {
    return wallet.addressForChainType(network.chainType).trim().isNotEmpty;
  }
}
