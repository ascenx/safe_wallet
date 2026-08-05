import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_fee_service.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_action.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';

void main() {
  test(
    'estimates burned TRX from staking transaction bandwidth shortfall',
    () async {
      final requests = <http.Request>[];
      final service = HttpTronStakingFeeService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['TRON-PRO-API-KEY'], 'key');
          return switch (request.url.path) {
            '/wallet/freezebalancev2' => http.Response(
              jsonEncode({
                'transaction': {'raw_data_hex': '00' * 200},
              }),
              200,
            ),
            '/wallet/getaccountresource' => http.Response(
              jsonEncode({'freeNetLimit': 600, 'freeNetUsed': 500}),
              200,
            ),
            '/wallet/getchainparameters' => http.Response(
              jsonEncode({
                'chainParameter': [
                  {'key': 'getTransactionFee', 'value': 1000},
                ],
              }),
              200,
            ),
            _ => http.Response('not found', 404),
          };
        }),
      );

      final estimate = await service.estimateFee(
        apiBaseUrl: 'https://api.trongrid.io',
        ownerAddress: 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH',
        action: TronStakeAction(
          resource: TronResourceType.energy,
          amountSun: BigInt.from(5000000),
        ),
        headers: const {'TRON-PRO-API-KEY': 'key'},
      );

      expect(estimate.bandwidth, 334);
      expect(estimate.availableBandwidth, 100);
      expect(estimate.burnedSun, BigInt.from(234000));
      expect(requests.map((request) => request.url.path), [
        '/wallet/freezebalancev2',
        '/wallet/getaccountresource',
        '/wallet/getchainparameters',
      ]);
    },
  );
}
