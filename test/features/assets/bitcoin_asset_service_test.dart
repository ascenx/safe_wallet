import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/assets/data/bitcoin_asset_service.dart';

void main() {
  group('HttpBitcoinAssetService', () {
    test('loads confirmed and mempool BTC balance from address stats',
        () async {
      final requests = <http.Request>[];
      final service = HttpBitcoinAssetService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'chain_stats': {
                'funded_txo_sum': 150000000,
                'spent_txo_sum': 20000000,
              },
              'mempool_stats': {
                'funded_txo_sum': '25000',
                'spent_txo_sum': '10000',
              },
            }),
            200,
          );
        }),
      );

      final balance = await service.getBtcBalance(
        apiBaseUrl: 'https://blockstream.info/api',
        walletAddress: _address,
      );

      expect(balance, BigInt.from(130015000));
      expect(requests, hasLength(1));
      expect(
        requests.single.url.toString(),
        'https://blockstream.info/api/address/$_address',
      );
    });

    test('throws when the address query fails', () async {
      final service = HttpBitcoinAssetService(
        client: MockClient((request) async {
          return http.Response('rate limited', 429);
        }),
      );

      expect(
        () => service.getBtcBalance(
          apiBaseUrl: 'https://blockstream.info/api',
          walletAddress: _address,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

const _address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
