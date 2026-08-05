import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/rpc_error.dart';
import '../network/bounded_http_client.dart';

abstract interface class TronClientFactory {
  Future<int> readBlockHeight(
    String apiBaseUrl, {
    Map<String, String> headers = const {},
  });
}

final class HttpTronClientFactory implements TronClientFactory {
  HttpTronClientFactory({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<int> readBlockHeight(
    String apiBaseUrl, {
    Map<String, String> headers = const {},
  }) async {
    final response = await _client.post(
      _endpoint(apiBaseUrl, '/wallet/getnowblock'),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({'visible': true}),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RpcError.invalidCredential();
    }
    if (response.statusCode == 429) {
      throw const RpcError.rateLimited();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Tron API returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const RpcError.unavailable(
        debugMessage: 'Tron block response is invalid',
      );
    }
    final header = decoded['block_header'];
    if (header is! Map<String, Object?>) {
      throw const RpcError.unavailable(
        debugMessage: 'Tron block header is missing',
      );
    }
    final rawData = header['raw_data'];
    if (rawData is! Map<String, Object?>) {
      throw const RpcError.unavailable(
        debugMessage: 'Tron block raw_data is missing',
      );
    }
    final number = rawData['number'];
    if (number is int && number >= 0) {
      return number;
    }
    if (number is num && number >= 0) {
      return number.toInt();
    }
    throw const RpcError.unavailable(
      debugMessage: 'Tron block number is invalid',
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
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
