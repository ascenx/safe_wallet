import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/utils/tron_abi.dart';
import '../domain/transaction_request.dart';

final class TronFeeEstimate {
  const TronFeeEstimate({
    required this.sun,
    this.recommendedFeeLimitSun,
    this.bandwidth,
    this.availableBandwidth,
    this.energy,
    this.availableEnergy,
  });

  final BigInt sun;
  final BigInt? recommendedFeeLimitSun;
  final int? bandwidth;
  final int? availableBandwidth;
  final int? energy;
  final int? availableEnergy;
}

abstract interface class TronFeeService {
  Future<TronFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt sun,
    required TransactionType transactionType,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  });
}

final class HttpTronFeeService implements TronFeeService {
  HttpTronFeeService({http.Client? client})
    : _client = client ?? BoundedHttpClient();

  final http.Client _client;

  @override
  Future<TronFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt sun,
    required TransactionType transactionType,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  }) async {
    final transaction = await _createTransaction(
      apiBaseUrl: apiBaseUrl,
      fromAddress: fromAddress,
      toAddress: toAddress,
      sun: sun,
      transactionType: transactionType,
      tokenContractAddress: tokenContractAddress,
      headers: headers,
    );
    final rawDataHex = _stringField(transaction, 'raw_data_hex');
    final bandwidth = _estimateBandwidth(rawDataHex);

    final accountResource = await _postJson(
      apiBaseUrl,
      '/wallet/getaccountresource',
      {'address': fromAddress, 'visible': true},
      operation: 'read Tron account resources',
      headers: headers,
    );
    final availableBandwidth = _availableBandwidth(accountResource);

    final chainParameters = await _postJson(
      apiBaseUrl,
      '/wallet/getchainparameters',
      const <String, Object?>{},
      operation: 'read Tron chain parameters',
      headers: headers,
    );
    final unitPrice = _bandwidthUnitPrice(chainParameters);
    final paidBandwidth = math.max(0, bandwidth - availableBandwidth);
    final energy = transactionType == TransactionType.trc20Transfer
        ? await _estimateTrc20Energy(
            apiBaseUrl: apiBaseUrl,
            fromAddress: fromAddress,
            toAddress: toAddress,
            amount: sun,
            tokenContractAddress: tokenContractAddress,
            headers: headers,
          )
        : null;
    final availableEnergy = energy == null
        ? null
        : _availableEnergy(accountResource);
    final energyUnitPrice = energy == null
        ? null
        : _energyUnitPrice(chainParameters);
    final paidEnergy = energy == null || availableEnergy == null
        ? 0
        : math.max(0, energy - availableEnergy);

    final estimatedSun =
        BigInt.from(paidBandwidth) * BigInt.from(unitPrice) +
        BigInt.from(paidEnergy) * BigInt.from(energyUnitPrice ?? 0);
    final recommendedFeeLimit = transactionType == TransactionType.trc20Transfer
        ? _recommendedTrc20FeeLimit(estimatedSun)
        : null;
    return TronFeeEstimate(
      sun: estimatedSun,
      recommendedFeeLimitSun: recommendedFeeLimit,
      bandwidth: bandwidth,
      availableBandwidth: availableBandwidth,
      energy: energy,
      availableEnergy: availableEnergy,
    );
  }

  Future<Map<String, Object?>> _createTransaction({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt sun,
    required TransactionType transactionType,
    String? tokenContractAddress,
    required Map<String, String> headers,
  }) async {
    return switch (transactionType) {
      TransactionType.nativeTransfer => _createNativeTransaction(
        apiBaseUrl: apiBaseUrl,
        fromAddress: fromAddress,
        toAddress: toAddress,
        sun: sun,
        headers: headers,
      ),
      TransactionType.trc20Transfer => _createTrc20Transaction(
        apiBaseUrl: apiBaseUrl,
        fromAddress: fromAddress,
        toAddress: toAddress,
        amount: sun,
        tokenContractAddress: tokenContractAddress,
        headers: headers,
      ),
      _ => throw StateError('Unsupported Tron transaction type'),
    };
  }

  Future<Map<String, Object?>> _createNativeTransaction({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt sun,
    required Map<String, String> headers,
  }) async {
    final transaction = await _postJson(
      apiBaseUrl,
      '/wallet/createtransaction',
      {
        'owner_address': fromAddress,
        'to_address': toAddress,
        'amount': sun.toInt(),
        'visible': true,
      },
      operation: 'create Tron transaction for fee estimate',
      headers: headers,
    );
    final error = transaction['Error'] ?? transaction['error'];
    if (error != null) {
      throw StateError('Failed to create Tron transaction: $error');
    }
    return transaction;
  }

  Future<Map<String, Object?>> _createTrc20Transaction({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
    required String? tokenContractAddress,
    required Map<String, String> headers,
  }) async {
    final contractAddress = tokenContractAddress;
    if (contractAddress == null || contractAddress.isEmpty) {
      throw StateError('TRC20 transfer is missing token contract address');
    }
    final response = await _postJson(
      apiBaseUrl,
      '/wallet/triggersmartcontract',
      {
        'owner_address': fromAddress,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': trc20TransferAbiParameter(
          toAddress: toAddress,
          amount: amount,
        ),
        'fee_limit': 100000000,
        'visible': true,
      },
      operation: 'create TRC20 transaction for fee estimate',
      headers: headers,
    );
    final result = response['result'];
    if (result is Map<String, Object?> && result['result'] == false) {
      throw StateError('Failed to create TRC20 transaction');
    }
    final transaction = response['transaction'];
    if (transaction is Map<String, Object?>) {
      return transaction;
    }
    throw StateError('TRC20 transaction response is missing transaction');
  }

  Future<int> _estimateTrc20Energy({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
    required String? tokenContractAddress,
    required Map<String, String> headers,
  }) async {
    final contractAddress = tokenContractAddress;
    if (contractAddress == null || contractAddress.isEmpty) {
      throw StateError('TRC20 transfer is missing token contract address');
    }
    final response = await _postJson(
      apiBaseUrl,
      '/wallet/triggerconstantcontract',
      {
        'owner_address': fromAddress,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': trc20TransferAbiParameter(
          toAddress: toAddress,
          amount: amount,
        ),
        'visible': true,
      },
      operation: 'estimate TRC20 energy',
      headers: headers,
    );
    return _intField(response, 'energy_used');
  }

  Future<Map<String, Object?>> _postJson(
    String apiBaseUrl,
    String path,
    Map<String, Object?> body, {
    required String operation,
    required Map<String, String> headers,
  }) async {
    final response = await _client.post(
      _endpoint(apiBaseUrl, path),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    );
    return _decodeJsonObject(response, operation: operation);
  }

  void close() => _client.close();
}

