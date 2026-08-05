import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:wallet/wallet.dart' show isValidTronAddress;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/utils/tron_abi.dart';
import '../domain/transaction_request.dart';

final class TronTransactionValidationException implements Exception {
  const TronTransactionValidationException(this.reason);

  final String reason;

  @override
  String toString() => 'Invalid Tron transaction: $reason';
}

Future<void> validateTronTransferTransaction({
  required Map<String, Object?> transaction,
  required String fromAddress,
  required TransactionRequest request,
  required BigInt? feeLimitSun,
}) async {
  if (!isValidTronAddress(fromAddress) ||
      !isValidTronAddress(request.toAddress)) {
    throw const TronTransactionValidationException('invalidAddress');
  }
  final txId = _stringField(transaction, 'txID');
  final rawDataHex = _stringField(transaction, 'raw_data_hex');
  final rawDataJson = transaction['raw_data'];
  if (rawDataJson is! Map<String, Object?>) {
    throw const TronTransactionValidationException('missingRawData');
  }
  final rawBytes = _hexBytes(rawDataHex);
  final calculatedTxId = web3.bytesToHex((await Sha256().hash(rawBytes)).bytes);
  if (calculatedTxId.toLowerCase() != txId.toLowerCase()) {
    throw const TronTransactionValidationException('txIdHashMismatch');
  }

  switch (request.transactionType) {
    case TransactionType.nativeTransfer:
      _verifyNativeJson(
        rawDataJson,
        fromAddress: fromAddress,
        request: request,
      );
      _verifyNativeProto(rawBytes, fromAddress: fromAddress, request: request);
    case TransactionType.trc20Transfer:
      final contractAddress = request.tokenContractAddress;
      if (contractAddress == null || !isValidTronAddress(contractAddress)) {
        throw const TronTransactionValidationException('invalidContract');
      }
      final resolvedFeeLimit = feeLimitSun ?? BigInt.from(100000000);
      _verifyTrc20Json(
        rawDataJson,
        fromAddress: fromAddress,
        contractAddress: contractAddress,
        request: request,
        feeLimitSun: resolvedFeeLimit,
      );
      _verifyTrc20Proto(
        rawBytes,
        fromAddress: fromAddress,
        contractAddress: contractAddress,
        request: request,
        feeLimitSun: resolvedFeeLimit,
      );
    default:
      throw const TronTransactionValidationException('unsupportedType');
  }
}

void _verifyNativeJson(
  Map<String, Object?> rawData, {
  required String fromAddress,
  required TransactionRequest request,
}) {
  final value = _jsonContractValue(rawData, 'TransferContract');
  if (value['owner_address'] != fromAddress ||
      value['to_address'] != request.toAddress ||
      _jsonBigInt(value['amount']) != _amount(request)) {
    throw const TronTransactionValidationException('jsonValueMismatch');
  }
}

void _verifyTrc20Json(
  Map<String, Object?> rawData, {
  required String fromAddress,
  required String contractAddress,
  required TransactionRequest request,
  required BigInt feeLimitSun,
}) {
  final value = _jsonContractValue(rawData, 'TriggerSmartContract');
  final expectedData = _trc20Calldata(request);
  final data = value['data'];
  if (value['owner_address'] != fromAddress ||
      value['contract_address'] != contractAddress ||
      data is! String ||
      data.toLowerCase() != web3.bytesToHex(expectedData).toLowerCase() ||
      _jsonBigInt(rawData['fee_limit']) != feeLimitSun) {
    throw const TronTransactionValidationException('jsonValueMismatch');
  }
}

Map<String, Object?> _jsonContractValue(
  Map<String, Object?> rawData,
  String expectedType,
) {
  final contracts = rawData['contract'];
  if (contracts is! List<Object?> || contracts.length != 1) {
    throw const TronTransactionValidationException('jsonContractCount');
  }
  final contract = contracts.single;
  if (contract is! Map<String, Object?> || contract['type'] != expectedType) {
    throw const TronTransactionValidationException('jsonContractType');
  }
  final parameter = contract['parameter'];
  if (parameter is! Map<String, Object?> ||
      parameter['type_url'] != 'type.googleapis.com/protocol.$expectedType') {
    throw const TronTransactionValidationException('jsonTypeUrl');
  }
  final value = parameter['value'];
  if (value is! Map<String, Object?>) {
    throw const TronTransactionValidationException('jsonContractValue');
  }
  return value;
}

