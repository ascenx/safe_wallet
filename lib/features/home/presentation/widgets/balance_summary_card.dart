import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:reel_text/reel_text.dart';

import '../../../../i18n/generated/translations.g.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_radius.dart';
import '../../../../shared/design/app_spacing.dart';
import '../../../../shared/design/app_text_styles.dart';
import '../../../../shared/widgets/app_section_card.dart';

final class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({
    required this.totalValue,
    required this.fiatEquivalent,
    required this.amountsHidden,
    required this.onToggleAmountsVisibility,
    super.key,
  });

  final String totalValue;
  final String fiatEquivalent;
  final bool amountsHidden;
  final VoidCallback onToggleAmountsVisibility;
  static const _hiddenAmount = '****';
  static const _totalValueSlotHeight = 42.0;
  static const _totalValueReelOptions = ReelTextOptions(
    direction: ReelTextDirection.up,
    duration: Duration(milliseconds: 320),
    stagger: Duration(milliseconds: 30),
    exitOffset: Duration(milliseconds: 42),
    bounce: 0.35,
  );

  @override
  Widget build(BuildContext context) {
    final mutedColor = context.appColors.textMuted;
    final displayedTotalValue = amountsHidden ? _hiddenAmount : totalValue;
    final displayedFiatEquivalent = amountsHidden
        ? _hiddenAmount
        : fiatEquivalent;

    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t.home.totalValue,
                      style: context.appTextStyles.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: amountsHidden
                          ? t.home.showAmounts
                          : t.home.hideAmounts,
                      child: GestureDetector(
                        onTap: onToggleAmountsVisibility,
                        child: Icon(
                          amountsHidden ? AppIcons.hidden : AppIcons.visible,
                          color: mutedColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: _totalValueSlotHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRect(
                      child: ReelText(
                        displayedTotalValue,
                        options: _totalValueReelOptions,
                        style: AppTextStyles.displayAmount.copyWith(
                          color: context.appColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  displayedFiatEquivalent,
                  style: context.appTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
