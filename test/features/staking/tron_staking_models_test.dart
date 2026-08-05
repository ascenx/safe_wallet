import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_action.dart';

void main() {
  group('TRX amount conversion', () {
    test('converts a six-decimal TRX amount to SUN without precision loss', () {
      expect(trxToSun('12.345678'), BigInt.from(12345678));
      expect(sunToTrx(BigInt.from(12345678)), '12.345678');
      expect(sunToTrx(BigInt.from(12000000)), '12');
    });

    test('rejects zero negative and over-precision amounts', () {
      expect(() => trxToSun('0'), throwsFormatException);
      expect(() => trxToSun('-1'), throwsFormatException);
      expect(() => trxToSun('1.0000001'), throwsFormatException);
      expect(() => trxToSun('abc'), throwsFormatException);
    });
  });

  test('overview derives available resources votes and pending totals', () {
    final overview = TronStakingOverview(
      availableBalanceSun: BigInt.from(20_000_000),
      bandwidthStakedSun: BigInt.from(5_000_000),
      energyStakedSun: BigInt.from(7_000_000),
      bandwidthLimit: 5000,
      bandwidthUsed: 1200,
      energyLimit: 9000,
      energyUsed: 2500,
      tronPower: 12,
      votes: const [
        TronVote(witnessAddress: 'TWitness1', voteCount: 4),
        TronVote(witnessAddress: 'TWitness2', voteCount: 3),
      ],
      pendingUnfreezes: [
        TronPendingUnfreeze(
          resource: TronResourceType.bandwidth,
          amountSun: BigInt.from(2_000_000),
          expiresAt: DateTime.utc(2026, 8, 16),
        ),
        TronPendingUnfreeze(
          resource: TronResourceType.energy,
          amountSun: BigInt.from(1_000_000),
          expiresAt: DateTime.utc(2026, 8, 17),
        ),
      ],
      availableUnfreezeCount: 30,
      withdrawableSun: BigInt.from(500_000),
      rewardSun: BigInt.from(250_000),
      unfreezeDelayDays: 14,
      cancelAllUnfreezeSupported: true,
      delegateResourceSupported: true,
    );

    expect(overview.availableBandwidth, 3800);
    expect(overview.availableEnergy, 6500);
    expect(overview.usedVotes, 7);
    expect(overview.availableVotes, 5);
    expect(overview.pendingUnfreezeSun, BigInt.from(3_000_000));
  });

  test('vote allocation rejects negative or excessive totals', () {
    expect(
      () => validateTronVotes(const [
        TronVote(witnessAddress: 'TWitness', voteCount: -1),
      ], tronPower: 10),
      throwsArgumentError,
    );
    expect(
      () => validateTronVotes(const [
        TronVote(witnessAddress: 'TWitness', voteCount: 11),
      ], tronPower: 10),
      throwsArgumentError,
    );
    expect(
      validateTronVotes(const [
        TronVote(witnessAddress: 'TWitness', voteCount: 10),
      ], tronPower: 10),
      10,
    );
  });

  test('stake and delegation enforce the protocol one TRX minimum', () {
    expect(
      () => TronStakeAction(
        resource: TronResourceType.bandwidth,
        amountSun: BigInt.from(999999),
      ),
      throwsArgumentError,
    );
    expect(
      () => TronDelegateAction(
        resource: TronResourceType.energy,
        amountSun: BigInt.from(999999),
        receiverAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      ),
      throwsArgumentError,
    );
    expect(
      TronUnstakeAction(
        resource: TronResourceType.energy,
        amountSun: BigInt.one,
      ).amountSun,
      BigInt.one,
    );
  });
}
