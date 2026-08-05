import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' show isValidTronAddress;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/bounded_http_client.dart';
import '../domain/tron_staking_action.dart';

final class TronStakingTransactionInput {
  const TronStakingTransactionInput({
    required this.apiBaseUrl,
    required this.privateKey,
    required this.ownerAddress,
    required this.action,
    this.headers = const {},
  });

  final String apiBaseUrl;
  final String privateKey;
  final String ownerAddress;
  final TronStakingAction action;
  final Map<String, String> headers;
}

abstract interface class TronStakingTransactionService {
  Future<String> signAndBroadcast(TronStakingTransactionInput input);
}

final class TronStakingTransactionValidationException implements Exception {
  const TronStakingTransactionValidationException([this.reason]);

  final String? reason;

  @override
  String toString() => 'Invalid Tron staking transaction';
}

enum TronStakingTransactionFailureReason {
  insufficientBalance,
  insufficientStakedBalance,
  noUnfreezeSlots,
  nothingToWithdraw,
  nothingToCancel,
  invalidDelegation,
  insufficientDelegatableBalance,
  delegationLocked,
  insufficientDelegatedBalance,
  excessiveVotes,
  nothingToClaim,
  rejected,
}

final class TronStakingTransactionRejectedException implements Exception {
  const TronStakingTransactionRejectedException(this.reason, {this.code});

  final TronStakingTransactionFailureReason reason;
  final String? code;

  @override
  String toString() =>
      'Tron staking transaction rejected (${code ?? reason.name})';
}

final class HttpTronStakingTransactionService
    implements TronStakingTransactionService {
  HttpTronStakingTransactionService({http.Client? client})
    : _client = client ?? BoundedHttpClient();

  final http.Client _client;

  @override
  Future<String> signAndBroadcast(TronStakingTransactionInput input) async {
    if (!isValidTronAddress(input.ownerAddress)) {
      throw const TronStakingTransactionValidationException('invalidOwner');
    }
    final action = input.action;
    if (action is TronDelegateAction &&
            !isValidTronAddress(action.receiverAddress) ||
        action is TronUndelegateAction &&
            !isValidTronAddress(action.receiverAddress)) {
      throw const TronStakingTransactionValidationException('invalidReceiver');
    }
    if (action is TronVoteAction) {
      for (final vote in action.votes) {
        if (!isValidTronAddress(vote.witnessAddress) || vote.voteCount < 0) {
          throw const TronStakingTransactionValidationException('invalidVote');
        }
      }
    }

    final createResponse = await _client.post(
      _endpoint(input.apiBaseUrl, _endpointFor(action)),
      headers: {'content-type': 'application/json', ...input.headers},
      body: jsonEncode(_requestBody(input.ownerAddress, action)),
    );
    final created = _decodeJsonObject(
      createResponse,
      operation: 'create Tron staking transaction',
    );
    final result = created['result'];
    if (result is Map<String, Object?> && result['result'] == false) {
      throw _nodeRejection(created, action);
    }
    if (created['Error'] != null || created['error'] != null) {
      throw _nodeRejection(created, action);
    }
    final transactionValue = created['transaction'];
    final transaction = transactionValue is Map<String, Object?>
        ? Map<String, Object?>.from(transactionValue)
        : Map<String, Object?>.from(created);
    final txId = _stringField(transaction, 'txID');
    final outerTxId = created['txid'];
    if (outerTxId is String && outerTxId.isNotEmpty && outerTxId != txId) {
      throw const TronStakingTransactionValidationException('txIdMismatch');
    }
    await _verifyTransaction(
      transaction: transaction,
      txId: txId,
      ownerAddress: input.ownerAddress,
      action: action,
    );

    transaction['signature'] = [_signatureHex(txId, input.privateKey)];
    final broadcastResponse = await _client.post(
      _endpoint(input.apiBaseUrl, '/wallet/broadcasttransaction'),
      headers: {'content-type': 'application/json', ...input.headers},
      body: jsonEncode(transaction),
    );
    final broadcast = _decodeJsonObject(
      broadcastResponse,
      operation: 'broadcast Tron staking transaction',
    );
    if (broadcast['result'] != true) {
      throw _nodeRejection(broadcast, action);
    }
    return (broadcast['txid'] as String?) ??
        (broadcast['txID'] as String?) ??
        txId;
  }

  void close() => _client.close();
}

