import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_fee_service.dart';

void main() {
  group('HttpBitcoinFeeService', () {
    test('estimates fee from the selected P2WPKH input count', () async {
      final requests = <http.Request>[];
      final service = HttpBitcoinFeeService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/fee-estimates') {
            return http.Response('{"2": 10}', 200);
          }
          if (request.url.path == '/api/address/$_fromAddress/utxo') {
            return http.Response('''
              [
                {
                  "txid": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "vout": 0,
                  "value": 6000000
                },
                {
                  "txid": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                  "vout": 1,
                  "value": 5000000
                }
              ]
              ''', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://blockstream.info/api',
        fromAddress: _fromAddress,
        toAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        satoshis: BigInt.from(10000000),
      );

      expect(estimate.satoshis, BigInt.from(2090));
      expect(requests.map((request) => request.url.path), [
        '/api/fee-estimates',
        '/api/address/$_fromAddress/utxo',
      ]);
    });

    test('uses the recipient output size for legacy P2PKH addresses', () async {
      final service = HttpBitcoinFeeService(
        client: MockClient((request) async {
          if (request.url.path == '/api/fee-estimates') {
            return http.Response('{"2": 10}', 200);
          }
          if (request.url.path == '/api/address/$_fromAddress/utxo') {
            return http.Response('''
              [
                {
                  "txid": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "vout": 0,
                  "value": 11000000
                }
              ]
              ''', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://blockstream.info/api',
        fromAddress: _fromAddress,
        toAddress: '1BoatSLRHtKNngkdXEeobR76b53LETtpyT',
        satoshis: BigInt.from(10000000),
      );

      expect(estimate.satoshis, BigInt.from(1440));
    });

    test('uses the recipient output size for Taproot addresses', () async {
      final service = HttpBitcoinFeeService(
        client: MockClient((request) async {
          if (request.url.path == '/api/fee-estimates') {
            return http.Response('{"2": 10}', 200);
          }
          if (request.url.path == '/api/address/$_fromAddress/utxo') {
            return http.Response('''
              [
                {
                  "txid": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "vout": 0,
                  "value": 11000000
                }
              ]
              ''', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://blockstream.info/api',
        fromAddress: _fromAddress,
        toAddress:
            'bc1ph4lmxwklchcvvh2wchzassw86yvahdt902mpe0velxzuz2c70sps70mzj4',
        satoshis: BigInt.from(10000000),
      );

      expect(estimate.satoshis, BigInt.from(1530));
    });

    test('keeps exact preset fee when dust remainder is burned', () async {
      final service = HttpBitcoinFeeService(
        client: MockClient((request) async {
          if (request.url.path == '/api/fee-estimates') {
            return http.Response('{"1": 20, "3": 10, "12": 5}', 200);
          }
          if (request.url.path == '/api/address/$_fromAddress/utxo') {
            return http.Response('''
              [
                {"txid": "a", "vout": 0, "value": 1000600},
                {"txid": "b", "vout": 1, "value": 100000}
              ]
              ''', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://blockstream.info/api',
        fromAddress: _fromAddress,
        toAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        satoshis: BigInt.from(1000000),
      );

      expect(estimate.feeOptionsSatoshis, [
        BigInt.from(600),
        BigInt.from(2090),
        BigInt.from(4180),
      ]);
      expect(estimate.confirmationBlocks, 3);
      expect(estimate.confirmationBlockOptions, [12, 3, 1]);
    });

    test('quotes a sweep by spending every UTXO without change', () async {
      final service = HttpBitcoinFeeService(
        client: MockClient((request) async {
          if (request.url.path == '/api/fee-estimates') {
            return http.Response('{"2": 10}', 200);
          }
          if (request.url.path == '/api/address/$_fromAddress/utxo') {
            return http.Response('''
              [
                {"txid": "a", "vout": 0, "value": 6000000},
                {"txid": "b", "vout": 1, "value": 5000000}
              ]
              ''', 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final estimate = await service.estimateTransferFee(
        apiBaseUrl: 'https://blockstream.info/api',
        fromAddress: _fromAddress,
        toAddress: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
        satoshis: BigInt.from(11000000),
        sweep: true,
      );

      expect(estimate.satoshis, BigInt.from(1780));
      expect(estimate.transactionVbytes, 178);
    });
  });
}

const _fromAddress = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
