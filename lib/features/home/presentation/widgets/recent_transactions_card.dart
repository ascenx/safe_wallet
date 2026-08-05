import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

import '../../../../i18n/generated/translations.g.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_radius.dart';
import '../../../../shared/design/app_spacing.dart';
import '../../../../shared/design/app_text_styles.dart';
import '../../../../shared/utils/address_display.dart';
import '../../../../shared/widgets/app_section_card.dart';
import '../../../transfer/domain/transaction_record.dart';
import '../../application/home_controller.dart';

final class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({
    required this.transactions,
    this.onViewAll,
    super.key,
  });

  final List<HomeTransactionPreview> transactions;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final mutedColor = context.appColors.textMuted;
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      t.home.recentTransactions,
                      style: context.appTextStyles.titleMedium,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.home.viewAll, style: context.appTextStyles.caption),
                    const SizedBox(width: 4),
                    Icon(AppIcons.chevronRight, color: mutedColor),
                  ],
                ),
              ),
            ],
          ),
          if (transactions.isNotEmpty) const SizedBox(height: 14),
          ...transactions.map(_TransactionRow.new),
        ],
      ),
    );
  }
}

final class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.transaction);

  final HomeTransactionPreview transaction;

  @override
  Widget build(BuildContext context) {
    final mutedColor = context.appColors.textMuted;
    final isTransfer = transaction.operation == TransactionOperation.transfer;
    final color = isTransfer
        ? transaction.isIncoming ? AppColors.success : AppColors.danger
        : Theme.of(context).colorScheme.primary;
    final icon = switch (transaction.operation) {
      TransactionOperation.transfer =>
        transaction.isIncoming ? AppIcons.receive : AppIcons.send,
      TransactionOperation.wrap || TransactionOperation.unwrap => AppIcons.swap,
      TransactionOperation.stake || TransactionOperation.unstake =>
        AppIcons.staking,
      TransactionOperation.withdrawUnfreeze ||
      TransactionOperation.cancelUnfreeze => AppIcons.pending,
      TransactionOperation.delegateResource ||
      TransactionOperation.undelegateResource => AppIcons.network,
      TransactionOperation.vote => AppIcons.checkCircle,
      TransactionOperation.claimReward => AppIcons.receive,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircleAvatar(
              backgroundColor: isTransfer
                  ? transaction.isIncoming
                      ? context.appColors.successSoft
                      : context.appColors.dangerSoft
                  : Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: color,
              child: Icon(icon, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.title, style: context.appTextStyles.bodyLarge),
                const SizedBox(height: 2),
                if (transaction.subtitleIsAddress)
                  _AdaptiveAddressText(
                    address: transaction.subtitle,
                    style: context.appTextStyles.caption,
                  )
                else
                  Text(
                    transaction.subtitle,
                    style: context.appTextStyles.caption.copyWith(color: mutedColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TransactionAmount(
                amount: transaction.amount,
                operation: transaction.operation,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(transaction.timestamp, style: context.appTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

final class _TransactionAmount extends StatelessWidget {
  const _TransactionAmount({
    required this.amount,
    required this.operation,
    required this.color,
  });

  final String amount;
  final TransactionOperation operation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = context.appTextStyles.bodyLarge.copyWith(color: color);
    final isWrappedAssetOperation =
        operation == TransactionOperation.wrap ||
        operation == TransactionOperation.unwrap;
    final separatorIndex = amount.indexOf(' ');
    if (!isWrappedAssetOperation || separatorIndex < 0) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(
          amount,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: style,
        ),
      );
    }

    final value = amount.substring(0, separatorIndex);
    final assetPair = amount.substring(separatorIndex + 1);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            key: const Key('recentTransactionAmountValue'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: style,
          ),
          Text(
            assetPair,
            key: const Key('recentTransactionAssetPair'),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: style,
          ),
        ],
      ),
    );
  }
}

final class _AdaptiveAddressText extends StatelessWidget {
  const _AdaptiveAddressText({required this.address, required this.style});

  final String address;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final highlightColor = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayAddress = constraints.hasBoundedWidth
            ? _middleEllipsizeToFit(
                address,
                maxWidth: constraints.maxWidth,
                style: style,
                textDirection: textDirection,
                textScaler: textScaler,
                locale: locale,
                highlightColor: highlightColor,
              )
            : address;

        return Text.rich(
          highlightedAddressTextSpan(
            displayAddress,
            style: style,
            highlightColor: highlightColor,
          ),
          maxLines: 1,
          softWrap: false,
        );
      },
    );
  }
}

String _middleEllipsizeToFit(
  String value, {
  required double maxWidth,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
  required Color highlightColor,
}) {
  if (_textFits(
    highlightedAddressTextSpan(
      value,
      style: style,
      highlightColor: highlightColor,
    ),
    maxWidth: maxWidth,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  )) {
    return value;
  }

  var minimum = 0;
  var maximum = value.length - 1;
  var visibleCharacterCount = 0;

  while (minimum <= maximum) {
    final candidateCount = (minimum + maximum) ~/ 2;
    final candidate = _middleEllipsize(value, candidateCount);
    if (_textFits(
      highlightedAddressTextSpan(
        candidate,
        style: style,
        highlightColor: highlightColor,
      ),
      maxWidth: maxWidth,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
    )) {
      visibleCharacterCount = candidateCount;
      minimum = candidateCount + 1;
    } else {
      maximum = candidateCount - 1;
    }
  }

  return _middleEllipsize(value, visibleCharacterCount);
}

String _middleEllipsize(String value, int visibleCharacterCount) {
  final leadingCount = (visibleCharacterCount + 1) ~/ 2;
  final trailingCount = visibleCharacterCount ~/ 2;
  return '${value.substring(0, leadingCount)}…'
      '${value.substring(value.length - trailingCount)}';
}

bool _textFits(
  InlineSpan text, {
  required double maxWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
}) {
  final painter = TextPainter(
    text: text,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: 1,
  )..layout();
  return painter.width <= maxWidth;
}