TronStakingTransactionRejectedException _nodeRejection(
  Map<String, Object?> response,
  TronStakingAction action,
) {
  final result = response['result'];
  final details = result is Map<String, Object?> ? result : response;
  final code =
      _optionalString(details['code']) ?? _optionalString(response['code']);
  final messageValue =
      details['message'] ??
      response['message'] ??
      response['Error'] ??
      response['error'];
  final message = _decodeNodeMessage(messageValue);
  return TronStakingTransactionRejectedException(
    _classifyNodeRejection(action, code: code, message: message),
    code: code,
  );
}

TronStakingTransactionFailureReason _classifyNodeRejection(
  TronStakingAction action, {
  required String? code,
  required String message,
}) {
  final normalized = '${code ?? ''} $message'.toLowerCase().replaceAll(
    RegExp(r'[_-]+'),
    ' ',
  );
  final insufficient =
      normalized.contains('insufficient') ||
      normalized.contains('not sufficient') ||
      normalized.contains('not enough') ||
      normalized.contains('less than or equal');
  return switch (action) {
    TronStakeAction() when insufficient && normalized.contains('balance') =>
      TronStakingTransactionFailureReason.insufficientBalance,
    TronUnstakeAction()
        when normalized.contains('unfreeze') &&
            (normalized.contains('times') ||
                normalized.contains('count') ||
                normalized.contains('limit') ||
                normalized.contains('slot')) =>
      TronStakingTransactionFailureReason.noUnfreezeSlots,
    TronUnstakeAction() when insufficient || normalized.contains('frozen') =>
      TronStakingTransactionFailureReason.insufficientStakedBalance,
    TronWithdrawUnfreezeAction()
        when normalized.contains('withdraw') ||
            normalized.contains('unfreeze') =>
      TronStakingTransactionFailureReason.nothingToWithdraw,
    TronCancelAllUnfreezeAction()
        when normalized.contains('cancel') || normalized.contains('unfreeze') =>
      TronStakingTransactionFailureReason.nothingToCancel,
    TronDelegateAction()
        when normalized.contains('lock period') ||
            normalized.contains('receiver') ||
            normalized.contains('address') =>
      TronStakingTransactionFailureReason.invalidDelegation,
    TronDelegateAction()
        when insufficient ||
            normalized.contains('available freezebalance') ||
            normalized.contains('available freeze balance') =>
      TronStakingTransactionFailureReason.insufficientDelegatableBalance,
    TronUndelegateAction() when normalized.contains('lock') =>
      TronStakingTransactionFailureReason.delegationLocked,
    TronUndelegateAction()
        when normalized.contains('receiver') ||
            normalized.contains('address') =>
      TronStakingTransactionFailureReason.invalidDelegation,
    TronUndelegateAction()
        when insufficient || normalized.contains('delegated balance') =>
      TronStakingTransactionFailureReason.insufficientDelegatedBalance,
    TronVoteAction()
        when normalized.contains('vote') || normalized.contains('tron power') =>
      TronStakingTransactionFailureReason.excessiveVotes,
    TronClaimRewardAction()
        when normalized.contains('reward') ||
            normalized.contains('allowance') ||
            normalized.contains('withdraw') =>
      TronStakingTransactionFailureReason.nothingToClaim,
    _ => TronStakingTransactionFailureReason.rejected,
  };
}

