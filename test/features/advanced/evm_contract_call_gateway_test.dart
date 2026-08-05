import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/advanced/data/evm_contract_call_gateway.dart';

void main() {
  test('checks deployed bytecode before allowing contract interaction',
      () async {
    final gateway = HttpEvmContractCallGateway(
      clientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], 'eth_getCode');
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x6000'}),
          200,
        );
      }),
    );

    expect(
      await gateway.hasContractCode(
        rpcUrl: 'https://rpc.example.com',
        contractAddress: '0x1111111111111111111111111111111111111111',
      ),
      isTrue,
    );
  });

  test('performs a raw eth_call and returns the encoded result', () async {
    final gateway = HttpEvmContractCallGateway(
      clientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], 'eth_call');
        final params = body['params'] as List<dynamic>;
        final call = params.first as Map<String, dynamic>;
        expect(call['data'], '0x70a08231');
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x2a'}),
          200,
        );
      }),
    );

    final result = await gateway.read(
      rpcUrl: 'https://rpc.example.com',
      fromAddress: '0x2222222222222222222222222222222222222222',
      contractAddress: '0x1111111111111111111111111111111111111111',
      calldata: '0x70a08231',
    );

    expect(result, '0x2a');
  });

  test('simulates and estimates a contract write', () async {
    final methods = <String>[];
    final gateway = HttpEvmContractCallGateway(
      clientFactory: () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final method = body['method'] as String;
        methods.add(method);
        final result = switch (method) {
          'eth_call' => '0x',
          'eth_estimateGas' => '0x7530',
          'eth_gasPrice' => '0x3b9aca00',
          'eth_getTransactionCount' => '0x7',
          _ => throw StateError('Unexpected method: $method'),
        };
        return http.Response(
          jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
          200,
        );
      }),
    );

    final preparation = await gateway.prepareWrite(
      rpcUrl: 'https://rpc.example.com',
      chainId: 1,
      fromAddress: '0x2222222222222222222222222222222222222222',
      contractAddress: '0x1111111111111111111111111111111111111111',
      calldata: '0xa9059cbb',
      valueWei: BigInt.zero,
    );

    expect(preparation.gasLimit, 30000);
    expect(preparation.gasPriceWei, BigInt.from(1000000000));
    expect(preparation.estimatedFeeWei, BigInt.from(30000000000000));
    expect(preparation.nonce, 7);
    expect(methods, [
      'eth_call',
      'eth_estimateGas',
      'eth_gasPrice',
      'eth_getTransactionCount',
    ]);
  });
}
