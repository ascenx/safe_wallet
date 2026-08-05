import 'dart:math' as math;

import '../../chains/domain/chain_config.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../wallet/domain/wallet_account.dart';
import '../domain/asset_balance.dart';
import '../domain/token_info.dart';
import 'asset_market_data_repository.dart';
import 'bitcoin_asset_service.dart';
import 'evm_asset_service.dart';
import 'solana_asset_service.dart';
import 'sui_asset_service.dart';
import 'token_balance_store.dart';
import 'token_logo_uris.dart';
import 'token_price_repository.dart';
import 'token_universe_repository.dart';
import 'tron_asset_service.dart';

abstract interface class AssetRepository {
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  });
}

abstract interface class CachedAssetRepository implements AssetRepository {
  Future<CachedAssetPortfolio?> loadCachedPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    List<TokenInfo> tokens = const [],
  });
}

final class CachedAssetPortfolio {
  const CachedAssetPortfolio({required this.portfolio, required this.isFresh});

  final AssetPortfolio portfolio;
  final bool isFresh;
}

final class _LoadedAssetBalances {
  const _LoadedAssetBalances({
    required this.displayBalances,
    required this.cacheBalances,
  });

  final List<AssetBalance> displayBalances;
  final List<AssetBalance> cacheBalances;
}

enum AssetPortfolioStatus { locked, loading, empty, error, loaded }

final class AssetPortfolio {
  const AssetPortfolio._({
    required this.status,
    this.balances = const [],
    this.errorMessage,
    this.account,
  });

  factory AssetPortfolio.locked({WalletAccount? account}) {
    return AssetPortfolio._(
      status: AssetPortfolioStatus.locked,
      account: account,
    );
  }

  factory AssetPortfolio.loading({WalletAccount? account}) {
    return AssetPortfolio._(
      status: AssetPortfolioStatus.loading,
      account: account,
    );
  }

  factory AssetPortfolio.empty({WalletAccount? account}) {
    return AssetPortfolio._(
      status: AssetPortfolioStatus.empty,
      account: account,
    );
  }

  factory AssetPortfolio.error(String message, {WalletAccount? account}) {
    return AssetPortfolio._(
      status: AssetPortfolioStatus.error,
      errorMessage: message,
      account: account,
    );
  }

  factory AssetPortfolio.loaded(
    List<AssetBalance> balances, {
    WalletAccount? account,
  }) {
    if (balances.isEmpty) {
      return AssetPortfolio.empty(account: account);
    }
    return AssetPortfolio._(
      status: AssetPortfolioStatus.loaded,
      balances: List.unmodifiable(_sortedBalances(balances)),
      account: account,
    );
  }

  final AssetPortfolioStatus status;
  final List<AssetBalance> balances;
  final String? errorMessage;
  final WalletAccount? account;
}

List<AssetBalance> _sortedBalances(List<AssetBalance> balances) {
  final indexedBalances = balances.indexed.toList();
  indexedBalances.sort((left, right) {
    final leftNative = left.$2.token.contractAddress == null;
    final rightNative = right.$2.token.contractAddress == null;
    if (leftNative != rightNative) {
      return leftNative ? -1 : 1;
    }
    if (leftNative && rightNative) {
      return left.$1.compareTo(right.$1);
    }

    final leftHasBalance = _hasPositiveBalance(left.$2);
    final rightHasBalance = _hasPositiveBalance(right.$2);
    if (leftHasBalance != rightHasBalance) {
      return leftHasBalance ? -1 : 1;
    }
    return left.$1.compareTo(right.$1);
  });
  return indexedBalances.map((entry) => entry.$2).toList(growable: false);
}

bool _hasPositiveBalance(AssetBalance balance) {
  final rawBalance = BigInt.tryParse(balance.balance ?? '');
  return rawBalance != null && rawBalance > BigInt.zero;
}

