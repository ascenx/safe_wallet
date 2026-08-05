import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/staking/application/tron_staking_action_controller.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_transaction_service.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_action.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';

void main() {
  group('TronStakingActionController', () {
    test('unlocks signs records and refreshes a successful stake', () async {
      final service = _FakeTransactionService(result: 'tron-tx-id');
      final history = _MemoryHistoryRepository();
      final security = InMemorySecurityLogRepository();
      final walletRepository = _FakeWalletRepository();
      final container = _container(
        service: service,
        history: history,
        security: security,
        walletRepository: walletRepository,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(tronStakingActionControllerProvider.notifier)
          .submit(
            _submission(
              TronStakeAction(
                resource: TronResourceType.energy,
                amountSun: BigInt.from(5000000),
              ),
            ),
            signingPassword: 'StrongPass-123',
          );

      expect(result.status, TronStakingActionStatus.success);
      expect(result.transactionHash, 'tron-tx-id');
      expect(walletRepository.unlockCalls, 1);
      expect(service.calls.single.privateKey, _privateKey);
      expect(service.calls.single.ownerAddress, _account.tronAddress);
      expect(service.calls.single.headers, {'TRON-PRO-API-KEY': 'key'});
      expect(history.records.single.operation, TransactionOperation.stake);
      expect(history.records.single.resource, 'ENERGY');
      expect(history.records.single.amount, '5');
      expect(
        (await security.listEntries()).single.type,
        SecurityLogEventType.tronStake,
      );
    });

    test(
      'completed staking broadcast succeeds when history save fails',
      () async {
        final service = _FakeTransactionService(result: 'tron-tx-id');
        final container = _container(
          service: service,
          history: _MemoryHistoryRepository(saveError: StateError('disk full')),
        );
        addTearDown(container.dispose);

        final result = await container
            .read(tronStakingActionControllerProvider.notifier)
            .submit(
              _submission(
                TronStakeAction(
                  resource: TronResourceType.energy,
                  amountSun: BigInt.from(5000000),
                ),
              ),
              signingPassword: 'StrongPass-123',
            );

        expect(result.status, TronStakingActionStatus.success);
        expect(result.transactionHash, 'tron-tx-id');
      },
    );

    test(
      'rejects an unstake larger than the selected resource balance',
      () async {
        final service = _FakeTransactionService(result: 'unused');
        final container = _container(service: service);
        addTearDown(container.dispose);

        final result = await container
            .read(tronStakingActionControllerProvider.notifier)
            .submit(
              _submission(
                TronUnstakeAction(
                  resource: TronResourceType.bandwidth,
                  amountSun: BigInt.from(6000000),
                ),
              ),
              signingPassword: 'StrongPass-123',
            );

        expect(result.status, TronStakingActionStatus.failure);
        expect(result.error, TronStakingActionError.insufficientStakedBalance);
        expect(service.calls, isEmpty);
      },
    );

    test(
      'maps a typed node rejection to an actionable failure state',
      () async {
        final service = _FakeTransactionService(
          error: const TronStakingTransactionRejectedException(
            TronStakingTransactionFailureReason.insufficientDelegatableBalance,
            code: 'CONTRACT_VALIDATE_ERROR',
          ),
        );
        final container = _container(service: service);
        addTearDown(container.dispose);

        final result = await container
            .read(tronStakingActionControllerProvider.notifier)
            .submit(
              _submission(
                TronDelegateAction(
                  resource: TronResourceType.energy,
                  amountSun: BigInt.from(1000000),
                  receiverAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
                ),
              ),
              signingPassword: 'StrongPass-123',
            );

        expect(
          result.error,
          TronStakingActionError.insufficientDelegatableBalance,
        );
      },
    );

    test(
      'prevents duplicate broadcasts while an action is submitting',
      () async {
        final completer = Completer<String>();
        final service = _FakeTransactionService(completer: completer);
        final container = _container(service: service);
        addTearDown(container.dispose);
        final controller = container.read(
          tronStakingActionControllerProvider.notifier,
        );
        final submission = _submission(
          TronStakeAction(
            resource: TronResourceType.bandwidth,
            amountSun: BigInt.from(1000000),
          ),
        );

        final first = controller.submit(
          submission,
          signingPassword: 'StrongPass-123',
        );
        await Future<void>.delayed(Duration.zero);
        final second = await controller.submit(
          submission,
          signingPassword: 'StrongPass-123',
        );

        expect(second.status, TronStakingActionStatus.submitting);
        expect(service.calls, hasLength(1));
        completer.complete('tron-tx-id');
        expect((await first).status, TronStakingActionStatus.success);
      },
    );

    test('requires a password when the wallet session has no key', () async {
      final service = _FakeTransactionService(result: 'unused');
      final container = _container(service: service);
      addTearDown(container.dispose);

      final result = await container
          .read(tronStakingActionControllerProvider.notifier)
          .submit(
            _submission(
              TronStakeAction(
                resource: TronResourceType.bandwidth,
                amountSun: BigInt.from(1000000),
              ),
            ),
          );

      expect(result.error, TronStakingActionError.walletLocked);
      expect(service.calls, isEmpty);
    });

    test(
      'rejects a delegation lock period above the chain parameter',
      () async {
        final service = _FakeTransactionService(result: 'unused');
        final container = _container(service: service);
        addTearDown(container.dispose);

        final result = await container
            .read(tronStakingActionControllerProvider.notifier)
            .submit(
              _submission(
                TronDelegateAction(
                  resource: TronResourceType.energy,
                  amountSun: BigInt.from(1000000),
                  receiverAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
                  lock: true,
                  lockPeriod: 900000,
                ),
              ),
              signingPassword: 'StrongPass-123',
            );

        expect(result.error, TronStakingActionError.invalidDelegation);
        expect(service.calls, isEmpty);
      },
    );

    test(
      'rejects invalid delegate and undelegate receiver addresses',
      () async {
        final service = _FakeTransactionService(result: 'unused');
        final container = _container(service: service);
        addTearDown(container.dispose);
        final controller = container.read(
          tronStakingActionControllerProvider.notifier,
        );

        final delegateResult = await controller.submit(
          _submission(
            TronDelegateAction(
              resource: TronResourceType.bandwidth,
              amountSun: BigInt.from(1000000),
              receiverAddress: 'invalid-address',
            ),
          ),
          signingPassword: 'StrongPass-123',
        );
        expect(delegateResult.error, TronStakingActionError.invalidDelegation);

        controller.reset();
        final base = _submission(
          TronUndelegateAction(
            resource: TronResourceType.bandwidth,
            amountSun: BigInt.from(1000000),
            receiverAddress: 'invalid-address',
          ),
        );
        final undelegateResult = await controller.submit(
          TronStakingActionSubmission(
            chain: base.chain,
            rpcNode: base.rpcNode,
            account: base.account,
            overview: base.overview,
            action: base.action,
            delegations: [
              TronDelegation(
                direction: TronDelegationDirection.outgoing,
                counterpartyAddress: 'invalid-address',
                bandwidthSun: BigInt.from(1000000),
                energySun: BigInt.zero,
              ),
            ],
          ),
          signingPassword: 'StrongPass-123',
        );
        expect(
          undelegateResult.error,
          TronStakingActionError.invalidDelegation,
        );
        expect(service.calls, isEmpty);
      },
    );

    test('does not undelegate a resource before its lock expiry', () async {
      final service = _FakeTransactionService(result: 'unused');
      final container = _container(service: service);
      addTearDown(container.dispose);
      final base = _submission(
        TronUndelegateAction(
          resource: TronResourceType.energy,
          amountSun: BigInt.from(1000000),
          receiverAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
        ),
      );
      final locked = TronStakingActionSubmission(
        chain: base.chain,
        rpcNode: base.rpcNode,
        account: base.account,
        overview: base.overview,
        action: base.action,
        delegations: [
          TronDelegation(
            direction: TronDelegationDirection.outgoing,
            counterpartyAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
            bandwidthSun: BigInt.zero,
            energySun: BigInt.from(2000000),
            energyExpiresAt: DateTime.utc(2026, 8, 3),
          ),
        ],
      );

      final result = await container
          .read(tronStakingActionControllerProvider.notifier)
          .submit(locked, signingPassword: 'StrongPass-123');

      expect(result.error, TronStakingActionError.delegationLocked);
      expect(service.calls, isEmpty);
    });
  });
}

ProviderContainer _container({
  required _FakeTransactionService service,
  _MemoryHistoryRepository? history,
  InMemorySecurityLogRepository? security,
  _FakeWalletRepository? walletRepository,
}) {
  return ProviderContainer(
    overrides: [
      tronStakingTransactionServiceProvider.overrideWithValue(service),
      walletRepositoryProvider.overrideWithValue(
        walletRepository ?? _FakeWalletRepository(),
      ),
      transactionHistoryRepositoryProvider.overrideWithValue(
        history ?? _MemoryHistoryRepository(),
      ),
      securityLogRepositoryProvider.overrideWithValue(
        security ?? InMemorySecurityLogRepository(),
      ),
      tronStakingActionClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 2),
      ),
    ],
  );
}

