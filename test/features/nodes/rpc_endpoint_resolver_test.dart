import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_endpoint.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_provider_catalog.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';

void main() {
  test('Helius credential is injected only into the resolved endpoint',
      () async {
    final store = _MemoryRpcCredentialStore()
      ..values['helius-mainnet'] = 'secret-helius-key';
    final resolver = RpcEndpointResolver(credentialStore: store);
    const node = RpcNode(
      id: 'helius-node',
      chainId: 'mainnet-beta',
      name: 'Helius',
      url: 'https://mainnet.helius-rpc.com/',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.helius,
      credentialMode: RpcCredentialMode.queryParameter,
      credentialParameter: 'api-key',
      credentialRef: 'helius-mainnet',
    );

    final endpoint = await resolver.resolve(node);

    expect(
      endpoint.uri.toString(),
      'https://mainnet.helius-rpc.com/?api-key=secret-helius-key',
    );
    expect(node.url, isNot(contains('secret-helius-key')));
    expect(node.displayUrl, 'https://mainnet.helius-rpc.com/?api-key=••••••••');
  });

  test('QuickNode keeps the complete dashboard endpoint in secure storage',
      () async {
    final store = _MemoryRpcCredentialStore()
      ..values['quicknode-ethereum'] =
          'https://quiet-name.quiknode.pro/private-token/';
    final resolver = RpcEndpointResolver(credentialStore: store);
    const node = RpcNode(
      id: 'quicknode-node',
      chainId: '1',
      name: 'QuickNode',
      url: 'https://quiet-name.quiknode.pro/',
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.quickNode,
      credentialMode: RpcCredentialMode.fullEndpoint,
      credentialRef: 'quicknode-ethereum',
    );

    final endpoint = await resolver.resolve(node);

    expect(
      endpoint.url,
      'https://quiet-name.quiknode.pro/private-token/',
    );
    expect(node.url, isNot(contains('private-token')));
    expect(node.displayUrl, 'https://quiet-name.quiknode.pro/••••••••');
  });

  test('Alchemy and Infura credentials are appended as path segments',
      () async {
    final store = _MemoryRpcCredentialStore()
      ..values['alchemy'] = 'alchemy-key'
      ..values['infura'] = 'infura-key';
    final resolver = RpcEndpointResolver(credentialStore: store);
    const alchemy = RpcNode(
      id: 'alchemy-node',
      chainId: '1',
      name: 'Alchemy',
      url: 'https://eth-mainnet.g.alchemy.com/v2',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.alchemy,
      credentialMode: RpcCredentialMode.pathSegment,
      credentialRef: 'alchemy',
    );
    const infura = RpcNode(
      id: 'infura-node',
      chainId: '1',
      name: 'Infura',
      url: 'https://mainnet.infura.io/v3',
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.infura,
      credentialMode: RpcCredentialMode.pathSegment,
      credentialRef: 'infura',
    );

    expect(
      (await resolver.resolve(alchemy)).url,
      'https://eth-mainnet.g.alchemy.com/v2/alchemy-key',
    );
    expect(
      (await resolver.resolve(infura)).url,
      'https://mainnet.infura.io/v3/infura-key',
    );
    expect(alchemy.displayUrl, contains('••••••••'));
    expect(infura.displayUrl, contains('••••••••'));
  });

  test('missing secure credential produces the dedicated RPC error', () async {
    final resolver = RpcEndpointResolver(
      credentialStore: _MemoryRpcCredentialStore(),
    );
    const node = RpcNode(
      id: 'missing-key',
      chainId: '1',
      name: 'Alchemy',
      url: 'https://eth-mainnet.g.alchemy.com/v2',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.untested,
      credentialMode: RpcCredentialMode.pathSegment,
      credentialRef: 'missing',
    );

    await expectLater(
      resolver.resolve(node),
      throwsA(
        isA<RpcError>().having(
          (error) => error.code,
          'code',
          'rpc_missing_credential',
        ),
      ),
    );
  });

  test('header credentials are returned separately from the URL', () async {
    final store = _MemoryRpcCredentialStore()..values['tron'] = 'tron-key';
    final resolver = RpcEndpointResolver(credentialStore: store);
    const node = RpcNode(
      id: 'tron-node',
      chainId: 'tron-mainnet',
      name: 'TronGrid',
      url: 'https://api.trongrid.io',
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      provider: RpcProvider.tronGrid,
      credentialMode: RpcCredentialMode.header,
      credentialParameter: 'TRON-PRO-API-KEY',
      credentialRef: 'tron',
    );

    final endpoint = await resolver.resolve(node);

    expect(endpoint.url, 'https://api.trongrid.io');
    expect(endpoint.headers, {'TRON-PRO-API-KEY': 'tron-key'});
  });

  test('provider catalog builds popular provider presets', () {
    expect(
      RpcProviderCatalog.forChain(
        provider: RpcProvider.helius,
        chainType: RpcProviderChainType.solana,
        chainId: 'devnet',
      ),
      const RpcProviderPreset(
        provider: RpcProvider.helius,
        url: 'https://devnet.helius-rpc.com/',
        credentialMode: RpcCredentialMode.queryParameter,
        credentialParameter: 'api-key',
      ),
    );
    expect(
      RpcProviderCatalog.forChain(
        provider: RpcProvider.alchemy,
        chainType: RpcProviderChainType.evm,
        chainId: '1',
      )?.url,
      'https://eth-mainnet.g.alchemy.com/v2',
    );
    expect(
      RpcProviderCatalog.forChain(
        provider: RpcProvider.infura,
        chainType: RpcProviderChainType.evm,
        chainId: '42161',
      )?.url,
      'https://arbitrum-mainnet.infura.io/v3',
    );
    expect(
      RpcProviderCatalog.forChain(
        provider: RpcProvider.tronGrid,
        chainType: RpcProviderChainType.tron,
        chainId: 'tron-mainnet',
      )?.credentialParameter,
      'TRON-PRO-API-KEY',
    );
  });
}

final class _MemoryRpcCredentialStore implements RpcCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String credentialRef) async {
    values.remove(credentialRef);
  }

  @override
  Future<String?> read(String credentialRef) async => values[credentialRef];

  @override
  Future<void> write(String credentialRef, String credential) async {
    values[credentialRef] = credential;
  }
}
