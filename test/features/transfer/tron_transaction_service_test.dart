import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/data/tron_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/shared/utils/tron_abi.dart';
import 'package:web3dart/web3dart.dart' as web3;

void main() {
  group('HttpTronTransactionService', () {
    test('creates signs and broadcasts a native TRX transaction', () async {
      final requests = <http.Request>[];
      Map<String, Object?>? createBody;
      Map<String, Object?>? broadcastBody;
      final fixture = await _nativeFixture();
      final service = HttpTronTransactionService(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.headers['TRON-PRO-API-KEY'], 'private-tron-key');
          if (request.method == 'POST' &&
              request.url.path == '/wallet/createtransaction') {
            createBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({
                'txID': fixture.txId,
                'raw_data_hex': fixture.rawDataHex,
                'raw_data': fixture.rawDataJson,
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/wallet/broadcasttransaction') {
            broadcastBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({'result': true, 'txid': fixture.txId}),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      final txId = await service.signAndBroadcast(
        _input(headers: const {'TRON-PRO-API-KEY': 'private-tron-key'}),
      );

      expect(txId, fixture.txId);
      expect(requests.map((request) => request.url.toString()), [
        'https://api.trongrid.io/wallet/createtransaction',
        'https://api.trongrid.io/wallet/broadcasttransaction',
      ]);
      expect(createBody, {
        'owner_address': _fromAddress,
        'to_address': _toAddress,
        'amount': 100000,
        'visible': true,
      });
      final signatures = broadcastBody?['signature'] as List<Object?>?;
      expect(signatures, hasLength(1));
      expect(signatures!.single, isA<String>());
      expect(signatures.single as String, hasLength(130));
      expect(broadcastBody?['txID'], fixture.txId);
      expect(broadcastBody?['raw_data_hex'], fixture.rawDataHex);
    });

    test('creates signs and broadcasts a TRC20 transfer transaction', () async {
      final requests = <http.Request>[];
      Map<String, Object?>? triggerBody;
      Map<String, Object?>? broadcastBody;
      final fixture = await _trc20Fixture();
      final service = HttpTronTransactionService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST' &&
              request.url.path == '/wallet/triggersmartcontract') {
            triggerBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({
                'result': {'result': true},
                'transaction': {
                  'txID': fixture.txId,
                  'raw_data_hex': fixture.rawDataHex,
                  'raw_data': fixture.rawDataJson,
                },
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/wallet/broadcasttransaction') {
            broadcastBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({'result': true, 'txid': fixture.txId}),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      final txId = await service.signAndBroadcast(
        _input(
          feeLimitSun: BigInt.from(30000000),
          transaction: const TransactionRequest(
            chainId: 'tron-mainnet',
            chainType: ChainType.tron,
            assetSymbol: 'USDT',
            toAddress: _toAddress,
            amount: '12.3456',
            amountInBaseUnits: '12345600',
            tokenDecimals: 6,
            tokenContractAddress: _trc20ContractAddress,
            transactionType: TransactionType.trc20Transfer,
          ),
        ),
      );

      expect(txId, fixture.txId);
      expect(requests.map((request) => request.url.toString()), [
        'https://api.trongrid.io/wallet/triggersmartcontract',
        'https://api.trongrid.io/wallet/broadcasttransaction',
      ]);
      expect(triggerBody?['owner_address'], _fromAddress);
      expect(triggerBody?['contract_address'], _trc20ContractAddress);
      expect(triggerBody?['function_selector'], 'transfer(address,uint256)');
      expect(triggerBody?['fee_limit'], 30000000);
      expect(triggerBody?['visible'], isTrue);
      expect(triggerBody?['parameter'], isA<String>());
      expect(triggerBody?['parameter'] as String, hasLength(128));
      expect(broadcastBody?['txID'], fixture.txId);
      expect(broadcastBody?['raw_data_hex'], fixture.rawDataHex);
      expect(broadcastBody?['signature'], hasLength(1));
    });

    test(
      'rejects a transaction whose txID does not hash raw_data_hex',
      () async {
        final requests = <http.Request>[];
        final fixture = await _nativeFixture();
        final service = HttpTronTransactionService(
          client: MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/wallet/createtransaction') {
              return http.Response(
                jsonEncode({
                  'txID': _unverifiedTxId,
                  'raw_data_hex': fixture.rawDataHex,
                  'raw_data': fixture.rawDataJson,
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'result': true}), 200);
          }),
        );

        await expectLater(
          service.signAndBroadcast(_input()),
          throwsA(anything),
        );

        expect(requests, hasLength(1));
      },
    );

    test('rejects a node transaction with a different recipient', () async {
      final requests = <http.Request>[];
      final fixture = await _nativeFixture();
      final service = HttpTronTransactionService(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/wallet/createtransaction') {
            return http.Response(
              jsonEncode({
                'txID': fixture.txId,
                'raw_data_hex': fixture.rawDataHex,
                'raw_data': fixture.rawDataJson,
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'result': true}), 200);
        }),
      );

      await expectLater(
        service.signAndBroadcast(
          _input(
            transaction: const TransactionRequest(
              chainId: 'tron-mainnet',
              chainType: ChainType.tron,
              assetSymbol: 'TRX',
              toAddress: _trc20ContractAddress,
              amount: '0.1',
              amountInBaseUnits: '100000',
              tokenDecimals: 6,
              transactionType: TransactionType.nativeTransfer,
            ),
          ),
        ),
        throwsA(anything),
      );

      expect(requests, hasLength(1));
    });

    test('does not broadcast when create transaction fails', () async {
      final requests = <http.Request>[];
      final service = HttpTronTransactionService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'Error': 'invalid address'}), 200);
        }),
      );

      await expectLater(
        service.signAndBroadcast(_input()),
        throwsA(isA<StateError>()),
      );

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/wallet/createtransaction');
    });

    test('throws when broadcast is rejected', () async {
      final fixture = await _nativeFixture();
      final service = HttpTronTransactionService(
        client: MockClient((request) async {
          if (request.url.path == '/wallet/createtransaction') {
            return http.Response(
              jsonEncode({
                'txID': fixture.txId,
                'raw_data_hex': fixture.rawDataHex,
                'raw_data': fixture.rawDataJson,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'result': false, 'code': 'SIGERROR'}),
            200,
          );
        }),
      );

      await expectLater(
        service.signAndBroadcast(_input()),
        throwsA(isA<StateError>()),
      );
    });
  });
}

