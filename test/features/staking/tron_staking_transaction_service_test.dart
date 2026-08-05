import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/staking/data/tron_staking_transaction_service.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_action.dart';
import 'package:safe_wallet/features/staking/domain/tron_staking_models.dart';
import 'package:web3dart/web3dart.dart' as web3;

void main() {
  group('HttpTronStakingTransactionService', () {
    for (final testCase in _cases) {
      test('creates verifies signs and broadcasts ${testCase.name}', () async {
        final requests = <http.Request>[];
        final rawData = _rawData(testCase.action);
        final rawDataHex = web3.bytesToHex(rawData);
        final txId = web3.bytesToHex((await Sha256().hash(rawData)).bytes);
        Map<String, Object?>? createBody;
        Map<String, Object?>? broadcastBody;
        final service = HttpTronStakingTransactionService(
          client: MockClient((request) async {
            requests.add(request);
            expect(request.headers['TRON-PRO-API-KEY'], 'test-key');
            if (request.url.path == testCase.endpoint) {
              createBody = jsonDecode(request.body) as Map<String, Object?>;
              return http.Response(
                jsonEncode({
                  'result': {'result': true},
                  'txid': txId,
                  'transaction': {
                    'txID': txId,
                    'raw_data_hex': rawDataHex,
                    'raw_data': _rawDataJson(testCase.action),
                  },
                }),
                200,
              );
            }
            if (request.url.path == '/wallet/broadcasttransaction') {
              broadcastBody = jsonDecode(request.body) as Map<String, Object?>;
              return http.Response(
                jsonEncode({'result': true, 'txid': txId}),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
        );

        final result = await service.signAndBroadcast(
          TronStakingTransactionInput(
            apiBaseUrl: 'https://api.trongrid.io',
            privateKey: _privateKey,
            ownerAddress: _owner,
            action: testCase.action,
            headers: const {'TRON-PRO-API-KEY': 'test-key'},
          ),
        );

        expect(result, txId);
        expect(createBody, testCase.expectedBody);
        expect(requests.map((request) => request.url.path), [
          testCase.endpoint,
          '/wallet/broadcasttransaction',
        ]);
        expect(broadcastBody?['txID'], txId);
        expect(broadcastBody?['raw_data_hex'], rawDataHex);
        expect(broadcastBody?['signature'], hasLength(1));
        expect(
          (broadcastBody?['signature'] as List<Object?>).single,
          isA<String>().having((value) => value.length, 'length', 130),
        );
      });
    }

    test('maps a node contract rejection to a typed staking failure', () async {
      final service = HttpTronStakingTransactionService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'result': {
                'result': false,
                'code': 'CONTRACT_VALIDATE_ERROR',
                'message': base64Encode(
                  utf8.encode(
                    'delegateBalance must be less than or equal to available '
                    'FreezeBalanceV2 balance',
                  ),
                ),
              },
            }),
            200,
          );
        }),
      );

      await expectLater(
        service.signAndBroadcast(
          _input(
            TronDelegateAction(
              resource: TronResourceType.energy,
              amountSun: BigInt.from(1000000),
              receiverAddress: _receiver,
            ),
          ),
        ),
        throwsA(
          isA<TronStakingTransactionRejectedException>().having(
            (error) => error.reason,
            'reason',
            TronStakingTransactionFailureReason.insufficientDelegatableBalance,
          ),
        ),
      );
    });

    test(
      'rejects a node transaction whose txID does not hash raw_data_hex',
      () async {
        var broadcastCalled = false;
        final service = HttpTronStakingTransactionService(
          client: MockClient((request) async {
            if (request.url.path == '/wallet/freezebalancev2') {
              return http.Response(
                jsonEncode({
                  'transaction': {
                    'txID': '00' * 32,
                    'raw_data_hex': web3.bytesToHex(
                      _rawData(_cases.first.action),
                    ),
                    'raw_data': _rawDataJson(_cases.first.action),
                  },
                }),
                200,
              );
            }
            broadcastCalled = true;
            return http.Response('{}', 200);
          }),
        );

        await expectLater(
          service.signAndBroadcast(_input(_cases.first.action)),
          throwsA(isA<TronStakingTransactionValidationException>()),
        );
        expect(broadcastCalled, isFalse);
      },
    );

    test('rejects an amount changed inside signed protobuf bytes', () async {
      var broadcastCalled = false;
      final expected = TronStakeAction(
        resource: TronResourceType.energy,
        amountSun: BigInt.from(5000000),
      );
      final malicious = TronStakeAction(
        resource: TronResourceType.energy,
        amountSun: BigInt.from(6000000),
      );
      final rawData = _rawData(malicious);
      final txId = web3.bytesToHex((await Sha256().hash(rawData)).bytes);
      final service = HttpTronStakingTransactionService(
        client: MockClient((request) async {
          if (request.url.path == '/wallet/freezebalancev2') {
            return http.Response(
              jsonEncode({
                'transaction': {
                  'txID': txId,
                  'raw_data_hex': web3.bytesToHex(rawData),
                  'raw_data': _rawDataJson(expected),
                },
              }),
              200,
            );
          }
          broadcastCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.signAndBroadcast(_input(expected)),
        throwsA(isA<TronStakingTransactionValidationException>()),
      );
      expect(broadcastCalled, isFalse);
    });

    test('rejects raw bytes containing more than one contract', () async {
      var broadcastCalled = false;
      final action = _cases.first.action;
      final contract = _contract(action);
      final rawData = <int>[
        ..._bytesField(11, contract),
        ..._bytesField(11, contract),
      ];
      final txId = web3.bytesToHex((await Sha256().hash(rawData)).bytes);
      final service = HttpTronStakingTransactionService(
        client: MockClient((request) async {
          if (request.url.path == _cases.first.endpoint) {
            return http.Response(
              jsonEncode({
                'transaction': {
                  'txID': txId,
                  'raw_data_hex': web3.bytesToHex(rawData),
                  'raw_data': _rawDataJson(action),
                },
              }),
              200,
            );
          }
          broadcastCalled = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.signAndBroadcast(_input(action)),
        throwsA(isA<TronStakingTransactionValidationException>()),
      );
      expect(broadcastCalled, isFalse);
    });
  });
}

TronStakingTransactionInput _input(TronStakingAction action) {
  return TronStakingTransactionInput(
    apiBaseUrl: 'https://api.trongrid.io',
    privateKey: _privateKey,
    ownerAddress: _owner,
    action: action,
  );
}

final _cases = <_ActionCase>[
  _ActionCase(
    name: 'Bandwidth stake',
    endpoint: '/wallet/freezebalancev2',
    action: TronStakeAction(
      resource: TronResourceType.bandwidth,
      amountSun: BigInt.from(5000000),
    ),
    expectedBody: {
      'owner_address': _owner,
      'frozen_balance': 5000000,
      'resource': 'BANDWIDTH',
      'visible': true,
    },
  ),
  _ActionCase(
    name: 'Energy unstake',
    endpoint: '/wallet/unfreezebalancev2',
    action: TronUnstakeAction(
      resource: TronResourceType.energy,
      amountSun: BigInt.from(2000000),
    ),
    expectedBody: {
      'owner_address': _owner,
      'unfreeze_balance': 2000000,
      'resource': 'ENERGY',
      'visible': true,
    },
  ),
  const _ActionCase(
    name: 'expired unfreeze withdrawal',
    endpoint: '/wallet/withdrawexpireunfreeze',
    action: TronWithdrawUnfreezeAction(),
    expectedBody: {'owner_address': _owner, 'visible': true},
  ),
  const _ActionCase(
    name: 'cancel all unfreezes',
    endpoint: '/wallet/cancelallunfreezev2',
    action: TronCancelAllUnfreezeAction(),
    expectedBody: {'owner_address': _owner, 'visible': true},
  ),
  _ActionCase(
    name: 'locked Energy delegation',
    endpoint: '/wallet/delegateresource',
    action: TronDelegateAction(
      resource: TronResourceType.energy,
      amountSun: BigInt.from(3000000),
      receiverAddress: _receiver,
      lock: true,
      lockPeriod: 86400,
    ),
    expectedBody: {
      'owner_address': _owner,
      'receiver_address': _receiver,
      'balance': 3000000,
      'resource': 'ENERGY',
      'lock': true,
      'lock_period': 86400,
      'visible': true,
    },
  ),
  _ActionCase(
    name: 'Bandwidth undelegation',
    endpoint: '/wallet/undelegateresource',
    action: TronUndelegateAction(
      resource: TronResourceType.bandwidth,
      amountSun: BigInt.from(1000000),
      receiverAddress: _receiver,
    ),
    expectedBody: {
      'owner_address': _owner,
      'receiver_address': _receiver,
      'balance': 1000000,
      'resource': 'BANDWIDTH',
      'visible': true,
    },
  ),
  _ActionCase(
    name: 'witness vote replacement',
    endpoint: '/wallet/votewitnessaccount',
    action: TronVoteAction(
      votes: [TronVote(witnessAddress: _witness, voteCount: 7)],
    ),
    expectedBody: {
      'owner_address': _owner,
      'votes': [
        {'vote_address': _witness, 'vote_count': 7},
      ],
      'visible': true,
    },
  ),
  const _ActionCase(
    name: 'voting reward claim',
    endpoint: '/wallet/withdrawbalance',
    action: TronClaimRewardAction(),
    expectedBody: {'owner_address': _owner, 'visible': true},
  ),
];

final class _ActionCase {
  const _ActionCase({
    required this.name,
    required this.endpoint,
    required this.action,
    required this.expectedBody,
  });

  final String name;
  final String endpoint;
  final TronStakingAction action;
  final Map<String, Object?> expectedBody;
}

List<int> _rawData(TronStakingAction action) =>
    _bytesField(11, _contract(action));

List<int> _contract(TronStakingAction action) {
  final type = _contractType(action);
  final typeName = _contractTypeName(action);
  final any = <int>[
    ..._bytesField(1, utf8.encode('type.googleapis.com/protocol.$typeName')),
    ..._bytesField(2, _contractValue(action)),
  ];
  return <int>[..._varintField(1, type), ..._bytesField(2, any)];
}

List<int> _contractValue(TronStakingAction action) {
  final owner = _tronAddressBytes(_owner);
  return switch (action) {
    TronStakeAction() => [
      ..._bytesField(1, owner),
      ..._varintField(2, action.amountSun.toInt()),
      ..._varintField(3, action.resource.apiCode),
    ],
    TronUnstakeAction() => [
      ..._bytesField(1, owner),
      ..._varintField(2, action.amountSun.toInt()),
      ..._varintField(3, action.resource.apiCode),
    ],
    TronWithdrawUnfreezeAction() ||
    TronCancelAllUnfreezeAction() ||
    TronClaimRewardAction() => _bytesField(1, owner),
    TronDelegateAction() => [
      ..._bytesField(1, owner),
      ..._varintField(2, action.resource.apiCode),
      ..._varintField(3, action.amountSun.toInt()),
      ..._bytesField(4, _tronAddressBytes(action.receiverAddress)),
      if (action.lock) ..._varintField(5, 1),
      if (action.lockPeriod != null) ..._varintField(6, action.lockPeriod!),
    ],
    TronUndelegateAction() => [
      ..._bytesField(1, owner),
      ..._varintField(2, action.resource.apiCode),
      ..._varintField(3, action.amountSun.toInt()),
      ..._bytesField(4, _tronAddressBytes(action.receiverAddress)),
    ],
    TronVoteAction() => [
      ..._bytesField(1, owner),
      for (final vote in action.votes)
        ..._bytesField(2, [
          ..._bytesField(1, _tronAddressBytes(vote.witnessAddress)),
          ..._varintField(2, vote.voteCount),
        ]),
    ],
  };
}

Map<String, Object?> _rawDataJson(TronStakingAction action) {
  return {
    'contract': [
      {
        'type': _contractTypeName(action),
        'parameter': {
          'type_url':
              'type.googleapis.com/protocol.${_contractTypeName(action)}',
          'value': _jsonContractValue(action),
        },
      },
    ],
  };
}

Map<String, Object?> _jsonContractValue(TronStakingAction action) {
  return switch (action) {
    TronStakeAction() => {
      'owner_address': _owner,
      'frozen_balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
    },
    TronUnstakeAction() => {
      'owner_address': _owner,
      'unfreeze_balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
    },
    TronWithdrawUnfreezeAction() ||
    TronCancelAllUnfreezeAction() ||
    TronClaimRewardAction() => {'owner_address': _owner},
    TronDelegateAction() => {
      'owner_address': _owner,
      'resource': action.resource.apiValue,
      'balance': action.amountSun.toInt(),
      'receiver_address': action.receiverAddress,
      'lock': action.lock,
      'lock_period': action.lockPeriod,
    },
    TronUndelegateAction() => {
      'owner_address': _owner,
      'resource': action.resource.apiValue,
      'balance': action.amountSun.toInt(),
      'receiver_address': action.receiverAddress,
    },
    TronVoteAction() => {
      'owner_address': _owner,
      'votes': [
        for (final vote in action.votes)
          {'vote_address': vote.witnessAddress, 'vote_count': vote.voteCount},
      ],
    },
  };
}

int _contractType(TronStakingAction action) => switch (action) {
  TronVoteAction() => 4,
  TronClaimRewardAction() => 13,
  TronStakeAction() => 54,
  TronUnstakeAction() => 55,
  TronWithdrawUnfreezeAction() => 56,
  TronDelegateAction() => 57,
  TronUndelegateAction() => 58,
  TronCancelAllUnfreezeAction() => 59,
};

String _contractTypeName(TronStakingAction action) => switch (action) {
  TronVoteAction() => 'VoteWitnessContract',
  TronClaimRewardAction() => 'WithdrawBalanceContract',
  TronStakeAction() => 'FreezeBalanceV2Contract',
  TronUnstakeAction() => 'UnfreezeBalanceV2Contract',
  TronWithdrawUnfreezeAction() => 'WithdrawExpireUnfreezeContract',
  TronDelegateAction() => 'DelegateResourceContract',
  TronUndelegateAction() => 'UnDelegateResourceContract',
  TronCancelAllUnfreezeAction() => 'CancelAllUnfreezeV2Contract',
};

List<int> _varintField(int field, int value) => [
  ..._varint(field << 3),
  ..._varint(value),
];

List<int> _bytesField(int field, List<int> value) => [
  ..._varint((field << 3) | 2),
  ..._varint(value.length),
  ...value,
];

List<int> _varint(int value) {
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

List<int> _tronAddressBytes(String value) {
  var decoded = BigInt.zero;
  for (final unit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(unit));
    if (index < 0) {
      throw FormatException('invalid address');
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final bytes = <int>[];
  while (decoded > BigInt.zero) {
    bytes.insert(0, (decoded & BigInt.from(0xff)).toInt());
    decoded >>= 8;
  }
  final leading = value.codeUnits.takeWhile((unit) => unit == 0x31).length;
  return [...List<int>.filled(leading, 0), ...bytes].sublist(0, 21);
}

const _privateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _owner = 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH';
const _receiver = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj';
const _witness = 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE';
const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
