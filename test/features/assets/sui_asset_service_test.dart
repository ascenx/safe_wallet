import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:grpc/grpc.dart';
import 'package:safe_wallet/features/assets/data/sui_asset_service.dart';
import 'package:safe_wallet/shared/chain_clients/sui_json_rpc_client.dart';
import 'package:safe_wallet/shared/network/grpc_client_channel.dart';
import 'package:sui_dart/grpc/sui_grpc_client.dart' as sdk;

void main() {
  test('parses Sui native, all-Coin balances, and metadata fixtures', () async {
    final methods = <String>[];
    final service = HttpSuiAssetService(
      rpcClient: HttpSuiJsonRpcClient(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final method = body['method'] as String;
          methods.add(method);
          final result = switch (method) {
            'suix_getBalance' => {
              'coinType': suiNativeCoinType,
              'coinObjectCount': 2,
              'totalBalance': '1500000000',
              'lockedBalance': const {},
            },
            'suix_getAllBalances' => [
              {
                'coinType': suiNativeCoinType,
                'coinObjectCount': 2,
                'totalBalance': '1500000000',
                'lockedBalance': const {},
              },
              {
                'coinType': '0xabc::usdc::USDC',
                'coinObjectCount': 1,
                'totalBalance': '1234500',
                'lockedBalance': const {},
              },
            ],
            'suix_getCoinMetadata' => {
              'decimals': 6,
              'name': 'USD Coin',
              'symbol': 'USDC',
              'description': 'Test coin',
              'iconUrl': 'https://example.com/usdc.png',
              'id': '0xmetadata',
            },
            _ => throw StateError('Unexpected method $method'),
          };
          return http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}),
            200,
          );
        }),
      ),
    );

    final native = await service.getBalance(
      rpcUrl: 'https://fullnode.test',
      owner: '0xowner',
    );
    final balances = await service.getAllBalances(
      rpcUrl: 'https://fullnode.test',
      owner: '0xowner',
    );
    final metadata = await service.getCoinMetadata(
      rpcUrl: 'https://fullnode.test',
      coinType: '0xabc::usdc::USDC',
    );

    expect(native.coinType, suiNativeCoinType);
    expect(native.totalBalance, BigInt.from(1500000000));
    expect(balances, hasLength(2));
    expect(balances.last.totalBalance, BigInt.from(1234500));
    expect(metadata?.symbol, 'USDC');
    expect(metadata?.decimals, 6);
    expect(methods, [
      'suix_getBalance',
      'suix_getAllBalances',
      'suix_getCoinMetadata',
    ]);
  });

  test('accepts missing Coin metadata', () async {
    final service = HttpSuiAssetService(
      rpcClient: HttpSuiJsonRpcClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': null}),
            200,
          ),
        ),
      ),
    );

    final metadata = await service.getCoinMetadata(
      rpcUrl: 'https://fullnode.test',
      coinType: '0xabc::unknown::UNKNOWN',
    );

    expect(metadata, isNull);
  });

  test('maps Sui SDK gRPC balances and metadata', () async {
    final fakeClient = _FakeSdkSuiGrpcClient();
    sdk.SuiGrpcClientOptions? capturedOptions;
    final service = GrpcSuiAssetService(
      clientFactory: (options) {
        capturedOptions = options;
        return fakeClient;
      },
    );

    final native = await service.getBalance(
      rpcUrl: 'https://fullnode.mainnet.sui.io:443',
      owner: '0xowner',
    );
    final balances = await service.getAllBalances(
      rpcUrl: 'https://fullnode.mainnet.sui.io:443',
      owner: '0xowner',
    );
    final metadata = await service.getCoinMetadata(
      rpcUrl: 'https://fullnode.mainnet.sui.io:443',
      coinType: '0xabc::usdc::USDC',
    );

    expect(capturedOptions?.baseUrl, 'fullnode.mainnet.sui.io');
    expect(capturedOptions?.port, 443);
    expect(native.totalBalance, BigInt.from(1500000000));
    expect(balances.last.coinType, '0xabc::usdc::USDC');
    expect(metadata?.symbol, 'USDC');
    expect(fakeClient.balanceOwners, ['0xowner']);
    expect(fakeClient.allBalanceOwners, ['0xowner']);
  });

  test('uses isolated gRPC clients for distinct custom headers', () async {
    final capturedOptions = <sdk.SuiGrpcClientOptions>[];
    final service = GrpcSuiAssetService(
      clientFactory: (options) {
        capturedOptions.add(options);
        return _FakeSdkSuiGrpcClient();
      },
    );

    for (final headers in const [
      {'x-api-key': 'one', 'authorization': 'Bearer token'},
      {'authorization': 'Bearer token', 'x-api-key': 'one'},
      {'authorization': 'Bearer other', 'x-api-key': 'one'},
    ]) {
      await service.getBalance(
        rpcUrl: 'https://localhost:1',
        owner: '0xowner',
        headers: headers,
      );
    }

    expect(capturedOptions, hasLength(2));
    expect(
      capturedOptions.map((options) => options.customChannel),
      everyElement(isA<DefaultCallOptionsClientChannel>()),
    );
  });
}

final class _FakeSdkSuiGrpcClient extends sdk.SuiGrpcClient {
  _FakeSdkSuiGrpcClient()
    : super(
        sdk.SuiGrpcClientOptions(
          baseUrl: 'localhost',
          port: 443,
          customChannel: ClientChannel(
            'localhost',
            port: 1,
            options: const ChannelOptions(
              credentials: ChannelCredentials.insecure(),
            ),
          ),
        ),
      );

  final balanceOwners = <String>[];
  final allBalanceOwners = <String>[];

  @override
  Future<sdk.Balance> getBalance(
    String owner, {
    String coinType = suiNativeCoinType,
  }) async {
    balanceOwners.add(owner);
    return sdk.Balance(
      coinType: coinType,
      balance: '1500000000',
      coinBalance: '1500000000',
      addressBalance: '1500000000',
    );
  }

  @override
  Future<List<sdk.Balance>> getAllBalances(String owner) async {
    allBalanceOwners.add(owner);
    return const [
      sdk.Balance(
        coinType: suiNativeCoinType,
        balance: '1500000000',
        coinBalance: '1500000000',
        addressBalance: '1500000000',
      ),
      sdk.Balance(
        coinType: '0xabc::usdc::USDC',
        balance: '1234500',
        coinBalance: '1234500',
        addressBalance: '1234500',
      ),
    ];
  }

  @override
  Future<sdk.CoinMetadata?> getCoinMetadata(String coinType) async {
    return const sdk.CoinMetadata(
      id: '0xmetadata',
      decimals: 6,
      name: 'USD Coin',
      symbol: 'USDC',
      description: 'Test coin',
      iconUrl: 'https://example.com/usdc.png',
    );
  }

  @override
  Future<void> shutdown() async {}
}
