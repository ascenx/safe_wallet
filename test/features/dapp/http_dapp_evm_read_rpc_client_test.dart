import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';

void main() {
  group('HttpDappEvmReadRpcClient', () {
    test('returns upstream JSON-RPC errors without throwing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      unawaited(
        server.first.then((request) async {
          expect(request.method, 'POST');
          final body = await utf8.decoder.bind(request).join();
          final json = jsonDecode(body) as Map<String, Object?>;
          expect(json['method'], 'eth_call');

          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'error': {
                  'code': -32000,
                  'message': 'err: insufficient funds for gas * price + value',
                },
              }),
            );
          await request.response.close();
        }),
      );

      final client = HttpDappEvmReadRpcClient();
      addTearDown(client.close);
      final response = await client.request(
        chain: defaultChains.firstWhere((chain) => chain.id == 'ethereum'),
        rpcUrl: 'http://${server.address.host}:${server.port}',
        method: 'eth_call',
        params: const [],
      );

      expect(response.error?.code, -32000);
      expect(
        response.error?.message,
        'err: insufficient funds for gas * price + value',
      );
    });
  });
}
