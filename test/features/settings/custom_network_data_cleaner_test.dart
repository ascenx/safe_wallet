import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/settings/data/custom_network_data_cleaner.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';
import 'package:safe_wallet/shared/storage/storage_keys.dart';

void main() {
  group('HiveCustomNetworkDataCleaner', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_custom_network_cleanup_test_',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('removes every chain-scoped record and keeps other chains', () async {
      final registry = await StorageInitializer(
        path: tempDirectory.path,
      ).initialize();
      final credentials = _MemoryRpcCredentialStore();
      final cleaner = HiveCustomNetworkDataCleaner(
        registry: registry,
        credentialStore: credentials,
      );
      const chain = ChainConfig(
        id: 'custom-evm-31337',
        chainType: ChainType.evm,
        name: 'Local Testnet',
        chainId: '31337',
        symbol: 'ETH',
        rpcUrls: [],
        blockExplorerUrl: null,
        isTestnet: true,
      );

      await credentials.write('rpc-node.node-a', 'secret-a');
      await credentials.write(
        'rpc-node.custom-custom-evm-31337-corrupt',
        'secret-corrupt',
      );
      await credentials.write('rpc-node.node-other', 'secret-other');
      await registry.rpcNodesBox.put(
        'node-a',
        '{"chainId":"31337","credentialRef":"rpc-node.node-a"}',
      );
      await registry.rpcNodesBox.put(
        'custom-custom-evm-31337-corrupt',
        'not-json',
      );
      await registry.rpcNodesBox.put(
        'node-other',
        '{"chainId":"313370","credentialRef":"rpc-node.node-other"}',
      );
      await registry.tokensBox.put('31337:0xabc', 'token');
      await registry.tokensBox.put('313370:0xdef', 'other-token');
      await registry.tokenPricesBox.put('31337:0xabc', 'price');
      await registry.tokenPricesBox.put('313370:0xdef', 'other-price');
      await registry.tokenBalancesBox.put('31337:0xwallet:native', 'balance');
      await registry.tokenBalancesBox.put(
        '313370:0xwallet:native',
        'other-balance',
      );
      await registry.transactionsBox.put('tx-a', '{"chainId":"31337"}');
      await registry.transactionsBox.put('tx-other', '{"chainId":"313370"}');
      await registry.dappPermissionsBox.put(
        'https://example.com|wallet-a|31337',
        '{"chainId":"31337"}',
      );
      await registry.dappPermissionsBox.put(
        'https://example.com|wallet-a|313370',
        '{"chainId":"313370"}',
      );
      await registry.settingsBox.put(
        '${StorageKeys.selectedRpcNodeIdPrefix}.31337',
        'node-a',
      );
      await registry.settingsBox.put(
        '${StorageKeys.selectedRpcNodeIdPrefix}.313370',
        'node-other',
      );
      await registry.settingsBox.put(
        'tokenDiscovery.lastScannedBlock.31337.0xwallet',
        100,
      );
      await registry.settingsBox.put(
        'tokenDiscovery.lastScannedBlock.313370.0xwallet',
        200,
      );

      await cleaner.deleteForChain(chain);

      expect(registry.rpcNodesBox.containsKey('node-a'), isFalse);
      expect(
        registry.rpcNodesBox.containsKey('custom-custom-evm-31337-corrupt'),
        isFalse,
      );
      expect(registry.rpcNodesBox.containsKey('node-other'), isTrue);
      expect(await credentials.read('rpc-node.node-a'), isNull);
      expect(
        await credentials.read('rpc-node.custom-custom-evm-31337-corrupt'),
        isNull,
      );
      expect(await credentials.read('rpc-node.node-other'), 'secret-other');
      expect(registry.tokensBox.containsKey('31337:0xabc'), isFalse);
      expect(registry.tokensBox.containsKey('313370:0xdef'), isTrue);
      expect(registry.tokenPricesBox.containsKey('31337:0xabc'), isFalse);
      expect(registry.tokenPricesBox.containsKey('313370:0xdef'), isTrue);
      expect(
        registry.tokenBalancesBox.containsKey('31337:0xwallet:native'),
        isFalse,
      );
      expect(
        registry.tokenBalancesBox.containsKey('313370:0xwallet:native'),
        isTrue,
      );
      expect(registry.transactionsBox.containsKey('tx-a'), isFalse);
      expect(registry.transactionsBox.containsKey('tx-other'), isTrue);
      expect(
        registry.dappPermissionsBox.containsKey(
          'https://example.com|wallet-a|31337',
        ),
        isFalse,
      );
      expect(
        registry.dappPermissionsBox.containsKey(
          'https://example.com|wallet-a|313370',
        ),
        isTrue,
      );
      expect(
        registry.settingsBox.containsKey(
          '${StorageKeys.selectedRpcNodeIdPrefix}.31337',
        ),
        isFalse,
      );
      expect(
        registry.settingsBox.containsKey(
          '${StorageKeys.selectedRpcNodeIdPrefix}.313370',
        ),
        isTrue,
      );
      expect(
        registry.settingsBox.containsKey(
          'tokenDiscovery.lastScannedBlock.31337.0xwallet',
        ),
        isFalse,
      );
      expect(
        registry.settingsBox.containsKey(
          'tokenDiscovery.lastScannedBlock.313370.0xwallet',
        ),
        isTrue,
      );
    });
  });
}

final class _MemoryRpcCredentialStore implements RpcCredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String credentialRef) async {
    _values.remove(credentialRef);
  }

  @override
  Future<String?> read(String credentialRef) async => _values[credentialRef];

  @override
  Future<void> write(String credentialRef, String credential) async {
    _values[credentialRef] = credential;
  }
}
