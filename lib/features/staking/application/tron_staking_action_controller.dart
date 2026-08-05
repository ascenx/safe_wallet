import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/wallet.dart' show isValidTronAddress;

import '../../assets/application/asset_portfolio_provider.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../settings/application/security_log_recorder.dart';
import '../../settings/domain/security_log_entry.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../transfer/domain/transaction_record.dart';
import '../../../shared/errors/wallet_error.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_account.dart';
import '../data/tron_staking_transaction_service.dart';
import '../data/tron_staking_fee_service.dart';
import '../domain/tron_staking_action.dart';
import '../domain/tron_staking_models.dart';

typedef TronStakingActionClock = DateTime Function();

final tronStakingTransactionServiceProvider =
    Provider<TronStakingTransactionService>((ref) {
      final service = HttpTronStakingTransactionService();
      ref.onDispose(service.close);
      return service;
    });

final tronStakingFeeServiceProvider = Provider<TronStakingFeeService>((ref) {
  final service = HttpTronStakingFeeService();
  ref.onDispose(service.close);
  return service;
});

final tronStakingActionClockProvider = Provider<TronStakingActionClock>((ref) {
  return () => DateTime.now().toUtc();
});

final tronStakingActionControllerProvider =
    NotifierProvider<TronStakingActionController, TronStakingActionState>(
      TronStakingActionController.new,
    );

enum TronStakingActionStatus { idle, submitting, success, failure }

enum TronStakingActionError {
  walletLocked,
  signingKeyUnavailable,
  insufficientBalance,
  insufficientStakedBalance,
  noUnfreezeSlots,
  nothingToWithdraw,
  cancelUnsupported,
  nothingToCancel,
  delegationUnsupported,
  invalidDelegation,
  insufficientDelegatableBalance,
  delegationLocked,
  insufficientDelegatedBalance,
  excessiveVotes,
  nothingToClaim,
  transactionValidationFailed,
  broadcastFailed,
}

final class TronStakingActionState {
  const TronStakingActionState._({
    required this.status,
    this.transactionHash,
    this.record,
    this.error,
  });

  const TronStakingActionState.idle()
    : this._(status: TronStakingActionStatus.idle);

  const TronStakingActionState.submitting()
    : this._(status: TronStakingActionStatus.submitting);

  const TronStakingActionState.success({
    required String transactionHash,
    required TransactionRecord record,
  }) : this._(
         status: TronStakingActionStatus.success,
         transactionHash: transactionHash,
         record: record,
       );

  const TronStakingActionState.failure(TronStakingActionError error)
    : this._(status: TronStakingActionStatus.failure, error: error);

  final TronStakingActionStatus status;
  final String? transactionHash;
  final TransactionRecord? record;
  final TronStakingActionError? error;
}

final class TronStakingActionSubmission {
  TronStakingActionSubmission({
    required this.chain,
    required this.rpcNode,
    required this.account,
    required this.overview,
    required this.action,
    required List<TronDelegation> delegations,
    this.maxDelegatableSun,
    BigInt? estimatedFeeSun,
  }) : delegations = List.unmodifiable(delegations),
       estimatedFeeSun = estimatedFeeSun ?? BigInt.zero;

  final ChainConfig chain;
  final RpcNode rpcNode;
  final WalletAccount account;
  final TronStakingOverview overview;
  final TronStakingAction action;
  final List<TronDelegation> delegations;
  final BigInt? maxDelegatableSun;
  final BigInt estimatedFeeSun;
}

