import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../../../shared/storage/storage_keys.dart';
import '../domain/chain_config.dart';
import 'chain_repository.dart';
import 'default_chains.dart';

final class HiveChainRepository
    implements ChainRepository, RemovableChainRepository {
  HiveChainRepository({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<List<ChainConfig>> getChains() async {
    await _ensureDefaultChains();
    final chains = _registry.chainsBox.values
        .whereType<String>()
        .map((value) => _codec.tryDecode(value, _chainFromJson))
        .whereType<ChainConfig>()
        .toList();
    chains.sort(_compareByDefaultOrder);
    return List.unmodifiable(chains);
  }

  @override
  Future<ChainConfig> getSelectedChain() async {
    final chains = await getChains();
    final selectedChainId =
        _registry.settingsBox.get(StorageKeys.selectedChainId) as String?;
    final selected = selectedChainId == null
        ? null
        : chains.where((chain) => chain.id == selectedChainId).firstOrNull;
    if (selected != null) {
      return selected;
    }

    final fallback = chains.firstWhere(
      (chain) => chain.chainType == ChainType.evm,
      orElse: () => chains.first,
    );
    await _registry.settingsBox.put(StorageKeys.selectedChainId, fallback.id);
    return fallback;
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    final chains = await getChains();
    final selected = chains.firstWhere((chain) => chain.id == chainId);
    await _registry.settingsBox.put(StorageKeys.selectedChainId, selected.id);
    return selected;
  }

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) async {
    final normalizedName = name.trim();
    final normalizedChainId = chainId.trim();
    final normalizedRpcUrl = rpcUrl.trim();
    final normalizedSymbol = symbol.trim().toUpperCase();
    final normalizedExplorerUrl = _blankToNull(blockExplorerUrl);
    _validateCustomEvmChain(
      name: normalizedName,
      chainId: normalizedChainId,
      rpcUrl: normalizedRpcUrl,
      symbol: normalizedSymbol,
      blockExplorerUrl: normalizedExplorerUrl,
    );
    final existing = await getChains();
    if (existing.any((chain) => chain.chainId == normalizedChainId)) {
      throw StateError('Chain ID already exists: $normalizedChainId');
    }

    final chain = ChainConfig(
      id: 'custom-evm-$normalizedChainId',
      chainType: ChainType.evm,
      name: normalizedName,
      chainId: normalizedChainId,
      symbol: normalizedSymbol,
      rpcUrls: const [],
      blockExplorerUrl: normalizedExplorerUrl,
      isTestnet: isTestnet,
    );
    await _registry.chainsBox.put(chain.id, _codec.encode(_chainToJson(chain)));
    return chain;
  }

  @override
  Future<void> deleteChain(String chainId) async {
    if (defaultChains.any((chain) => chain.id == chainId)) {
      throw StateError('Default chains cannot be deleted');
    }
    final chains = await getChains();
    if (!chains.any((chain) => chain.id == chainId)) {
      return;
    }

    await _registry.chainsBox.delete(chainId);
    final selectedChainId =
        _registry.settingsBox.get(StorageKeys.selectedChainId) as String?;
    if (selectedChainId == chainId) {
      await _registry.settingsBox.put(
        StorageKeys.selectedChainId,
        defaultChains.first.id,
      );
    }
  }

  Future<void> _ensureDefaultChains() async {
    for (final chain in defaultChains) {
      if (!_registry.chainsBox.containsKey(chain.id)) {
        await _registry.chainsBox.put(
          chain.id,
          _codec.encode(_chainToJson(chain)),
        );
      }
    }
  }

  int _compareByDefaultOrder(ChainConfig left, ChainConfig right) {
    return _defaultOrder(left.id).compareTo(_defaultOrder(right.id));
  }

  int _defaultOrder(String chainId) {
    final index = defaultChains.indexWhere((chain) => chain.id == chainId);
    return index == -1 ? defaultChains.length : index;
  }

  Map<String, Object?> _chainToJson(ChainConfig chain) {
    return {
      'id': chain.id,
      'chainType': chain.chainType.name,
      'name': chain.name,
      'chainId': chain.chainId,
      'symbol': chain.symbol,
      'rpcUrls': chain.rpcUrls,
      'blockExplorerUrl': chain.blockExplorerUrl,
      'isTestnet': chain.isTestnet,
    };
  }

  ChainConfig _chainFromJson(Map<String, Object?> json) {
    return ChainConfig(
      id: json['id'] as String,
      chainType: ChainType.values.byName(json['chainType'] as String),
      name: json['name'] as String,
      chainId: json['chainId'] as String,
      symbol: json['symbol'] as String,
      rpcUrls: (json['rpcUrls'] as List).cast<String>(),
      blockExplorerUrl: json['blockExplorerUrl'] as String?,
      isTestnet: json['isTestnet'] as bool,
    );
  }

  void _validateCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    required String? blockExplorerUrl,
  }) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final numericChainId = int.tryParse(chainId);
    if (numericChainId == null || numericChainId <= 0) {
      throw ArgumentError.value(chainId, 'chainId', 'must be positive');
    }
    if (!_isValidHttpUrl(rpcUrl)) {
      throw ArgumentError.value(rpcUrl, 'rpcUrl', 'invalid URL');
    }
    if (symbol.isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'must not be empty');
    }
    if (blockExplorerUrl != null && !_isValidHttpUrl(blockExplorerUrl)) {
      throw ArgumentError.value(
        blockExplorerUrl,
        'blockExplorerUrl',
        'invalid URL',
      );
    }
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
