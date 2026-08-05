import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/rpc_error.dart';
import '../network/bounded_http_client.dart';

abstract interface class SuiJsonRpcClient {
  Future<Object?> call({
    required String rpcUrl,
    required String method,
    List<Object?> params = const [],
    Map<String, String> headers = const {},
  });
}

final class HttpSuiJsonRpcClient implements SuiJsonRpcClient {
  HttpSuiJsonRpcClient({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<Object?> call({
    required String rpcUrl,
    required String method,
    List<Object?> params = const [],
    Map<String, String> headers = const {},
  }) async {
    final uri = _parseRpcUri(rpcUrl);
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const RpcError.invalidCredential();
    }
    if (response.statusCode == 429) {
      throw const RpcError.rateLimited();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Sui RPC returned HTTP ${response.statusCode}',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const RpcError.unavailable(
        debugMessage: 'Sui RPC returned malformed JSON',
      );
    }
    if (decoded is! Map) {
      throw const RpcError.unavailable(
        debugMessage: 'Sui RPC response is invalid',
      );
    }
    final error = decoded['error'];
    if (error != null) {
      final code = error is Map ? error['code'] : null;
      throw RpcError.unavailable(
        debugMessage: 'Sui RPC returned error code ${code ?? 'unknown'}',
      );
    }
    if (!decoded.containsKey('result')) {
      throw const RpcError.unavailable(
        debugMessage: 'Sui RPC result is missing',
      );
    }
    return decoded['result'];
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

Uri _parseRpcUri(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw const RpcError.invalidUrl();
  }
  return uri;
}
