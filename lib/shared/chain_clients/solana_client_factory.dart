import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/rpc_error.dart';
import '../network/bounded_http_client.dart';

const solanaMainnetGenesisHashPrefix =
    '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp';
const solanaDevnetGenesisHashPrefix = 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1';

// Solana CAIP-2 references use the first 32 characters of the full genesis
// hash returned by getGenesisHash.
String? expectedSolanaGenesisHashPrefix(String chainId) {
  return switch (chainId) {
    'mainnet-beta' => solanaMainnetGenesisHashPrefix,
    'devnet' => solanaDevnetGenesisHashPrefix,
    _ => null,
  };
}

bool matchesExpectedSolanaGenesisHash(String chainId, String actualHash) {
  final expectedPrefix = expectedSolanaGenesisHashPrefix(chainId);
  return expectedPrefix == null || actualHash.startsWith(expectedPrefix);
}

abstract interface class SolanaClientFactory {
  Future<void> checkHealth(
    String rpcUrl, {
    Map<String, String> headers = const {},
  });

  Future<String> readGenesisHash(
    String rpcUrl, {
    Map<String, String> headers = const {},
  });
}

final class HttpSolanaClientFactory implements SolanaClientFactory {
  HttpSolanaClientFactory({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<void> checkHealth(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    final result = await _postRpc(rpcUrl, 'getHealth', headers: headers);
    if (result != 'ok') {
      throw const RpcError.unavailable(
        debugMessage: 'Solana RPC health result is invalid',
      );
    }
  }

  @override
  Future<String> readGenesisHash(
    String rpcUrl, {
    Map<String, String> headers = const {},
  }) async {
    final result = await _postRpc(rpcUrl, 'getGenesisHash', headers: headers);
    if (result is! String || result.isEmpty) {
      throw const RpcError.unavailable(
        debugMessage: 'Solana RPC genesis hash result is invalid',
      );
    }
    return result;
  }

  Future<Object?> _postRpc(
    String rpcUrl,
    String method, {
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
    if (response.statusCode == 401) {
      throw const RpcError.invalidCredential();
    }
    if (response.statusCode == 403) {
      throw const RpcError.accessDenied();
    }
    if (response.statusCode == 429) {
      throw const RpcError.rateLimited();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Solana RPC returned HTTP ${response.statusCode}',
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

Uri _parseRpcUri(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'https' && uri.scheme != 'http')) {
    throw const RpcError.invalidUrl();
  }
  return uri;
}