final class DefaultAssetRepository implements CachedAssetRepository {
  DefaultAssetRepository({
    EvmAssetService evmAssetService = const Web3EvmAssetService(),
    BitcoinAssetService? bitcoinAssetService,
    SolanaAssetService? solanaAssetService,
    SuiAssetService? suiAssetService,
    TronAssetService? tronAssetService,
    TokenPriceRepository priceRepository = const NoopTokenPriceRepository(),
    TokenBalanceStore balanceStore = const NoopTokenBalanceStore(),
    TokenUniverseRepository tokenUniverseRepository =
        const JsonTokenUniverseRepository(),
    AssetMarketDataRepository? marketDataRepository,
    Duration balanceCacheTtl = const Duration(minutes: 1),
    int tokenBatchSize = 20,
    DateTime Function()? now,
  }) : _evmAssetService = evmAssetService,
       _bitcoinAssetService = bitcoinAssetService,
       _solanaAssetService = solanaAssetService,
       _suiAssetService = suiAssetService,
       _tronAssetService = tronAssetService,
       _priceRepository = priceRepository,
       _balanceStore = balanceStore,
       _tokenUniverseRepository = tokenUniverseRepository,
       _marketDataRepository = marketDataRepository,
       _balanceCacheTtl = balanceCacheTtl,
       _tokenBatchSize = tokenBatchSize,
       _now = now ?? DateTime.now;

  final EvmAssetService _evmAssetService;
  final BitcoinAssetService? _bitcoinAssetService;
  final SolanaAssetService? _solanaAssetService;
  final SuiAssetService? _suiAssetService;
  final TronAssetService? _tronAssetService;
  final TokenPriceRepository _priceRepository;
  final TokenBalanceStore _balanceStore;
  final TokenUniverseRepository _tokenUniverseRepository;
  final AssetMarketDataRepository? _marketDataRepository;
  final Duration _balanceCacheTtl;
  final int _tokenBatchSize;
  final DateTime Function() _now;

  SolanaAssetService? _ownedSolanaAssetService;
  SuiAssetService? _ownedSuiAssetService;
  BitcoinAssetService? _ownedBitcoinAssetService;
  TronAssetService? _ownedTronAssetService;

  SolanaAssetService get _solana =>
      _solanaAssetService ??
      (_ownedSolanaAssetService ??= HttpSolanaAssetService());
  SuiAssetService get _sui =>
      _suiAssetService ?? (_ownedSuiAssetService ??= GrpcSuiAssetService());
  BitcoinAssetService get _bitcoin =>
      _bitcoinAssetService ??
      (_ownedBitcoinAssetService ??= HttpBitcoinAssetService());
  TronAssetService get _tron =>
      _tronAssetService ?? (_ownedTronAssetService ??= HttpTronAssetService());

  Future<void> close() async {
    final solana = _ownedSolanaAssetService;
    _ownedSolanaAssetService = null;
    if (solana is HttpSolanaAssetService) {
      solana.close();
    }
    final sui = _ownedSuiAssetService;
    _ownedSuiAssetService = null;
    if (sui is GrpcSuiAssetService) {
      await sui.close();
    } else if (sui is HttpSuiAssetService) {
      sui.close();
    }
    final bitcoin = _ownedBitcoinAssetService;
    _ownedBitcoinAssetService = null;
    if (bitcoin is HttpBitcoinAssetService) {
      bitcoin.close();
    }
    final tron = _ownedTronAssetService;
    _ownedTronAssetService = null;
    if (tron is HttpTronAssetService) {
      tron.close();
    }
  }

