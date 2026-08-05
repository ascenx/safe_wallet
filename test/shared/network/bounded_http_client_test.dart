import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:safe_wallet/shared/network/bounded_http_client.dart';

void main() {
  test('rejects a response body larger than the configured limit', () async {
    final inner = _FakeClient(
      response: http.StreamedResponse(
        Stream.value(List<int>.filled(5, 1)),
        200,
      ),
    );
    final client = BoundedHttpClient(inner: inner, maxResponseBytes: 4);

    await expectLater(
      client.get(Uri.parse('https://rpc.example')),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('times out while waiting for response headers', () async {
    final inner = _FakeClient(pending: Completer<http.StreamedResponse>());
    final client = BoundedHttpClient(
      inner: inner,
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      client.get(Uri.parse('https://rpc.example')),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('closing the bounded client cancels its inner client', () {
    final inner = _FakeClient(
      response: http.StreamedResponse(const Stream.empty(), 200),
    );
    final client = BoundedHttpClient(inner: inner);

    client.close();

    expect(inner.closed, isTrue);
  });
}

final class _FakeClient extends http.BaseClient {
  _FakeClient({this.response, this.pending});

  final http.StreamedResponse? response;
  final Completer<http.StreamedResponse>? pending;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final pending = this.pending;
    if (pending != null) {
      return pending.future;
    }
    return Future.value(response!);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}
