import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/network/external_url_launcher.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../transfer/presentation/transfer_page.dart';
import '../../chains/domain/chain_config.dart';
import '../../staking/presentation/tron_staking_page.dart';
import '../application/asset_market_data_provider.dart';
import '../application/asset_portfolio_provider.dart';
import '../data/asset_market_data_repository.dart';
import 'widgets/token_icon.dart';
import 'token_management_page.dart';

final class AssetDetailPage extends ConsumerWidget {
  const AssetDetailPage({
    required this.name,
    required this.symbol,
    required this.amount,
    required this.fiatValue,
    required this.chainName,
    this.price = '--',
    this.priceUsd,
    this.contractAddress,
    this.logoUri,
    super.key,
  });

  final String name;
  final String symbol;
  final String amount;
  final String fiatValue;
  final String price;
  final double? priceUsd;
  final String chainName;
  final String? contractAddress;
  final String? logoUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioRequestValue = ref.watch(assetPortfolioRequestValueProvider);
    final chain = portfolioRequestValue.value?.chain;
    final currentContractAddress = contractAddress;
    final marketDataValue = currentContractAddress == null || chain == null
        ? null
        : ref.watch(
            assetMarketDataProvider(
              AssetMarketDataRequest(
                chain: chain,
                contractAddress: currentContractAddress,
              ),
            ),
          );
    final marketData = marketDataValue?.value;
    final isNativeTrx =
        chain?.chainType == ChainType.tron &&
        currentContractAddress == null &&
        symbol.toUpperCase() == 'TRX' &&
        (portfolioRequestValue.value?.account.tronAddress.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(t.assets.detailTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            16,
            AppSpacing.pageX,
            24,
          ),
          children: [
            _AssetHeroCard(
              name: name,
              symbol: symbol,
              amount: amount,
              fiatValue: fiatValue,
              price: price == '--' && marketData?.priceUsd != null
                  ? _formatUsd(marketData!.priceUsd)
                  : price,
              priceChange24h: marketData?.priceChange24h,
              logoUri: logoUri,
            ),
            const SizedBox(height: AppSpacing.sectionY),
            AppButton.primary(
              label: t.actions.send,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TransferPage(initialContractAddress: contractAddress),
                  ),
                );
              },
            ),
            if (isNativeTrx) ...[
              const SizedBox(height: 12),
              AppButton.secondary(
                key: const Key('assetTronStakingButton'),
                label: context.t.tronStaking.stake,
                icon: const Icon(AppIcons.staking, size: 18),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TronStakingPage(),
                    ),
                  );
                },
              ),
            ],
            if (currentContractAddress != null) ...[
              const SizedBox(height: AppSpacing.sectionY),
              _MarketDataCard(
                value: marketDataValue,
                waitingForChain: portfolioRequestValue.isLoading,
                canonicalPriceUsd: priceUsd,
                onOpenExternal: (url) {
                  ref.read(externalUrlLauncherProvider).openExternal(url);
                },
              ),
            ],
            const SizedBox(height: AppSpacing.sectionY),
            AppSectionCard(
              borderRadius: AppRadius.largeBorder,
              padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
              child: Column(
                children: [
                  _InfoRow(label: t.assets.network, value: chainName),
                  _InfoRow(
                    label: t.assets.contractAddress,
                    value: contractAddress ?? t.assets.nativeAsset,
                    isAddress: contractAddress != null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppButton.secondary(
              label: t.home.manageTokens,
              onPressed: () => _openTokenManagement(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTokenManagement(BuildContext context, WidgetRef ref) async {
    final request = await ref.read(assetPortfolioRequestProvider);
    if (!context.mounted || request == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TokenManagementPage(
          chain: request.chain,
          rpcUrl: request.rpcNode.endpointUrl,
          rpcHeaders: request.rpcNode.endpointHeaders,
          walletAddress: request.account.addressForChainType(
            request.chain.chainType,
          ),
        ),
      ),
    );
  }
}

final class _AssetHeroCard extends StatelessWidget {
  const _AssetHeroCard({
    required this.name,
    required this.symbol,
    required this.amount,
    required this.fiatValue,
    required this.price,
    required this.priceChange24h,
    required this.logoUri,
  });

  final String name;
  final String symbol;
  final String amount;
  final String fiatValue;
  final String price;
  final double? priceChange24h;
  final String? logoUri;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      borderRadius: AppRadius.largeBorder,
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TokenIcon(symbol: symbol, logoUri: logoUri, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.appTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(symbol, style: context.appTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionY),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.assets.currentPrice, style: context.appTextStyles.caption),
                    const SizedBox(height: 2),
                    Text(price, style: context.appTextStyles.displayAmount),
                  ],
                ),
              ),
              if (priceChange24h != null)
                _PriceChangeBadge(value: priceChange24h!),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.appColors.divider),
          const SizedBox(height: 16),
          Text(t.assets.balance, style: context.appTextStyles.caption),
          const SizedBox(height: 2),
          Text(amount, style: context.appTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(fiatValue, style: context.appTextStyles.bodySmall),
        ],
      ),
    );
  }
}

