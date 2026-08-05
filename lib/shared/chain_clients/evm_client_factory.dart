import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/rpc_error.dart';
import '../network/bounded_http_client.dart';

abstract interface class EvmClientFactory {
  Future<String> readChainId(
    String rpcUrl, {
    Map<String, String> headers = const {},
  });

  Future<int> readBlockNumber(
    String rpcUrl, {
    Map<String, String> headers = const {},
  });
}

final class HttpEvmClientFactory implements EvmClientFactory {
  HttpEvmClientFactory({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<String> readChainId(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    final result = await _postRpc(
      rpcUrl: rpcUrl,
      method: 'eth_chainId',
      headers: headers,
    );
    if (result is! String || !result.startsWith('0x')) {
      throw const RpcError.unavailable(
        debugMessage: 'EVM RPC eth_chainId result is invalid',
      );
    }

    return BigInt.parse(result.substring(2), radix: 16).toString();
  }

  @override
  Future<int> readBlockNumber(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    final result = await _postRpc(
      rpcUrl: rpcUrl,
      method: 'eth_blockNumber',
      headers: headers,
    );
    if (result is! String || !result.startsWith('0x')) {
      throw const RpcError.unavailable(
        debugMessage: 'EVM RPC eth_blockNumber result is invalid',
      );
    }

    return BigInt.parse(result.substring(2), radix: 16).toInt();
  }

  Future<Object?> _postRpc({
    required String rpcUrl,
    required String method,
    required Map<String, String> headers,
  }) async {
    final uri = _parseRpcUri(rpcUrl);
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': const [],
      }),
    );
    _throwForAuthenticationStatus(response.statusCode);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'EVM RPC returned HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?> || decoded['error'] != null) {
      throw const RpcError.unavailable();
    }

    return decoded['result'];
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

void _throwForAuthenticationStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 403) {
    throw const RpcError.invalidCredential();
  }
  if (statusCode == 429) {
    throw const RpcError.rateLimited();
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
