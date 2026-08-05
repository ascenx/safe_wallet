import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/shared/network/safe_remote_image_loader.dart';

void main() {
  test('rejects insecure, credentialed, and non-standard-port URLs', () {
    expect(safeRemoteImageUri('http://images.example/token.png'), isNull);
    expect(
      safeRemoteImageUri('https://user:pass@images.example/token.png'),
      isNull,
    );
    expect(safeRemoteImageUri('https://images.example:8443/token.png'), isNull);
  });

  test('rejects a hostname that resolves to a private address', () async {
    var requestCount = 0;
    final loader = SafeRemoteImageLoader(
      client: MockClient((request) async {
        requestCount += 1;
        return http.Response('not reached', 200);
      }),
      lookup: (_) async => [InternetAddress('127.0.0.1')],
    );

    final result = await loader.load('https://images.example/token.png');

    expect(result, isNull);
    expect(requestCount, 0);
  });

  test('does not follow redirects', () async {
    final loader = SafeRemoteImageLoader(
      client: MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://other.example/token.png'},
        );
      }),
      lookup: (_) async => [InternetAddress('93.184.216.34')],
    );

    expect(await loader.load('https://images.example/token.png'), isNull);
  });

  test('rejects unsupported content types and oversized responses', () async {
    final unsupported = SafeRemoteImageLoader(
      client: MockClient(
        (_) async => http.Response(
          '<html></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
      lookup: (_) async => [InternetAddress('93.184.216.34')],
    );
    final oversized = SafeRemoteImageLoader(
      client: MockClient(
        (_) async => http.Response.bytes(
          List<int>.filled(17, 1),
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
      lookup: (_) async => [InternetAddress('93.184.216.34')],
      maxImageBytes: 16,
    );

    expect(await unsupported.load('https://images.example/token.png'), isNull);
    expect(await oversized.load('https://images.example/token.png'), isNull);
  });

  test('loads a bounded public HTTPS image', () async {
    final loader = SafeRemoteImageLoader(
      client: MockClient(
        (_) async => http.Response.bytes(
          const [1, 2, 3, 4],
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
      lookup: (_) async => [InternetAddress('93.184.216.34')],
    );

    final result = await loader.load('https://images.example/token.png');

    expect(result?.bytes, const [1, 2, 3, 4]);
    expect(result?.mimeType, 'image/png');
  });
}
