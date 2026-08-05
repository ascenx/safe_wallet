import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/transfer/data/tron_fee_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';

void main() {
  group('HttpTronFeeService', () {
    test('estimates burned TRX from transaction bandwidth shortfall', () async {
      final requests = <http.Request>[];
      Map<String, Object?>? createBody;
      Map<String, Object?>? resourceBody;
      final service = HttpTronFeeService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['TRON-PRO-API-KEY'], 'private-tron-key');
          if (request.method == 'POST' &&
              request.url.path == '/wallet/createtransaction') {
            createBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({
                'txID': _txId,
                'raw_data_hex': List.filled(200, 'aa').join(),
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/wallet/getaccountresource') {
            resourceBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({
                'freeNetLimit': 600,
                'freeNetUsed': 500,
                'NetLimit': 0,
                'NetUsed': 0,
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/wallet/getchainparameters') {
            return http.Response(
              jsonEncode({
                'chainParameter': [
                  {'key': 'getTransactionFee', 'value': 1000},
                ],
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://api.trongrid.io',
        fromAddress: _fromAddress,
        toAddress: _toAddress,
        sun: BigInt.from(100000),
        transactionType: TransactionType.nativeTransfer,
        headers: const {'TRON-PRO-API-KEY': 'private-tron-key'},
      );

      expect(estimate.sun, BigInt.from(234000));
      expect(estimate.bandwidth, 334);
      expect(estimate.availableBandwidth, 100);
      expect(requests.map((request) => request.url.toString()), [
        'https://api.trongrid.io/wallet/createtransaction',
        'https://api.trongrid.io/wallet/getaccountresource',
        'https://api.trongrid.io/wallet/getchainparameters',
      ]);
      expect(createBody, {
        'owner_address': _fromAddress,
        'to_address': _toAddress,
        'amount': 100000,
        'visible': true,
      });
      expect(resourceBody, {
        'address': _fromAddress,
        'visible': true,
      });
    });

    test('returns zero fee when available bandwidth covers transaction',
        () async {
      final service = HttpTronFeeService(
        client: MockClient((request) async {
          if (request.url.path == '/wallet/createtransaction') {
            return http.Response(
              jsonEncode({
                'txID': _txId,
                'raw_data_hex': List.filled(100, 'aa').join(),
              }),
              200,
            );
          }
          if (request.url.path == '/wallet/getaccountresource') {
            return http.Response(
              jsonEncode({
                'freeNetLimit': 500,
                'freeNetUsed': 0,
              }),
              200,
            );
          }
          if (request.url.path == '/wallet/getchainparameters') {
            return http.Response(jsonEncode({'chainParameter': []}), 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://api.trongrid.io',
        fromAddress: _fromAddress,
        toAddress: _toAddress,
        sun: BigInt.from(100000),
        transactionType: TransactionType.nativeTransfer,
      );

      expect(estimate.sun, BigInt.zero);
      expect(estimate.bandwidth, 234);
      expect(estimate.availableBandwidth, 500);
    });

    test('adds TRC20 energy shortfall to the burned TRX estimate', () async {
      final requests = <http.Request>[];
      final service = HttpTronFeeService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/wallet/triggersmartcontract') {
            return http.Response(
              jsonEncode({
                'result': {'result': true},
                'transaction': {
                  'txID': _txId,
                  'raw_data_hex': List.filled(100, 'aa').join(),
                },
              }),
              200,
            );
          }
          if (request.url.path == '/wallet/triggerconstantcontract') {
            return http.Response(jsonEncode({'energy_used': 1000}), 200);
          }
          if (request.url.path == '/wallet/getaccountresource') {
            return http.Response(
              jsonEncode({
                'freeNetLimit': 0,
                'freeNetUsed': 0,
                'EnergyLimit': 50,
                'EnergyUsed': 0,
              }),
              200,
            );
          }
          if (request.url.path == '/wallet/getchainparameters') {
            return http.Response(
              jsonEncode({
                'chainParameter': [
                  {'key': 'getTransactionFee', 'value': 1000},
                  {'key': 'getEnergyFee', 'value': 420},
                ],
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://api.trongrid.io',
        fromAddress: _fromAddress,
        toAddress: _toAddress,
        sun: BigInt.from(12345600),
        transactionType: TransactionType.trc20Transfer,
        tokenContractAddress: _trc20ContractAddress,
      );

      expect(estimate.bandwidth, 234);
      expect(estimate.availableBandwidth, 0);
      expect(estimate.energy, 1000);
      expect(estimate.availableEnergy, 50);
      expect(estimate.sun, BigInt.from(633000));
      expect(requests.map((request) => request.url.path), [
        '/wallet/triggersmartcontract',
        '/wallet/getaccountresource',
        '/wallet/getchainparameters',
        '/wallet/triggerconstantcontract',
      ]);
    });
  });
}

const _fromAddress = 'TJ4uT7n9LQvz1J9jQK5hJkCcnHJfLgkSnj';
const _toAddress = 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi';
const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
const _txId =
    '491c81e567b1cc3194e3c573fb433546b4f51c8ad7a363e7dfbbaea78d26aedc';
