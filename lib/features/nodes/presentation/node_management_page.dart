import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/errors/rpc_error.dart';
import '../../../shared/chain_clients/solana_client_factory.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_refresh_icon_button.dart';
import '../../chains/domain/chain_config.dart';
import '../application/rpc_node_test_controller.dart';
import '../application/selected_rpc_node_provider.dart';
import '../data/chainlist_rpc_repository.dart';
import '../domain/rpc_endpoint.dart';
import '../domain/rpc_node.dart';
import 'edit_rpc_node_page.dart';

final chainlistRpcNodesForChainProvider =
    FutureProvider.family<List<RpcNode>, ChainConfig>((ref, chain) {
  return ref.read(chainlistRpcRepositoryProvider).getNodesForChain(chain);
});

final chainlistRpcNodeTestCacheProvider = NotifierProvider<
    ChainlistRpcNodeTestCacheController,
    Map<String, RpcNodeRuntimeTestCacheEntry>>(
  ChainlistRpcNodeTestCacheController.new,
);

const rpcNodeLatencyCacheTtl = Duration(minutes: 5);

final class ChainlistRpcNodeTestCacheController
    extends Notifier<Map<String, RpcNodeRuntimeTestCacheEntry>> {
  @override
  Map<String, RpcNodeRuntimeTestCacheEntry> build() => const {};

  void put({
    required ChainConfig chain,
    required RpcNode node,
    required RpcNodeRuntimeTestCacheEntry entry,
  }) {
    state = {
      ...state,
      _nodeCacheKey(chain: chain, node: node): entry,
    };
  }
}

String _nodeCacheKey({
  required ChainConfig chain,
  required RpcNode node,
}) {
  return '${chain.chainId}:${node.url.trim()}';
}

final class RpcNodeRuntimeTestCacheEntry {
  const RpcNodeRuntimeTestCacheEntry({
    required this.status,
    required this.testedAt,
    required this.latencyMs,
    this.blockHeight,
  });

  final RpcNodeTestStatus status;
  final DateTime testedAt;
  final int latencyMs;
  final int? blockHeight;
}

final class NodeManagementPage extends ConsumerStatefulWidget {
  const NodeManagementPage({required this.chain, super.key});

  final ChainConfig chain;

  @override
  ConsumerState<NodeManagementPage> createState() => _NodeManagementPageState();
}

final class _NodeManagementPageState extends ConsumerState<NodeManagementPage> {
  var _isRefreshing = false;
  var _lastVisibleNodes = <RpcNode>[];
  final _localNodeTestCache = <String, RpcNodeRuntimeTestCacheEntry>{};

  ChainConfig get chain => widget.chain;

