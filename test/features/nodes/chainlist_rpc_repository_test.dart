import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/data/chainlist_rpc_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';

void main() {
  test('loads chainlist RPC nodes for a chain and filters unusable URLs',
      () async {
    final ethereum =
        defaultChains.firstWhere((chain) => chain.id == 'ethereum');
    final repository = DefaultChainlistRpcRepository(
      client: MockClient((request) async {
        expect(request.url, Uri.parse('https://chainlist.org/rpcs.json'));
        return http.Response(
          jsonEncode([
            {
              'name': 'Ethereum Mainnet',
              'chainId': 1,
              'rpc': [
                {
                  'url': 'https://ethereum-rpc.publicnode.com',
                  'tracking': 'none'
                },
                {
                  'url': 'wss://ethereum-rpc.publicnode.com',
                  'tracking': 'none'
                },
                {'url': 'https://mainnet.infura.io/v3/\${INFURA_API_KEY}'},
                {
                  'url': 'https://ethereum-rpc.publicnode.com',
                  'tracking': 'none'
                },
                {'url': 'https://rpc.ankr.com/eth', 'tracking': 'yes'},
              ],
            },
            {
              'name': 'BNB Smart Chain',
              'chainId': 56,
              'rpc': [
                {'url': 'https://bsc-dataseed.binance.org'},
              ],
            },
          ]),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final nodes = await repository.getNodesForChain(ethereum);

    expect(nodes.map((node) => node.url), [
      'https://ethereum-rpc.publicnode.com',
      'https://rpc.ankr.com/eth',
    ]);
    expect(
        nodes.every((node) => node.nodeType == RpcNodeType.chainlist), isTrue);
    expect(nodes.first.note, 'tracking:none');
    expect(nodes.first.name, 'ethereum-rpc.publicnode.com');
  });
}
