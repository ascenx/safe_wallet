import '../../../shared/errors/rpc_error.dart';
import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../../../shared/storage/storage_keys.dart';
import '../../chains/data/default_chains.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/rpc_node.dart';
import 'rpc_credential_store.dart';
import 'rpc_credential_migration.dart';
import 'rpc_node_repository.dart';

typedef RpcNodeIdFactory = String Function(ChainConfig chain);

final class HiveRpcNodeRepository implements RpcNodeRepository {
  HiveRpcNodeRepository({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
    RpcNodeIdFactory? idFactory,
    RpcCredentialStore? credentialStore,
  }) : _registry = registry,
       _codec = codec,
       _idFactory = idFactory ?? _defaultIdFactory,
       _credentialStore = credentialStore ?? FlutterSecureRpcCredentialStore();

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;
  final RpcNodeIdFactory _idFactory;
  final RpcCredentialStore _credentialStore;

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    await _ensureDefaultNodes(chain);
    final selectedNodeId = await _selectedNodeIdForChain(chain);
    final nodes =
        _storedNodes()
            .where((node) => node.chainId == chain.chainId)
            .map((node) => _withSelection(node, node.id == selectedNodeId))
            .toList()
          ..sort(_compareNodes);
    return List.unmodifiable(nodes);
  }

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async {
    final nodes = await getNodesForChain(chain);
    return nodes.firstWhere((node) => node.isSelected);
  }

  @override
  Future<RpcNode> addCustomNode({
    required ChainConfig chain,
    required String name,
    required String url,
    String? note,
    RpcProvider provider = RpcProvider.custom,
    RpcCredentialMode credentialMode = RpcCredentialMode.none,
    String? credentialParameter,
    String? credential,
  }) async {
    final parsedEndpoint =
        credentialMode == RpcCredentialMode.none &&
            (credential == null || credential.trim().isEmpty)
        ? parsePrivateRpcEndpoint(url)
        : null;
    final effectiveUrl = parsedEndpoint?.safeUrl ?? url;
    final effectiveProvider = parsedEndpoint?.provider ?? provider;
    final effectiveCredentialMode = parsedEndpoint?.mode ?? credentialMode;
    final effectiveCredentialParameter =
        parsedEndpoint?.parameter ?? credentialParameter;
    final effectiveCredential = parsedEndpoint?.credential ?? credential;
    _validateRpcUrl(effectiveUrl);
    _validateCredential(
      credentialMode: effectiveCredentialMode,
      credentialParameter: effectiveCredentialParameter,
      credential: effectiveCredential,
    );
    final nodeId = _idFactory(chain);
    final credentialRef = effectiveCredentialMode == RpcCredentialMode.none
        ? null
        : 'rpc-node.$nodeId';
    final node = RpcNode(
      id: nodeId,
      chainId: chain.chainId,
      name: name.trim(),
      url: effectiveUrl.trim(),
      nodeType: RpcNodeType.custom,
      isSelected: false,
      lastTestStatus: RpcNodeTestStatus.untested,
      note: _blankToNull(note),
      provider: effectiveProvider,
      credentialMode: effectiveCredentialMode,
      credentialParameter: _blankToNull(effectiveCredentialParameter),
      credentialRef: credentialRef,
    );
    if (credentialRef != null) {
      await _credentialStore.write(credentialRef, effectiveCredential!.trim());
    }
    try {
      await _putNode(node);
    } catch (_) {
      if (credentialRef != null) {
        await _credentialStore.delete(credentialRef);
      }
      rethrow;
    }
    return node;
  }

  @override
  Future<RpcNode> updateCustomNode({
    required ChainConfig chain,
    required String nodeId,
    required String name,
    required String url,
    String? note,
    RpcProvider? provider,
    RpcCredentialMode? credentialMode,
    String? credentialParameter,
    String? credential,
  }) async {
    final existing = await _nodeById(nodeId);
    if (existing.nodeType == RpcNodeType.defaultNode ||
        existing.chainId != chain.chainId) {
      throw StateError(
        'Only custom nodes for the selected chain can be edited',
      );
    }

    final requestedCredentialMode = credentialMode ?? existing.credentialMode;
    final parsedEndpoint =
        requestedCredentialMode == RpcCredentialMode.none &&
            (credential == null || credential.trim().isEmpty)
        ? parsePrivateRpcEndpoint(url)
        : null;
    final effectiveUrl = parsedEndpoint?.safeUrl ?? url;
    final updatedProvider =
        parsedEndpoint?.provider ?? provider ?? existing.provider;
    final updatedCredentialMode =
        parsedEndpoint?.mode ?? requestedCredentialMode;
    final updatedCredentialParameter =
        updatedCredentialMode == RpcCredentialMode.none
        ? null
        : parsedEndpoint?.parameter ??
              (credentialParameter == null
                  ? existing.credentialParameter
                  : _blankToNull(credentialParameter));
    final effectiveCredential = parsedEndpoint?.credential ?? credential;
    _validateRpcUrl(effectiveUrl);
    final updatedCredentialRef = updatedCredentialMode == RpcCredentialMode.none
        ? null
        : existing.credentialRef ?? 'rpc-node.${existing.id}';
    if (updatedCredentialMode != RpcCredentialMode.none &&
        updatedCredentialRef != null &&
        effectiveCredential == null &&
        await _credentialStore.read(updatedCredentialRef) == null) {
      throw StateError('RPC credential is required');
    }
    _validateCredential(
      credentialMode: updatedCredentialMode,
      credentialParameter: updatedCredentialParameter,
      credential: effectiveCredential,
      allowMissingCredential: updatedCredentialRef != null,
    );
    final updated = RpcNode(
      id: existing.id,
      chainId: existing.chainId,
      name: name.trim(),
      url: effectiveUrl.trim(),
      nodeType: existing.nodeType,
      isSelected: existing.isSelected,
      lastTestStatus: RpcNodeTestStatus.untested,
      lastTestedAt: null,
      note: _blankToNull(note),
      provider: updatedProvider,
      credentialMode: updatedCredentialMode,
      credentialParameter: updatedCredentialParameter,
      credentialRef: updatedCredentialRef,
    );
    final previousCredential = existing.credentialRef == null
        ? null
        : await _credentialStore.read(existing.credentialRef!);
    final removesCredential =
        updatedCredentialRef == null && existing.credentialRef != null;
    if (removesCredential) {
      await _credentialStore.delete(existing.credentialRef!);
    }
    if (updatedCredentialRef != null &&
        effectiveCredential != null &&
        effectiveCredential.trim().isNotEmpty) {
      await _credentialStore.write(
        updatedCredentialRef,
        effectiveCredential.trim(),
      );
    }
    try {
      await _putNode(updated);
    } catch (_) {
      if (updatedCredentialRef != null &&
          effectiveCredential != null &&
          effectiveCredential.trim().isNotEmpty) {
        if (previousCredential == null) {
          await _credentialStore.delete(updatedCredentialRef);
        } else {
          await _credentialStore.write(
            updatedCredentialRef,
            previousCredential,
          );
        }
      }
      if (removesCredential && previousCredential != null) {
        try {
          await _credentialStore.write(
            existing.credentialRef!,
            previousCredential,
          );
        } catch (_) {
          // Preserve the node persistence failure that triggered rollback.
        }
      }
      rethrow;
    }
    return updated;
  }

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    final existing = await _nodeById(nodeId);
    if (existing.nodeType == RpcNodeType.defaultNode &&
        defaultChains.any((defaultChain) => defaultChain.id == chain.id)) {
      throw StateError('Default RPC nodes cannot be deleted');
    }
    if (existing.chainId != chain.chainId) {
      throw StateError('RPC node does not belong to the selected chain');
    }

    final selectedKey = _selectedNodeKey(chain);
    final selectedNodeId = _registry.settingsBox.get(selectedKey) as String?;
    String? deletedCredential;
    if (existing.credentialRef != null) {
      deletedCredential = await _credentialStore.read(existing.credentialRef!);
      await _credentialStore.delete(existing.credentialRef!);
    }
    try {
      await _registry.rpcNodesBox.delete(nodeId);
    } catch (_) {
      if (existing.credentialRef != null && deletedCredential != null) {
        try {
          await _credentialStore.write(
            existing.credentialRef!,
            deletedCredential,
          );
        } catch (_) {
          // Preserve the storage deletion failure that triggered rollback.
        }
      }
      rethrow;
    }
    if (selectedNodeId == nodeId) {
      await _registry.settingsBox.delete(selectedKey);
      final hasRemainingNodes = _storedNodes().any(
        (node) => node.chainId == chain.chainId,
      );
      if (hasRemainingNodes) {
        await getSelectedNode(chain);
      }
    }
  }

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) async {
    final nodes = await getNodesForChain(chain);
    final selected = nodes.firstWhere((node) => node.id == nodeId);
    if (selected.lastTestStatus == RpcNodeTestStatus.unavailable) {
      throw StateError('Unavailable RPC nodes cannot be selected');
    }

    await _registry.settingsBox.put(_selectedNodeKey(chain), selected.id);
    for (final node in nodes) {
      await _putNode(_withSelection(node, node.id == selected.id));
    }
    return _withSelection(selected, true);
  }

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) async {
    final existing = await _nodeById(nodeId);
    var updated = RpcNode(
      id: existing.id,
      chainId: existing.chainId,
      name: existing.name,
      url: existing.url,
      nodeType: existing.nodeType,
      isSelected: existing.isSelected,
      lastTestStatus: status,
      lastTestedAt: testedAt,
      lastBlockHeight: blockHeight,
      lastLatencyMs: latencyMs,
      note: existing.note,
      provider: existing.provider,
      credentialMode: existing.credentialMode,
      credentialParameter: existing.credentialParameter,
      credentialRef: existing.credentialRef,
    );
    if (status == RpcNodeTestStatus.unavailable && existing.isSelected) {
      final fallbackCandidates =
          _storedNodes()
              .where(
                (node) =>
                    node.chainId == existing.chainId &&
                    node.id != existing.id &&
                    node.lastTestStatus != RpcNodeTestStatus.unavailable,
              )
              .toList()
            ..sort(_compareFallbackNodes);
      if (fallbackCandidates.isNotEmpty) {
        updated = _withSelection(updated, false);
        final fallback = _withSelection(fallbackCandidates.first, true);
        await _registry.settingsBox.put(
          _selectedNodeKeyForChainId(existing.chainId),
          fallback.id,
        );
        await _putNode(fallback);
      }
    }
    await _putNode(updated);
    return updated;
  }

  Future<void> _ensureDefaultNodes(ChainConfig chain) async {
    for (var index = 0; index < chain.rpcUrls.length; index += 1) {
      final nodeId = '${chain.id}-default-$index';
      if (!_registry.rpcNodesBox.containsKey(nodeId)) {
        final node = RpcNode(
          id: nodeId,
          chainId: chain.chainId,
          name: chain.rpcUrls.length == 1
              ? '${chain.name} Default'
              : '${chain.name} Default ${index + 1}',
          url: chain.rpcUrls[index],
          nodeType: RpcNodeType.defaultNode,
          isSelected: index == 0,
          lastTestStatus: RpcNodeTestStatus.untested,
          provider: RpcProvider.public,
        );
        await _putNode(node);
      }
    }
  }

  Future<String> _selectedNodeIdForChain(ChainConfig chain) async {
    final selectedKey = _selectedNodeKey(chain);
    final storedSelectedNodeId =
        _registry.settingsBox.get(selectedKey) as String?;
    final nodes =
        _storedNodes().where((node) => node.chainId == chain.chainId).toList()
          ..sort(_compareNodes);
    final storedSelectedExists =
        storedSelectedNodeId != null &&
        nodes.any((node) => node.id == storedSelectedNodeId);
    if (storedSelectedExists) {
      return storedSelectedNodeId;
    }

    if (nodes.isEmpty) {
      throw StateError('No RPC nodes configured for chain: ${chain.id}');
    }

    final defaultNode = nodes.firstWhere(
      (node) => node.nodeType == RpcNodeType.defaultNode,
      orElse: () => nodes.first,
    );
    await _registry.settingsBox.put(selectedKey, defaultNode.id);
    return defaultNode.id;
  }

  Future<RpcNode> _nodeById(String nodeId) async {
    final rawValue = _registry.rpcNodesBox.get(nodeId);
    if (rawValue is! String) {
      throw StateError('RPC node not found: $nodeId');
    }
    final node = _codec.tryDecode(rawValue, _nodeFromJson);
    if (node == null) {
      throw StateError('RPC node record is corrupted: $nodeId');
    }
    return node;
  }

  List<RpcNode> _storedNodes() {
    return _registry.rpcNodesBox.values
        .whereType<String>()
        .map((value) => _codec.tryDecode(value, _nodeFromJson))
        .whereType<RpcNode>()
        .toList();
  }

  Future<void> _putNode(RpcNode node) async {
    await _registry.rpcNodesBox.put(node.id, _codec.encode(_nodeToJson(node)));
  }

  int _compareNodes(RpcNode left, RpcNode right) {
    if (left.nodeType != right.nodeType) {
      return _nodeTypeSort(
        left.nodeType,
      ).compareTo(_nodeTypeSort(right.nodeType));
    }
    return left.name.compareTo(right.name);
  }

  int _compareFallbackNodes(RpcNode left, RpcNode right) {
    final leftAvailable = left.lastTestStatus == RpcNodeTestStatus.available
        ? 0
        : 1;
    final rightAvailable = right.lastTestStatus == RpcNodeTestStatus.available
        ? 0
        : 1;
    final statusComparison = leftAvailable.compareTo(rightAvailable);
    return statusComparison != 0
        ? statusComparison
        : _compareNodes(left, right);
  }

  int _nodeTypeSort(RpcNodeType nodeType) {
    return switch (nodeType) {
      RpcNodeType.defaultNode => 0,
      RpcNodeType.chainlist => 1,
      RpcNodeType.custom => 2,
    };
  }

  String _selectedNodeKey(ChainConfig chain) {
    return _selectedNodeKeyForChainId(chain.chainId);
  }

  String _selectedNodeKeyForChainId(String chainId) {
    return '${StorageKeys.selectedRpcNodeIdPrefix}.$chainId';
  }

  void _validateRpcUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && _isLoopbackHost(uri.host)))) {
      throw const RpcError.invalidUrl();
    }
  }

  RpcNode _withSelection(RpcNode node, bool isSelected) {
    return RpcNode(
      id: node.id,
      chainId: node.chainId,
      name: node.name,
      url: node.url,
      nodeType: node.nodeType,
      isSelected: isSelected,
      lastTestStatus: node.lastTestStatus,
      lastTestedAt: node.lastTestedAt,
      lastBlockHeight: node.lastBlockHeight,
      lastLatencyMs: node.lastLatencyMs,
      note: node.note,
      provider: node.provider,
      credentialMode: node.credentialMode,
      credentialParameter: node.credentialParameter,
      credentialRef: node.credentialRef,
    );
  }

  Map<String, Object?> _nodeToJson(RpcNode node) {
    return {
      'id': node.id,
      'chainId': node.chainId,
      'name': node.name,
      'url': node.url,
      'nodeType': node.nodeType.name,
      'isSelected': node.isSelected,
      'lastTestStatus': node.lastTestStatus.name,
      'lastTestedAt': node.lastTestedAt?.toIso8601String(),
      'lastBlockHeight': node.lastBlockHeight,
      'lastLatencyMs': node.lastLatencyMs,
      'note': node.note,
      'provider': node.provider.name,
      'credentialMode': node.credentialMode.name,
      'credentialParameter': node.credentialParameter,
      'credentialRef': node.credentialRef,
    };
  }

  RpcNode _nodeFromJson(Map<String, Object?> json) {
    final lastTestedAt = json['lastTestedAt'] as String?;
    final nodeType = RpcNodeType.values.byName(json['nodeType'] as String);
    return RpcNode(
      id: json['id'] as String,
      chainId: json['chainId'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      nodeType: nodeType,
      isSelected: json['isSelected'] as bool,
      lastTestStatus: RpcNodeTestStatus.values.byName(
        json['lastTestStatus'] as String,
      ),
      lastTestedAt: lastTestedAt == null ? null : DateTime.parse(lastTestedAt),
      lastBlockHeight: json['lastBlockHeight'] as int?,
      lastLatencyMs: json['lastLatencyMs'] as int?,
      note: json['note'] as String?,
      provider: RpcProvider.values.byName(
        json['provider'] as String? ??
            (nodeType == RpcNodeType.custom
                ? RpcProvider.custom.name
                : RpcProvider.public.name),
      ),
      credentialMode: RpcCredentialMode.values.byName(
        json['credentialMode'] as String? ?? RpcCredentialMode.none.name,
      ),
      credentialParameter: json['credentialParameter'] as String?,
      credentialRef: json['credentialRef'] as String?,
    );
  }

  void _validateCredential({
    required RpcCredentialMode credentialMode,
    required String? credentialParameter,
    required String? credential,
    bool allowMissingCredential = false,
  }) {
    if (credentialMode == RpcCredentialMode.none) {
      return;
    }
    if (!allowMissingCredential &&
        (credential == null || credential.trim().isEmpty)) {
      throw StateError('RPC credential is required');
    }
    if ((credentialMode == RpcCredentialMode.queryParameter ||
            credentialMode == RpcCredentialMode.header) &&
        (credentialParameter == null || credentialParameter.trim().isEmpty)) {
      throw StateError('RPC credential parameter is required');
    }
  }

  static String _defaultIdFactory(ChainConfig chain) {
    return 'custom-${chain.id}-${DateTime.now().microsecondsSinceEpoch}';
  }
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
