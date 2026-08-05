import 'package:wallet/wallet.dart' show isValidTronAddress;

String tronAddressToAbiParameter(String address) {
  if (!isValidTronAddress(address)) {
    throw StateError('Tron address is invalid');
  }
  final decoded = _decodeBase58(address);
  if (decoded.length != 25 || decoded.first != 0x41) {
    throw StateError('Tron address payload is invalid');
  }
  final payload = decoded.sublist(1, 21);
  return '${'0' * 24}${_bytesToHex(payload)}';
}

String uint256ToAbiParameter(BigInt value) {
  if (value < BigInt.zero) {
    throw ArgumentError.value(value, 'value', 'must not be negative');
  }
  return value.toRadixString(16).padLeft(64, '0');
}

String trc20TransferAbiParameter({
  required String toAddress,
  required BigInt amount,
}) {
  return '${tronAddressToAbiParameter(toAddress)}'
      '${uint256ToAbiParameter(amount)}';
}

List<int> _decodeBase58(String value) {
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw StateError('Tron address has invalid Base58 characters');
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final leadingZeroes =
      value.codeUnits.takeWhile((unit) => unit == 0x31).length;
  return [
    ...List<int>.filled(leadingZeroes, 0),
    ..._unsignedIntToBytes(decoded),
  ];
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

String _bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