  @override
  Widget build(BuildContext context) {
    final nodesValue = ref.watch(rpcNodesForChainProvider(chain));
    final chainlistNodesValue =
        ref.watch(chainlistRpcNodesForChainProvider(chain));
    final chainlistCache = ref.watch(chainlistRpcNodeTestCacheProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.nodes.managementTitle),
        actions: [
          AppRefreshIconButton(
            buttonKey: const Key('nodeManagementRefreshButton'),
            spinnerKey: const Key('nodeManagementRefreshSpinner'),
            tooltip: t.browser.refresh,
            isRefreshing: _isRefreshing,
            onPressed: () => _refreshVisibleNodes(force: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('nodeManagementAddButton'),
        tooltip: t.nodes.addNode,
        elevation: 0,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        shape: CircleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EditRpcNodePage(chain: chain),
            ),
          );
        },
        child: Icon(
          AppIcons.add,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: SafeArea(
        child: nodesValue.when(
          data: (nodes) {
            final visibleNodes = _mergeLocalAndChainlistNodes(
              localNodes: _applyRuntimeTestCache(
                chain: chain,
                nodes: nodes,
                cache: _localNodeTestCache,
              ),
              chainlistNodes: _applyRuntimeTestCache(
                chain: chain,
                nodes: _applyRuntimeTestCache(
                  chain: chain,
                  nodes: chainlistNodesValue.value ?? const [],
                  cache: chainlistCache,
                ),
                cache: _localNodeTestCache,
              ),
            );
            _lastVisibleNodes = visibleNodes;
            _scheduleAutoRefresh(visibleNodes);
            if (visibleNodes.isEmpty) {
              return Center(
                child: Text(t.nodes.empty, style: context.appTextStyles.bodySmall),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                16,
                AppSpacing.pageX,
                96,
              ),
              itemBuilder: (context, index) {
                final node = visibleNodes[index];
                return _NodeRow(
                  node: node,
                  onSelect: () => _selectNode(ref, node),
                  onTest: () => _testNode(context, ref, node),
                  onEdit: node.nodeType == RpcNodeType.custom
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EditRpcNodePage(
                                chain: chain,
                                node: node,
                              ),
                            ),
                          );
                        }
                      : null,
                  onDelete: node.nodeType == RpcNodeType.custom
                      ? () => _confirmDeleteNode(context, ref, node)
                      : null,
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sectionY),
              itemCount: visibleNodes.length,
            );
          },
          error: (error, stackTrace) => Center(
            child: Text(t.nodes.loadFailed, style: context.appTextStyles.bodySmall),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  void _scheduleAutoRefresh(List<RpcNode> visibleNodes) {
    if (_isRefreshing || visibleNodes.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    if (!visibleNodes.any((node) => _needsRefresh(node, now))) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isRefreshing) {
        return;
      }
      _refreshVisibleNodes(force: false);
    });
  }

  Future<void> _refreshVisibleNodes({required bool force}) async {
    if (_isRefreshing) {
      return;
    }
    final now = DateTime.now().toUtc();
    final targets = _lastVisibleNodes.where((node) {
      return force || _needsRefresh(node, now);
    }).toList(growable: false);
    if (targets.isEmpty) {
      return;
    }

    _setRefreshing(true);
    try {
      for (var index = 0; index < targets.length; index += 4) {
        if (!mounted) {
          break;
        }
        final end = (index + 4).clamp(0, targets.length);
        await Future.wait(
          targets.sublist(index, end).map((node) => _refreshNodeSilently(node)),
        );
      }
    } finally {
      if (mounted) {
        _setRefreshing(false);
      }
    }
  }

  Future<void> _refreshNodeSilently(RpcNode node) async {
    if (!mounted) {
      return;
    }
    if (node.nodeType == RpcNodeType.chainlist) {
      await _refreshChainlistNode(node);
      return;
    }
    try {
      final tested = await ref
          .read(rpcNodeTestControllerProvider.notifier)
          .testNode(chain: chain, node: node);
      _rememberLocalNodeTestResult(tested);
    } catch (_) {
      // Batch refresh should update node state without interrupting the list.
    }
  }

  Future<void> _refreshChainlistNode(RpcNode node) async {
    final testedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();
    var status = RpcNodeTestStatus.unavailable;
    int? blockHeight;
    try {
      switch (chain.chainType) {
        case ChainType.evm:
          final evmClient = ref.read(evmClientFactoryProvider);
          final actualChainId = await evmClient.readChainId(node.url);
          if (actualChainId != chain.chainId) {
            throw RpcError.chainMismatch(
              expectedChainId: chain.chainId,
              actualChainId: actualChainId,
            );
          }
          blockHeight = await evmClient.readBlockNumber(node.url);
          status = RpcNodeTestStatus.available;
        case ChainType.bitcoin:
          blockHeight =
              await ref.read(bitcoinClientFactoryProvider).readBlockHeight(
                    node.url,
                  );
          status = RpcNodeTestStatus.available;
        case ChainType.tron:
          blockHeight =
              await ref.read(tronClientFactoryProvider).readBlockHeight(
                    node.url,
                  );
          status = RpcNodeTestStatus.available;
        case ChainType.solana:
          final solanaClient = ref.read(solanaClientFactoryProvider);
          await solanaClient.checkHealth(node.url);
          final expectedGenesisHashPrefix = expectedSolanaGenesisHashPrefix(
            chain.chainId,
          );
          if (expectedGenesisHashPrefix != null) {
            final actualGenesisHash = await solanaClient.readGenesisHash(
              node.url,
            );
            if (matchesExpectedSolanaGenesisHash(
              chain.chainId,
              actualGenesisHash,
            )) {
              status = RpcNodeTestStatus.available;
              break;
            }
            throw RpcError.chainMismatch(
              expectedChainId: expectedGenesisHashPrefix,
              actualChainId: actualGenesisHash,
            );
          }
          status = RpcNodeTestStatus.available;
        case ChainType.sui:
          final info = await ref.read(suiClientFactoryProvider).getServiceInfo(
                node.url,
              );
          blockHeight = info.checkpointHeight;
          status = RpcNodeTestStatus.available;
      }
    } catch (_) {
      status = RpcNodeTestStatus.unavailable;
    } finally {
      stopwatch.stop();
      if (mounted) {
        ref.read(chainlistRpcNodeTestCacheProvider.notifier).put(
              chain: chain,
              node: node,
              entry: RpcNodeRuntimeTestCacheEntry(
                status: status,
                testedAt: testedAt,
                latencyMs: stopwatch.elapsedMilliseconds,
              ),
            );
        _rememberNodeTestResult(
          node: node,
          status: status,
          testedAt: testedAt,
          latencyMs: stopwatch.elapsedMilliseconds,
          blockHeight: blockHeight,
        );
      }
    }
  }

  void _rememberLocalNodeTestResult(RpcNode node) {
    final testedAt = node.lastTestedAt;
    final latencyMs = node.lastLatencyMs;
    if (testedAt == null || latencyMs == null) {
      return;
    }
    _rememberNodeTestResult(
      node: node,
      status: node.lastTestStatus,
      testedAt: testedAt,
      latencyMs: latencyMs,
      blockHeight: node.lastBlockHeight,
    );
  }

  void _rememberNodeTestResult({
    required RpcNode node,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    required int latencyMs,
    int? blockHeight,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _localNodeTestCache[_nodeCacheKey(chain: chain, node: node)] =
          RpcNodeRuntimeTestCacheEntry(
        status: status,
        testedAt: testedAt,
        latencyMs: latencyMs,
        blockHeight: blockHeight,
      );
    });
  }

