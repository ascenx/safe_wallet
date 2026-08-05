import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../../../../i18n/generated/translations.g.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_radius.dart';
import '../../../../shared/design/app_spacing.dart';
import '../../../../shared/design/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_state.dart';
import '../../../../shared/widgets/app_section_card.dart';
import '../../../assets/presentation/widgets/token_icon.dart';
import '../../application/home_controller.dart';

final class AssetListCard extends StatelessWidget {
  const AssetListCard({
    required this.state,
    required this.amountsHidden,
    this.onManageTokens,
    this.onAssetSelected,
    super.key,
  });

  final HomeState state;
  final bool amountsHidden;
  final VoidCallback? onManageTokens;
  final ValueChanged<HomeAssetPreview>? onAssetSelected;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.home.assetList,
                  style: context.appTextStyles.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onManageTokens,
                icon: const Icon(AppIcons.filters, size: 18),
                label: Text(t.home.manageTokens),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AssetContent(
            state: state,
            amountsHidden: amountsHidden,
            onAssetSelected: onAssetSelected,
          ),
        ],
      ),
    );
  }
}

final class _AssetContent extends StatelessWidget {
  const _AssetContent({
    required this.state,
    required this.amountsHidden,
    required this.onAssetSelected,
  });

  final HomeState state;
  final bool amountsHidden;
  final ValueChanged<HomeAssetPreview>? onAssetSelected;

  @override
  Widget build(BuildContext context) {
    if (state.assets.isNotEmpty) {
      return _AssetRows(
        assets: state.assets,
        amountsHidden: amountsHidden,
        onAssetSelected: onAssetSelected,
      );
    }

    return switch (state.assetStatus) {
      HomeAssetStatus.noWallet => AppEmptyState(
        icon: AppIcons.wallet,
        message: t.home.noWallet,
      ),
      HomeAssetStatus.locked => AppEmptyState(
        icon: AppIcons.lock,
        message: t.home.walletLocked,
      ),
      HomeAssetStatus.loading => AppLoadingState(message: t.home.loadingAssets),
      HomeAssetStatus.empty => AppEmptyState(
        icon: AppIcons.inbox,
        message: t.home.emptyAssets,
      ),
      HomeAssetStatus.error => AppErrorState(message: t.home.assetLoadError),
      HomeAssetStatus.loaded => AppEmptyState(
        icon: AppIcons.inbox,
        message: t.home.emptyAssets,
      ),
    };
  }
}

final class _AssetRows extends StatelessWidget {
  const _AssetRows({
    required this.assets,
    required this.amountsHidden,
    required this.onAssetSelected,
  });

  final List<HomeAssetPreview> assets;
  final bool amountsHidden;
  final ValueChanged<HomeAssetPreview>? onAssetSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: assets
          .map(
            (asset) => _AssetRow(
              asset: asset,
              amountsHidden: amountsHidden,
              onTap: onAssetSelected == null
                  ? null
                  : () => onAssetSelected!(asset),
            ),
          )
          .toList(),
    );
  }
}

final class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.asset,
    required this.amountsHidden,
    required this.onTap,
  });

  final HomeAssetPreview asset;
  final bool amountsHidden;
  final VoidCallback? onTap;
  static const _hiddenAmount = '****';

  @override
  Widget build(BuildContext context) {
    final mutedColor = context.appColors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              TokenIcon(
                symbol: asset.symbol,
                logoUri: asset.logoUri,
                logoKeyPrefix: 'assetLogo',
                fallbackKeyPrefix: 'assetLogoFallback',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.symbol,
                      style: context.appTextStyles.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      asset.price,
                      style: context.appTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 172),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountsHidden
                          ? _hiddenAmount
                          : _amountWithoutSymbol(asset),
                      style: context.appTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      amountsHidden ? _hiddenAmount : asset.fiatValue,
                      style: context.appTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(AppIcons.chevronRight, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }

  String _amountWithoutSymbol(HomeAssetPreview asset) {
    if (asset.symbol.isEmpty) {
      return asset.amount;
    }
    final symbolSuffix = ' ${asset.symbol}';
    if (!asset.amount.endsWith(symbolSuffix)) {
      return asset.amount;
    }
    return asset.amount.substring(0, asset.amount.length - symbolSuffix.length);
  }
}
