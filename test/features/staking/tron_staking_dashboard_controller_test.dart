import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/staking/application/tron_staking_dashboard_controller.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_repository.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  test(
    'loads Tron wallets networks overview delegations and witnesses',
    () async {
      final repository = _FakeStakingRepository();
      final tron = defaultChains.firstWhere(
        (chain) => chain.id == 'tron-mainnet',
      );
      final container = ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
          availableChainsProvider.overrideWith(
            (ref) async => [
              defaultChains.firstWhere((chain) => chain.id == 'ethereum'),
              tron,
            ],
          ),
          tronStakingRepositoryProvider.overrideWithValue(repository),
          tronStakingDefaultNetworkIdProvider.overrideWithValue(
            () async => tron.id,
          ),
          tronStakingRpcNodeResolverProvider.overrideWithValue(
            (chain) async => _node,
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        tronStakingDashboardControllerProvider.future,
      );

      expect(state.wallets, [_tronWallet]);
      expect(state.networks, [tron]);
      expect(state.selectedWallet, _tronWallet);
      expect(state.selectedNetwork, tron);
      expect(state.rpcNode, _node);
      expect(state.overview, same(_overview));
      expect(state.delegations, hasLength(1));
      expect(state.witnesses, hasLength(1));
      expect(repository.overviewCalls, 1);
    },
  );

  test('selecting a wallet reloads its staking state', () async {
    final repository = _FakeStakingRepository();
    final second = WalletAccount(
      id: 'wallet-2',
      name: 'Second Tron',
      evmAddress: '',
      solanaAddress: '',
      tronAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      createdAt: DateTime.utc(2026, 8, 2),
      updatedAt: DateTime.utc(2026, 8, 2),
    );
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _FakeWalletRepository(wallets: [_tronWallet, second]),
        ),
        availableChainsProvider.overrideWith(
          (ref) async => [
            defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet'),
          ],
        ),
        tronStakingRepositoryProvider.overrideWithValue(repository),
        tronStakingDefaultNetworkIdProvider.overrideWithValue(() async => null),
        tronStakingRpcNodeResolverProvider.overrideWithValue(
          (chain) async => _node,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(tronStakingDashboardControllerProvider.future);

    await container
        .read(tronStakingDashboardControllerProvider.notifier)
        .selectWallet(second.id);
    final state = container
        .read(tronStakingDashboardControllerProvider)
        .requireValue;

    expect(state.selectedWallet, second);
    expect(repository.walletAddresses.last, second.tronAddress);
    expect(repository.overviewCalls, 2);
  });
}

final class _FakeStakingRepository implements TronStakingRepository {
  int overviewCalls = 0;
  final walletAddresses = <String>[];

  @override
  Future<TronStakingOverview> loadOverview({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    overviewCalls += 1;
    walletAddresses.add(walletAddress);
    return _overview;
  }

  @override
  Future<List<TronDelegation>> loadDelegations({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async => [
    TronDelegation(
      direction: TronDelegationDirection.outgoing,
      counterpartyAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      bandwidthSun: BigInt.from(1000000),
      energySun: BigInt.zero,
    ),
  ];

  @override
  Future<List<TronWitness>> loadWitnesses({
    required String apiBaseUrl,
    Map<String, String> headers = const {},
  }) async => const [
    TronWitness(
      address: 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE',
      voteCount: 100,
      url: 'https://sr.example',
      isActive: true,
    ),
  ];

  @override
  Future<BigInt> getMaxDelegatableSun({
    required String apiBaseUrl,
    required String walletAddress,
    required TronResourceType resource,
    Map<String, String> headers = const {},
  }) async => BigInt.from(3000000);
}

final _overview = TronStakingOverview(
  availableBalanceSun: BigInt.from(20000000),
  bandwidthStakedSun: BigInt.from(5000000),
  energyStakedSun: BigInt.from(7000000),
  bandwidthLimit: 5000,
  bandwidthUsed: 100,
  energyLimit: 9000,
  energyUsed: 500,
  tronPower: 12,
  votes: const [],
  pendingUnfreezes: const [],
  availableUnfreezeCount: 32,
  withdrawableSun: BigInt.zero,
  rewardSun: BigInt.zero,
  unfreezeDelayDays: 14,
  cancelAllUnfreezeSupported: true,
  delegateResourceSupported: true,
);

final _tronWallet = WalletAccount(
  id: 'wallet-1',
  name: 'Tron Wallet',
  evmAddress: '',
  solanaAddress: '',
  tronAddress: 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

const _node = RpcNode(
  id: 'tron-node',
  chainId: 'tron-mainnet',
  name: 'TronGrid',
  url: 'https://api.trongrid.io',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.available,
);

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({List<WalletAccount>? wallets})
    : wallets = wallets ?? [_tronWallet, _evmWallet];

  final List<WalletAccount> wallets;

  @override
  Future<List<WalletAccount>> getWallets() async => wallets;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _evmWallet = WalletAccount(
  id: 'wallet-evm',
  name: 'EVM only',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);
