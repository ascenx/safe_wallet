import 'package:hive_ce/hive.dart';

import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../../../shared/storage/storage_keys.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/data/rpc_credential_store.dart';
import '../../nodes/data/rpc_node_repository.dart';

abstract interface class CustomNetworkDataCleaner {
  Future<void> deleteForChain(ChainConfig chain);
}

final class NoopCustomNetworkDataCleaner implements CustomNetworkDataCleaner {
  const NoopCustomNetworkDataCleaner();

  @override
  Future<void> deleteForChain(ChainConfig chain) async {}
}

final class RepositoryCustomNetworkDataCleaner
    implements CustomNetworkDataCleaner {
  const RepositoryCustomNetworkDataCleaner({
    required RpcNodeRepository rpcNodeRepository,
  }) : _rpcNodeRepository = rpcNodeRepository;

  final RpcNodeRepository _rpcNodeRepository;

  @override
  Future<void> deleteForChain(ChainConfig chain) async {
    final nodes = await _rpcNodeRepository.getNodesForChain(chain);
    for (final node in nodes) {
      await _rpcNodeRepository.deleteNode(chain: chain, nodeId: node.id);
    }
  }
}

final class HiveCustomNetworkDataCleaner implements CustomNetworkDataCleaner {
  HiveCustomNetworkDataCleaner({
    required HiveBoxRegistry registry,
    required RpcCredentialStore credentialStore,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _credentialStore = credentialStore,
       _codec = codec;

  static const _tokenDiscoveryKeyPrefix = 'tokenDiscovery.lastScannedBlock.';

  final HiveBoxRegistry _registry;
  final RpcCredentialStore _credentialStore;
  final StorageJsonCodec _codec;

  @override
  Future<void> deleteForChain(ChainConfig chain) async {
    await _deleteRpcNodes(chain);
    await _deleteKeysWithPrefix(_registry.tokensBox, '${chain.chainId}:');
    await _deleteKeysWithPrefix(_registry.tokenPricesBox, '${chain.chainId}:');
    await _deleteKeysWithPrefix(
      _registry.tokenBalancesBox,
      '${chain.chainId}:',
    );
    await _deleteJsonRecordsForChain(
      box: _registry.transactionsBox,
      chainId: chain.chainId,
    );
    await _deleteJsonRecordsForChain(
      box: _registry.dappPermissionsBox,
      chainId: chain.chainId,
      fallbackKeyMatches: (key) => key.endsWith('|${chain.chainId}'),
    );
    await _registry.settingsBox.delete(
      '${StorageKeys.selectedRpcNodeIdPrefix}.${chain.chainId}',
    );
    await _deleteKeysWithPrefix(
      _registry.settingsBox,
      '$_tokenDiscoveryKeyPrefix${chain.chainId}.',
    );
  }

  Future<void> _deleteRpcNodes(ChainConfig chain) async {
    final keys = <dynamic>[];
    final credentialRefs = <String>{};
    final corruptCustomNodePrefix = 'custom-${chain.id}-';
    for (final key in _registry.rpcNodesBox.keys.toList(growable: false)) {
      final rawValue = _registry.rpcNodesBox.get(key);
      final json = rawValue is String
          ? _codec.tryDecode(rawValue, (value) => value)
          : null;
      final isDecodedMatch = json?['chainId'] == chain.chainId;
      final isKeyMatch =
          key is String && key.startsWith(corruptCustomNodePrefix);
      if (!isDecodedMatch && !isKeyMatch) {
        continue;
      }
      keys.add(key);
      final credentialRef = json?['credentialRef'];
      if (credentialRef is String && credentialRef.isNotEmpty) {
        credentialRefs.add(credentialRef);
      } else if (key is String && isKeyMatch) {
        credentialRefs.add('rpc-node.$key');
      }
    }
    for (final credentialRef in credentialRefs) {
      await _credentialStore.delete(credentialRef);
    }
    await _registry.rpcNodesBox.deleteAll(keys);
  }

  Future<void> _deleteJsonRecordsForChain({
    required Box<dynamic> box,
    required String chainId,
    bool Function(String key)? fallbackKeyMatches,
  }) async {
    final keys = <dynamic>[];
    for (final key in box.keys.toList(growable: false)) {
      final rawValue = box.get(key);
      final json = rawValue is String
          ? _codec.tryDecode(rawValue, (value) => value)
          : null;
      final keyMatches =
          key is String && (fallbackKeyMatches?.call(key) ?? false);
      if (json?['chainId'] == chainId || keyMatches) {
        keys.add(key);
      }
    }
    await box.deleteAll(keys);
  }

  Future<void> _deleteKeysWithPrefix(Box<dynamic> box, String prefix) async {
    final keys = box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    await box.deleteAll(keys);
  }
}