TronStakingActionSubmission _submission(TronStakingAction action) {
  final chain = defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet');
  return TronStakingActionSubmission(
    chain: chain,
    rpcNode: const RpcNode(
      id: 'tron-node',
      chainId: 'tron-mainnet',
      name: 'TronGrid',
      url: 'https://api.trongrid.io',
      resolvedHeaders: {'TRON-PRO-API-KEY': 'key'},
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
    ),
    account: _account,
    overview: _overview,
    action: action,
    delegations: const [],
    maxDelegatableSun: BigInt.from(3000000),
  );
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
  withdrawableSun: BigInt.from(1000000),
  rewardSun: BigInt.from(500000),
  unfreezeDelayDays: 14,
  cancelAllUnfreezeSupported: true,
  delegateResourceSupported: true,
  maxDelegateLockPeriod: 864000,
);

final _account = WalletAccount(
  id: 'wallet-tron',
  name: 'Tron Wallet',
  evmAddress: '',
  solanaAddress: '',
  tronAddress: 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

final class _FakeTransactionService implements TronStakingTransactionService {
  _FakeTransactionService({this.result, this.completer, this.error});

  final String? result;
  final Completer<String>? completer;
  final Object? error;
  final calls = <TronStakingTransactionInput>[];

  @override
  Future<String> signAndBroadcast(TronStakingTransactionInput input) {
    calls.add(input);
    final error = this.error;
    if (error != null) {
      return Future<String>.error(error);
    }
    return completer?.future ?? Future.value(result!);
  }
}

final class _MemoryHistoryRepository implements TransactionHistoryRepository {
  _MemoryHistoryRepository({this.saveError});

  final Object? saveError;
  final records = <TransactionRecord>[];

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async => records;

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async => records.take(limit).toList();

  @override
  Future<void> save(TransactionRecord record) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    records.add(record);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _FakeWalletRepository implements WalletRepository {
  int unlockCalls = 0;

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCalls += 1;
    return WalletUnlockResult(account: _account, walletDek: [1, 2, 3]);
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async => WalletKeyMaterial(tronPrivateKey: _privateKey);

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _privateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
