import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../data/asset_repository.dart';
import '../data/token_balance_store.dart';
import '../data/token_price_repository.dart';
import 'asset_market_data_provider.dart';
import 'token_repository_provider.dart';

final tokenPriceRepositoryProvider = Provider<TokenPriceRepository>((ref) {
  final repository = DefaultTokenPriceRepository();
  ref.onDispose(repository.close);
  return repository;
});

final tokenBalanceStoreProvider = Provider<TokenBalanceStore>((ref) {
  return InMemoryTokenBalanceStore();
});

typedef AssetPortfolioRefreshClock = DateTime Function();

const assetPortfolioLiveRefreshInterval = Duration(minutes: 1);

final assetPortfolioRefreshClockProvider = Provider<AssetPortfolioRefreshClock>(
  (ref) {
    return () => DateTime.now().toUtc();
  },
);

final assetPortfolioLiveRefreshRegistryProvider =
    Provider<AssetPortfolioLiveRefreshRegistry>((ref) {
      return AssetPortfolioLiveRefreshRegistry();
    });

final class AssetPortfolioLiveRefreshRegistry {
  final _lastStartedAtByKey = <String, DateTime>{};
  final _inFlightByKey = <String, Future<AssetPortfolio>>{};
  final _lastPortfolioByKey = <String, AssetPortfolio>{};
  final _forcedRefreshKeys = <String>{};

  DateTime? lastStartedAt(String key) => _lastStartedAtByKey[key];

  Future<AssetPortfolio>? inFlight(String key) => _inFlightByKey[key];

  AssetPortfolio? lastPortfolio(String key) => _lastPortfolioByKey[key];

  void forceNext(String key) {
    _forcedRefreshKeys.add(key);
  }

  bool takeForced(String key) {
    return _forcedRefreshKeys.remove(key);
  }

  void markStarted(String key, DateTime now) {
    _lastStartedAtByKey[key] = now;
  }

  bool canStart(String key, DateTime now) {
    final lastStartedAt = _lastStartedAtByKey[key];
    if (lastStartedAt == null) {
      return true;
    }
    return now.difference(lastStartedAt) >= assetPortfolioLiveRefreshInterval;
  }

  Future<AssetPortfolio> trackStarted(
    String key,
    DateTime now,
    Future<AssetPortfolio> future,
  ) {
    markStarted(key, now);
    final trackedFuture = future.then((portfolio) {
      _lastPortfolioByKey[key] = portfolio;
      return portfolio;
    });
    _inFlightByKey[key] = trackedFuture;
    unawaited(
      trackedFuture.then<void>((_) {}, onError: (_, _) {}).whenComplete(() {
        if (identical(_inFlightByKey[key], trackedFuture)) {
          _inFlightByKey.remove(key);
        }
      }),
    );
    return trackedFuture;
  }
}

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  final repository = DefaultAssetRepository(
    priceRepository: ref.watch(tokenPriceRepositoryProvider),
    balanceStore: ref.watch(tokenBalanceStoreProvider),
    tokenUniverseRepository: ref.watch(tokenUniverseRepositoryProvider),
    marketDataRepository: ref.watch(assetMarketDataRepositoryProvider),
  );
  ref.onDispose(() => unawaited(repository.close()));
  return repository;
});

final assetPortfolioRequestProvider = Provider<Future<AssetPortfolioRequest?>>((
  ref,
) async {
  final walletId = ref.watch(selectedWalletIdProvider);
  if (walletId == null) {
    return null;
  }

  final wallets = await ref.read(walletRepositoryProvider).getWallets();
  final account = wallets.where((wallet) => wallet.id == walletId).firstOrNull;
  if (account == null) {
    return null;
  }

  final chain = await ref.watch(selectedChainControllerProvider.future);
  final rpcNode = await ref.watch(
    selectedResolvedRpcNodeProvider(chain).future,
  );
  return AssetPortfolioRequest(
    account: account,
    chain: chain,
    rpcNode: rpcNode,
  );
});

