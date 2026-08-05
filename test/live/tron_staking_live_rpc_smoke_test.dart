import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_repository.dart';

void main() {
  const enabled = bool.hasEnvironment('SAFE_WALLET_LIVE_TRON_STAKING')
      ? bool.fromEnvironment('SAFE_WALLET_LIVE_TRON_STAKING')
      : false;
  final skip = enabled
      ? false
      : 'Set SAFE_WALLET_LIVE_TRON_STAKING=true to run read-only TRON staking smoke.';

  test(
    'queries the public mainnet Stake 2.0 overview without broadcasting',
    () async {
      final overview = await HttpTronStakingRepository().loadOverview(
        apiBaseUrl: 'https://api.trongrid.io',
        walletAddress: 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj',
      );

      expect(overview.availableBalanceSun, isNonNegative);
      expect(overview.bandwidthStakedSun, isNonNegative);
      expect(overview.energyStakedSun, isNonNegative);
      expect(overview.availableUnfreezeCount, isNonNegative);
      expect(overview.unfreezeDelayDays, greaterThan(0));
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
