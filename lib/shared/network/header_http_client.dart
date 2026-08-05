import 'package:http/http.dart' as http;

import 'bounded_http_client.dart';

final class HeaderHttpClient extends http.BaseClient {
  HeaderHttpClient({required Map<String, String> headers, http.Client? inner})
    : _headers = Map.unmodifiable(headers),
      _inner = inner ?? BoundedHttpClient();

  final Map<String, String> _headers;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
