import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../settings/application/security_log_recorder.dart';
import '../../settings/domain/security_log_entry.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_account.dart';
import '../data/solana_rent_recovery_gateway.dart';
import '../domain/solana_rent_recovery_models.dart';

typedef SolanaRentRecoveryDefaultNetworkId = Future<String?> Function();
typedef SolanaRentRecoveryRpcUrlResolver = Future<String> Function(
  ChainConfig chain,
);

final solanaRentRecoveryGatewayProvider = Provider<SolanaRentRecoveryGateway>(
  (ref) => const SdkSolanaRentRecoveryGateway(),
);

final solanaRentRecoveryDefaultNetworkIdProvider =
    Provider<SolanaRentRecoveryDefaultNetworkId>((ref) {
  return () async {
    try {
      return (await ref.read(selectedChainControllerProvider.future)).id;
    } catch (_) {
      return null;
    }
  };
});

final solanaRentRecoveryRpcUrlProvider =
    Provider<SolanaRentRecoveryRpcUrlResolver>((ref) {
  return (chain) async {
    final node = await ref.read(selectedResolvedRpcNodeProvider(chain).future);
    return node.endpointUrl;
  };
});

final solanaRentRecoveryControllerProvider = AsyncNotifierProvider<
    SolanaRentRecoveryController, SolanaRentRecoveryState>(
  SolanaRentRecoveryController.new,
);

enum SolanaRentRecoveryStatus {
  idle,
  scanning,
  ready,
  submitting,
  success,
  partialSuccess,
  failure,
}

enum SolanaRentRecoveryError {
  noWallet,
  noNetwork,
  scanFailed,
  simulationFailed,
  insufficientFeeBalance,
  noAccountsSelected,
  walletLocked,
  signingKeyUnavailable,
  accountsChanged,
  recoveryFailed,
}

final class SolanaRentRecoveryState {
  SolanaRentRecoveryState({
    required List<WalletAccount> wallets,
    required List<ChainConfig> networks,
    required this.selectedWalletId,
    required this.selectedNetworkId,
    this.status = SolanaRentRecoveryStatus.idle,
    this.scanResult,
    Set<String> selectedAccountAddresses = const {},
    this.estimate,
    this.result,
    this.error,
  })  : wallets = List.unmodifiable(wallets),
        networks = List.unmodifiable(networks),
        selectedAccountAddresses = Set.unmodifiable(selectedAccountAddresses);

  final List<WalletAccount> wallets;
  final List<ChainConfig> networks;
  final String? selectedWalletId;
  final String? selectedNetworkId;
  final SolanaRentRecoveryStatus status;
  final SolanaRentScanResult? scanResult;
  final Set<String> selectedAccountAddresses;
  final SolanaRentRecoveryEstimate? estimate;
  final SolanaRentRecoveryResult? result;
  final SolanaRentRecoveryError? error;

  WalletAccount? get selectedWallet =>
      wallets.where((wallet) => wallet.id == selectedWalletId).firstOrNull;

  ChainConfig? get selectedNetwork =>
      networks.where((network) => network.id == selectedNetworkId).firstOrNull;

  List<SolanaRentAccount> get selectedAccounts {
    final accounts = scanResult?.accounts ?? const <SolanaRentAccount>[];
    return accounts
        .where((account) => selectedAccountAddresses.contains(account.address))
        .toList(growable: false);
  }