  @override
  Future<AssetPortfolio> loadPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    List<TokenInfo> tokens = const [],
  }) async {
    final walletAddress = _walletAddressFor(account: account, chain: chain);
    if (walletAddress.trim().isEmpty) {
      return AssetPortfolio.empty(account: account);
    }
    try {
      final loadedBalances = switch (chain.chainType) {
        ChainType.evm => await _loadEvmBalances(
          account: account,
          chain: chain,
          rpcNode: rpcNode,
          tokens: tokens,
        ),
        ChainType.bitcoin => await _loadBitcoinBalances(
          account: account,
          chain: chain,
          rpcNode: rpcNode,
        ),
        ChainType.tron => await _loadTronBalances(
          account: account,
          chain: chain,
          rpcNode: rpcNode,
          tokens: tokens,
        ),
        ChainType.solana => await _loadSolanaBalances(
          account: account,
          chain: chain,
          rpcNode: rpcNode,
          tokens: tokens,
        ),
        ChainType.sui => await _loadSuiBalances(
          account: account,
          chain: chain,
          rpcNode: rpcNode,
          tokens: tokens,
        ),
      };
      await _cacheBalances(
        account: account,
        chain: chain,
        balances: loadedBalances.cacheBalances,
      );
      return AssetPortfolio.loaded(
        await _attachFiatValues(
          chain: chain,
          balances: loadedBalances.displayBalances,
        ),
        account: account,
      );
    } catch (error) {
      return AssetPortfolio.error(error.toString(), account: account);
    }
  }

  @override
  Future<CachedAssetPortfolio?> loadCachedPortfolio({
    required WalletAccount account,
    required ChainConfig chain,
    List<TokenInfo> tokens = const [],
  }) async {
    final walletAddress = _walletAddressFor(account: account, chain: chain);
    if (walletAddress.trim().isEmpty) {
      return null;
    }
    final tokenList = await _portfolioTokens(chain: chain, tokens: tokens);
    final visibleTokenKeys = _visibleContractTokens(
      chain: chain,
      tokens: tokens,
    ).map((token) => _contractTokenKey(chain: chain, token: token)).toSet();
    final keysByToken = {
      for (final token in tokenList)
        tokenBalanceKey(
          chain: chain,
          walletAddress: walletAddress,
          token: token,
        ): token,
    };
    final cachedEntries = await _balanceStore.getAll(keysByToken.keys);
    if (cachedEntries.isEmpty) {
      return null;
    }
    final balances = <AssetBalance>[];
    for (final entry in cachedEntries.entries) {
      final token = keysByToken[entry.key];
      if (token == null) {
        continue;
      }
      final tokenKey = _contractTokenKey(chain: chain, token: token);
      final isVisibleToken =
          token.contractAddress == null || visibleTokenKeys.contains(tokenKey);
      if (!isVisibleToken && !_hasPositiveRawBalance(entry.value.rawBalance)) {
        continue;
      }
      balances.add(
        AssetBalance(
          chainId: chain.chainId,
          token: token,
          balance: entry.value.rawBalance,
          formattedBalance: entry.value.formattedBalance,
          status: AssetBalanceStatus.loaded,
        ),
      );
    }
    if (balances.isEmpty) {
      return null;
    }
    final now = _now();
    final allExpectedBalancesCached = cachedEntries.length == tokenList.length;
    final allCachedBalancesFresh = cachedEntries.values.every(
      (entry) => entry.expiresAt.isAfter(now),
    );
    return CachedAssetPortfolio(
      portfolio: AssetPortfolio.loaded(
        await _attachCachedFiatValues(chain: chain, balances: balances),
        account: account,
      ),
      isFresh: allExpectedBalancesCached && allCachedBalancesFresh,
    );
  }

  Future<_LoadedAssetBalances> _loadEvmBalances({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    required List<TokenInfo> tokens,
  }) async {
    final nativeBalance = await _evmAssetService.getNativeBalance(
      rpcUrl: rpcNode.endpointUrl,
      walletAddress: account.evmAddress,
      headers: rpcNode.endpointHeaders,
    );
    final nativeAssetBalance = _balanceFor(
      chain: chain,
      token: TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: 18,
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: nativeTokenLogoUri(chain.chainId),
      ),
      rawBalance: nativeBalance,
    );
    final visibleTokens = _visibleContractTokens(
      chain: chain,
      tokens: tokens,
    ).toList(growable: false);
    final visibleTokenKeys = visibleTokens
        .map((token) => _contractTokenKey(chain: chain, token: token))
        .toSet();
    final queryTokens = await _queryContractTokens(
      chain: chain,
      tokens: tokens,
      visibleTokens: visibleTokens,
    );

    final rawBalances = <String, BigInt>{};
    for (final chunk in _chunks(queryTokens, _tokenBatchSize)) {
      final chunkBalances = await _evmAssetService.getErc20Balances(
        rpcUrl: rpcNode.endpointUrl,
        contractAddresses: chunk
            .map((token) => token.contractAddress!)
            .toList(growable: false),
        walletAddress: account.evmAddress,
        headers: rpcNode.endpointHeaders,
      );
      rawBalances.addAll(chunkBalances);
    }

    final displayBalances = <AssetBalance>[nativeAssetBalance];
    final cacheBalances = <AssetBalance>[nativeAssetBalance];
    for (final token in queryTokens) {
      final tokenKey = _contractTokenKey(chain: chain, token: token);
      final rawBalance = rawBalances[tokenKey] ?? BigInt.zero;
      final balance = _balanceFor(
        chain: chain,
        token: token,
        rawBalance: rawBalance,
      );
      cacheBalances.add(balance);
      if (visibleTokenKeys.contains(tokenKey) || rawBalance > BigInt.zero) {
        displayBalances.add(balance);
      }
    }
    return _LoadedAssetBalances(
      displayBalances: displayBalances,
      cacheBalances: cacheBalances,
    );
  }

  Future<void> _cacheBalances({
    required WalletAccount account,
    required ChainConfig chain,
    required List<AssetBalance> balances,
  }) async {
    final walletAddress = _walletAddressFor(account: account, chain: chain);
    if (walletAddress.trim().isEmpty || balances.isEmpty) {
      return;
    }
    final now = _now().toUtc();
    await _balanceStore.putAll({
      for (final balance in balances)
        tokenBalanceKey(
          chain: chain,
          walletAddress: walletAddress,
          token: balance.token,
        ): TokenBalanceCacheEntry(
          rawBalance: balance.balance ?? '0',
          formattedBalance: balance.formattedBalance ?? '--',
          updatedAt: now,
          expiresAt: now.add(_balanceCacheTtl),
        ),
    });
  }

  Future<_LoadedAssetBalances> _loadBitcoinBalances({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
  }) async {
    final nativeBalance = await _bitcoin.getBtcBalance(
      apiBaseUrl: rpcNode.endpointUrl,
      walletAddress: account.btcAddress,
      headers: rpcNode.endpointHeaders,
    );
    final nativeAssetBalance = _balanceFor(
      chain: chain,
      token: TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: 8,
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: nativeTokenLogoUri(chain.chainId),
      ),
      rawBalance: nativeBalance,
    );
    return _LoadedAssetBalances(
      displayBalances: [nativeAssetBalance],
      cacheBalances: [nativeAssetBalance],
    );
  }

  Future<_LoadedAssetBalances> _loadTronBalances({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    required List<TokenInfo> tokens,
  }) async {
    final nativeBalance = await _tron.getTrxBalance(
      apiBaseUrl: rpcNode.endpointUrl,
      walletAddress: account.tronAddress,
      headers: rpcNode.endpointHeaders,
    );
    final nativeAssetBalance = _balanceFor(
      chain: chain,
      token: TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: 6,
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: nativeTokenLogoUri(chain.chainId),
      ),
      rawBalance: nativeBalance,
    );
    final visibleTokens = _visibleContractTokens(
      chain: chain,
      tokens: tokens,
    ).toList(growable: false);
    final visibleTokenKeys = visibleTokens
        .map((token) => _contractTokenKey(chain: chain, token: token))
        .toSet();
    final queryTokens = await _queryContractTokens(
      chain: chain,
      tokens: tokens,
      visibleTokens: visibleTokens,
    );

    final rawBalances = <String, BigInt>{};
    for (final chunk in _chunks(queryTokens, _tokenBatchSize)) {
      final chunkBalances = await _tron.getTrc20Balances(
        apiBaseUrl: rpcNode.endpointUrl,
        contractAddresses: chunk
            .map((token) => token.contractAddress!)
            .toList(growable: false),
        walletAddress: account.tronAddress,
        headers: rpcNode.endpointHeaders,
      );
      rawBalances.addAll(chunkBalances);
    }

    final displayBalances = <AssetBalance>[nativeAssetBalance];
    final cacheBalances = <AssetBalance>[nativeAssetBalance];
    for (final token in queryTokens) {
      final tokenKey = _contractTokenKey(chain: chain, token: token);
      final rawBalance = rawBalances[tokenKey] ?? BigInt.zero;
      final balance = _balanceFor(
        chain: chain,
        token: token,
        rawBalance: rawBalance,
      );
      cacheBalances.add(balance);
      if (visibleTokenKeys.contains(tokenKey) || rawBalance > BigInt.zero) {
        displayBalances.add(balance);
      }
    }
    return _LoadedAssetBalances(
      displayBalances: displayBalances,
      cacheBalances: cacheBalances,
    );
  }

  Future<_LoadedAssetBalances> _loadSolanaBalances({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    required List<TokenInfo> tokens,
  }) async {
    final solBalance = await _solana.getSolBalance(
      rpcUrl: rpcNode.endpointUrl,
      walletAddress: account.solanaAddress,
      headers: rpcNode.endpointHeaders,
    );
    final nativeAssetBalance = _balanceFor(
      chain: chain,
      token: TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: 9,
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: nativeTokenLogoUri(chain.chainId),
      ),
      rawBalance: solBalance,
    );
    final visibleTokens = _visibleContractTokens(
      chain: chain,
      tokens: tokens,
    ).toList(growable: false);
    final visibleTokenKeys = visibleTokens
        .map((token) => _contractTokenKey(chain: chain, token: token))
        .toSet();
    final metadataTokens = await _queryContractTokens(
      chain: chain,
      tokens: tokens,
      visibleTokens: visibleTokens,
    );
    final metadataByKey = {
      for (final token in metadataTokens)
        _contractTokenKey(chain: chain, token: token): token,
    };
    final hiddenTokenKeys = _hiddenContractTokenKeys(
      chain: chain,
      tokens: tokens,
    );

    final ownerTokenBalances = await _solana.getTokenBalancesByOwner(
      rpcUrl: rpcNode.endpointUrl,
      ownerAddress: account.solanaAddress,
      headers: rpcNode.endpointHeaders,
    );
    final rawBalancesByMint = {
      for (final balance in ownerTokenBalances)
        _contractAddressKey(chain: chain, address: balance.mintAddress):
            balance,
    };
    final discoveredMetadataByKey = await _queryUnknownSolanaTokenMetadata(
      chain: chain,
      tokenBalances: ownerTokenBalances,
      excludedTokenKeys: {...metadataByKey.keys, ...hiddenTokenKeys},
    );

    final displayBalances = <AssetBalance>[nativeAssetBalance];
    final cacheBalances = <AssetBalance>[nativeAssetBalance];
    for (final token in visibleTokens) {
      final tokenKey = _contractTokenKey(chain: chain, token: token);
      final tokenBalance = rawBalancesByMint[tokenKey];
      final balance = _balanceFor(
        chain: chain,
        token: token,
        rawBalance: tokenBalance?.rawBalance ?? BigInt.zero,
      );
      displayBalances.add(balance);
      cacheBalances.add(balance);
    }

    for (final tokenBalance in ownerTokenBalances) {
      final tokenKey = _contractAddressKey(
        chain: chain,
        address: tokenBalance.mintAddress,
      );
      if (visibleTokenKeys.contains(tokenKey) ||
          hiddenTokenKeys.contains(tokenKey)) {
        continue;
      }
      final token =
          metadataByKey[tokenKey] ??
          discoveredMetadataByKey[tokenKey] ??
          _unknownSolanaToken(chain: chain, tokenBalance: tokenBalance);
      final balance = _balanceFor(
        chain: chain,
        token: token,
        rawBalance: tokenBalance.rawBalance,
      );
      cacheBalances.add(balance);
      if (tokenBalance.rawBalance > BigInt.zero) {
        displayBalances.add(balance);
      }
    }
    return _LoadedAssetBalances(
      displayBalances: displayBalances,
      cacheBalances: cacheBalances,
    );
  }

  Future<_LoadedAssetBalances> _loadSuiBalances({
    required WalletAccount account,
    required ChainConfig chain,
    required RpcNode rpcNode,
    required List<TokenInfo> tokens,
  }) async {
    final nativeBalance = await _sui.getBalance(
      rpcUrl: rpcNode.endpointUrl,
      owner: account.suiAddress,
      headers: rpcNode.endpointHeaders,
    );
    final nativeAssetBalance = _balanceFor(
      chain: chain,
      token: TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: 9,
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: nativeTokenLogoUri(chain.chainId),
      ),
      rawBalance: nativeBalance.totalBalance,
    );
    final configuredTokens = {
      for (final token in tokens)
        if (token.chainId == chain.chainId && token.contractAddress != null)
          token.contractAddress!: token,
    };
    final allBalances = await _sui.getAllBalances(
      rpcUrl: rpcNode.endpointUrl,
      owner: account.suiAddress,
      headers: rpcNode.endpointHeaders,
    );
    final balancesByType = {
      for (final balance in allBalances)
        if (!isSuiNativeCoinType(balance.coinType))
          balance.coinType: balance.totalBalance,
    };

    final displayBalances = <AssetBalance>[nativeAssetBalance];
    final cacheBalances = <AssetBalance>[nativeAssetBalance];
    for (final entry in balancesByType.entries) {
      final configured = configuredTokens[entry.key];
      final token =
          configured ??
          await _suiTokenInfo(
            chain: chain,
            rpcNode: rpcNode,
            coinType: entry.key,
          );
      final balance = _balanceFor(
        chain: chain,
        token: token,
        rawBalance: entry.value,
      );
      cacheBalances.add(balance);
      if (!token.isHidden && entry.value > BigInt.zero) {
        displayBalances.add(balance);
      }
    }
    for (final configured in configuredTokens.values) {
      final coinType = configured.contractAddress!;
      if (balancesByType.containsKey(coinType) || configured.isHidden) {
        continue;
      }
      final balance = _balanceFor(
        chain: chain,
        token: configured,
        rawBalance: BigInt.zero,
      );
      displayBalances.add(balance);
      cacheBalances.add(balance);
    }
    return _LoadedAssetBalances(
      displayBalances: displayBalances,
      cacheBalances: cacheBalances,
    );
  }

  Future<TokenInfo> _suiTokenInfo({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required String coinType,
  }) async {
    SuiCoinMetadata? metadata;
    try {
      metadata = await _sui.getCoinMetadata(
        rpcUrl: rpcNode.endpointUrl,
        coinType: coinType,
        headers: rpcNode.endpointHeaders,
      );
    } catch (_) {
      metadata = null;
    }
    return TokenInfo(
      chainId: chain.chainId,
      contractAddress: coinType,
      symbol: metadata?.symbol ?? _suiCoinSymbol(coinType),
      name: metadata?.name ?? coinType,
      decimals: metadata?.decimals ?? 0,
      source: TokenSource.discovered,
      isHidden: false,
      logoUri: metadata?.iconUrl,
    );
  }

  Iterable<TokenInfo> _visibleContractTokens({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) {
    return tokens.where(
      (token) =>
          token.chainId == chain.chainId &&
          !token.isHidden &&
          token.contractAddress != null,
    );
  }

  Set<String> _hiddenContractTokenKeys({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) {
    return tokens
        .where(
          (token) =>
              token.chainId == chain.chainId &&
              token.isHidden &&
              token.contractAddress != null,
        )
        .map((token) => _contractTokenKey(chain: chain, token: token))
        .toSet();
  }

  Future<List<TokenInfo>> _queryContractTokens({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
    required List<TokenInfo> visibleTokens,
  }) async {
    final hiddenTokenKeys = _hiddenContractTokenKeys(
      chain: chain,
      tokens: tokens,
    );
    final universeTokens = await _tokenUniverseRepository.getTopTokens(
      chain: chain,
      limit: 100,
    );
    final merged = <String, TokenInfo>{};
    for (final token in [
      ...visibleTokens,
      ...universeTokens.where((token) {
        final contractAddress = token.contractAddress;
        if (contractAddress == null) {
          return false;
        }
        return !hiddenTokenKeys.contains(
          _contractAddressKey(chain: chain, address: contractAddress),
        );
      }),
    ]) {
      final tokenKey = _contractTokenKey(chain: chain, token: token);
      merged.putIfAbsent(tokenKey, () => token);
    }
    return merged.values.toList(growable: false);
  }

  String _contractTokenKey({
    required ChainConfig chain,
    required TokenInfo token,
  }) {
    final contractAddress = token.contractAddress;
    if (contractAddress == null) {
      return 'native';
    }
    return _contractAddressKey(chain: chain, address: contractAddress);
  }

  String _contractAddressKey({
    required ChainConfig chain,
    required String address,
  }) {
    return chain.chainType == ChainType.evm ? address.toLowerCase() : address;
  }

  TokenInfo _unknownSolanaToken({
    required ChainConfig chain,
    required SolanaTokenBalance tokenBalance,
  }) {
    return TokenInfo(
      chainId: chain.chainId,
      contractAddress: tokenBalance.mintAddress,
      symbol: _shortAddress(tokenBalance.mintAddress),
      name: tokenBalance.mintAddress,
      decimals: tokenBalance.decimals,
      source: TokenSource.discovered,
      isHidden: false,
    );
  }

  Future<Map<String, TokenInfo>> _queryUnknownSolanaTokenMetadata({
    required ChainConfig chain,
    required List<SolanaTokenBalance> tokenBalances,
    required Set<String> excludedTokenKeys,
  }) async {
    final repository = _marketDataRepository;
    if (repository == null) {
      return const {};
    }
    final candidates = tokenBalances
        .where((tokenBalance) {
          if (tokenBalance.rawBalance <= BigInt.zero) {
            return false;
          }
          final tokenKey = _contractAddressKey(
            chain: chain,
            address: tokenBalance.mintAddress,
          );
          return !excludedTokenKeys.contains(tokenKey);
        })
        .toList(growable: false);
    final resolved = <String, TokenInfo>{};
    for (final chunk in _chunks(candidates, _tokenBatchSize)) {
      final entries = await Future.wait(
        chunk.map((tokenBalance) async {
          final token = await _resolveUnknownSolanaToken(
            chain: chain,
            tokenBalance: tokenBalance,
            repository: repository,
          );
          return MapEntry(
            _contractAddressKey(
              chain: chain,
              address: tokenBalance.mintAddress,
            ),
            token,
          );
        }),
      );
      resolved.addEntries(entries);
    }
    return resolved;
  }

  Future<TokenInfo> _resolveUnknownSolanaToken({
    required ChainConfig chain,
    required SolanaTokenBalance tokenBalance,
    required AssetMarketDataRepository repository,
  }) async {
    final fallback = _unknownSolanaToken(
      chain: chain,
      tokenBalance: tokenBalance,
    );
    try {
      final marketData = await repository.getMarketData(
        chain: chain,
        contractAddress: tokenBalance.mintAddress,
      );
      if (marketData == null) {
        return fallback;
      }
      final name = marketData.baseName?.trim();
      final symbol = marketData.baseSymbol.trim();
      final logoUri = marketData.tokenLogoUri?.trim();
      return TokenInfo(
        chainId: chain.chainId,
        contractAddress: tokenBalance.mintAddress,
        symbol: symbol.isEmpty || symbol == '--' ? fallback.symbol : symbol,
        name: name == null || name.isEmpty ? fallback.name : name,
        decimals: tokenBalance.decimals,
        source: TokenSource.discovered,
        isHidden: false,
        logoUri: logoUri == null || logoUri.isEmpty ? null : logoUri,
      );
    } catch (_) {
      return fallback;
    }
  }

  AssetBalance _balanceFor({
    required ChainConfig chain,
    required TokenInfo token,
    required BigInt rawBalance,
  }) {
    return AssetBalance(
      chainId: chain.chainId,
      token: token,
      balance: rawBalance.toString(),
      formattedBalance: _formatUnits(rawBalance, token.decimals),
      status: AssetBalanceStatus.loaded,
    );
  }

  Future<List<AssetBalance>> _attachFiatValues({
    required ChainConfig chain,
    required List<AssetBalance> balances,
  }) async {
    if (balances.isEmpty) {
      return balances;
    }

    final prices = <String, TokenPriceQuote>{};
    for (final chunk in _chunks(balances, _tokenBatchSize)) {
      prices.addAll(
        await _priceRepository.refreshUsdPrices(
          chain: chain,
          tokens: chunk.map((balance) => balance.token).toList(growable: false),
        ),
      );
    }
    if (prices.isEmpty) {
      return balances;
    }

    return _balancesWithFiatValues(
      chain: chain,
      balances: balances,
      prices: prices,
    );
  }

  Future<List<AssetBalance>> _attachCachedFiatValues({
    required ChainConfig chain,
    required List<AssetBalance> balances,
  }) async {
    if (balances.isEmpty) {
      return balances;
    }

    final prices = <String, TokenPriceQuote>{};
    for (final chunk in _chunks(balances, _tokenBatchSize)) {
      prices.addAll(
        await _priceRepository.getCachedUsdPrices(
          chain: chain,
          tokens: chunk.map((balance) => balance.token).toList(growable: false),
        ),
      );
    }
    if (prices.isEmpty) {
      return balances;
    }

    return _balancesWithFiatValues(
      chain: chain,
      balances: balances,
      prices: prices,
    );
  }

  List<AssetBalance> _balancesWithFiatValues({
    required ChainConfig chain,
    required List<AssetBalance> balances,
    required Map<String, TokenPriceQuote> prices,
  }) {
    return balances
        .map((balance) {
          final quote =
              prices[tokenPriceKey(chain: chain, token: balance.token)];
          if (quote == null || balance.balance == null) {
            return balance;
          }
          final amount = _rawUnitsToDouble(
            rawBalance: BigInt.tryParse(balance.balance!) ?? BigInt.zero,
            decimals: balance.token.decimals,
          );
          final fiatValueUsd = amount * quote.priceUsd;
          return AssetBalance(
            chainId: balance.chainId,
            token: balance.token,
            balance: balance.balance,
            formattedBalance: balance.formattedBalance,
            status: balance.status,
            errorMessage: balance.errorMessage,
            fiatValue: formatUsdValue(fiatValueUsd),
            fiatValueUsd: fiatValueUsd,
            priceUsd: quote.priceUsd,
          );
        })
        .toList(growable: false);
  }

  Future<List<TokenInfo>> _portfolioTokens({
    required ChainConfig chain,
    required List<TokenInfo> tokens,
  }) async {
    final visibleTokens = _visibleContractTokens(
      chain: chain,
      tokens: tokens,
    ).toList(growable: false);
    return [
      TokenInfo(
        chainId: chain.chainId,
        contractAddress: null,
        symbol: chain.symbol,
        name: chain.name,
        decimals: switch (chain.chainType) {
          ChainType.evm => 18,
          ChainType.bitcoin => 8,
          ChainType.tron => 6,
          ChainType.solana => 9,
          ChainType.sui => 9,
        },
        source: TokenSource.builtIn,
        isHidden: false,
        logoUri: nativeTokenLogoUri(chain.chainId),
      ),
      ...await _queryContractTokens(
        chain: chain,
        tokens: tokens,
        visibleTokens: visibleTokens,
      ),
    ];
  }

  String _walletAddressFor({
    required WalletAccount account,
    required ChainConfig chain,
  }) {
    return switch (chain.chainType) {
      ChainType.evm => account.evmAddress,
      ChainType.bitcoin => account.btcAddress,
      ChainType.tron => account.tronAddress,
      ChainType.solana => account.solanaAddress,
      ChainType.sui => account.suiAddress,
    };
  }
}

String _suiCoinSymbol(String coinType) {
  final parts = coinType.split('::');
  final symbol = parts.isEmpty ? '' : parts.last.trim();
  return symbol.isEmpty ? coinType : symbol;
}

bool _hasPositiveRawBalance(String rawBalance) {
  final parsed = BigInt.tryParse(rawBalance);
  return parsed != null && parsed > BigInt.zero;
}

String _shortAddress(String address) {
  if (address.length <= 12) {
    return address;
  }
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

Iterable<List<T>> _chunks<T>(List<T> items, int chunkSize) sync* {
  final safeChunkSize = chunkSize <= 0 ? 20 : chunkSize;
  for (var index = 0; index < items.length; index += safeChunkSize) {
    final end = math.min(index + safeChunkSize, items.length);
    yield items.sublist(index, end);
  }
}

double _rawUnitsToDouble({required BigInt rawBalance, required int decimals}) {
  if (decimals <= 0) {
    return rawBalance.toDouble();
  }
  return rawBalance.toDouble() / math.pow(10, decimals).toDouble();
}

String formatUsdValue(double value) {
  final sign = value < 0 ? '-' : '';
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = _withThousandsSeparators(parts.first);
  return '$sign\$$whole.${parts[1]}';
}

String _withThousandsSeparators(String value) {
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index += 1) {
    final remaining = value.length - index;
    buffer.write(value[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatUnits(BigInt value, int decimals) {
  if (decimals <= 0) {
    return value.toString();
  }

  final base = BigInt.from(10).pow(decimals);
  final whole = value ~/ base;
  final fraction = value.remainder(base);
  if (fraction == BigInt.zero) {
    return whole.toString();
  }

  final fractionText = fraction
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  if (decimals == 8) {
    return '$whole.$fractionText';
  }
  return _limitSignificantFraction(
    whole: whole.toString(),
    fraction: fractionText,
    significantDigits: 6,
  );
}

String _limitSignificantFraction({
  required String whole,
  required String fraction,
  required int significantDigits,
}) {
  if (fraction.isEmpty) {
    return whole;
  }
  if (whole != '0') {
    final remainingFractionDigits = significantDigits - whole.length;
    if (remainingFractionDigits <= 0) {
      return whole;
    }
    final limited = fraction.length > remainingFractionDigits
        ? fraction.substring(0, remainingFractionDigits)
        : fraction;
    final trimmed = limited.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? whole : '$whole.$trimmed';
  }

  final firstSignificantIndex = fraction.indexOf(RegExp(r'[1-9]'));
  if (firstSignificantIndex == -1) {
    return '0';
  }
  final targetEnd = firstSignificantIndex + significantDigits;
  final end = targetEnd > fraction.length ? fraction.length : targetEnd;
  final limited = fraction.substring(0, end).replaceFirst(RegExp(r'0+$'), '');
  return limited.isEmpty ? '0' : '0.$limited';
}