final assetPortfolioRequestValueProvider =
    FutureProvider<AssetPortfolioRequest?>((ref) {
      return ref.watch(assetPortfolioRequestProvider);
    });

final assetPortfolioProvider = FutureProvider<AssetPortfolio>((ref) async {
  final request = await ref.watch(assetPortfolioRequestProvider);
  if (request == null) {
    return AssetPortfolio.locked();
  }
  if (request.account
      .addressForChainType(request.chain.chainType)
      .trim()
      .isEmpty) {
    return AssetPortfolio.empty(account: request.account);
  }

  final repository = ref.read(assetRepositoryProvider);
  final tokens = await ref.watch(
    allTokensForChainProvider(request.chain.chainId).future,
  );
  final liveRefreshKey = assetPortfolioLiveRefreshKey(request);
  final liveRefreshRegistry = ref.read(
    assetPortfolioLiveRefreshRegistryProvider,
  );
  final forceRefresh = liveRefreshRegistry.takeForced(liveRefreshKey);
  final now = ref.read(assetPortfolioRefreshClockProvider)();
  if (repository is CachedAssetRepository) {
    final cachedPortfolio = await repository.loadCachedPortfolio(
      account: request.account,
      chain: request.chain,
      tokens: tokens,
    );
    if (forceRefresh) {
      final inFlight = liveRefreshRegistry.inFlight(liveRefreshKey);
      if (inFlight != null) {
        return inFlight;
      }
      return liveRefreshRegistry.trackStarted(
        liveRefreshKey,
        now,
        repository.loadPortfolio(
          account: request.account,
          chain: request.chain,
          rpcNode: request.rpcNode,
          tokens: tokens,
        ),
      );
    }
    if (cachedPortfolio != null) {
      if (liveRefreshRegistry.canStart(liveRefreshKey, now)) {
        unawaited(
          liveRefreshRegistry
              .trackStarted(
                liveRefreshKey,
                now,
                repository.loadPortfolio(
                  account: request.account,
                  chain: request.chain,
                  rpcNode: request.rpcNode,
                  tokens: tokens,
                ),
              )
              .then((_) {
                ref.invalidateSelf();
              })
              .catchError((_) {}),
        );
      }
      return cachedPortfolio.portfolio;
    }

    final inFlight = liveRefreshRegistry.inFlight(liveRefreshKey);
    if (inFlight != null) {
      return inFlight;
    }

    if (!liveRefreshRegistry.canStart(liveRefreshKey, now)) {
      final lastPortfolio = liveRefreshRegistry.lastPortfolio(liveRefreshKey);
      if (lastPortfolio != null) {
        return lastPortfolio;
      }
    }
  }

  return liveRefreshRegistry.trackStarted(
    liveRefreshKey,
    now,
    repository.loadPortfolio(
      account: request.account,
      chain: request.chain,
      rpcNode: request.rpcNode,
      tokens: tokens,
    ),
  );
}, retry: _doNotRetry);

Duration? _doNotRetry(int retryCount, Object error) => null;

String assetPortfolioLiveRefreshKey(AssetPortfolioRequest request) {
  final walletAddress = request.account.addressForChainType(
    request.chain.chainType,
  );
  final headerEntries = request.rpcNode.endpointHeaders.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return [
    request.chain.chainType.name,
    request.chain.chainId,
    request.chain.chainType == ChainType.evm
        ? walletAddress.toLowerCase()
        : walletAddress,
    request.rpcNode.endpointUrl,
    for (final header in headerEntries) '${header.key}:${header.value}',
  ].join(':');
}

final class AssetPortfolioRequest {
  const AssetPortfolioRequest({
    required this.account,
    required this.chain,
    required this.rpcNode,
  });

  final WalletAccount account;
  final ChainConfig chain;
  final RpcNode rpcNode;
}