void _verifyNativeProto(
  List<int> rawBytes, {
  required String fromAddress,
  required TransactionRequest request,
}) {
  final value = _contractValue(
    rawBytes,
    expectedType: 1,
    expectedTypeName: 'TransferContract',
  );
  _expectAllowedFields(value, const {1, 2, 3});
  _expectBytes(value.singleBytes(1), _tronAddressBytes(fromAddress));
  _expectBytes(value.singleBytes(2), _tronAddressBytes(request.toAddress));
  _expectVarint(value, 3, _amount(request));
}

void _verifyTrc20Proto(
  List<int> rawBytes, {
  required String fromAddress,
  required String contractAddress,
  required TransactionRequest request,
  required BigInt feeLimitSun,
}) {
  final rawMessage = _ProtoMessage.decode(rawBytes);
  _expectVarint(rawMessage, 18, feeLimitSun);
  final value = _contractValueFromMessage(
    rawMessage,
    expectedType: 31,
    expectedTypeName: 'TriggerSmartContract',
  );
  _expectAllowedFields(value, const {1, 2, 3, 4, 5, 6});
  _expectBytes(value.singleBytes(1), _tronAddressBytes(fromAddress));
  _expectBytes(value.singleBytes(2), _tronAddressBytes(contractAddress));
  _expectBytes(value.singleBytes(3), _trc20Calldata(request));
  _expectVarint(value, 4, BigInt.zero, defaultValue: BigInt.zero);
  _expectVarint(value, 5, BigInt.zero, defaultValue: BigInt.zero);
  _expectVarint(value, 6, BigInt.zero, defaultValue: BigInt.zero);
}

_ProtoMessage _contractValue(
  List<int> rawBytes, {
  required int expectedType,
  required String expectedTypeName,
}) {
  return _contractValueFromMessage(
    _ProtoMessage.decode(rawBytes),
    expectedType: expectedType,
    expectedTypeName: expectedTypeName,
  );
}

_ProtoMessage _contractValueFromMessage(
  _ProtoMessage rawMessage, {
  required int expectedType,
  required String expectedTypeName,
}) {
  final contracts = rawMessage.bytesValues(11);
  if (contracts.length != 1) {
    throw const TronTransactionValidationException('contractCount');
  }
  final contract = _ProtoMessage.decode(contracts.single);
  if (contract.varint(1) != BigInt.from(expectedType)) {
    throw const TronTransactionValidationException('contractType');
  }
  if (contract.keys.any((field) => field != 1 && field != 2 && field != 5) ||
      contract.varint(5, defaultValue: BigInt.zero) != BigInt.zero) {
    throw const TronTransactionValidationException('contractFields');
  }
  final any = _ProtoMessage.decode(contract.singleBytes(2));
  final typeUrl = utf8.decode(any.singleBytes(1));
  if (typeUrl != 'type.googleapis.com/protocol.$expectedTypeName') {
    throw const TronTransactionValidationException('typeUrl');
  }
  return _ProtoMessage.decode(any.singleBytes(2));
}

List<int> _trc20Calldata(TransactionRequest request) {
  return web3.hexToBytes(
    'a9059cbb${trc20TransferAbiParameter(toAddress: request.toAddress, amount: _amount(request))}',
  );
}

BigInt _amount(TransactionRequest request) {
  final value = request.amountInBaseUnits;
  final amount = value == null ? null : BigInt.tryParse(value);
  if (amount == null || amount <= BigInt.zero) {
    throw const TronTransactionValidationException('invalidAmount');
  }
  return amount;
}

BigInt? _jsonBigInt(Object? value) {
  return switch (value) {
    int() => BigInt.from(value),
    String() => BigInt.tryParse(value),
    _ => null,
  };
}

void _expectAllowedFields(_ProtoMessage value, Set<int> allowed) {
  if (value.keys.any((field) => !allowed.contains(field))) {
    throw const TronTransactionValidationException('unexpectedField');
  }
}

void _expectVarint(
  _ProtoMessage value,
  int field,
  BigInt expected, {
  BigInt? defaultValue,
}) {
  if (value.varint(field, defaultValue: defaultValue) != expected) {
    throw const TronTransactionValidationException('varintMismatch');
  }
}