String _decodeNodeMessage(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return '';
  }
  final raw = value.trim();
  try {
    final padded = raw.padRight((raw.length + 3) ~/ 4 * 4, '=');
    final decoded = utf8.decode(base64Decode(padded));
    if (decoded.runes.every(
      (rune) => rune == 0x09 || rune == 0x0a || rune == 0x0d || rune >= 0x20,
    )) {
      return decoded;
    }
  } catch (_) {
    // Some nodes return a plain-text message instead of Base64.
  }
  return raw;
}

String? _optionalString(Object? value) {
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _endpointFor(TronStakingAction action) => switch (action) {
  TronStakeAction() => '/wallet/freezebalancev2',
  TronUnstakeAction() => '/wallet/unfreezebalancev2',
  TronWithdrawUnfreezeAction() => '/wallet/withdrawexpireunfreeze',
  TronCancelAllUnfreezeAction() => '/wallet/cancelallunfreezev2',
  TronDelegateAction() => '/wallet/delegateresource',
  TronUndelegateAction() => '/wallet/undelegateresource',
  TronVoteAction() => '/wallet/votewitnessaccount',
  TronClaimRewardAction() => '/wallet/withdrawbalance',
};

Map<String, Object?> _requestBody(
  String ownerAddress,
  TronStakingAction action,
) {
  return switch (action) {
    TronStakeAction() => {
      'owner_address': ownerAddress,
      'frozen_balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'visible': true,
    },
    TronUnstakeAction() => {
      'owner_address': ownerAddress,
      'unfreeze_balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'visible': true,
    },
    TronWithdrawUnfreezeAction() ||
    TronCancelAllUnfreezeAction() ||
    TronClaimRewardAction() => {'owner_address': ownerAddress, 'visible': true},
    TronDelegateAction() => {
      'owner_address': ownerAddress,
      'receiver_address': action.receiverAddress,
      'balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'lock': action.lock,
      if (action.lockPeriod != null) 'lock_period': action.lockPeriod,
      'visible': true,
    },
    TronUndelegateAction() => {
      'owner_address': ownerAddress,
      'receiver_address': action.receiverAddress,
      'balance': action.amountSun.toInt(),
      'resource': action.resource.apiValue,
      'visible': true,
    },
    TronVoteAction() => {
      'owner_address': ownerAddress,
      'votes': [
        for (final vote in action.votes)
          {'vote_address': vote.witnessAddress, 'vote_count': vote.voteCount},
      ],
      'visible': true,
    },
  };
}

Future<void> _verifyTransaction({
  required Map<String, Object?> transaction,
  required String txId,
  required String ownerAddress,
  required TronStakingAction action,
}) async {
  final rawDataHex = _stringField(transaction, 'raw_data_hex');
  final rawDataJson = transaction['raw_data'];
  if (rawDataJson is! Map<String, Object?>) {
    throw const TronStakingTransactionValidationException('missingRawData');
  }
  final rawBytes = _hexBytes(rawDataHex);
  final calculatedTxId = web3.bytesToHex((await Sha256().hash(rawBytes)).bytes);
  if (calculatedTxId.toLowerCase() != txId.toLowerCase()) {
    throw const TronStakingTransactionValidationException('txIdHashMismatch');
  }

  final expectedType = _contractType(action);
  final expectedTypeName = _contractTypeName(action);
  _verifyJsonContract(rawDataJson, expectedTypeName);

  final rawMessage = _ProtoMessage.decode(rawBytes);
  final contracts = rawMessage.bytesValues(11);
  if (contracts.length != 1) {
    throw const TronStakingTransactionValidationException('contractCount');
  }
  final contract = _ProtoMessage.decode(contracts.single);
  if (contract.varint(1) != BigInt.from(expectedType)) {
    throw const TronStakingTransactionValidationException('contractType');
  }
  if (contract.keys.any((field) => field != 1 && field != 2 && field != 5) ||
      contract.varint(5, defaultValue: BigInt.zero) != BigInt.zero) {
    throw const TronStakingTransactionValidationException('contractFields');
  }
  final any = _ProtoMessage.decode(contract.singleBytes(2));
  final typeUrl = utf8.decode(any.singleBytes(1));
  if (typeUrl != 'type.googleapis.com/protocol.$expectedTypeName') {
    throw const TronStakingTransactionValidationException('typeUrl');
  }
  final value = _ProtoMessage.decode(any.singleBytes(2));
  _verifyContractValue(value, ownerAddress: ownerAddress, action: action);
}

void _verifyJsonContract(
  Map<String, Object?> rawData,
  String expectedTypeName,
) {
  final contracts = rawData['contract'];
  if (contracts is! List<Object?> || contracts.length != 1) {
    throw const TronStakingTransactionValidationException('jsonContractCount');
  }
  final contract = contracts.single;
  if (contract is! Map<String, Object?> ||
      contract['type'] != expectedTypeName ||
      contract['parameter'] is! Map<String, Object?>) {
    throw const TronStakingTransactionValidationException('jsonContractType');
  }
}

void _verifyContractValue(
  _ProtoMessage value, {
  required String ownerAddress,
  required TronStakingAction action,
}) {
  _expectBytes(value.singleBytes(1), _tronAddressBytes(ownerAddress));
  switch (action) {
    case TronStakeAction():
      _expectAllowedFields(value, const {1, 2, 3});
      _expectVarint(value, 2, action.amountSun);
      _expectVarint(value, 3, BigInt.from(action.resource.apiCode));
    case TronUnstakeAction():
      _expectAllowedFields(value, const {1, 2, 3});
      _expectVarint(value, 2, action.amountSun);
      _expectVarint(value, 3, BigInt.from(action.resource.apiCode));
    case TronWithdrawUnfreezeAction() ||
        TronCancelAllUnfreezeAction() ||
        TronClaimRewardAction():
      _expectAllowedFields(value, const {1});
    case TronDelegateAction():
      _expectAllowedFields(value, const {1, 2, 3, 4, 5, 6});
      _expectVarint(value, 2, BigInt.from(action.resource.apiCode));
      _expectVarint(value, 3, action.amountSun);
      _expectBytes(
        value.singleBytes(4),
        _tronAddressBytes(action.receiverAddress),
      );
      _expectVarint(
        value,
        5,
        action.lock ? BigInt.one : BigInt.zero,
        defaultValue: BigInt.zero,
      );
      if (action.lockPeriod == null) {
        if (value.hasField(6)) {
          throw const TronStakingTransactionValidationException('lockPeriod');
        }
      } else {
        _expectVarint(value, 6, BigInt.from(action.lockPeriod!));
      }
    case TronUndelegateAction():
      _expectAllowedFields(value, const {1, 2, 3, 4});
      _expectVarint(value, 2, BigInt.from(action.resource.apiCode));
      _expectVarint(value, 3, action.amountSun);
      _expectBytes(
        value.singleBytes(4),
        _tronAddressBytes(action.receiverAddress),
      );
    case TronVoteAction():
      _expectAllowedFields(value, const {1, 2, 3});
      final encodedVotes = value.bytesValues(2);
      if (encodedVotes.length != action.votes.length) {
        throw const TronStakingTransactionValidationException('voteCount');
      }
      for (var index = 0; index < encodedVotes.length; index += 1) {
        final encoded = _ProtoMessage.decode(encodedVotes[index]);
        _expectAllowedFields(encoded, const {1, 2});
        _expectBytes(
          encoded.singleBytes(1),
          _tronAddressBytes(action.votes[index].witnessAddress),
        );
        _expectVarint(encoded, 2, BigInt.from(action.votes[index].voteCount));
      }
      _expectVarint(value, 3, BigInt.zero, defaultValue: BigInt.zero);
  }
}

void _expectAllowedFields(_ProtoMessage value, Set<int> allowed) {
  if (value.keys.any((field) => !allowed.contains(field))) {
    throw const TronStakingTransactionValidationException('unexpectedField');
  }
}

void _expectVarint(
  _ProtoMessage value,
  int field,
  BigInt expected, {
  BigInt? defaultValue,
}) {
  if (value.varint(field, defaultValue: defaultValue) != expected) {
    throw const TronStakingTransactionValidationException('varintMismatch');
  }
}

void _expectBytes(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) {
    throw const TronStakingTransactionValidationException('bytesMismatch');
  }
  for (var index = 0; index < actual.length; index += 1) {
    if (actual[index] != expected[index]) {
      throw const TronStakingTransactionValidationException('bytesMismatch');
    }
  }
}

