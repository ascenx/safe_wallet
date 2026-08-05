import 'tron_staking_models.dart';

sealed class TronStakingAction {
  const TronStakingAction();
}

final class TronStakeAction extends TronStakingAction {
  TronStakeAction({required this.resource, required this.amountSun}) {
    _validateAtLeastOneTrx(amountSun);
  }

  final TronResourceType resource;
  final BigInt amountSun;
}

final class TronUnstakeAction extends TronStakingAction {
  TronUnstakeAction({required this.resource, required this.amountSun}) {
    _validateAmount(amountSun);
  }

  final TronResourceType resource;
  final BigInt amountSun;
}

final class TronWithdrawUnfreezeAction extends TronStakingAction {
  const TronWithdrawUnfreezeAction();
}

final class TronCancelAllUnfreezeAction extends TronStakingAction {
  const TronCancelAllUnfreezeAction();
}

final class TronDelegateAction extends TronStakingAction {
  TronDelegateAction({
    required this.resource,
    required this.amountSun,
    required this.receiverAddress,
    this.lock = false,
    this.lockPeriod,
  }) {
    _validateAtLeastOneTrx(amountSun);
    if (receiverAddress.trim().isEmpty) {
      throw ArgumentError.value(
        receiverAddress,
        'receiverAddress',
        'must not be empty',
      );
    }
    if (lockPeriod != null && lockPeriod! <= 0) {
      throw ArgumentError.value(lockPeriod, 'lockPeriod', 'must be positive');
    }
  }

  final TronResourceType resource;
  final BigInt amountSun;
  final String receiverAddress;
  final bool lock;
  final int? lockPeriod;
}

final class TronUndelegateAction extends TronStakingAction {
  TronUndelegateAction({
    required this.resource,
    required this.amountSun,
    required this.receiverAddress,
  }) {
    _validateAmount(amountSun);
    if (receiverAddress.trim().isEmpty) {
      throw ArgumentError.value(
        receiverAddress,
        'receiverAddress',
        'must not be empty',
      );
    }
  }

  final TronResourceType resource;
  final BigInt amountSun;
  final String receiverAddress;
}

final class TronVoteAction extends TronStakingAction {
  TronVoteAction({required List<TronVote> votes})
    : votes = List.unmodifiable(votes);

  final List<TronVote> votes;
}

final class TronClaimRewardAction extends TronStakingAction {
  const TronClaimRewardAction();
}

void _validateAmount(BigInt value) {
  if (value <= BigInt.zero || value > BigInt.from(0x7fffffffffffffff)) {
    throw ArgumentError.value(value, 'amountSun', 'must fit a positive int64');
  }
}

void _validateAtLeastOneTrx(BigInt value) {
  _validateAmount(value);
  if (value < BigInt.from(1000000)) {
    throw ArgumentError.value(value, 'amountSun', 'must be at least 1 TRX');
  }
}
