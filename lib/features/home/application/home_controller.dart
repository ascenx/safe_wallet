import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/application/asset_portfolio_provider.dart';
import '../../assets/application/token_repository_provider.dart';
import '../../assets/data/asset_repository.dart';
import '../../assets/data/token_logo_uris.dart';
import '../../assets/domain/token_info.dart';
import '../../chains/data/chain_logo_uris.dart' as chain_logos;
import '../../chains/domain/chain_config.dart';
import '../../settings/application/fiat_currency_setting.dart';
import '../../settings/data/fiat_exchange_rate_repository.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../transfer/domain/transaction_record.dart';
import '../../../i18n/generated/translations.g.dart';

final homeControllerProvider = Provider<HomeState>((ref) {
  final portfolioValue = ref.watch(assetPortfolioProvider);
  final requestValue = ref.watch(assetPortfolioRequestValueProvider);
  final request = requestValue.value;
  final walletName = request?.account.name;
  final chain = request?.chain;
  final tokensValue =
      chain == null ? null : ref.watch(tokensForChainProvider(chain.chainId));
  final recentTransactions =
      ref.watch(recentTransactionsProvider).value ?? const [];
  final fiatCurrency =
      ref.watch(fiatCurrencySettingProvider).value ?? AppFiatCurrency.usd;
  final usdExchangeRate = fiatCurrency == AppFiatCurrency.usd
      ? 1.0
      : ref.watch(fiatExchangeRateProvider(fiatCurrency)).value;
  HomeState? cachedLoadedState({bool isNodeUnavailable = false}) {
    final cachedPortfolio = portfolioValue.value;
    if (cachedPortfolio != null &&
        cachedPortfolio.status == AssetPortfolioStatus.loaded &&
        _portfolioMatchesRequest(cachedPortfolio, request)) {
      return HomeState.fromPortfolio(
        cachedPortfolio,
        chain: chain,
        walletName: walletName,
        recentRecords: recentTransactions,
        fiatCurrency: fiatCurrency,
        usdExchangeRate: usdExchangeRate,
        isNodeUnavailable: isNodeUnavailable,
      );
    }
    return null;
  }

  return portfolioValue.when(
    data: (portfolio) => HomeState.fromPortfolio(
      portfolio,
      chain: chain,
      walletName: walletName,
      recentRecords: recentTransactions,
      fiatCurrency: fiatCurrency,
      usdExchangeRate: usdExchangeRate,
    ),
    error: (error, stackTrace) =>
        cachedLoadedState(isNodeUnavailable: true) ??
        HomeState.errorAssets(
          walletName: walletName,
          chain: chain,
          fiatCurrency: fiatCurrency,
        ),
    loading: () {
      final cachedState = cachedLoadedState();
      if (cachedState != null) {
        return cachedState;
      }
      return HomeState.loadingAssets(
        walletName: walletName,
        chain: chain,
        tokens: tokensValue?.value ?? const [],
        fiatCurrency: fiatCurrency,
      );
    },
  );
});

enum HomeAssetStatus {
  noWallet,
  locked,
  loading,
  empty,
  error,
  loaded,
}

final class HomeState {
  const HomeState({
    required this.assetStatus,
    this.walletName,
    this.chainName = 'Ethereum',
    this.chainSymbol = 'ETH',
    this.chainLogoUri,
    this.isNodeUnavailable = false,
    this.totalValue = '\$0.00',
    this.nativeEquivalent = '≈ 0.0000 ETH',
    this.fiatEquivalent = '≈ \$0.00 USD',
    this.assets = const [],
    this.recentTransactions = const [],
  });

  factory HomeState.noWallet() {
    return const HomeState(
      assetStatus: HomeAssetStatus.noWallet,
      totalValue: '--',
      nativeEquivalent: '--',
      fiatEquivalent: '--',
    );
  }

  factory HomeState.locked({String? walletName, ChainConfig? chain}) {
    return HomeState(
      assetStatus: HomeAssetStatus.locked,
      walletName: walletName,
      chainName: _chainName(chain),
      chainSymbol: _chainSymbol(chain),
      chainLogoUri: _chainLogoUri(chain),
      totalValue: '--',
      nativeEquivalent: '--',
      fiatEquivalent: '--',
    );
  }

