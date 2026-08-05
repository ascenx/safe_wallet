import 'package:http/http.dart' as http;

import '../errors/rpc_error.dart';
import '../network/bounded_http_client.dart';

abstract interface class BitcoinClientFactory {
  Future<int> readBlockHeight(String apiBaseUrl);
}

final class HttpBitcoinClientFactory implements BitcoinClientFactory {
  HttpBitcoinClientFactory({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<int> readBlockHeight(String apiBaseUrl) async {
    final response = await _client.get(
      _endpoint(apiBaseUrl, '/blocks/tip/height'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcError.unavailable(
        debugMessage: 'Bitcoin API returned HTTP ${response.statusCode}',
      );
    }
    final height = int.tryParse(response.body.trim());
    if (height == null || height < 0) {
      throw const RpcError.unavailable(
        debugMessage: 'Bitcoin API tip height result is invalid',
      );
    }
    return height;
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
