import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../../../../i18n/generated/translations.g.dart';
import '../../../../shared/design/app_brand_colors.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_radius.dart';
import '../../../../shared/design/app_text_styles.dart';
import '../../../assets/presentation/widgets/token_icon.dart';

final class WalletTopBar extends StatelessWidget {
  const WalletTopBar({
    required this.walletName,
    required this.chainName,
    required this.chainSymbol,
    this.chainLogoUri,
    this.isNodeUnavailable = false,
    this.onWalletTap,
    this.onChainTap,
    super.key,
  });

  final String? walletName;
  final String chainName;
  final String chainSymbol;
  final String? chainLogoUri;
  final bool isNodeUnavailable;
  final VoidCallback? onWalletTap;
  final VoidCallback? onChainTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullWalletName = walletName ?? t.home.defaultWalletName;
    final displayWalletName = _middleEllipsizedWalletName(fullWalletName);

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          GestureDetector(
            onTap: onWalletTap,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: context.brandColors.primarySoft,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(AppIcons.wallet),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 116, maxWidth: 156),
            child: GestureDetector(
              onTap: onWalletTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayWalletName,
                      semanticsLabel: fullWalletName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    AppIcons.chevronDown,
                    color: context.appColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onChainTap,
                child: DecoratedBox(
                  key: const Key('homeChainSelector'),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: isNodeUnavailable
                          ? AppColors.danger
                          : colorScheme.outline,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TokenIcon(
                          symbol: chainSymbol,
                          logoUri: chainLogoUri,
                          size: 22,
                          logoKeyPrefix: 'homeChainLogo',
                          fallbackKeyPrefix: 'homeChainLogoFallback',
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            chainName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.appTextStyles.caption,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          AppIcons.chevronDown,
                          size: 18,
                          color: context.appColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _middleEllipsizedWalletName(String value) {
  const fullDisplayLength = 9;
  const longPrefixLength = 6;
  const compactPrefixLength = 3;
  const suffixLength = 3;
  const marker = '...';

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return value;
  }
  if (trimmed.length <= fullDisplayLength) {
    return trimmed;
  }

  final prefixLength =
      longPrefixLength + marker.length + suffixLength >= trimmed.length
      ? compactPrefixLength
      : longPrefixLength;
  final compacted =
      '${trimmed.substring(0, prefixLength)}$marker'
      '${trimmed.substring(trimmed.length - suffixLength)}';
  return compacted;
}
