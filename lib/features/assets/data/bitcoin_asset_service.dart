import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/network/bounded_http_client.dart';

abstract interface class BitcoinAssetService {
  Future<BigInt> getBtcBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  });
}

final class HttpBitcoinAssetService implements BitcoinAssetService {
  HttpBitcoinAssetService({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<BigInt> getBtcBalance({
    required String apiBaseUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final response = await _client.get(
      _endpoint(apiBaseUrl, '/address/$walletAddress'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Bitcoin balance query failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Bitcoin balance response was not an object');
    }
    return _balanceFromAddressPayload(decoded);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

Uri _endpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}

BigInt _balanceFromAddressPayload(Map<String, dynamic> payload) {
  final chainStats = _stats(payload['chain_stats']);
  final mempoolStats = _stats(payload['mempool_stats']);
  final funded = chainStats.funded + mempoolStats.funded;
  final spent = chainStats.spent + mempoolStats.spent;
  return funded - spent;
}

({BigInt funded, BigInt spent}) _stats(Object? value) {
  if (value is! Map<String, dynamic>) {
    return (funded: BigInt.zero, spent: BigInt.zero);
  }
  return (
    funded: _bigIntFromJson(value['funded_txo_sum']),
    spent: _bigIntFromJson(value['spent_txo_sum']),
  );
}

BigInt _bigIntFromJson(Object? value) {
  if (value is int) {
    return BigInt.from(value);
  }
  if (value is String) {
    return BigInt.tryParse(value) ?? BigInt.zero;
  }
  return BigInt.zero;
}
