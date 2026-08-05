import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/data/hive_rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';
import 'package:safe_wallet/shared/storage/storage_initializer.dart';

void main() {
  group('HiveRpcNodeRepository', () {
    late Directory tempDirectory;
    late ChainConfig ethereum;
    late ChainConfig solana;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'safe_wallet_rpc_nodes_test_',
      );
      ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
    });

    tearDown(() async {
      await Hive.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'creates default nodes and persists selected node per chain',
      () async {
        final repository = await _createRepository(tempDirectory);

        final defaultEthNode = await repository.getSelectedNode(ethereum);
        final defaultSolanaNode = await repository.getSelectedNode(solana);

        expect(defaultEthNode.nodeType, RpcNodeType.defaultNode);
        expect(defaultEthNode.chainId, ethereum.chainId);
        expect(defaultSolanaNode.chainId, solana.chainId);

        final custom = await repository.addCustomNode(
          chain: ethereum,
          name: 'Fast Ethereum',
          url: 'https://eth.example.com',
        );
        final available = await repository.updateTestStatus(
          nodeId: custom.id,
          status: RpcNodeTestStatus.available,
          testedAt: DateTime.utc(2026, 6, 6),
          blockHeight: 19000000,
          latencyMs: 120,
        );
        final selected = await repository.selectNode(
          chain: ethereum,
          nodeId: available.id,
        );

        expect(selected.id, custom.id);
        expect(
          (await repository.getSelectedNode(solana)).id,
          defaultSolanaNode.id,
        );

        final restoredRepository = await _reopenRepository(tempDirectory);
        final restored = await restoredRepository.getSelectedNode(ethereum);

        expect(restored.id, custom.id);
        expect(restored.lastBlockHeight, 19000000);
        expect(restored.lastLatencyMs, 120);
      },
    );

    test(
      'selects a custom node when chain metadata has no default RPC',
      () async {
        final repository = await _createRepository(tempDirectory);
        const customChain = ChainConfig(
          id: 'custom-evm-31337',
          chainType: ChainType.evm,
          name: 'Local Testnet',
          chainId: '31337',
          symbol: 'ETH',
          rpcUrls: [],
          blockExplorerUrl: null,
          isTestnet: true,
        );
        final customNode = await repository.addCustomNode(
          chain: customChain,
          name: 'Local RPC',
          url: 'http://127.0.0.1:8545',
        );

        final selected = await repository.selectNode(
          chain: customChain,
          nodeId: customNode.id,
        );

        expect(selected.id, customNode.id);
        expect(selected.isSelected, isTrue);
        expect(
          (await repository.getSelectedNode(customChain)).id,
          customNode.id,
        );
      },
    );

    test('rejects cleartext RPC endpoints outside loopback', () async {
      final repository = await _createRepository(tempDirectory);

      await expectLater(
        repository.addCustomNode(
          chain: ethereum,
          name: 'Insecure RPC',
          url: 'http://rpc.example.com',
        ),
        throwsA(
          isA<RpcError>().having(
            (error) => error.code,
            'code',
            'invalid_rpc_url',
          ),
        ),
      );
    });

    test('deleting selected custom node falls back to default node', () async {
      final repository = await _createRepository(tempDirectory);
      final defaultNode = await repository.getSelectedNode(ethereum);
      final custom = await repository.addCustomNode(
        chain: ethereum,
        name: 'Custom Ethereum',
        url: 'https://custom.example.com',
      );
      final available = await repository.updateTestStatus(
        nodeId: custom.id,
        status: RpcNodeTestStatus.available,
        testedAt: DateTime.utc(2026, 6, 6),
      );
      await repository.selectNode(chain: ethereum, nodeId: available.id);

      await repository.deleteNode(chain: ethereum, nodeId: custom.id);

      final selectedAfterDelete = await repository.getSelectedNode(ethereum);

      expect(selectedAfterDelete.id, defaultNode.id);
      await expectLater(
        repository.deleteNode(chain: ethereum, nodeId: defaultNode.id),
        throwsStateError,
      );
    });

    test('unavailable EVM node cannot be selected', () async {
      final repository = await _createRepository(tempDirectory);
      final defaultNode = await repository.getSelectedNode(ethereum);
      final custom = await repository.addCustomNode(
        chain: ethereum,
        name: 'Wrong Chain',
        url: 'https://wrong-chain.example.com',
      );
      final unavailable = await repository.updateTestStatus(
        nodeId: custom.id,
        status: RpcNodeTestStatus.unavailable,
        testedAt: DateTime.utc(2026, 6, 6),
      );

      await expectLater(
        repository.selectNode(chain: ethereum, nodeId: unavailable.id),
        throwsStateError,
      );
      expect((await repository.getSelectedNode(ethereum)).id, defaultNode.id);
    });

    test(
      'selected node automatically falls back when it becomes unavailable',
      () async {
        final repository = await _createRepository(tempDirectory);
        final defaultNode = await repository.getSelectedNode(ethereum);
        final custom = await repository.addCustomNode(
          chain: ethereum,
          name: 'Private Ethereum',
          url: 'https://private.example.com',
        );
        await repository.selectNode(chain: ethereum, nodeId: custom.id);

        final unavailable = await repository.updateTestStatus(
          nodeId: custom.id,
          status: RpcNodeTestStatus.unavailable,
          testedAt: DateTime.utc(2026, 7, 23),
        );

        expect(unavailable.isSelected, isFalse);
        expect((await repository.getSelectedNode(ethereum)).id, defaultNode.id);
      },
    );

    test(
      'private node stores credential outside Hive and deletes it with node',
      () async {
        final initializer = StorageInitializer(path: tempDirectory.path);
        final registry = await initializer.initialize();
        final credentialStore = _MemoryRpcCredentialStore();
        final repository = HiveRpcNodeRepository(
          registry: registry,
          credentialStore: credentialStore,
          idFactory: (_) => 'private-node',
        );

        final node = await repository.addCustomNode(
          chain: solana,
          name: 'Helius',
          url: 'https://mainnet.helius-rpc.com/',
          provider: RpcProvider.helius,
          credentialMode: RpcCredentialMode.queryParameter,
          credentialParameter: 'api-key',
          credential: 'secret-helius-key',
        );

        expect(node.credentialRef, 'rpc-node.private-node');
        expect(
          await credentialStore.read(node.credentialRef!),
          'secret-helius-key',
        );
        expect(
          registry.rpcNodesBox.values.join(),
          isNot(contains('secret-helius-key')),
        );

        await repository.deleteNode(chain: solana, nodeId: node.id);

        expect(await credentialStore.read(node.credentialRef!), isNull);
      },
    );

    test(
      'deletes the last custom node for a chain without a default RPC',
      () async {
        final initializer = StorageInitializer(path: tempDirectory.path);
        final registry = await initializer.initialize();
        final credentialStore = _MemoryRpcCredentialStore();
        final repository = HiveRpcNodeRepository(
          registry: registry,
          credentialStore: credentialStore,
          idFactory: (_) => 'private-node',
        );
        const customChain = ChainConfig(
          id: 'custom-evm-9999',
          chainType: ChainType.evm,
          name: 'Private EVM',
          chainId: '9999',
          symbol: 'PRV',
          rpcUrls: [],
          blockExplorerUrl: null,
          isTestnet: false,
        );
        final node = await repository.addCustomNode(
          chain: customChain,
          name: 'Helius-style private RPC',
          url: 'https://rpc.example.com',
          credentialMode: RpcCredentialMode.header,
          credentialParameter: 'x-api-key',
          credential: 'private-key',
        );
        await repository.selectNode(chain: customChain, nodeId: node.id);

        await repository.deleteNode(chain: customChain, nodeId: node.id);

        expect(registry.rpcNodesBox.containsKey(node.id), isFalse);
        expect(await credentialStore.read(node.credentialRef!), isNull);
      },
    );

    test('keeps node metadata when secure credential deletion fails', () async {
      final initializer = StorageInitializer(path: tempDirectory.path);
      final registry = await initializer.initialize();
      final credentialStore = _FailingDeleteRpcCredentialStore();
      final repository = HiveRpcNodeRepository(
        registry: registry,
        credentialStore: credentialStore,
        idFactory: (_) => 'private-node',
      );
      final node = await repository.addCustomNode(
        chain: ethereum,
        name: 'Private Ethereum',
        url: 'https://rpc.example.com',
        credentialMode: RpcCredentialMode.queryParameter,
        credentialParameter: 'api-key',
        credential: 'private-key',
      );

      await expectLater(
        repository.deleteNode(chain: ethereum, nodeId: node.id),
        throwsStateError,
      );

      expect(registry.rpcNodesBox.containsKey(node.id), isTrue);
      expect(await credentialStore.read(node.credentialRef!), 'private-key');
    });

    test(
      'keeps private node metadata when removing its credential fails',
      () async {
        final initializer = StorageInitializer(path: tempDirectory.path);
        final registry = await initializer.initialize();
        final credentialStore = _FailingDeleteRpcCredentialStore();
        final repository = HiveRpcNodeRepository(
          registry: registry,
          credentialStore: credentialStore,
          idFactory: (_) => 'private-node',
        );
        final node = await repository.addCustomNode(
          chain: ethereum,
          name: 'Private Ethereum',
          url: 'https://eth-mainnet.g.alchemy.com/v2',
          provider: RpcProvider.alchemy,
          credentialMode: RpcCredentialMode.pathSegment,
          credential: 'private-key',
        );

        await expectLater(
          repository.updateCustomNode(
            chain: ethereum,
            nodeId: node.id,
            name: 'Public Ethereum',
            url: 'https://rpc.example.com',
            provider: RpcProvider.custom,
            credentialMode: RpcCredentialMode.none,
          ),
          throwsStateError,
        );

        final persisted = (await repository.getNodesForChain(
          ethereum,
        )).firstWhere((item) => item.id == node.id);
        expect(persisted.credentialMode, RpcCredentialMode.pathSegment);
        expect(persisted.credentialRef, node.credentialRef);
        expect(await credentialStore.read(node.credentialRef!), 'private-key');
      },
    );

    test(
      'pasted private endpoint is automatically split before persistence',
      () async {
        final initializer = StorageInitializer(path: tempDirectory.path);
        final registry = await initializer.initialize();
        final credentialStore = _MemoryRpcCredentialStore();
        final repository = HiveRpcNodeRepository(
          registry: registry,
          credentialStore: credentialStore,
          idFactory: (_) => 'quicknode-import',
        );

        final node = await repository.addCustomNode(
          chain: ethereum,
          name: 'QuickNode import',
          url: 'https://quiet-name.quiknode.pro/private-token/',
        );

        expect(node.url, 'https://quiet-name.quiknode.pro/');
        expect(node.provider, RpcProvider.quickNode);
        expect(node.credentialMode, RpcCredentialMode.fullEndpoint);
        expect(
          await credentialStore.read(node.credentialRef!),
          'https://quiet-name.quiknode.pro/private-token/',
        );
        expect(
          registry.rpcNodesBox.values.join(),
          isNot(contains('private-token')),
        );
      },
    );

    test(
      'editing a private node keeps or replaces its credential explicitly',
      () async {
        final initializer = StorageInitializer(path: tempDirectory.path);
        final registry = await initializer.initialize();
        final credentialStore = _MemoryRpcCredentialStore();
        final repository = HiveRpcNodeRepository(
          registry: registry,
          credentialStore: credentialStore,
          idFactory: (_) => 'private-node',
        );
        final node = await repository.addCustomNode(
          chain: ethereum,
          name: 'Alchemy',
          url: 'https://eth-mainnet.g.alchemy.com/v2',
          provider: RpcProvider.alchemy,
          credentialMode: RpcCredentialMode.pathSegment,
          credential: 'old-key',
        );

        await repository.updateCustomNode(
          chain: ethereum,
          nodeId: node.id,
          name: 'Alchemy renamed',
          url: node.url,
          provider: node.provider,
          credentialMode: node.credentialMode,
        );
        expect(await credentialStore.read(node.credentialRef!), 'old-key');

        await repository.updateCustomNode(
          chain: ethereum,
          nodeId: node.id,
          name: 'Alchemy renamed',
          url: node.url,
          provider: node.provider,
          credentialMode: node.credentialMode,
          credential: 'new-key',
        );
        expect(await credentialStore.read(node.credentialRef!), 'new-key');
      },
    );
  });
}

Future<RpcNodeRepository> _createRepository(Directory directory) async {
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveRpcNodeRepository(registry: registry);
}

Future<RpcNodeRepository> _reopenRepository(Directory directory) async {
  await Hive.close();
  final initializer = StorageInitializer(path: directory.path);
  final registry = await initializer.initialize();
  return HiveRpcNodeRepository(registry: registry);
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

final class _FailingDeleteRpcCredentialStore extends _MemoryRpcCredentialStore {
  @override
  Future<void> delete(String credentialRef) {
    throw StateError('secure credential deletion failed');
  }
}