  SolanaRentRecoveryState copyWith({
    String? selectedWalletId,
    String? selectedNetworkId,
    SolanaRentRecoveryStatus? status,
    SolanaRentScanResult? scanResult,
    bool clearScanResult = false,
    Set<String>? selectedAccountAddresses,
    SolanaRentRecoveryEstimate? estimate,
    bool clearEstimate = false,
    SolanaRentRecoveryResult? result,
    bool clearResult = false,
    SolanaRentRecoveryError? error,
    bool clearError = false,
  }) {
    return SolanaRentRecoveryState(
      wallets: wallets,
      networks: networks,
      selectedWalletId: selectedWalletId ?? this.selectedWalletId,
      selectedNetworkId: selectedNetworkId ?? this.selectedNetworkId,
      status: status ?? this.status,
      scanResult: clearScanResult ? null : scanResult ?? this.scanResult,
      selectedAccountAddresses:
          selectedAccountAddresses ?? this.selectedAccountAddresses,
      estimate: clearEstimate ? null : estimate ?? this.estimate,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final class SolanaRentRecoveryController
    extends AsyncNotifier<SolanaRentRecoveryState> {
  int _estimateGeneration = 0;

  @override
  Future<SolanaRentRecoveryState> build() async {
    final wallets = (await ref.read(walletRepositoryProvider).getWallets())
        .where((wallet) => wallet.solanaAddress.trim().isNotEmpty)
        .toList(growable: false);
    final networks = (await ref.read(availableChainsProvider.future))
        .where((chain) => chain.chainType == ChainType.solana)
        .toList(growable: false);
    final currentWalletId = ref.watch(selectedWalletIdProvider);
    final defaultNetworkId =
        await ref.read(solanaRentRecoveryDefaultNetworkIdProvider)();
    final selectedWalletId = wallets.any(
      (wallet) => wallet.id == currentWalletId,
    )
        ? currentWalletId
        : wallets.firstOrNull?.id;
    final selectedNetworkId = networks.any(
      (network) => network.id == defaultNetworkId,
    )
        ? defaultNetworkId
        : networks.where((network) => !network.isTestnet).firstOrNull?.id ??
            networks.firstOrNull?.id;
    return SolanaRentRecoveryState(
      wallets: wallets,
      networks: networks,
      selectedWalletId: selectedWalletId,
      selectedNetworkId: selectedNetworkId,
    );
  }

  void selectWallet(String walletId) {
    final current = state.requireValue;
    if (current.status == SolanaRentRecoveryStatus.scanning ||
        current.status == SolanaRentRecoveryStatus.submitting) {
      return;
    }
    if (!current.wallets.any((wallet) => wallet.id == walletId)) {
      return;
    }
    _estimateGeneration += 1;
    state = AsyncData(
      current.copyWith(
        selectedWalletId: walletId,
        status: SolanaRentRecoveryStatus.idle,
        clearScanResult: true,
        selectedAccountAddresses: const {},
        clearEstimate: true,
        clearResult: true,
        clearError: true,
      ),
    );
  }

  void selectNetwork(String networkId) {
    final current = state.requireValue;
    if (current.status == SolanaRentRecoveryStatus.scanning ||
        current.status == SolanaRentRecoveryStatus.submitting) {
      return;
    }
    if (!current.networks.any((network) => network.id == networkId)) {
      return;
    }
    _estimateGeneration += 1;
    state = AsyncData(
      current.copyWith(
        selectedNetworkId: networkId,
        status: SolanaRentRecoveryStatus.idle,
        clearScanResult: true,
        selectedAccountAddresses: const {},
        clearEstimate: true,
        clearResult: true,
        clearError: true,
      ),
    );
  }

  Future<void> scan() async {
    final current = state.requireValue;
    if (current.status == SolanaRentRecoveryStatus.scanning ||
        current.status == SolanaRentRecoveryStatus.submitting) {
      return;
    }
    _estimateGeneration += 1;
    final wallet = current.selectedWallet;
    final network = current.selectedNetwork;
    if (wallet == null) {
      state =
          AsyncData(current.copyWith(error: SolanaRentRecoveryError.noWallet));
      return;
    }
    if (network == null) {
      state =
          AsyncData(current.copyWith(error: SolanaRentRecoveryError.noNetwork));
      return;
    }
    state = AsyncData(
      current.copyWith(
        status: SolanaRentRecoveryStatus.scanning,
        clearResult: true,
        clearError: true,
      ),
    );
    try {
      final rpcUrl = await ref.read(solanaRentRecoveryRpcUrlProvider)(network);
      final scanResult = await ref.read(solanaRentRecoveryGatewayProvider).scan(
            rpcUrl: rpcUrl,
            ownerAddress: wallet.solanaAddress,
          );
      final selectedAddresses =
          scanResult.accounts.map((account) => account.address).toSet();
      final estimate =
          await ref.read(solanaRentRecoveryGatewayProvider).estimate(
                rpcUrl: rpcUrl,
                ownerAddress: wallet.solanaAddress,
                accounts: scanResult.accounts,
              );
      state = AsyncData(
        current.copyWith(
          status: SolanaRentRecoveryStatus.ready,
          scanResult: scanResult,
          selectedAccountAddresses: selectedAddresses,
          estimate: estimate,
          clearResult: true,
          clearError: true,
        ),
      );
    } catch (_) {
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          status: SolanaRentRecoveryStatus.failure,
          error: SolanaRentRecoveryError.scanFailed,
        ),
      );
    }
  }

  Future<void> toggleAccount(String address) async {
    final current = state.requireValue;
    if (current.status != SolanaRentRecoveryStatus.ready) {
      return;
    }
    final selected = {...current.selectedAccountAddresses};
    if (!selected.add(address)) {
      selected.remove(address);
    }
    state = AsyncData(
      current.copyWith(
        selectedAccountAddresses: selected,
        clearEstimate: true,
        clearError: true,
      ),
    );
    final generation = ++_estimateGeneration;
    await _estimateSelected(generation);
  }

  Future<SolanaRentRecoveryResult?> recover({
    String? signingPassword,
    bool rememberSigningPassword = true,
  }) async {
    var current = state.requireValue;
    if (current.status != SolanaRentRecoveryStatus.ready) {
      return null;
    }
    final wallet = current.selectedWallet;
    final network = current.selectedNetwork;
    if (wallet == null || network == null) {
      return null;
    }
    if (current.selectedAccountAddresses.isEmpty) {
      state = AsyncData(
        current.copyWith(error: SolanaRentRecoveryError.noAccountsSelected),
      );
      return null;
    }
    state = AsyncData(
      current.copyWith(
        status: SolanaRentRecoveryStatus.submitting,
        clearResult: true,
        clearError: true,
      ),
    );
    _estimateGeneration += 1;
    try {
      final rpcUrl = await ref.read(solanaRentRecoveryRpcUrlProvider)(network);
      final freshScan = await ref.read(solanaRentRecoveryGatewayProvider).scan(
            rpcUrl: rpcUrl,
            ownerAddress: wallet.solanaAddress,
          );
      final freshByAddress = {
        for (final account in freshScan.accounts) account.address: account,
      };
      final selectedAccounts = current.selectedAccountAddresses
          .map((address) => freshByAddress[address])
          .whereType<SolanaRentAccount>()
          .toList(growable: false);
      if (selectedAccounts.length != current.selectedAccountAddresses.length) {
        state = AsyncData(
          current.copyWith(error: SolanaRentRecoveryError.accountsChanged),
        );
        return null;
      }
      final estimate =
          await ref.read(solanaRentRecoveryGatewayProvider).estimate(
                rpcUrl: rpcUrl,
                ownerAddress: wallet.solanaAddress,
                accounts: selectedAccounts,
              );
      if (freshScan.solBalanceLamports < estimate.networkFeeLamports) {
        state = AsyncData(
          current.copyWith(
            scanResult: freshScan,
            estimate: estimate,
            error: SolanaRentRecoveryError.insufficientFeeBalance,
          ),
        );
        return null;
      }
      final WalletKeyMaterial? keyMaterial;
      try {
        keyMaterial = await _readKeyMaterial(
          wallet.id,
          signingPassword: signingPassword,
          rememberSigningPassword: rememberSigningPassword,
        );
      } catch (_) {
        state = AsyncData(
          current.copyWith(
            status: SolanaRentRecoveryStatus.ready,
            error: SolanaRentRecoveryError.walletLocked,
          ),
        );
        return null;
      }
      final privateKey = keyMaterial?.solanaPrivateKey;
      if (keyMaterial == null) {
        state = AsyncData(
          current.copyWith(error: SolanaRentRecoveryError.walletLocked),
        );
        return null;
      }
      if (privateKey == null) {
        state = AsyncData(
          current.copyWith(
            error: SolanaRentRecoveryError.signingKeyUnavailable,
          ),
        );
        return null;
      }
      state = AsyncData(
        current.copyWith(
          status: SolanaRentRecoveryStatus.submitting,
          scanResult: freshScan,
          estimate: estimate,
          clearResult: true,
          clearError: true,
        ),
      );
      final result = await ref.read(solanaRentRecoveryGatewayProvider).recover(
            rpcUrl: rpcUrl,
            ownerAddress: wallet.solanaAddress,
            privateKey: privateKey,
            batches: estimate.batches,
          );
      final status = result.isSuccess
          ? SolanaRentRecoveryStatus.success
          : result.isPartial
              ? SolanaRentRecoveryStatus.partialSuccess
              : SolanaRentRecoveryStatus.failure;
      if (result.signatures.isNotEmpty) {
        await ref.read(securityLogRecorderProvider).record(
              SecurityLogEventType.solanaRentRecovery,
              walletName: wallet.name,
              chainName: network.name,
              assetSymbol: 'SOL',
              amount: formatSolLamports(result.recoveredLamports),
            );
      }
      var latestScan = freshScan;
      var latestEstimate = estimate;
      var latestSelectedAddresses = current.selectedAccountAddresses;
      if (result.signatures.isNotEmpty) {
        try {
          final refreshedScan =
              await ref.read(solanaRentRecoveryGatewayProvider).scan(
                    rpcUrl: rpcUrl,
                    ownerAddress: wallet.solanaAddress,
                  );
          final refreshedSelectedAddresses = refreshedScan.accounts
              .map((account) => account.address)
              .toSet();
          final refreshedEstimate =
              await ref.read(solanaRentRecoveryGatewayProvider).estimate(
                    rpcUrl: rpcUrl,
                    ownerAddress: wallet.solanaAddress,
                    accounts: refreshedScan.accounts,
                  );
          latestScan = refreshedScan;
          latestEstimate = refreshedEstimate;
          latestSelectedAddresses = refreshedSelectedAddresses;
        } catch (_) {
          // The recovery result is already final. Keep it visible even when
          // the follow-up refresh is temporarily unavailable.
        }
      }
      state = AsyncData(
        current.copyWith(
          status: status,
          scanResult: latestScan,
          selectedAccountAddresses: latestSelectedAddresses,
          estimate: latestEstimate,
          result: result,
          error:
              result.isSuccess ? null : SolanaRentRecoveryError.recoveryFailed,
          clearError: result.isSuccess,
        ),
      );
      return result;
    } catch (_) {
      current = state.requireValue;
      state = AsyncData(
        current.copyWith(
          status: SolanaRentRecoveryStatus.failure,
          error: SolanaRentRecoveryError.recoveryFailed,
        ),
      );
      return null;
    }
  }

  Future<void> _estimateSelected(int generation) async {
    final current = state.requireValue;
    final wallet = current.selectedWallet;
    final network = current.selectedNetwork;
    if (wallet == null || network == null) {
      return;
    }
    try {
      final estimate = await ref
          .read(solanaRentRecoveryGatewayProvider)
          .estimate(
            rpcUrl: await ref.read(solanaRentRecoveryRpcUrlProvider)(network),
            ownerAddress: wallet.solanaAddress,
            accounts: current.selectedAccounts,
          );
      if (generation != _estimateGeneration) {
        return;
      }
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(estimate: estimate, clearError: true),
      );
    } catch (_) {
      if (generation != _estimateGeneration) {
        return;
      }
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(error: SolanaRentRecoveryError.simulationFailed),
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
      if (signingPassword == null || signingPassword.isEmpty) {
        return null;
      }
      final unlockResult = await ref.read(walletRepositoryProvider).unlock(
            walletId: walletId,
            password: signingPassword,
          );
      walletDek = unlockResult.walletDek;
      if (rememberSigningPassword) {
        cache.unlock(walletId: walletId, walletDek: walletDek, now: now);
      }
    } else {
      cache.touch(now: now);
    }
    return ref.read(walletRepositoryProvider).readKeyMaterial(
          walletId: walletId,
          walletDek: walletDek,
        );
  }
}
