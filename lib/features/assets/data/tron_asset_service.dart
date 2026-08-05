import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' show isValidTronAddress;

import '../../../shared/errors/rpc_error.dart';
import '../../../shared/network/bounded_http_client.dart';

abstract interface class TronAssetService {
  Future<BigInt> getTrxBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  });

  Future<Map<String, BigInt>> getTrc20Balances({
    required String apiBaseUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  });
}

final class HttpTronAssetService implements TronAssetService {
  HttpTronAssetService({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<BigInt> getTrxBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final response = await _client.post(
      _endpoint(apiBaseUrl, '/wallet/getaccount'),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({'address': walletAddress, 'visible': true}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Tron API returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const RpcError.unavailable(
        debugMessage: 'Tron account response is invalid',
      );
    }
    final balance = decoded['balance'];
    if (balance == null) {
      return BigInt.zero;
    }
    if (balance is int) {
      return BigInt.from(balance);
    }
    if (balance is num) {
      return BigInt.from(balance);
    }
    if (balance is String) {
      final parsed = BigInt.tryParse(balance);
      if (parsed != null) {
        return parsed;
      }
    }
    throw const RpcError.unavailable(
      debugMessage: 'Tron account balance is invalid',
    );
  }

  @override
  Future<Map<String, BigInt>> getTrc20Balances({
    required String apiBaseUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final parameter = _tronAddressAbiParameter(walletAddress);
    final balances = <String, BigInt>{};
    for (final contractAddress in contractAddresses) {
      final response = await _client.post(
        _endpoint(apiBaseUrl, '/wallet/triggersmartcontract'),
        headers: {'content-type': 'application/json', ...headers},
        body: jsonEncode({
          'owner_address': walletAddress,
          'contract_address': contractAddress,
          'function_selector': 'balanceOf(address)',
          'parameter': parameter,
          'visible': true,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RpcError.unavailable(
          debugMessage: 'Tron API returned HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        throw const RpcError.unavailable(
          debugMessage: 'Tron smart contract response is invalid',
        );
      }
      final result = decoded['result'];
      if (result is Map<String, Object?> && result['result'] == false) {
        throw const RpcError.unavailable(
          debugMessage: 'Tron smart contract call failed',
        );
      }
      balances[contractAddress] = _trc20BalanceFromResult(decoded);
    }
    return balances;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

BigInt _trc20BalanceFromResult(Map<String, Object?> decoded) {
  final constantResult = decoded['constant_result'];
  if (constantResult is! List<Object?> || constantResult.isEmpty) {
    return BigInt.zero;
  }
  final value = constantResult.first;
  if (value is! String || value.isEmpty) {
    return BigInt.zero;
  }
  return BigInt.parse(value, radix: 16);
}

String _tronAddressAbiParameter(String address) {
  if (!isValidTronAddress(address)) {
    throw const RpcError.unavailable(debugMessage: 'Tron address is invalid');
  }
  final decoded = _decodeBase58(address);
  if (decoded.length != 25 || decoded.first != 0x41) {
    throw const RpcError.unavailable(
      debugMessage: 'Tron address payload is invalid',
    );
  }
  final payload = decoded.sublist(1, 21);
  return '${'0' * 24}${_bytesToHex(payload)}';
}

List<int> _decodeBase58(String value) {
  var decoded = BigInt.zero;
  for (final codeUnit in value.codeUnits) {
    final index = _base58Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw const RpcError.unavailable(
        debugMessage: 'Tron address has invalid Base58 characters',
      );
    }
    decoded = decoded * BigInt.from(58) + BigInt.from(index);
  }
  final leadingZeroes = value.codeUnits
      .takeWhile((unit) => unit == 0x31)
      .length;
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

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.tryParse(apiBaseUrl);
  if (base == null ||
      !base.hasAuthority ||
      (base.scheme != 'https' && base.scheme != 'http')) {
    throw const RpcError.invalidUrl();
  }
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}

const _base58Alphabet =
    '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
