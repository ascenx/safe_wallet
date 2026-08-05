import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../i18n/generated/translations.g.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_radius.dart';
import '../../../../shared/design/app_spacing.dart';
import '../../../../shared/design/app_text_styles.dart';
import '../../../../shared/utils/address_display.dart';
import '../../../../shared/widgets/app_buttons.dart';

final class AddressQrCard extends StatelessWidget {
  const AddressQrCard({
    required this.title,
    required this.address,
    required this.qrData,
    required this.amountSummary,
    required this.exportBoundaryKey,
    required this.onEditAmount,
    required this.onRemoveAmount,
    required this.onSave,
    required this.onCopy,
    this.isSaving = false,
    super.key,
  });

  final String title;
  final String address;
  final String qrData;
  final String? amountSummary;
  final GlobalKey exportBoundaryKey;
  final VoidCallback onEditAmount;
  final VoidCallback onRemoveAmount;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final bool isSaving;

  static const _actionButtonPadding = EdgeInsets.symmetric(horizontal: 8);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('addressQrCard'),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: AppRadius.largeBorder,
        // border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RepaintBoundary(
            key: exportBoundaryKey,
            child: ColoredBox(
              key: const Key('receiveAddressQrExportContent'),
              color: context.appColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(title, style: context.appTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.sectionY),
                    QrImageView(
                      data: qrData,
                      size: 220,
                      semanticsLabel: qrData,
                    ),
                    const SizedBox(height: AppSpacing.sectionY),
                    Text.rich(
                      highlightedAddressTextSpan(
                        address,
                        style: context.appTextStyles.bodySmall,
                        highlightColor: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPaddingLarge,
              0,
              AppSpacing.cardPaddingLarge,
              AppSpacing.cardPaddingLarge,
            ),
            child: Column(
              children: [
                if (amountSummary != null) ...[
                  _ReceiveAmountSummary(
                    summary: amountSummary!,
                    onRemove: onRemoveAmount,
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    AppButton.text(
                      key: const Key('editReceiveAmountButton'),
                      label: t.wallet.amount,
                      icon: const Icon(AppIcons.edit),
                      padding: _actionButtonPadding,
                      onPressed: onEditAmount,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.secondary(
                        key: const Key('saveReceiveAddressQrButton'),
                        label: t.wallet.saveQrImage,
                        icon: const Icon(AppIcons.save),
                        padding: _actionButtonPadding,
                        onPressed: isSaving ? null : onSave,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.primary(
                        key: const Key('copyReceiveAddressButton'),
                        label: t.wallet.copy,
                        icon: const Icon(AppIcons.copy),
                        padding: _actionButtonPadding,
                        onPressed: onCopy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ReceiveAmountSummary extends StatelessWidget {
  const _ReceiveAmountSummary({required this.summary, required this.onRemove});

  final String summary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                style: context.appTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const Key('removeReceiveAmountButton'),
              tooltip: t.actions.close,
              onPressed: onRemove,
              icon: const Icon(AppIcons.close),
            ),
          ],
        ),
      ),
    );
  }
}