final class _ProtoMessage {
  _ProtoMessage(this._fields);

  final Map<int, List<Object>> _fields;

  Iterable<int> get keys => _fields.keys;

  bool hasField(int field) => _fields.containsKey(field);

  BigInt varint(int field, {BigInt? defaultValue}) {
    final values = _fields[field];
    if (values == null || values.isEmpty) {
      if (defaultValue != null) {
        return defaultValue;
      }
      throw const TronStakingTransactionValidationException('missingVarint');
    }
    final value = values.single;
    if (value is! BigInt) {
      throw const TronStakingTransactionValidationException('wrongWireType');
    }
    return value;
  }

  List<int> singleBytes(int field) {
    final values = bytesValues(field);
    if (values.length != 1) {
      throw const TronStakingTransactionValidationException('missingBytes');
    }
    return values.single;
  }

  List<List<int>> bytesValues(int field) {
    final values = _fields[field] ?? const <Object>[];
    if (values.any((value) => value is! List<int>)) {
      throw const TronStakingTransactionValidationException('wrongWireType');
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
        throw const TronStakingTransactionValidationException('invalidField');
      }
      Object value;
      switch (wireType) {
        case 0:
          final result = _readVarint(bytes, offset);
          value = result.$1;
          offset = result.$2;
        case 1:
          if (offset + 8 > bytes.length) {
            throw const TronStakingTransactionValidationException('truncated');
          }
          value = bytes.sublist(offset, offset + 8);
          offset += 8;
        case 2:
          final lengthResult = _readVarint(bytes, offset);
          final length = lengthResult.$1.toInt();
          offset = lengthResult.$2;
          if (length < 0 || offset + length > bytes.length) {
            throw const TronStakingTransactionValidationException('truncated');
          }
          value = bytes.sublist(offset, offset + length);
          offset += length;
        case 5:
          if (offset + 4 > bytes.length) {
            throw const TronStakingTransactionValidationException('truncated');
          }
          value = bytes.sublist(offset, offset + 4);
          offset += 4;
        default:
          throw const TronStakingTransactionValidationException('wireType');
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
  throw const TronStakingTransactionValidationException('invalidVarint');
}

List<int> _hexBytes(String value) {
  if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const TronStakingTransactionValidationException('invalidHex');
  }
  return web3.hexToBytes(value);
}

List<int> _tronAddressBytes(String address) {
  if (!isValidTronAddress(address)) {
    throw const TronStakingTransactionValidationException('invalidAddress');
  }
  var decoded = BigInt.zero;
  for (final codeUnit in address.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw const TronStakingTransactionValidationException('invalidAddress');
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
    throw const TronStakingTransactionValidationException('invalidAddress');
  }
  return decodedBytes.sublist(0, 21);
}

String _signatureHex(String txId, String privateKey) {
  final signature = web3.sign(
    web3.hexToBytes(txId),
    web3.hexToBytes(privateKey),
  );
  final recovery = signature.v >= 27 ? signature.v - 27 : signature.v;
  return [
    signature.r.toRadixString(16).padLeft(64, '0'),
    signature.s.toRadixString(16).padLeft(64, '0'),
    recovery.toRadixString(16).padLeft(2, '0'),
  ].join();
}

Map<String, Object?> _decodeJsonObject(
  http.Response response, {
  required String operation,
}) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Failed to $operation with HTTP ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, Object?>) {
    throw StateError('Failed to $operation: response is not an object');
  }
  return decoded;
}

String _stringField(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw TronStakingTransactionValidationException('missing$field');
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

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