  void _setRefreshing(bool value) {
    setState(() {
      _isRefreshing = value;
    });
  }

  bool _needsRefresh(RpcNode node, DateTime now) {
    final lastTestedAt = node.lastTestedAt;
    if (lastTestedAt == null) {
      return true;
    }
    return now.difference(lastTestedAt) >= rpcNodeLatencyCacheTtl;
  }

  Future<void> _selectNode(WidgetRef ref, RpcNode node) async {
    final selectableNode = await _persistChainlistNodeIfNeeded(ref, node);
    await ref
        .read(rpcNodeRepositoryProvider)
        .selectNode(chain: chain, nodeId: selectableNode.id);
    ref.invalidate(rpcNodesForChainProvider(chain));
    ref.invalidate(selectedRpcNodeProvider(chain));
  }

  Future<void> _testNode(
    BuildContext context,
    WidgetRef ref,
    RpcNode node,
  ) async {
    try {
      final testableNode = await _persistChainlistNodeIfNeeded(ref, node);
      final tested = await ref
          .read(rpcNodeTestControllerProvider.notifier)
          .testNode(chain: chain, node: testableNode);
      _rememberLocalNodeTestResult(tested);
    } on AppError catch (error) {
      _forgetLocalNodeTestResult(node);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(const ErrorLocalizer().messageFor(error, t)),
        ),
      );
    } catch (_) {
      _forgetLocalNodeTestResult(node);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.errors.unknown)),
      );
    }
  }

  void _forgetLocalNodeTestResult(RpcNode node) {
    if (!mounted) {
      return;
    }
    setState(() {
      _localNodeTestCache.remove(_nodeCacheKey(chain: chain, node: node));
    });
  }

  Future<void> _confirmDeleteNode(
    BuildContext context,
    WidgetRef ref,
    RpcNode node,
  ) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.nodes.deleteTitle,
      content: Text(t.nodes.deleteMessage),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: t.nodes.confirmDelete,
      confirmVariant: AppDialogActionVariant.danger,
      confirmCallback: () => Navigator.of(context).pop(true),
    );

    if (confirmed != true) {
      return;
    }

    await _deleteNode(ref, node);
  }

  Future<void> _deleteNode(WidgetRef ref, RpcNode node) async {
    await ref
        .read(rpcNodeRepositoryProvider)
        .deleteNode(chain: chain, nodeId: node.id);
    ref.invalidate(rpcNodesForChainProvider(chain));
    ref.invalidate(selectedRpcNodeProvider(chain));
  }

  Future<RpcNode> _persistChainlistNodeIfNeeded(
    WidgetRef ref,
    RpcNode node,
  ) async {
    if (node.nodeType != RpcNodeType.chainlist) {
      return node;
    }
    final repository = ref.read(rpcNodeRepositoryProvider);
    final localNodes = await repository.getNodesForChain(chain);
    final existing = localNodes.where((localNode) {
      return localNode.chainId == chain.chainId &&
          localNode.url.trim() == node.url.trim();
    }).firstOrNull;
    if (existing != null) {
      return existing;
    }
    return repository.addCustomNode(
      chain: chain,
      name: node.name,
      url: node.url,
      note: node.note,
    );
  }
}