TronTransactionBroadcastInput _input({
  TransactionRequest? transaction,
  Map<String, String> headers = const {},
  BigInt? feeLimitSun,
}) {
  return TronTransactionBroadcastInput(
    apiBaseUrl: 'https://api.trongrid.io',
    privateKey: _privateKey,
    fromAddress: _fromAddress,
    headers: headers,
    feeLimitSun: feeLimitSun,
    transaction:
        transaction ??
        const TransactionRequest(
          chainId: 'tron-mainnet',
          chainType: ChainType.tron,
          assetSymbol: 'TRX',
          toAddress: _toAddress,
          amount: '0.1',
          amountInBaseUnits: '100000',
          tokenDecimals: 6,
          transactionType: TransactionType.nativeTransfer,
        ),
  );
}

const _privateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _fromAddress = 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH';
const _toAddress = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj';
const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
const _unverifiedTxId =
    '491c81e567b1cc3194e3c573fb433546b4f51c8ad7a363e7dfbbaea78d26aedc';

Future<({String txId, String rawDataHex, Map<String, Object?> rawDataJson})>
_nativeFixture() async {
  final transferContract = <int>[
    ..._bytesField(1, _tronAddressBytes(_fromAddress)),
    ..._bytesField(2, _tronAddressBytes(_toAddress)),
    ..._varintField(3, 100000),
  ];
  final any = <int>[
    ..._bytesField(
      1,
      utf8.encode('type.googleapis.com/protocol.TransferContract'),
    ),
    ..._bytesField(2, transferContract),
  ];
  final contract = <int>[..._varintField(1, 1), ..._bytesField(2, any)];
  final rawData = <int>[..._bytesField(11, contract)];
  final txId = web3.bytesToHex((await Sha256().hash(rawData)).bytes);
  return (
    txId: txId,
    rawDataHex: web3.bytesToHex(rawData),
    rawDataJson: {
      'contract': [
        {
          'type': 'TransferContract',
          'parameter': {
            'type_url': 'type.googleapis.com/protocol.TransferContract',
            'value': {
              'owner_address': _fromAddress,
              'to_address': _toAddress,
              'amount': 100000,
            },
          },
        },
      ],
    },
  );
}

Future<({String txId, String rawDataHex, Map<String, Object?> rawDataJson})>
_trc20Fixture() async {
  final calldata = web3.hexToBytes(
    'a9059cbb${trc20TransferAbiParameter(toAddress: _toAddress, amount: BigInt.from(12345600))}',
  );
  final triggerContract = <int>[
    ..._bytesField(1, _tronAddressBytes(_fromAddress)),
    ..._bytesField(2, _tronAddressBytes(_trc20ContractAddress)),
    ..._bytesField(3, calldata),
  ];
  final any = <int>[
    ..._bytesField(
      1,
      utf8.encode('type.googleapis.com/protocol.TriggerSmartContract'),
    ),
    ..._bytesField(2, triggerContract),
  ];
  final contract = <int>[..._varintField(1, 31), ..._bytesField(2, any)];
  final rawData = <int>[
    ..._bytesField(11, contract),
    ..._varintField(18, 30000000),
  ];
  final txId = web3.bytesToHex((await Sha256().hash(rawData)).bytes);
  return (
    txId: txId,
    rawDataHex: web3.bytesToHex(rawData),
    rawDataJson: {
      'contract': [
        {
          'type': 'TriggerSmartContract',
          'parameter': {
            'type_url': 'type.googleapis.com/protocol.TriggerSmartContract',
            'value': {
              'owner_address': _fromAddress,
              'contract_address': _trc20ContractAddress,
              'data': web3.bytesToHex(calldata),
            },
          },
        },
      ],
      'fee_limit': 30000000,
    },
  );
}

List<int> _bytesField(int field, List<int> value) => [
  ..._encodeVarint((field << 3) | 2),
  ..._encodeVarint(value.length),
  ...value,
];

List<int> _varintField(int field, int value) => [
  ..._encodeVarint(field << 3),
  ..._encodeVarint(value),
];

List<int> _encodeVarint(int value) {
  final bytes = <int>[];
  var remaining = value;
  do {
    var byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) {
      byte |= 0x80;
    }
    bytes.add(byte);
  } while (remaining != 0);
  return bytes;
}

List<int> _tronAddressBytes(String address) {
  var decoded = BigInt.zero;
  for (final codeUnit in address.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final bytes = <int>[];
  while (decoded > BigInt.zero) {
    bytes.insert(0, (decoded & BigInt.from(0xff)).toInt());
    decoded >>= 8;
  }
  return bytes.sublist(0, 21);
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