BigInt _recommendedTrc20FeeLimit(BigInt estimatedSun) {
  final buffered =
      (estimatedSun * BigInt.from(12) + BigInt.from(9)) ~/ BigInt.from(10);
  final minimum = BigInt.from(1000000);
  return buffered < minimum ? minimum : buffered;
}

int _estimateBandwidth(String rawDataHex) {
  if (rawDataHex.length.isOdd) {
    throw StateError('Tron raw_data_hex length is invalid');
  }
  const maxResultSize = 64;
  const signatureSize = 67;
  const protobufExtraSize = 3;
  return (rawDataHex.length ~/ 2) +
      maxResultSize +
      signatureSize +
      protobufExtraSize;
}

int _availableBandwidth(Map<String, Object?> accountResource) {
  final stakedBandwidth = math.max(
    0,
    _intField(accountResource, 'NetLimit') -
        _intField(accountResource, 'NetUsed'),
  );
  final freeBandwidth = math.max(
    0,
    _intField(accountResource, 'freeNetLimit') -
        _intField(accountResource, 'freeNetUsed'),
  );
  return stakedBandwidth + freeBandwidth;
}

int _availableEnergy(Map<String, Object?> accountResource) {
  return math.max(
    0,
    _intField(accountResource, 'EnergyLimit') -
        _intField(accountResource, 'EnergyUsed'),
  );
}

int _bandwidthUnitPrice(Map<String, Object?> chainParameters) {
  return _chainParameterValue(
    chainParameters,
    key: 'getTransactionFee',
    fallback: 1000,
  );
}

int _energyUnitPrice(Map<String, Object?> chainParameters) {
  return _chainParameterValue(
    chainParameters,
    key: 'getEnergyFee',
    fallback: 420,
  );
}

int _chainParameterValue(
  Map<String, Object?> chainParameters, {
  required String key,
  required int fallback,
}) {
  final parameters = chainParameters['chainParameter'];
  if (parameters is Iterable<Object?>) {
    for (final parameter in parameters) {
      if (parameter is Map<String, Object?> && parameter['key'] == key) {
        final value = parameter['value'];
        if (value is int) {
          return value;
        }
        if (value is num) {
          return value.toInt();
        }
      }
    }
  }
  return fallback;
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

int _intField(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}