  factory HomeState.loadingAssets({
    String? walletName,
    ChainConfig? chain,
    List<TokenInfo> tokens = const [],
    AppFiatCurrency fiatCurrency = AppFiatCurrency.usd,
  }) {
    return HomeState(
      assetStatus: HomeAssetStatus.loading,
      walletName: walletName,
      chainName: _chainName(chain),
      chainSymbol: _chainSymbol(chain),
      chainLogoUri: _chainLogoUri(chain),
      nativeEquivalent: _zeroNativeEquivalent(chain),
      fiatEquivalent: _zeroFiatEquivalent(fiatCurrency),
      assets: _placeholderAssets(chain, tokens),
    );
  }

  factory HomeState.emptyAssets({
    String? walletName,
    ChainConfig? chain,
    AppFiatCurrency fiatCurrency = AppFiatCurrency.usd,
  }) {
    return HomeState(
      assetStatus: HomeAssetStatus.empty,
      walletName: walletName,
      chainName: _chainName(chain),
      chainSymbol: _chainSymbol(chain),
      chainLogoUri: _chainLogoUri(chain),
      nativeEquivalent: _zeroNativeEquivalent(chain),
      fiatEquivalent: _zeroFiatEquivalent(fiatCurrency),
    );
  }

  factory HomeState.errorAssets({
    String? walletName,
    ChainConfig? chain,
    AppFiatCurrency fiatCurrency = AppFiatCurrency.usd,
  }) {
    return HomeState(
      assetStatus: HomeAssetStatus.error,
      walletName: walletName,
      chainName: _chainName(chain),
      chainSymbol: _chainSymbol(chain),
      chainLogoUri: _chainLogoUri(chain),
      isNodeUnavailable: true,
      nativeEquivalent: _zeroNativeEquivalent(chain),
      fiatEquivalent: _zeroFiatEquivalent(fiatCurrency),
    );
  }

  factory HomeState.fromPortfolio(
    AssetPortfolio portfolio, {
    ChainConfig? chain,
    String chainName = 'Ethereum',
    String? walletName,
    List<TransactionRecord> recentRecords = const [],
    AppFiatCurrency fiatCurrency = AppFiatCurrency.usd,
    double? usdExchangeRate = 1,
    bool isNodeUnavailable = false,
  }) {
    final currentWalletName = walletName ?? portfolio.account?.name;
    final recentTransactions = recentRecords.map((record) {
      final isIncoming = record.direction == TransactionDirection.incoming;
      final counterparty = isIncoming ? record.fromAddress : record.toAddress;
      final formattedAmount = _formatRecentTransactionAmount(record.amount);
      return HomeTransactionPreview(
        title: switch (record.operation) {
          TransactionOperation.transfer =>
            isIncoming ? t.actions.receive : t.actions.send,
          TransactionOperation.wrap => t.transactions.operationWrap,
          TransactionOperation.unwrap => t.transactions.operationUnwrap,
          TransactionOperation.stake => t.transactions.operationStake,
          TransactionOperation.unstake => t.transactions.operationUnstake,
          TransactionOperation.withdrawUnfreeze =>
            t.transactions.operationWithdrawUnfreeze,
          TransactionOperation.cancelUnfreeze =>
            t.transactions.operationCancelUnfreeze,
          TransactionOperation.delegateResource =>
            t.transactions.operationDelegateResource,
          TransactionOperation.undelegateResource =>
            t.transactions.operationUndelegateResource,
          TransactionOperation.vote => t.transactions.operationVote,
          TransactionOperation.claimReward =>
            t.transactions.operationClaimReward,
        },
        subtitle: counterparty ?? record.transactionHash,
        subtitleIsAddress: counterparty != null,
        amount: switch (record.operation) {
          TransactionOperation.wrap || TransactionOperation.unwrap =>
            '$formattedAmount ${record.assetSymbol} → ${record.resource ?? ''}',
          _ =>
            '${isIncoming ? '+' : '-'}$formattedAmount ${record.assetSymbol}',
        },
        timestamp: _formatTimestamp(record.createdAt),
        isIncoming: isIncoming,
        operation: record.operation,
      );
    }).toList();

    return switch (portfolio.status) {
      AssetPortfolioStatus.locked =>
        HomeState.locked(walletName: currentWalletName, chain: chain),
      AssetPortfolioStatus.loading => HomeState.loadingAssets(
          walletName: currentWalletName,
          chain: chain,
          fiatCurrency: fiatCurrency,
        ),
      AssetPortfolioStatus.empty => HomeState.emptyAssets(
          walletName: currentWalletName,
          chain: chain,
          fiatCurrency: fiatCurrency,
        ),
      AssetPortfolioStatus.error => HomeState.errorAssets(
          walletName: currentWalletName,
          chain: chain,
          fiatCurrency: fiatCurrency,
        ),
      AssetPortfolioStatus.loaded => () {
          final totalFiatValueUsd = _totalFiatValueUsd(portfolio);
          final fiatTotalValue = _formattedFiatValue(
            totalFiatValueUsd,
            fiatCurrency,
            usdExchangeRate,
          );
          return HomeState.loaded(
            walletName: currentWalletName,
            totalValue: formatFiatValue(
              totalFiatValueUsd,
              AppFiatCurrency.usd,
            ),
            nativeEquivalent: _nativeEquivalent(portfolio, totalFiatValueUsd),
            fiatEquivalent: fiatTotalValue == '--'
                ? '--'
                : '≈ $fiatTotalValue ${fiatCurrency.code}',
            chainName: _chainNameFromPortfolio(
              portfolio,
              fallback: _chainName(chain, fallback: chainName),
            ),
            chainSymbol: _chainSymbolFromPortfolio(
              portfolio,
              fallback: _chainSymbol(chain),
            ),
            chainLogoUri: _chainLogoUri(chain),
            isNodeUnavailable: isNodeUnavailable,
            recentTransactions: recentTransactions,
            assets: portfolio.balances.map((balance) {
              final formattedBalance = balance.formattedBalance ?? '--';
              return HomeAssetPreview(
                name: balance.token.name,
                symbol: balance.token.symbol,
                amount: '$formattedBalance ${balance.token.symbol}',
                fiatValue: _formattedFiatValue(
                  balance.fiatValueUsd,
                  fiatCurrency,
                  usdExchangeRate,
                ),
                price: _formattedFiatValue(
                  balance.priceUsd,
                  fiatCurrency,
                  usdExchangeRate,
                ),
                priceUsd: balance.priceUsd,
                contractAddress: balance.token.contractAddress,
                logoUri: balance.token.logoUri,
              );
            }).toList(),
          );
        }(),
    };
  }

