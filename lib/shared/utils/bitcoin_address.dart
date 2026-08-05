import 'dart:typed_data';

import 'package:cryptography/dart.dart';

enum BitcoinAddressNetwork {
  mainnet,
  testnet,
}

final class BitcoinWitnessProgram {
  const BitcoinWitnessProgram({
    required this.network,
    required this.version,
    required this.program,
  });

  final BitcoinAddressNetwork network;
  final int version;
  final List<int> program;
}

bool isBitcoinAddress(String value) {
  return bitcoinAddressNetwork(value) != null;
}

bool isBitcoinAddressForNetwork(String value, {required bool isTestnet}) {
  final network = bitcoinAddressNetwork(value);
  return network ==
      (isTestnet
          ? BitcoinAddressNetwork.testnet
          : BitcoinAddressNetwork.mainnet);
}

BitcoinAddressNetwork? bitcoinAddressNetwork(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return decodeBitcoinWitnessProgram(trimmed)?.network ??
      _base58BitcoinAddressNetwork(trimmed);
}

BitcoinWitnessProgram? decodeBitcoinWitnessProgram(String value) {
  if (value.length > _bech32MaxLength || _isMixedCase(value)) {
    return null;
  }

  final normalized = value.toLowerCase();
  final separatorIndex = normalized.lastIndexOf(_bech32Separator);
  if (separatorIndex <= 0 ||
      normalized.length - separatorIndex - 1 < _bech32ChecksumLength + 1) {
    return null;
  }

  final hrp = normalized.substring(0, separatorIndex);
  if (hrp != 'bc' && hrp != 'tb') {
    return null;
  }
  final network = switch (hrp) {
    'bc' => BitcoinAddressNetwork.mainnet,
    'tb' => BitcoinAddressNetwork.testnet,
    _ => null,
  };
  if (network == null) {
    return null;
  }

  final data = <int>[];
  for (var index = separatorIndex + 1; index < normalized.length; index += 1) {
    final value = _bech32Charset.indexOf(normalized[index]);
    if (value < 0) {
      return null;
    }
    data.add(value);
  }

  final checksum = _bech32Polymod([..._bech32HrpExpand(hrp), ...data]);
  final encoding = switch (checksum) {
    _bech32ChecksumConstant => _Bech32Encoding.bech32,
    _bech32mChecksumConstant => _Bech32Encoding.bech32m,
    _ => null,
  };
  if (encoding == null) {
    return null;
  }

  final payload = data.sublist(0, data.length - _bech32ChecksumLength);
  if (payload.isEmpty) {
    return null;
  }

  final witnessVersion = payload.first;
  if (witnessVersion > 16) {
    return null;
  }
  if (witnessVersion == 0 && encoding != _Bech32Encoding.bech32) {
    return null;
  }
  if (witnessVersion != 0 && encoding != _Bech32Encoding.bech32m) {
    return null;
  }

  final witnessProgram = _convertBits(
    payload.sublist(1),
    from: 5,
    to: 8,
    pad: false,
  );
  if (witnessProgram == null ||
      witnessProgram.length < 2 ||
      witnessProgram.length > 40) {
    return null;
  }

  final validVersion0 =
      witnessProgram.length == 20 || witnessProgram.length == 32;
  if (witnessVersion == 0 && !validVersion0) {
    return null;
  }

  return BitcoinWitnessProgram(
    network: network,
    version: witnessVersion,
    program: List<int>.unmodifiable(witnessProgram),
  );
}

BitcoinAddressNetwork? _base58BitcoinAddressNetwork(String value) {
  final decoded = _tryDecodeBase58(value);
  if (decoded == null || decoded.length != 25) {
    return null;
  }

  final payload = decoded.sublist(0, decoded.length - 4);
  final checksum = decoded.sublist(decoded.length - 4);
  final expectedChecksum = _hash256(payload).sublist(0, 4);
  for (var index = 0; index < checksum.length; index += 1) {
    if (checksum[index] != expectedChecksum[index]) {
      return null;
    }
  }

  final version = payload.first;
  final hash = payload.sublist(1);
  if (hash.length != 20) {
    return null;
  }
  return switch (version) {
    0x00 || 0x05 => BitcoinAddressNetwork.mainnet,
    0x6f || 0xc4 => BitcoinAddressNetwork.testnet,
    _ => null,
  };
}

bool _isMixedCase(String value) {
  return value.toLowerCase() != value && value.toUpperCase() != value;
}

int _bech32Polymod(List<int> values) {
  var checksum = 1;
  for (final value in values) {
    final top = checksum >> 25;
    checksum = ((checksum & 0x1ffffff) << 5) ^ value;
    for (var index = 0; index < _bech32Generator.length; index += 1) {
      if (((top >> index) & 1) == 1) {
        checksum ^= _bech32Generator[index];
      }
    }
  }
  return checksum;
}

List<int> _bech32HrpExpand(String hrp) {
  return [
    for (final codeUnit in hrp.codeUnits) codeUnit >> 5,
    0,
    for (final codeUnit in hrp.codeUnits) codeUnit & 31,
  ];
}

List<int>? _convertBits(
  List<int> data, {
  required int from,
  required int to,
  required bool pad,
}) {
  var accumulator = 0;
  var bits = 0;
  final result = <int>[];
  final maxValue = (1 << to) - 1;
  final maxAccumulator = (1 << (from + to - 1)) - 1;

  for (final value in data) {
    if (value < 0 || (value >> from) != 0) {
      return null;
    }
    accumulator = ((accumulator << from) | value) & maxAccumulator;
    bits += from;
    while (bits >= to) {
      bits -= to;
      result.add((accumulator >> bits) & maxValue);
    }
  }

  if (pad) {
    if (bits > 0) {
      result.add((accumulator << (to - bits)) & maxValue);
    }
  } else if (bits >= from) {
    return null;
  } else if (((accumulator << (to - bits)) & maxValue) != 0) {
    return null;
  }

  return result;
}

Uint8List? _tryDecodeBase58(String value) {
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      return null;
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }

  final leadingZeroes =
      value.codeUnits.takeWhile((unit) => unit == 0x31).length;
  return Uint8List.fromList([
    ...List<int>.filled(leadingZeroes, 0),
    ..._unsignedIntToBytes(decoded),
  ]);
}

List<int> _unsignedIntToBytes(BigInt value) {
  if (value == BigInt.zero) {
    return const [];
  }

  final bytes = <int>[];
  var remaining = value;
  while (remaining > BigInt.zero) {
    bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
    remaining >>= 8;
  }
  return bytes;
}

List<int> _hash256(List<int> bytes) {
  final first = _sha256.hashSync(bytes);
  final second = _sha256.hashSync(first.bytes);
  return second.bytes;
}

enum _Bech32Encoding { bech32, bech32m }

const _bech32MaxLength = 90;
const _bech32Separator = '1';
const _bech32ChecksumLength = 6;
const _bech32ChecksumConstant = 1;
const _bech32mChecksumConstant = 0x2bc830a3;
const _bech32Charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
const _bech32Generator = [
  0x3b6a57b2,
  0x26508e6d,
  0x1ea119fa,
  0x3d4233dd,
  0x2a1462b3,
];
const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const _sha256 = DartSha256();
