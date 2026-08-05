import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../domain/token_info.dart';
import 'token_repository.dart';

final class HiveTokenRepository implements TokenRepository {
  HiveTokenRepository({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<List<TokenInfo>> getTokens({
    required String chainId,
    bool includeHidden = false,
  }) async {
    await _ensureBuiltIns(chainId);
    final tokens =
        _storedTokens()
            .where((token) => token.chainId == chainId)
            .where((token) => includeHidden || !token.isHidden)
            .toList()
          ..sort(_compareTokens);
    return List.unmodifiable(tokens);
  }

  @override
  Future<TokenInfo> saveToken(TokenInfo token) async {
    _validateToken(token);
    final normalized = _normalizeToken(token);
    final existing = await _tokenByKey(_tokenKey(normalized));
    final tokenToSave = existing != null && existing.isHidden
        ? _withHidden(normalized, isHidden: true)
        : normalized;
    await _putToken(tokenToSave);
    return tokenToSave;
  }

  void _validateToken(TokenInfo token) {
    if (token.contractAddress == null || token.contractAddress!.isEmpty) {
      throw ArgumentError.value(
        token.contractAddress,
        'contractAddress',
        'must not be empty',
      );
    }
    if (token.name.trim().isEmpty || token.symbol.trim().isEmpty) {
      throw ArgumentError('Token metadata must include name and symbol');
    }
    if (token.decimals < 0) {
      throw ArgumentError.value(token.decimals, 'decimals', 'must be positive');
    }
  }

  @override
  Future<void> hideToken({
    required String chainId,
    required String contractAddress,
  }) async {
    await _setHidden(
      chainId: chainId,
      contractAddress: contractAddress,
      isHidden: true,
    );
  }

  @override
  Future<void> unhideToken({
    required String chainId,
    required String contractAddress,
  }) async {
    await _setHidden(
      chainId: chainId,
      contractAddress: contractAddress,
      isHidden: false,
    );
  }

  @override
  Future<int?> getLastScannedBlock({
    required String chainId,
    required String walletAddress,
  }) async {
    return _registry.settingsBox.get(
          _lastScannedBlockKey(chainId: chainId, walletAddress: walletAddress),
        )
        as int?;
  }

  @override
  Future<void> setLastScannedBlock({
    required String chainId,
    required String walletAddress,
    required int blockNumber,
  }) async {
    await _registry.settingsBox.put(
      _lastScannedBlockKey(chainId: chainId, walletAddress: walletAddress),
      blockNumber,
    );
  }

  Future<void> _ensureBuiltIns(String chainId) async {
    for (final token in builtInTokens.where(
      (token) => token.chainId == chainId,
    )) {
      final key = _tokenKey(token);
      final existing = await _tokenByKey(key);
      if (existing == null) {
        await _putToken(token);
        continue;
      }
      if (existing.source == TokenSource.userAdded) {
        continue;
      }
      final refreshed = _withBuiltInMetadata(stored: existing, builtIn: token);
      if (refreshed != existing) {
        await _putToken(refreshed);
      }
    }
  }

  Future<void> _setHidden({
    required String chainId,
    required String contractAddress,
    required bool isHidden,
  }) async {
    await _ensureBuiltIns(chainId);
    final key = _tokenKeyParts(
      chainId: chainId,
      contractAddress: contractAddress,
    );
    final token = await _tokenByKey(key);
    if (token == null) {
      return;
    }
    await _putToken(_withHidden(token, isHidden: isHidden));
  }

  Future<TokenInfo?> _tokenByKey(String key) async {
    final rawValue = _registry.tokensBox.get(key);
    if (rawValue is! String) {
      return null;
    }
    return _codec.tryDecode(rawValue, _tokenFromJson);
  }

  List<TokenInfo> _storedTokens() {
    return _registry.tokensBox.values
        .whereType<String>()
        .map((value) => _codec.tryDecode(value, _tokenFromJson))
        .whereType<TokenInfo>()
        .toList();
  }

  Future<void> _putToken(TokenInfo token) async {
    await _registry.tokensBox.put(
      _tokenKey(token),
      _codec.encode(_tokenToJson(token)),
    );
  }

  int _compareTokens(TokenInfo left, TokenInfo right) {
    final sourceCompare = left.source.index.compareTo(right.source.index);
    if (sourceCompare != 0) {
      return sourceCompare;
    }
    return left.symbol.compareTo(right.symbol);
  }

  TokenInfo _normalizeToken(TokenInfo token) {
    final contractAddress = token.contractAddress?.toLowerCase();
    return TokenInfo(
      chainId: token.chainId,
      contractAddress: contractAddress,
      symbol: token.symbol,
      name: token.name,
      decimals: token.decimals,
      source: token.source,
      isHidden: token.isHidden,
      logoUri: token.logoUri,
      requiresMemo: token.requiresMemo,
      memoLabel: token.memoLabel,
    );
  }

  TokenInfo _withHidden(TokenInfo token, {required bool isHidden}) {
    return TokenInfo(
      chainId: token.chainId,
      contractAddress: token.contractAddress,
      symbol: token.symbol,
      name: token.name,
      decimals: token.decimals,
      source: token.source,
      isHidden: isHidden,
      logoUri: token.logoUri,
      requiresMemo: token.requiresMemo,
      memoLabel: token.memoLabel,
    );
  }

  TokenInfo _withBuiltInMetadata({
    required TokenInfo stored,
    required TokenInfo builtIn,
  }) {
    return TokenInfo(
      chainId: builtIn.chainId,
      contractAddress: builtIn.contractAddress,
      symbol: builtIn.symbol,
      name: builtIn.name,
      decimals: builtIn.decimals,
      source: TokenSource.builtIn,
      isHidden: stored.isHidden,
      logoUri: builtIn.logoUri,
      requiresMemo: builtIn.requiresMemo,
      memoLabel: builtIn.memoLabel,
    );
  }

  Map<String, Object?> _tokenToJson(TokenInfo token) {
    return {
      'chainId': token.chainId,
      'contractAddress': token.contractAddress,
      'symbol': token.symbol,
      'name': token.name,
      'decimals': token.decimals,
      'source': token.source.name,
      'isHidden': token.isHidden,
      'logoUri': token.logoUri,
      'requiresMemo': token.requiresMemo,
      'memoLabel': token.memoLabel,
    };
  }

  TokenInfo _tokenFromJson(Map<String, Object?> json) {
    return TokenInfo(
      chainId: json['chainId'] as String,
      contractAddress: json['contractAddress'] as String?,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      decimals: json['decimals'] as int,
      source: TokenSource.values.byName(json['source'] as String),
      isHidden: json['isHidden'] as bool,
      logoUri: json['logoUri'] as String?,
      requiresMemo: json['requiresMemo'] == true,
      memoLabel: json['memoLabel'] as String?,
    );
  }

  String _tokenKey(TokenInfo token) {
    return _tokenKeyParts(
      chainId: token.chainId,
      contractAddress: token.contractAddress,
    );
  }

  String _tokenKeyParts({
    required String chainId,
    required String? contractAddress,
  }) {
    return '$chainId:${contractAddress?.toLowerCase() ?? 'native'}';
  }

  String _lastScannedBlockKey({
    required String chainId,
    required String walletAddress,
  }) {
    return 'tokenDiscovery.lastScannedBlock.$chainId.${walletAddress.toLowerCase()}';
  }
}
