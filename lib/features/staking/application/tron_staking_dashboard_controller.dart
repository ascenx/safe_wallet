import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../data/tron_staking_repository.dart';
import '../domain/tron_staking_models.dart';

typedef TronStakingDefaultNetworkId = Future<String?> Function();
typedef TronStakingRpcNodeResolver =
    Future<RpcNode> Function(ChainConfig chain);

final tronStakingRepositoryProvider = Provider<TronStakingRepository>((ref) {
  final repository = HttpTronStakingRepository();
  ref.onDispose(repository.close);
  return repository;
});

final tronStakingDefaultNetworkIdProvider =
    Provider<TronStakingDefaultNetworkId>((ref) {
      return () async {
        try {
          return (await ref.read(selectedChainControllerProvider.future)).id;
        } catch (_) {
          return null;
        }
      };
    });

final tronStakingRpcNodeResolverProvider = Provider<TronStakingRpcNodeResolver>(
  (ref) {
    return (chain) => ref.read(selectedResolvedRpcNodeProvider(chain).future);
  },
);

final tronStakingDashboardControllerProvider =
    AsyncNotifierProvider<
      TronStakingDashboardController,
      TronStakingDashboardState
    >(TronStakingDashboardController.new);

final class TronStakingDashboardState {
  TronStakingDashboardState({
    required List<WalletAccount> wallets,
    required List<ChainConfig> networks,
    required this.selectedWalletId,
    required this.selectedNetworkId,
    required this.rpcNode,
    required this.overview,
    required List<TronDelegation> delegations,
    required List<TronWitness> witnesses,
  }) : wallets = List.unmodifiable(wallets),
       networks = List.unmodifiable(networks),
       delegations = List.unmodifiable(delegations),
       witnesses = List.unmodifiable(witnesses);

  final List<WalletAccount> wallets;
  final List<ChainConfig> networks;
  final String? selectedWalletId;
  final String? selectedNetworkId;
  final RpcNode? rpcNode;
  final TronStakingOverview? overview;
  final List<TronDelegation> delegations;
  final List<TronWitness> witnesses;

  WalletAccount? get selectedWallet =>
      wallets.where((wallet) => wallet.id == selectedWalletId).firstOrNull;

  ChainConfig? get selectedNetwork =>
      networks.where((network) => network.id == selectedNetworkId).firstOrNull;
}

class TronStakingDashboardController
    extends AsyncNotifier<TronStakingDashboardState> {
  @override
  Future<TronStakingDashboardState> build() async {
    final wallets = (await ref.read(walletRepositoryProvider).getWallets())
        .where((wallet) => wallet.tronAddress.trim().isNotEmpty)
        .toList(growable: false);
    final networks = (await ref.read(availableChainsProvider.future))
        .where((chain) => chain.chainType == ChainType.tron)
        .toList(growable: false);
    final selectedWalletId = ref.watch(selectedWalletIdProvider);
    final defaultNetworkId = await ref.read(
      tronStakingDefaultNetworkIdProvider,
    )();
    final walletId = wallets.any((wallet) => wallet.id == selectedWalletId)
        ? selectedWalletId
        : wallets.firstOrNull?.id;
    final networkId = networks.any((network) => network.id == defaultNetworkId)
        ? defaultNetworkId
        : networks.where((network) => !network.isTestnet).firstOrNull?.id ??
              networks.firstOrNull?.id;
    return _load(
      wallets: wallets,
      networks: networks,
      selectedWalletId: walletId,
      selectedNetworkId: networkId,
    );
  }

  Future<void> selectWallet(String walletId) async {
    final current = state.requireValue;
    if (!current.wallets.any((wallet) => wallet.id == walletId)) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(
        wallets: current.wallets,
        networks: current.networks,
        selectedWalletId: walletId,
        selectedNetworkId: current.selectedNetworkId,
      ),
    );
  }

  Future<void> selectNetwork(String networkId) async {
    final current = state.requireValue;
    if (!current.networks.any((network) => network.id == networkId)) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(
        wallets: current.wallets,
        networks: current.networks,
        selectedWalletId: current.selectedWalletId,
        selectedNetworkId: networkId,
      ),
    );
  }

  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(
        wallets: current.wallets,
        networks: current.networks,
        selectedWalletId: current.selectedWalletId,
        selectedNetworkId: current.selectedNetworkId,
      ),
    );
  }

  Future<BigInt> getMaxDelegatableSun(TronResourceType resource) async {
    final current = state.requireValue;
    final wallet = current.selectedWallet;
    final node = current.rpcNode;
    if (wallet == null || node == null) {
      return BigInt.zero;
    }
    return ref
        .read(tronStakingRepositoryProvider)
        .getMaxDelegatableSun(
          apiBaseUrl: node.endpointUrl,
          walletAddress: wallet.tronAddress,
          resource: resource,
          headers: node.endpointHeaders,
        );
  }

  Future<TronStakingDashboardState> _load({
    required List<WalletAccount> wallets,
    required List<ChainConfig> networks,
    required String? selectedWalletId,
    required String? selectedNetworkId,
  }) async {
    final wallet = wallets
        .where((wallet) => wallet.id == selectedWalletId)
        .firstOrNull;
    final network = networks
        .where((network) => network.id == selectedNetworkId)
        .firstOrNull;
    if (wallet == null || network == null) {
      return TronStakingDashboardState(
        wallets: wallets,
        networks: networks,
        selectedWalletId: selectedWalletId,
        selectedNetworkId: selectedNetworkId,
        rpcNode: null,
        overview: null,
        delegations: const [],
        witnesses: const [],
      );
    }
    final node = await ref.read(tronStakingRpcNodeResolverProvider)(network);
    final repository = ref.read(tronStakingRepositoryProvider);
    final overview = await repository.loadOverview(
      apiBaseUrl: node.endpointUrl,
      walletAddress: wallet.tronAddress,
      headers: node.endpointHeaders,
    );
    List<TronDelegation> delegations;
    try {
      delegations = await repository.loadDelegations(
        apiBaseUrl: node.endpointUrl,
        walletAddress: wallet.tronAddress,
        headers: node.endpointHeaders,
      );
    } catch (_) {
      delegations = const [];
    }
    List<TronWitness> witnesses;
    try {
      witnesses = await repository.loadWitnesses(
        apiBaseUrl: node.endpointUrl,
        headers: node.endpointHeaders,
      );
    } catch (_) {
      witnesses = const [];
    }
    return TronStakingDashboardState(
      wallets: wallets,
      networks: networks,
      selectedWalletId: wallet.id,
      selectedNetworkId: network.id,
      rpcNode: node,
      overview: overview,
      delegations: delegations,
      witnesses: witnesses,
    );
  }
}
