enum TronResourceType {
  bandwidth('BANDWIDTH', 0),
  energy('ENERGY', 1);

  const TronResourceType(this.apiValue, this.apiCode);

  final String apiValue;
  final int apiCode;

  static TronResourceType fromApiValue(Object? value) {
    return switch (value) {
      'BANDWIDTH' || 0 => TronResourceType.bandwidth,
      'ENERGY' || 1 => TronResourceType.energy,
      _ => throw FormatException('Unsupported Tron resource type: $value'),
    };
  }
}

final class TronVote {
  const TronVote({required this.witnessAddress, required this.voteCount});

  final String witnessAddress;
  final int voteCount;
}

final class TronPendingUnfreeze {
  const TronPendingUnfreeze({
    required this.resource,
    required this.amountSun,
    required this.expiresAt,
  });

  final TronResourceType resource;
  final BigInt amountSun;
  final DateTime expiresAt;
}

enum TronDelegationDirection { incoming, outgoing }

final class TronDelegation {
  const TronDelegation({
    required this.direction,
    required this.counterpartyAddress,
    required this.bandwidthSun,
    required this.energySun,
    this.bandwidthExpiresAt,
    this.energyExpiresAt,
  });

  final TronDelegationDirection direction;
  final String counterpartyAddress;
  final BigInt bandwidthSun;
  final BigInt energySun;
  final DateTime? bandwidthExpiresAt;
  final DateTime? energyExpiresAt;
}

final class TronWitness {
  const TronWitness({
    required this.address,
    required this.voteCount,
    required this.url,
    required this.isActive,
  });

  final String address;
  final int voteCount;
  final String url;
  final bool isActive;
}

final class TronStakingOverview {
  TronStakingOverview({
    required this.availableBalanceSun,
    required this.bandwidthStakedSun,
    required this.energyStakedSun,
    required this.bandwidthLimit,
    required this.bandwidthUsed,
    required this.energyLimit,
    required this.energyUsed,
    required this.tronPower,
    required List<TronVote> votes,
    required List<TronPendingUnfreeze> pendingUnfreezes,
    required this.availableUnfreezeCount,
    required this.withdrawableSun,
    required this.rewardSun,
    required this.unfreezeDelayDays,
    required this.cancelAllUnfreezeSupported,
    required this.delegateResourceSupported,
    this.maxDelegateLockPeriod = 0,
  }) : votes = List.unmodifiable(votes),
       pendingUnfreezes = List.unmodifiable(pendingUnfreezes);

  final BigInt availableBalanceSun;
  final BigInt bandwidthStakedSun;
  final BigInt energyStakedSun;
  final int bandwidthLimit;
  final int bandwidthUsed;
  final int energyLimit;
  final int energyUsed;
  final int tronPower;
  final List<TronVote> votes;
  final List<TronPendingUnfreeze> pendingUnfreezes;
  final int availableUnfreezeCount;
  final BigInt withdrawableSun;
  final BigInt rewardSun;
  final int unfreezeDelayDays;
  final bool cancelAllUnfreezeSupported;
  final bool delegateResourceSupported;
  final int maxDelegateLockPeriod;

  int get availableBandwidth =>
      (bandwidthLimit - bandwidthUsed).clamp(0, bandwidthLimit);

  int get availableEnergy => (energyLimit - energyUsed).clamp(0, energyLimit);

  int get usedVotes => votes.fold(0, (total, vote) => total + vote.voteCount);

  int get availableVotes => (tronPower - usedVotes).clamp(0, tronPower);

  BigInt get pendingUnfreezeSun => pendingUnfreezes.fold(
    BigInt.zero,
    (total, item) => total + item.amountSun,
  );
}

BigInt trxToSun(String value) {
  final normalized = value.trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,6}))?$').firstMatch(normalized);
  if (match == null) {
    throw const FormatException('Invalid TRX amount');
  }
  final whole = BigInt.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(6, '0');
  final result =
      whole * BigInt.from(1000000) +
      (fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction));
  if (result <= BigInt.zero) {
    throw const FormatException('TRX amount must be positive');
  }
  return result;
}

String sunToTrx(BigInt sun) {
  final negative = sun.isNegative;
  final absolute = sun.abs();
  final whole = absolute ~/ BigInt.from(1000000);
  final fraction = (absolute % BigInt.from(1000000))
      .toString()
      .padLeft(6, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  final value = fraction.isEmpty ? '$whole' : '$whole.$fraction';
  return negative ? '-$value' : value;
}

int validateTronVotes(List<TronVote> votes, {required int tronPower}) {
  var total = 0;
  final addresses = <String>{};
  for (final vote in votes) {
    if (vote.witnessAddress.trim().isEmpty || vote.voteCount < 0) {
      throw ArgumentError.value(vote, 'votes', 'contains an invalid vote');
    }
    if (!addresses.add(vote.witnessAddress)) {
      throw ArgumentError.value(vote, 'votes', 'contains a duplicate witness');
    }
    total += vote.voteCount;
    if (total > tronPower) {
      throw ArgumentError.value(votes, 'votes', 'exceeds TRON Power');
    }
  }
  return total;
}