  factory HomeState.loaded({
    required List<HomeAssetPreview> assets,
    List<HomeTransactionPreview> recentTransactions = const [],
    String totalValue = '\$0.00',
    String nativeEquivalent = '≈ 0.0000 ETH',
    String? fiatEquivalent,
    String? walletName,
    String chainName = 'Ethereum',
    String chainSymbol = 'ETH',
    String? chainLogoUri,
    bool isNodeUnavailable = false,
  }) {
    return HomeState(
      assetStatus: HomeAssetStatus.loaded,
      walletName: walletName,
      chainName: chainName,
      chainSymbol: chainSymbol,
      chainLogoUri: chainLogoUri,
      isNodeUnavailable: isNodeUnavailable,
      totalValue: totalValue,
      nativeEquivalent: nativeEquivalent,
      fiatEquivalent: fiatEquivalent ?? '≈ $totalValue USD',
      assets: assets,
      recentTransactions: recentTransactions,
    );
  }

  final HomeAssetStatus assetStatus;
  final String? walletName;
  final String chainName;
  final String chainSymbol;
  final String? chainLogoUri;
  final bool isNodeUnavailable;
  final String totalValue;
  final String nativeEquivalent;
  final String fiatEquivalent;
  final List<HomeAssetPreview> assets;
  final List<HomeTransactionPreview> recentTransactions;
}

final class HomeAssetPreview {
  const HomeAssetPreview({
    required this.name,
    required this.symbol,
    required this.amount,
    required this.fiatValue,
    this.price = '--',
    this.priceUsd,
    this.contractAddress,
    this.logoUri,
  });

  final String name;
  final String symbol;
  final String amount;
  final String fiatValue;
  final String price;
  final double? priceUsd;
  final String? contractAddress;
  final String? logoUri;
}