final class TronStakingActionController
    extends Notifier<TronStakingActionState> {
  @override
  TronStakingActionState build() => const TronStakingActionState.idle();

  Future<TronStakingActionState> submit(
    TronStakingActionSubmission submission, {
    String? signingPassword,
    bool rememberSigningPassword = true,
  }) async {
    if (state.status == TronStakingActionStatus.submitting) {
      return state;
    }
    final validationError = _validate(submission);
    if (validationError != null) {
      return _fail(validationError);
    }
    state = const TronStakingActionState.submitting();
    try {
      final keyMaterial = await _readSigningKeyMaterial(
        submission.account.id,
        signingPassword: signingPassword,
        rememberSigningPassword: rememberSigningPassword,
      );
      final privateKey = keyMaterial.tronPrivateKey;
      if (privateKey == null || privateKey.isEmpty) {
        return _fail(TronStakingActionError.signingKeyUnavailable);
      }
      final transactionHash = await ref
          .read(tronStakingTransactionServiceProvider)
          .signAndBroadcast(
            TronStakingTransactionInput(
              apiBaseUrl: submission.rpcNode.endpointUrl,
              privateKey: privateKey,
              ownerAddress: submission.account.tronAddress,
              action: submission.action,
              headers: submission.rpcNode.endpointHeaders,
            ),
          );
      final record = _recordFor(submission, transactionHash);
      try {
        await ref.read(transactionHistoryRepositoryProvider).save(record);
      } catch (_) {
        // The staking transaction is already on-chain; never report it as a
        // broadcast failure because local history could not be persisted.
      }
      await ref
          .read(securityLogRecorderProvider)
          .record(
            _securityEvent(submission.action),
            walletName: submission.account.name,
            chainName: submission.chain.name,
            assetSymbol: 'TRX',
            amount: _amountFor(submission).isEmpty
                ? null
                : _amountFor(submission),
            address:
                _counterparty(submission.action) ??
                submission.account.tronAddress,
          );
      ref.invalidate(transactionHistoryProvider(submission.chain.chainId));
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(assetPortfolioProvider);
      final success = TronStakingActionState.success(
        transactionHash: transactionHash,
        record: record,
      );
      state = success;
      return success;
    } on _WalletLockedException {
      return _fail(TronStakingActionError.walletLocked);
    } on WalletError {
      return _fail(TronStakingActionError.walletLocked);
    } on TronStakingTransactionRejectedException catch (error) {
      return _fail(_nodeRejectionError(error.reason));
    } on TronStakingTransactionValidationException {
      return _fail(TronStakingActionError.transactionValidationFailed);
    } catch (_) {
      return _fail(TronStakingActionError.broadcastFailed);
    }
  }

  void reset() {
    if (state.status != TronStakingActionStatus.submitting) {
      state = const TronStakingActionState.idle();
    }
  }

  TronStakingActionError? _validate(TronStakingActionSubmission submission) {
    final action = submission.action;
    final overview = submission.overview;
    return switch (action) {
      TronStakeAction()
          when action.amountSun + submission.estimatedFeeSun >
              overview.availableBalanceSun =>
        TronStakingActionError.insufficientBalance,
      TronStakeAction() => null,
      TronUnstakeAction() when overview.availableUnfreezeCount <= 0 =>
        TronStakingActionError.noUnfreezeSlots,
      TronUnstakeAction()
          when action.amountSun >
              (action.resource == TronResourceType.bandwidth
                  ? overview.bandwidthStakedSun
                  : overview.energyStakedSun) =>
        TronStakingActionError.insufficientStakedBalance,
      TronUnstakeAction() => null,
      TronWithdrawUnfreezeAction()
          when overview.withdrawableSun <= BigInt.zero =>
        TronStakingActionError.nothingToWithdraw,
      TronWithdrawUnfreezeAction() => null,
      TronCancelAllUnfreezeAction() when !overview.cancelAllUnfreezeSupported =>
        TronStakingActionError.cancelUnsupported,
      TronCancelAllUnfreezeAction() when overview.pendingUnfreezes.isEmpty =>
        TronStakingActionError.nothingToCancel,
      TronCancelAllUnfreezeAction() => null,
      TronDelegateAction() when !overview.delegateResourceSupported =>
        TronStakingActionError.delegationUnsupported,
      TronDelegateAction()
          when !isValidTronAddress(action.receiverAddress) ||
              action.receiverAddress == submission.account.tronAddress =>
        TronStakingActionError.invalidDelegation,
      TronDelegateAction()
          when action.lock &&
              (action.lockPeriod == null ||
                  overview.maxDelegateLockPeriod <= 0 ||
                  action.lockPeriod! > overview.maxDelegateLockPeriod) =>
        TronStakingActionError.invalidDelegation,
      TronDelegateAction()
          when submission.maxDelegatableSun == null ||
              action.amountSun > submission.maxDelegatableSun! =>
        TronStakingActionError.insufficientDelegatableBalance,
      TronDelegateAction() => null,
      TronUndelegateAction()
          when !isValidTronAddress(action.receiverAddress) ||
              action.receiverAddress == submission.account.tronAddress =>
        TronStakingActionError.invalidDelegation,
      TronUndelegateAction() => _undelegateValidationError(
        submission.delegations,
        action,
        ref.read(tronStakingActionClockProvider)(),
      ),
      TronVoteAction()
          when _invalidVoteTotal(action.votes, overview.tronPower) =>
        TronStakingActionError.excessiveVotes,
      TronVoteAction() => null,
      TronClaimRewardAction() when overview.rewardSun <= BigInt.zero =>
        TronStakingActionError.nothingToClaim,
      TronClaimRewardAction() => null,
    };
  }

  Future<WalletKeyMaterial> _readSigningKeyMaterial(
    String walletId, {
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    final now = ref.read(tronStakingActionClockProvider)();
    final cache = ref.read(sessionKeyCacheProvider);
    final cachedWalletDek = cache.readKey(walletId, now: now);
    if (cachedWalletDek != null) {
      cache.touch(now: now);
      return ref
          .read(walletRepositoryProvider)
          .readKeyMaterial(walletId: walletId, walletDek: cachedWalletDek);
    }
    if (signingPassword == null || signingPassword.isEmpty) {
      throw const _WalletLockedException();
    }
    final unlockResult = await ref
        .read(walletRepositoryProvider)
        .unlock(walletId: walletId, password: signingPassword);
    if (rememberSigningPassword) {
      cache.unlock(
        walletId: unlockResult.account.id,
        walletDek: unlockResult.walletDek,
        now: now,
      );
    }
    return ref
        .read(walletRepositoryProvider)
        .readKeyMaterial(walletId: walletId, walletDek: unlockResult.walletDek);
  }

  TransactionRecord _recordFor(
    TronStakingActionSubmission submission,
    String transactionHash,
  ) {
    final now = ref.read(tronStakingActionClockProvider)();
    final action = submission.action;
    return TransactionRecord(
      id: 'tx-${now.microsecondsSinceEpoch}',
      walletId: submission.account.id,
      chainId: submission.chain.chainId,
      chainType: submission.chain.chainType,
      assetSymbol: 'TRX',
      direction: TransactionDirection.outgoing,
      amount: _amountFor(submission),
      status: TransactionStatus.submitted,
      transactionHash: transactionHash,
      createdAt: now,
      fromAddress: submission.account.tronAddress,
      toAddress: _counterparty(action),
      operation: _operation(action),
      resource: _resource(action)?.apiValue,
    );
  }

  TronStakingActionState _fail(TronStakingActionError error) {
    final failure = TronStakingActionState.failure(error);
    state = failure;
    return failure;
  }
}

TronStakingActionError _nodeRejectionError(
  TronStakingTransactionFailureReason reason,
) {
  return switch (reason) {
    TronStakingTransactionFailureReason.insufficientBalance =>
      TronStakingActionError.insufficientBalance,
    TronStakingTransactionFailureReason.insufficientStakedBalance =>
      TronStakingActionError.insufficientStakedBalance,
    TronStakingTransactionFailureReason.noUnfreezeSlots =>
      TronStakingActionError.noUnfreezeSlots,
    TronStakingTransactionFailureReason.nothingToWithdraw =>
      TronStakingActionError.nothingToWithdraw,
    TronStakingTransactionFailureReason.nothingToCancel =>
      TronStakingActionError.nothingToCancel,
    TronStakingTransactionFailureReason.invalidDelegation =>
      TronStakingActionError.invalidDelegation,
    TronStakingTransactionFailureReason.insufficientDelegatableBalance =>
      TronStakingActionError.insufficientDelegatableBalance,
    TronStakingTransactionFailureReason.delegationLocked =>
      TronStakingActionError.delegationLocked,
    TronStakingTransactionFailureReason.insufficientDelegatedBalance =>
      TronStakingActionError.insufficientDelegatedBalance,
    TronStakingTransactionFailureReason.excessiveVotes =>
      TronStakingActionError.excessiveVotes,
    TronStakingTransactionFailureReason.nothingToClaim =>
      TronStakingActionError.nothingToClaim,
    TronStakingTransactionFailureReason.rejected =>
      TronStakingActionError.broadcastFailed,
  };
}

final class _WalletLockedException implements Exception {
  const _WalletLockedException();
}

TronStakingActionError? _undelegateValidationError(
  List<TronDelegation> delegations,
  TronUndelegateAction action,
  DateTime now,
) {
  var total = BigInt.zero;
  var unlocked = BigInt.zero;
  for (final item in delegations.where(
    (item) =>
        item.direction == TronDelegationDirection.outgoing &&
        item.counterpartyAddress == action.receiverAddress,
  )) {
    final amount = action.resource == TronResourceType.bandwidth
        ? item.bandwidthSun
        : item.energySun;
    final expiresAt = action.resource == TronResourceType.bandwidth
        ? item.bandwidthExpiresAt
        : item.energyExpiresAt;
    total += amount;
    if (expiresAt?.isAfter(now) != true) {
      unlocked += amount;
    }
  }
  if (action.amountSun <= unlocked) {
    return null;
  }
  if (action.amountSun <= total) {
    return TronStakingActionError.delegationLocked;
  }
  return TronStakingActionError.insufficientDelegatedBalance;
}

bool _invalidVoteTotal(List<TronVote> votes, int tronPower) {
  try {
    validateTronVotes(votes, tronPower: tronPower);
    return false;
  } on ArgumentError {
    return true;
  }
}

String _amountFor(TronStakingActionSubmission submission) {
  final action = submission.action;
  final sun = switch (action) {
    TronStakeAction() => action.amountSun,
    TronUnstakeAction() => action.amountSun,
    TronWithdrawUnfreezeAction() => submission.overview.withdrawableSun,
    TronCancelAllUnfreezeAction() => submission.overview.pendingUnfreezeSun,
    TronDelegateAction() => action.amountSun,
    TronUndelegateAction() => action.amountSun,
    TronClaimRewardAction() => submission.overview.rewardSun,
    TronVoteAction() => BigInt.zero,
  };
  return sun == BigInt.zero ? '' : sunToTrx(sun);
}

String? _counterparty(TronStakingAction action) => switch (action) {
  TronDelegateAction() => action.receiverAddress,
  TronUndelegateAction() => action.receiverAddress,
  _ => null,
};

TronResourceType? _resource(TronStakingAction action) => switch (action) {
  TronStakeAction() => action.resource,
  TronUnstakeAction() => action.resource,
  TronDelegateAction() => action.resource,
  TronUndelegateAction() => action.resource,
  _ => null,
};

TransactionOperation _operation(TronStakingAction action) => switch (action) {
  TronStakeAction() => TransactionOperation.stake,
  TronUnstakeAction() => TransactionOperation.unstake,
  TronWithdrawUnfreezeAction() => TransactionOperation.withdrawUnfreeze,
  TronCancelAllUnfreezeAction() => TransactionOperation.cancelUnfreeze,
  TronDelegateAction() => TransactionOperation.delegateResource,
  TronUndelegateAction() => TransactionOperation.undelegateResource,
  TronVoteAction() => TransactionOperation.vote,
  TronClaimRewardAction() => TransactionOperation.claimReward,
};

SecurityLogEventType _securityEvent(TronStakingAction action) =>
    switch (action) {
      TronStakeAction() => SecurityLogEventType.tronStake,
      TronUnstakeAction() => SecurityLogEventType.tronUnstake,
      TronWithdrawUnfreezeAction() => SecurityLogEventType.tronWithdrawUnfreeze,
      TronCancelAllUnfreezeAction() => SecurityLogEventType.tronCancelUnfreeze,
      TronDelegateAction() => SecurityLogEventType.tronDelegateResource,
      TronUndelegateAction() => SecurityLogEventType.tronUndelegateResource,
      TronVoteAction() => SecurityLogEventType.tronVote,
      TronClaimRewardAction() => SecurityLogEventType.tronClaimReward,
    };
