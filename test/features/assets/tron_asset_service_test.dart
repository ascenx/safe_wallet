import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/assets/data/tron_asset_service.dart';

void main() {
  group('HttpTronAssetService', () {
    test('reads TRC20 balances through trigger smart contract', () async {
      Map<String, Object?>? requestBody;
      final service = HttpTronAssetService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(),
              'https://api.trongrid.io/wallet/triggersmartcontract');
          expect(request.headers['TRON-PRO-API-KEY'], 'private-tron-key');
          requestBody = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'result': {'result': true},
              'constant_result': [
                '00000000000000000000000000000000000000000000000000000000075bcd15',
              ],
            }),
            200,
          );
        }),
      );

      final balances = await service.getTrc20Balances(
        apiBaseUrl: 'https://api.trongrid.io',
        contractAddresses: const [_contractAddress],
        walletAddress: _walletAddress,
        headers: const {'TRON-PRO-API-KEY': 'private-tron-key'},
      );

      expect(balances, {_contractAddress: BigInt.from(123456789)});
      expect(requestBody?['owner_address'], _walletAddress);
      expect(requestBody?['contract_address'], _contractAddress);
      expect(requestBody?['function_selector'], 'balanceOf(address)');
      expect(requestBody?['visible'], isTrue);
      expect(requestBody?['parameter'], isA<String>());
      expect(requestBody?['parameter'] as String, hasLength(64));
      expect(requestBody?['parameter'] as String, startsWith('000000000000'));
    });

    test('returns zero for an empty TRC20 balance result', () async {
      final service = HttpTronAssetService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'result': {'result': true},
              'constant_result': const <String>[],
            }),
            200,
          );
        }),
      );

      final balances = await service.getTrc20Balances(
        apiBaseUrl: 'https://api.trongrid.io',
        contractAddresses: const [_contractAddress],
        walletAddress: _walletAddress,
      );

      expect(balances, {_contractAddress: BigInt.zero});
    });
  });
}

const _walletAddress = 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi';
const _contractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