List<RpcNode> _mergeLocalAndChainlistNodes({
  required List<RpcNode> localNodes,
  required List<RpcNode> chainlistNodes,
}) {
  final seenUrls = localNodes.map((node) => node.url.trim()).toSet();
  final merged = [
    ...localNodes,
    for (final node in chainlistNodes)
      if (seenUrls.add(node.url.trim())) node,
  ];
  merged.sort(_compareVisibleNodes);
  return List.unmodifiable(merged);
}

List<RpcNode> _applyRuntimeTestCache({
  required ChainConfig chain,
  required List<RpcNode> nodes,
  required Map<String, RpcNodeRuntimeTestCacheEntry> cache,
}) {
  return nodes.map((node) {
    final cached = cache[_nodeCacheKey(chain: chain, node: node)];
    if (cached == null) {
      return node;
    }
    return RpcNode(
      id: node.id,
      chainId: node.chainId,
      name: node.name,
      url: node.url,
      nodeType: node.nodeType,
      isSelected: node.isSelected,
      lastTestStatus: cached.status,
      lastTestedAt: cached.testedAt,
      lastBlockHeight: cached.blockHeight,
      lastLatencyMs: cached.latencyMs,
      note: node.note,
      provider: node.provider,
      credentialMode: node.credentialMode,
      credentialParameter: node.credentialParameter,
      credentialRef: node.credentialRef,
      resolvedUrl: node.resolvedUrl,
      resolvedHeaders: node.resolvedHeaders,
    );
  }).toList(growable: false);
}

int _compareVisibleNodes(RpcNode left, RpcNode right) {
  if (left.isSelected != right.isSelected) {
    return left.isSelected ? -1 : 1;
  }
  final leftStatusSort = _statusSort(left.lastTestStatus);
  final rightStatusSort = _statusSort(right.lastTestStatus);
  if (leftStatusSort != rightStatusSort) {
    return leftStatusSort.compareTo(rightStatusSort);
  }
  final leftLatency = left.lastLatencyMs;
  final rightLatency = right.lastLatencyMs;
  if (leftLatency != null &&
      rightLatency != null &&
      leftLatency != rightLatency) {
    return leftLatency.compareTo(rightLatency);
  }
  if (leftLatency != null && rightLatency == null) {
    return -1;
  }
  if (leftLatency == null && rightLatency != null) {
    return 1;
  }
  final leftTypeSort = _nodeTypeSort(left.nodeType);
  final rightTypeSort = _nodeTypeSort(right.nodeType);
  if (leftTypeSort != rightTypeSort) {
    return leftTypeSort.compareTo(rightTypeSort);
  }
  return left.name.compareTo(right.name);
}

