import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/domain/eip712_typed_data.dart';
import 'package:web3dart/web3dart.dart' as web3;

void main() {
  test('encodes EIP-712 v4 arrays and nested structs', () {
    final typedData = Eip712TypedData.tryParse(jsonEncode(_typedData));
    expect(typedData, isNotNull);

    final signature = web3.EthPrivateKey.fromHex(
      web3.bytesToHex(web3.keccakUtf8('cow')),
    ).signToUint8List(typedData!.signingPayload());

    expect(
      web3.bytesToHex(signature, include0x: true),
      '0x65cbd956f2fae28a601bebc9b906cea0191744bd4c4247bcd27cd08f8eb6b71c'
      '78efdf7a31dc9abee78f492292721f362d296cf86b4538e07b51303b67f749061b',
    );
  });
}

const _typedData = {
  'types': {
    'EIP712Domain': [
      {'name': 'name', 'type': 'string'},
      {'name': 'version', 'type': 'string'},
      {'name': 'chainId', 'type': 'uint256'},
      {'name': 'verifyingContract', 'type': 'address'},
    ],
    'Person': [
      {'name': 'name', 'type': 'string'},
      {'name': 'wallets', 'type': 'address[]'},
    ],
    'Mail': [
      {'name': 'from', 'type': 'Person'},
      {'name': 'to', 'type': 'Person[]'},
      {'name': 'contents', 'type': 'string'},
    ],
    'Group': [
      {'name': 'name', 'type': 'string'},
      {'name': 'members', 'type': 'Person[]'},
    ],
  },
  'domain': {
    'name': 'Ether Mail',
    'version': '1',
    'chainId': 1,
    'verifyingContract': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  'primaryType': 'Mail',
  'message': {
    'from': {
      'name': 'Cow',
      'wallets': [
        '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
        '0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF',
      ],
    },
    'to': [
      {
        'name': 'Bob',
        'wallets': [
          '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
          '0xB0BdaBea57B0BDABeA57b0bdABEA57b0BDabEa57',
          '0xB0B0b0b0b0b0B000000000000000000000000000',
        ],
      },
    ],
    'contents': 'Hello, Bob!',
  },
};
