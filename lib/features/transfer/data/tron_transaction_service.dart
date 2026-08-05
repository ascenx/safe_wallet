import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/utils/tron_abi.dart';
import '../domain/transaction_request.dart';
import 'tron_transaction_validator.dart';

final class TronTransactionBroadcastInput {
  const TronTransactionBroadcastInput({
    required this.apiBaseUrl,
    required this.privateKey,
    required this.fromAddress,
    required this.transaction,
    this.headers = const {},
    this.feeLimitSun,
  });

  final String apiBaseUrl;
  final String privateKey;
  final String fromAddress;
  final TransactionRequest transaction;
  final Map<String, String> headers;
  final BigInt? feeLimitSun;
}

abstract interface class TronTransactionService {
  Future<String> signAndBroadcast(TronTransactionBroadcastInput input);
}

final class HttpTronTransactionService implements TronTransactionService {
  HttpTronTransactionService({http.Client? client})
    : _client = client ?? BoundedHttpClient();

  final http.Client _client;

  @override
  Future<String> signAndBroadcast(TronTransactionBroadcastInput input) async {
    final transaction = await _createTransaction(
      apiBaseUrl: input.apiBaseUrl,
      fromAddress: input.fromAddress,
      transaction: input.transaction,
      headers: input.headers,
      feeLimitSun: input.feeLimitSun,
    );
    final txId = _stringField(transaction, 'txID');
    await validateTronTransferTransaction(
      transaction: transaction,
      fromAddress: input.fromAddress,
      request: input.transaction,
      feeLimitSun: input.feeLimitSun,
    );

    final signedTransaction = Map<String, Object?>.from(transaction)
      ..['signature'] = [_signatureHex(txId, input.privateKey)];

    final broadcastResponse = await _client.post(
      _endpoint(input.apiBaseUrl, '/wallet/broadcasttransaction'),
      headers: {'content-type': 'application/json', ...input.headers},
      body: jsonEncode(signedTransaction),
    );
    final broadcast = _decodeJsonObject(
      broadcastResponse,
      operation: 'broadcast Tron transaction',
    );
    if (broadcast['result'] != true) {
      final code = broadcast['code'] ?? broadcast['message'] ?? 'unknown';
      throw StateError('Failed to broadcast Tron transaction: $code');
    }

    return (broadcast['txid'] as String?) ??
        (broadcast['txID'] as String?) ??
        txId;
  }

  Future<Map<String, Object?>> _createTransaction({
    required String apiBaseUrl,
    required String fromAddress,
    required TransactionRequest transaction,
    required Map<String, String> headers,
    required BigInt? feeLimitSun,
  }) {
    return switch (transaction.transactionType) {
      TransactionType.nativeTransfer => _createNativeTransaction(
        apiBaseUrl: apiBaseUrl,
        fromAddress: fromAddress,
        transaction: transaction,
        headers: headers,
      ),
      TransactionType.trc20Transfer => _createTrc20Transaction(
        apiBaseUrl: apiBaseUrl,
        fromAddress: fromAddress,
        transaction: transaction,
        headers: headers,
        feeLimitSun: feeLimitSun,
      ),
      _ => throw StateError('Unsupported Tron transaction type'),
    };
  }

  Future<Map<String, Object?>> _createNativeTransaction({
    required String apiBaseUrl,
    required String fromAddress,
    required TransactionRequest transaction,
    required Map<String, String> headers,
  }) async {
    final createResponse = await _client.post(
      _endpoint(apiBaseUrl, '/wallet/createtransaction'),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'owner_address': fromAddress,
        'to_address': transaction.toAddress,
        'amount': _amountInBaseUnits(transaction).toInt(),
        'visible': true,
      }),
    );
    final created = _decodeJsonObject(
      createResponse,
      operation: 'create Tron transaction',
    );
    final error = created['Error'] ?? created['error'];
    if (error != null) {
      throw StateError('Failed to create Tron transaction: $error');
    }
    return created;
  }

  Future<Map<String, Object?>> _createTrc20Transaction({
    required String apiBaseUrl,
    required String fromAddress,
    required TransactionRequest transaction,
    required Map<String, String> headers,
    required BigInt? feeLimitSun,
  }) async {
    final contractAddress = transaction.tokenContractAddress;
    if (contractAddress == null || contractAddress.isEmpty) {
      throw StateError('TRC20 transfer is missing token contract address');
    }
    final triggerResponse = await _client.post(
      _endpoint(apiBaseUrl, '/wallet/triggersmartcontract'),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'owner_address': fromAddress,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': trc20TransferAbiParameter(
          toAddress: transaction.toAddress,
          amount: _amountInBaseUnits(transaction),
        ),
        'fee_limit': (feeLimitSun ?? BigInt.from(100000000)).toInt(),
        'visible': true,
      }),
    );
    final triggered = _decodeJsonObject(
      triggerResponse,
      operation: 'create TRC20 transaction',
    );
    final result = triggered['result'];
    if (result is Map<String, Object?> && result['result'] == false) {
      throw StateError('Failed to create TRC20 transaction');
    }
    final created = triggered['transaction'];
    if (created is Map<String, Object?>) {
      return created;
    }
    throw StateError('TRC20 transaction response is missing transaction');
  }

  void close() => _client.close();
}

BigInt _amountInBaseUnits(TransactionRequest request) {
  final amount = request.amountInBaseUnits;
  if (amount == null) {
    throw ArgumentError.value(amount, 'amountInBaseUnits', 'must not be null');
  }
  final parsed = BigInt.parse(amount);
  if (parsed < BigInt.zero) {
    throw ArgumentError.value(amount, 'amountInBaseUnits', 'must be positive');
  }
  return parsed;
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
  throw StateError('Tron transaction response is missing $field');
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}
