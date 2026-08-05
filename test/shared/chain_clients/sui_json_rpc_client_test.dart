import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/shared/chain_clients/sui_json_rpc_client.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  group('HttpSuiJsonRpcClient', () {
    test('posts JSON-RPC method, params, and custom headers', () async {
      late http.Request captured;
      final client = HttpSuiJsonRpcClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '12345'}),
            200,
          );
        }),
      );

      final result = await client.call(
        rpcUrl: 'https://fullnode.test',
        method: 'sui_getLatestCheckpointSequenceNumber',
        params: const [],
        headers: const {'x-api-key': 'secret'},
      );

      expect(result, '12345');
      expect(captured.headers['content-type'], 'application/json');
      expect(captured.headers['x-api-key'], 'secret');
      expect(jsonDecode(captured.body), {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'sui_getLatestCheckpointSequenceNumber',
        'params': const [],
      });
    });

    test('maps authentication and rate limit responses', () async {
      for (final entry in const [
        (401, 'rpc_invalid_credential'),
        (429, 'rpc_rate_limited'),
      ]) {
        final client = HttpSuiJsonRpcClient(
          client: MockClient((_) async => http.Response('', entry.$1)),
        );

        await expectLater(
          client.call(
            rpcUrl: 'https://fullnode.test',
            method: 'sui_getChainIdentifier',
          ),
          throwsA(
            isA<RpcError>().having((error) => error.code, 'code', entry.$2),
          ),
        );
      }
    });

    test('rejects malformed and JSON-RPC error responses', () async {
      final malformed = HttpSuiJsonRpcClient(
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      final rpcError = HttpSuiJsonRpcClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'error': {'code': -32602, 'message': 'Invalid params'},
            }),
            200,
          ),
        ),
      );

      await expectLater(
        malformed.call(rpcUrl: 'https://fullnode.test', method: 'test'),
        throwsA(isA<RpcError>()),
      );
      await expectLater(
        rpcError.call(rpcUrl: 'https://fullnode.test', method: 'test'),
        throwsA(isA<RpcError>()),
      );
    });
  });
}