void _expectBytes(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) {
    throw const TronTransactionValidationException('bytesMismatch');
  }
  for (var index = 0; index < actual.length; index += 1) {
    if (actual[index] != expected[index]) {
      throw const TronTransactionValidationException('bytesMismatch');
    }
  }
}

final class _ProtoMessage {
  _ProtoMessage(this._fields);

  final Map<int, List<Object>> _fields;

  Iterable<int> get keys => _fields.keys;

  BigInt varint(int field, {BigInt? defaultValue}) {
    final values = _fields[field];
    if (values == null || values.isEmpty) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw const TronTransactionValidationException('missingVarint');
    }
    final value = values.single;
    if (value is! BigInt) {
      throw const TronTransactionValidationException('wrongWireType');
    }
    return value;
  }

  List<int> singleBytes(int field) {
    final values = bytesValues(field);
    if (values.length != 1) {
      throw const TronTransactionValidationException('missingBytes');
    }
    return values.single;
  }

  List<List<int>> bytesValues(int field) {
    final values = _fields[field] ?? const <Object>[];
    if (values.any((value) => value is! List<int>)) {
      throw const TronTransactionValidationException('wrongWireType');
    }
    return values.cast<List<int>>();
  }

  static _ProtoMessage decode(List<int> bytes) {
    final fields = <int, List<Object>>{};
    var offset = 0;
    while (offset < bytes.length) {
      final keyResult = _readVarint(bytes, offset);
      final key = keyResult.$1.toInt();
      offset = keyResult.$2;
      final field = key >> 3;
      final wireType = key & 0x07;
      if (field <= 0) {
        throw const TronTransactionValidationException('invalidField');
      }
      Object value;
      switch (wireType) {
        case 0:
          final result = _readVarint(bytes, offset);
          value = result.$1;
          offset = result.$2;
        case 1:
          if (offset + 8 > bytes.length) {
            throw const TronTransactionValidationException('truncated');
          }
          value = bytes.sublist(offset, offset + 8);
          offset += 8;
        case 2:
          final lengthResult = _readVarint(bytes, offset);
          final length = lengthResult.$1.toInt();
          offset = lengthResult.$2;
          if (length < 0 || offset + length > bytes.length) {
            throw const TronTransactionValidationException('truncated');
          }
          value = bytes.sublist(offset, offset + length);
          offset += length;
        case 5:
          if (offset + 4 > bytes.length) {
            throw const TronTransactionValidationException('truncated');
          }
          value = bytes.sublist(offset, offset + 4);
          offset += 4;
        default:
          throw const TronTransactionValidationException('wireType');
      }
      fields.putIfAbsent(field, () => <Object>[]).add(value);
    }
    return _ProtoMessage(fields);
  }
}

(BigInt, int) _readVarint(List<int> bytes, int start) {
  var result = BigInt.zero;
  var shift = 0;
  var offset = start;
  while (offset < bytes.length && shift <= 70) {
    final byte = bytes[offset];
    offset += 1;
    result |= BigInt.from(byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) {
      return (result, offset);
    }
    shift += 7;
  }
  throw const TronTransactionValidationException('invalidVarint');
}

List<int> _hexBytes(String value) {
  if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const TronTransactionValidationException('invalidHex');
  }
  return web3.hexToBytes(value);
}

List<int> _tronAddressBytes(String address) {
  if (!isValidTronAddress(address)) {
    throw const TronTransactionValidationException('invalidAddress');
  }
  var decoded = BigInt.zero;
  for (final codeUnit in address.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw const TronTransactionValidationException('invalidAddress');
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final bytes = <int>[];
  while (decoded > BigInt.zero) {
    bytes.insert(0, (decoded & BigInt.from(0xff)).toInt());
    decoded >>= 8;
  }
  final leadingZeroes = address.codeUnits
      .takeWhile((unit) => unit == 0x31)
      .length;
  final decodedBytes = [...List<int>.filled(leadingZeroes, 0), ...bytes];
  if (decodedBytes.length != 25) {
    throw const TronTransactionValidationException('invalidAddress');
  }
  return decodedBytes.sublist(0, 21);
}

String _stringField(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw TronTransactionValidationException('missing$field');
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