int _statusSort(RpcNodeTestStatus status) {
  return switch (status) {
    RpcNodeTestStatus.available => 0,
    RpcNodeTestStatus.untested => 1,
    RpcNodeTestStatus.testing => 2,
    RpcNodeTestStatus.unavailable => 3,
  };
}

int _nodeTypeSort(RpcNodeType nodeType) {
  return switch (nodeType) {
    RpcNodeType.defaultNode => 0,
    RpcNodeType.custom => 1,
    RpcNodeType.chainlist => 2,
  };
}

final class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.onSelect,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  final RpcNode node;
  final VoidCallback onSelect;
  final VoidCallback onTest;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final trackingLabel = _trackingLabel(node.note);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: AppRadius.largeBorder,
        border: Border.all(
          color: node.isSelected
              ? Theme.of(context).colorScheme.primary
              : context.appColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(node.name, style: context.appTextStyles.bodyLarge)),
                _NodeBadge(
                  label: _typeLabel(node.nodeType),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(node.displayUrl, style: context.appTextStyles.caption),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NodeBadge(label: _statusLabel(node.lastTestStatus)),
                if (node.provider != RpcProvider.public &&
                    node.provider != RpcProvider.custom)
                  _NodeBadge(label: _providerLabel(node.provider)),
                if (node.isSelected) _NodeBadge(label: t.nodes.selected),
                if (node.nodeType == RpcNodeType.chainlist &&
                    trackingLabel != null)
                  _NodeBadge(label: trackingLabel),
                if (node.lastBlockHeight != null)
                  _NodeBadge(label: _blockHeightLabel(node.lastBlockHeight!)),
                if (node.lastLatencyMs != null)
                  _NodeBadge(label: _latencyLabel(node.lastLatencyMs!)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  key: ValueKey('selectRpcNode:${node.id}'),
                  onPressed: node.isSelected ? null : onSelect,
                  icon: const Icon(AppIcons.checkCircle),
                  label: Text(t.nodes.select),
                ),
                TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(AppIcons.networkCheck),
                  label: Text(t.nodes.test),
                ),
                const Spacer(),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(AppIcons.edit),
                    tooltip: t.nodes.editNode,
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(AppIcons.delete),
                    tooltip: t.nodes.delete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(RpcNodeTestStatus status) {
    return switch (status) {
      RpcNodeTestStatus.untested => t.nodes.statusUntested,
      RpcNodeTestStatus.testing => t.nodes.statusTesting,
      RpcNodeTestStatus.available => t.nodes.statusAvailable,
      RpcNodeTestStatus.unavailable => t.nodes.statusUnavailable,
    };
  }

  String _typeLabel(RpcNodeType type) {
    return switch (type) {
      RpcNodeType.defaultNode => t.nodes.defaultNode,
      RpcNodeType.chainlist => t.nodes.chainlistNode,
      RpcNodeType.custom => t.nodes.customNode,
    };
  }

  String _providerLabel(RpcProvider provider) {
    return switch (provider) {
      RpcProvider.public => 'Public',
      RpcProvider.custom => t.nodes.customProvider,
      RpcProvider.helius => 'Helius',
      RpcProvider.quickNode => 'QuickNode',
      RpcProvider.alchemy => 'Alchemy',
      RpcProvider.infura => 'Infura',
      RpcProvider.tronGrid => 'TronGrid',
    };
  }

  String? _trackingLabel(String? note) {
    return switch (note) {
      'tracking:none' => t.nodes.trackingNone,
      'tracking:yes' => t.nodes.trackingYes,
      _ => null,
    };
  }

  String _blockHeightLabel(int height) {
    return '${t.nodes.blockHeightPrefix} $height';
  }

  String _latencyLabel(int latencyMs) {
    return '$latencyMs ${t.nodes.latencyMsSuffix}';
  }
}

final class _NodeBadge extends StatelessWidget {
  const _NodeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceSoft,
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: context.appTextStyles.caption),
      ),
    );
  }
}
