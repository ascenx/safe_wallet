import 'dart:async';

import 'package:http/http.dart' as http;

const defaultNetworkRequestTimeout = Duration(seconds: 20);
const defaultMaximumResponseBytes = 4 * 1024 * 1024;

final class BoundedHttpClient extends http.BaseClient {
  BoundedHttpClient({
    http.Client? inner,
    this.requestTimeout = defaultNetworkRequestTimeout,
    this.maxResponseBytes = defaultMaximumResponseBytes,
  }) : assert(!requestTimeout.isNegative && requestTimeout != Duration.zero),
       assert(maxResponseBytes > 0),
       _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration requestTimeout;
  final int maxResponseBytes;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request).timeout(requestTimeout);
    final declaredLength = response.contentLength;
    if (declaredLength != null && declaredLength > maxResponseBytes) {
      await response.stream.listen(null).cancel();
      throw http.ClientException(
        'Response exceeds $maxResponseBytes bytes',
        request.url,
      );
    }
    return http.StreamedResponse(
      _boundedStream(response.stream, request.url),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Stream<List<int>> _boundedStream(Stream<List<int>> source, Uri requestUri) {
    return _countBytes(source.timeout(requestTimeout), requestUri);
  }

  Stream<List<int>> _countBytes(
    Stream<List<int>> source,
    Uri requestUri,
  ) async* {
    var receivedBytes = 0;
    await for (final chunk in source) {
      receivedBytes += chunk.length;
      if (receivedBytes > maxResponseBytes) {
        throw http.ClientException(
          'Response exceeds $maxResponseBytes bytes',
          requestUri,
        );
      }
      yield chunk;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
