import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/utils/bitcoin_address.dart';

Future<Uint8List> bitcoinScriptPubKeyForAddress(String address) async {
  final witnessProgram = decodeBitcoinWitnessProgram(address);
  if (witnessProgram != null) {
    return Uint8List.fromList([
      witnessProgram.version == 0 ? 0x00 : 0x50 + witnessProgram.version,
      witnessProgram.program.length,
      ...witnessProgram.program,
    ]);
  }
  return _base58ScriptPubKey(address);
}

Future<Uint8List> _base58ScriptPubKey(String address) async {
  final decoded = _decodeBase58(address);
  if (decoded.length != 25) {
    throw StateError('Bitcoin base58 address has invalid length');
  }
  final payload = Uint8List.fromList(decoded.sublist(0, decoded.length - 4));
  final checksum = decoded.sublist(decoded.length - 4);
  final expectedChecksum = (await _hash256(payload)).sublist(0, 4);
  for (var index = 0; index < checksum.length; index += 1) {
    if (checksum[index] != expectedChecksum[index]) {
      throw StateError('Bitcoin base58 address checksum is invalid');
    }
  }

  final version = payload.first;
  final hash = payload.sublist(1);
  if (hash.length != 20) {
    throw StateError('Bitcoin base58 address hash is invalid');
  }

  return switch (version) {
    0x00 || 0x6f => Uint8List.fromList([
        0x76,
        0xa9,
        0x14,
        ...hash,
        0x88,
        0xac,
      ]),
    0x05 || 0xc4 => Uint8List.fromList([
        0xa9,
        0x14,
        ...hash,
        0x87,
      ]),
    _ => throw StateError('Bitcoin base58 address version is unsupported'),
  };
}

Uint8List _decodeBase58(String value) {
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw StateError('Bitcoin base58 address has invalid characters');
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final leadingZeroes =
      value.codeUnits.takeWhile((unit) => unit == 0x31).length;
  return Uint8List.fromList([
    ...List<int>.filled(leadingZeroes, 0),
    ...web3.unsignedIntToBytes(decoded),
  ]);
}

Future<Uint8List> _hash256(Uint8List bytes) async {
  final first = await _sha256.hash(bytes);
  final second = await _sha256.hash(first.bytes);
  return Uint8List.fromList(second.bytes);
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
final _sha256 = Sha256();