final class HomeTransactionPreview {
  const HomeTransactionPreview({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.timestamp,
    required this.isIncoming,
    this.operation = TransactionOperation.transfer,
    this.subtitleIsAddress = false,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String timestamp;
  final bool isIncoming;
  final TransactionOperation operation;
  final bool subtitleIsAddress;
}

String _formatTimestamp(DateTime value) {
  final localValue = value.toLocal();
  return '${localValue.month.toString().padLeft(2, '0')}-'
      '${localValue.day.toString().padLeft(2, '0')} '
      '${localValue.hour.toString().padLeft(2, '0')}:'
      '${localValue.minute.toString().padLeft(2, '0')}:'
      '${localValue.second.toString().padLeft(2, '0')}';
}

String _chainNameFromPortfolio(
  AssetPortfolio portfolio, {
  required String fallback,
}) {
  final nativeToken = portfolio.balances.firstOrNull?.token;
  return nativeToken?.name ?? fallback;
}

String _chainSymbolFromPortfolio(
  AssetPortfolio portfolio, {
  required String fallback,
}) {
  final nativeToken = portfolio.balances.firstOrNull?.token;
  return nativeToken?.symbol ?? fallback;
}

String _chainName(ChainConfig? chain, {String fallback = 'Ethereum'}) {
  return chain?.name ?? fallback;
}

String _chainSymbol(ChainConfig? chain, {String fallback = 'ETH'}) {
  return chain?.symbol ?? fallback;
}

String _zeroNativeEquivalent(ChainConfig? chain) {
  return '≈ 0.0000 ${_chainSymbol(chain)}';
}

String _zeroFiatEquivalent(AppFiatCurrency currency) {
  return '≈ ${formatFiatValue(0, currency)} ${currency.code}';
}

String? _chainLogoUri(ChainConfig? chain) {
  return chain == null ? null : chain_logos.chainLogoUri(chain);
}

bool _portfolioMatchesRequest(
  AssetPortfolio portfolio,
  AssetPortfolioRequest? request,
) {
  if (request == null) {
    return true;
  }

  final portfolioAccount = portfolio.account;
  if (portfolioAccount != null && portfolioAccount.id != request.account.id) {
    return false;
  }

  return portfolio.balances.every(
    (balance) => balance.chainId == request.chain.chainId,
  );
}

double _totalFiatValueUsd(AssetPortfolio portfolio) {
  return portfolio.balances.fold<double>(
    0,
    (total, balance) => total + (balance.fiatValueUsd ?? 0),
  );
}

String _nativeEquivalent(AssetPortfolio portfolio, double totalFiatValueUsd) {
  final nativeTokenBalance = portfolio.balances.firstOrNull;
  final nativePriceUsd = nativeTokenBalance?.priceUsd;
  if (nativeTokenBalance == null ||
      nativePriceUsd == null ||
      nativePriceUsd <= 0) {
    return '≈ 0.0000 ${nativeTokenBalance?.token.symbol ?? ''}'.trimRight();
  }

  return '≈ ${_formatTokenAmount(totalFiatValueUsd / nativePriceUsd)} '
      '${nativeTokenBalance.token.symbol}';
}

String _formatTokenAmount(double value) {
  final fixed = value.toStringAsFixed(6);
  final trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? '${trimmed}0' : trimmed;
}

String _formatRecentTransactionAmount(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^([+-]?\d+)(?:\.(\d+))?$').firstMatch(trimmed);
  if (match == null) {
    return trimmed;
  }

  final whole = match.group(1)!;
  final fraction = match.group(2);
  if (fraction == null || fraction.length <= 6) {
    return trimmed;
  }

  final limitedFraction = fraction
      .substring(0, 6)
      .replaceFirst(RegExp(r'0+$'), '');
  return limitedFraction.isEmpty ? whole : '$whole.$limitedFraction';
}

String _formattedFiatValue(
  double? valueUsd,
  AppFiatCurrency currency,
  double? usdExchangeRate,
) {
  if (valueUsd == null || usdExchangeRate == null) {
    return '--';
  }
  return formatFiatValue(valueUsd * usdExchangeRate, currency);
}

List<HomeAssetPreview> _placeholderAssets(
  ChainConfig? chain,
  List<TokenInfo> tokens,
) {
  if (chain == null) {
    return const [];
  }

  final visibleTokens = tokens
      .where((token) => !token.isHidden && token.contractAddress != null)
      .toList(growable: false);
  return [
    HomeAssetPreview(
      name: chain.name,
      symbol: chain.symbol,
      amount: '-- ${chain.symbol}',
      fiatValue: '--',
      logoUri: nativeTokenLogoUri(chain.chainId),
    ),
    for (final token in visibleTokens)
      HomeAssetPreview(
        name: token.name,
        symbol: token.symbol,
        amount: '-- ${token.symbol}',
        fiatValue: '--',
        contractAddress: token.contractAddress,
        logoUri: token.logoUri,
      ),
  ];
}
