import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/shared/chain_clients/evm_client_factory.dart';
import 'package:safe_wallet/shared/chain_clients/solana_client_factory.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  test('EVM client distinguishes invalid credentials from rate limiting',
      () async {
    final unauthorized = HttpEvmClientFactory(
      client: MockClient((_) async => http.Response('', 401)),
    );
    final rateLimited = HttpEvmClientFactory(
      client: MockClient((_) async => http.Response('', 429)),
    );

    await expectLater(
      unauthorized.readChainId('https://rpc.example.com'),
      throwsA(
        isA<RpcError>()
            .having((error) => error.code, 'code', 'rpc_invalid_credential'),
      ),
    );
    await expectLater(
      rateLimited.readChainId('https://rpc.example.com'),
      throwsA(
        isA<RpcError>()
            .having((error) => error.code, 'code', 'rpc_rate_limited'),
      ),
    );
  });

  test('Solana client returns genesis hash for network verification', () async {
    final client = HttpSolanaClientFactory(
      client: MockClient(
        (_) async => http.Response(
          '{"jsonrpc":"2.0","id":1,"result":"genesis-hash"}',
          200,
        ),
      ),
    );

    expect(
      await client.readGenesisHash('https://rpc.example.com'),
      'genesis-hash',
    );
  });
  test('Solana client does not report HTTP 403 as an invalid credential',
      () async {
    final client = HttpSolanaClientFactory(
      client: MockClient((_) async => http.Response('Forbidden', 403)),
    );

    await expectLater(
      client.checkHealth('https://rpc.example.com'),
      throwsA(
        isA<RpcError>().having(
          (error) => error.code,
          'code',
          'rpc_access_denied',
        ),
      ),
    );
  });

}
