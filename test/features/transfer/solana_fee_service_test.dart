import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/transfer/data/solana_fee_service.dart';
import 'package:solana_sdk/solana_sdk.dart';

void main() {
  test('simulates CU usage and reads recent priority fee percentiles',
      () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      final method = body['method']! as String;
      methods.add(method);
      final id = body['id'];
      final result = switch (method) {
        'getLatestBlockhash' => {
            'context': {'slot': 99},
            'value': {
              'blockhash': 'CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8',
              'lastValidBlockHeight': 123456,
            },
          },
        'getFeeForMessage' => {
            'context': {'slot': 100},
            'value': 5000,
          },
        'simulateTransaction' => {
            'context': {'slot': 101},
            'value': {
              'err': null,
              'logs': <String>[],
              'accounts': null,
              'unitsConsumed': 200000,
            },
          },
        'getRecentPrioritizationFees' => [
            {'slot': 1, 'prioritizationFee': 500},
            {'slot': 2, 'prioritizationFee': 1000},
            {'slot': 3, 'prioritizationFee': 2000},
            {'slot': 4, 'prioritizationFee': 4000},
            {'slot': 5, 'prioritizationFee': 8000},
          ],
        _ => throw StateError('Unexpected RPC method $method'),
      };
      return http.Response(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
        200,
      );
    });
    final service = SdkSolanaFeeService(
      connectionFactory: (rpcUrl) => Connection(rpcUrl, httpClient: client),
    );

    final estimate = await service.estimateSolTransferFee(
      rpcUrl: 'https://solana.example.com',
      fromAddress: '11111111111111111111111111111111',
      toAddress: 'So11111111111111111111111111111111111111112',
      lamports: BigInt.from(100000000),
    );

    expect(methods, [
      'getLatestBlockhash',
      'getFeeForMessage',
      'simulateTransaction',
      'getRecentPrioritizationFees',
    ]);
    expect(estimate.lamports, BigInt.from(5000));
    expect(estimate.computeUnitLimit, 220000);
    expect(
      estimate.priorityFeeOptionsMicroLamports,
      [BigInt.from(1000), BigInt.from(2000), BigInt.from(4000)],
    );
  });
}