final class _PriceChangeBadge extends StatelessWidget {
  const _PriceChangeBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final backgroundColor = isPositive
        ? context.appColors.successSoft
        : context.appColors.dangerSoft;
    final prefix = isPositive ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(
        '$prefix${value.toStringAsFixed(2)}%',
        style: context.appTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _MarketDataCard extends StatelessWidget {
  const _MarketDataCard({
    required this.value,
    required this.waitingForChain,
    required this.canonicalPriceUsd,
    required this.onOpenExternal,
  });

  final AsyncValue<AssetMarketData?>? value;
  final bool waitingForChain;
  final double? canonicalPriceUsd;
  final ValueChanged<String> onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final currentValue = value;
    if (waitingForChain || currentValue == null || currentValue.isLoading) {
      return AppSectionCard(
        borderRadius: AppRadius.largeBorder,
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.assets.marketOverview, style: context.appTextStyles.titleMedium),
            const SizedBox(height: 16),
            const _MarketLoadingPlaceholder(),
          ],
        ),
      );
    }

    final data = currentValue.value;
    if (currentValue.hasError || data == null) {
      return AppSectionCard(
        borderRadius: AppRadius.largeBorder,
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        child: Row(
          children: [
            Icon(AppIcons.info, color: context.appColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.assets.marketDataUnavailable,
                style: context.appTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return AppSectionCard(
      borderRadius: AppRadius.largeBorder,
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.assets.marketOverview,
                  style: context.appTextStyles.titleMedium,
                ),
              ),
              Text(
                '${t.assets.updatedAt} ${_formatTime(data.updatedAt)}',
                style: context.appTextStyles.caption,
              ),
            ],
          ),
          if (_hasPriceDivergence(canonicalPriceUsd, data.priceUsd)) ...[
            const SizedBox(height: 12),
            _MarketWarning(message: t.assets.priceDivergenceWarning),
          ],
          if (data.liquidityUsd != null && data.liquidityUsd! < 10000) ...[
            const SizedBox(height: 12),
            _MarketWarning(message: t.assets.lowLiquidityWarning),
          ],
          const SizedBox(height: 16),
          _MetricRow(
            left: _MarketMetric(
              label: t.assets.volume24h,
              value: _formatCompactUsd(data.volume24hUsd),
            ),
            right: _MarketMetric(
              label: t.assets.liquidity,
              value: _formatCompactUsd(data.liquidityUsd),
            ),
          ),
          const SizedBox(height: 16),
          _MetricRow(
            left: _MarketMetric(
              label: t.assets.marketCap,
              value: _formatCompactUsd(data.marketCapUsd),
            ),
            right: _MarketMetric(
              label: t.assets.fdv,
              value: _formatCompactUsd(data.fdvUsd),
            ),
          ),
          const SizedBox(height: 16),
          _MarketMetric(
            label: t.assets.transactions24h,
            value:
                '${_formatInteger(data.buys24h)} / '
                '${_formatInteger(data.sells24h)}',
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: context.appColors.divider),
          const SizedBox(height: 16),
          Text(t.assets.primaryPair, style: context.appTextStyles.bodyLarge),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceSoft,
              borderRadius: AppRadius.mediumBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_displayDexName(data.dexId)} · '
                  '${data.baseSymbol}/${data.quoteSymbol}',
                  style: context.appTextStyles.bodyLarge,
                ),
                if (data.pairCreatedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${t.assets.pairCreatedAt} '
                    '${_formatDate(data.pairCreatedAt!)}',
                    style: context.appTextStyles.caption,
                  ),
                ],
                if (data.externalUrl != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => onOpenExternal(data.externalUrl!),
                    icon: const Icon(AppIcons.externalLink, size: 18),
                    label: Text(t.assets.viewOnDexScreener),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(t.assets.marketDataSource, style: context.appTextStyles.caption),
        ],
      ),
    );
  }
}

final class _MarketLoadingPlaceholder extends StatelessWidget {
  const _MarketLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 14,
          decoration: BoxDecoration(
            color: context.appColors.divider,
            borderRadius: AppRadius.smallBorder,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 14,
          decoration: BoxDecoration(
            color: context.appColors.surfaceSoft,
            borderRadius: AppRadius.smallBorder,
          ),
        ),
      ],
    );
  }
}

final class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

final class _MarketMetric extends StatelessWidget {
  const _MarketMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.appTextStyles.caption),
        const SizedBox(height: 2),
        Text(value, style: context.appTextStyles.bodyLarge),
      ],
    );
  }
}

final class _MarketWarning extends StatelessWidget {
  const _MarketWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appColors.warningSoft,
        borderRadius: AppRadius.mediumBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.warning, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: context.appTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

bool _hasPriceDivergence(double? canonicalPriceUsd, double? dexPriceUsd) {
  if (canonicalPriceUsd == null ||
      canonicalPriceUsd <= 0 ||
      dexPriceUsd == null ||
      dexPriceUsd <= 0) {
    return false;
  }
  return (canonicalPriceUsd - dexPriceUsd).abs() / canonicalPriceUsd > 0.05;
}

String _formatUsd(double? value) {
  return value == null ? '--' : '\$${value.toStringAsFixed(2)}';
}

String _formatCompactUsd(double? value) {
  if (value == null) {
    return '--';
  }
  if (value.abs() >= 1000000000) {
    return '\$${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value.abs() >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value.abs() >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(2)}K';
  }
  return _formatUsd(value);
}

String _formatInteger(int? value) {
  if (value == null) {
    return '--';
  }
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _displayDexName(String value) {
  return switch (value.toLowerCase()) {
    'uniswap' => 'Uniswap',
    'sushiswap' => 'SushiSwap',
    'pancakeswap' => 'PancakeSwap',
    'quickswap' => 'QuickSwap',
    'raydium' => 'Raydium',
    'orca' => 'Orca',
    _ when value.isEmpty => '--',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isAddress = false,
  });

  final String label;
  final String value;
  final bool isAddress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: context.appTextStyles.caption)),
          Expanded(
            child: isAddress
                ? Text.rich(
                    highlightedAddressTextSpan(
                      value,
                      style: context.appTextStyles.bodySmall,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  )
                : Text(
                    value,
                    style: context.appTextStyles.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
          ),
        ],
      ),
    );
  }
}
