import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../application/dapp_request_controller.dart';
import 'dapp_sheet_container.dart';

Future<DappConfirmationDecision> showDappSignatureConfirmSheet(
  BuildContext context,
  DappRequestConfirmation confirmation,
) async {
  final decision = await showModalBottomSheet<DappConfirmationDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => DappSignatureConfirmSheet(confirmation: confirmation),
  );
  return decision ?? DappConfirmationDecision.rejected;
}

final class DappSignatureConfirmSheet extends StatelessWidget {
  const DappSignatureConfirmSheet({
    required this.confirmation,
    super.key,
  });

  final DappRequestConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final readableMessage = confirmation.message;
    final rawMessage = confirmation.rawMessage ?? '';
    final isUnreadable = readableMessage == null && rawMessage.isNotEmpty;

    return DappSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dapp.signatureTitle, style: context.appTextStyles.titleLarge),
          const SizedBox(height: AppSpacing.sectionY),
          _InfoRow(label: t.dapp.domain, value: confirmation.domain),
          _InfoRow(label: t.dapp.chain, value: confirmation.chain.name),
          _InfoRow(
            label: t.dapp.account,
            value: confirmation.address,
            isAddress: true,
          ),
          const SizedBox(height: 10),
          Text(t.dapp.message, style: context.appTextStyles.titleMedium),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.appColors.surfaceSoft,
              borderRadius: AppRadius.smallBorder,
              border: Border.all(color: context.appColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                readableMessage ?? rawMessage,
                style: context.appTextStyles.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RiskNotice(
            level: RiskLevel.warning,
            message: isUnreadable
                ? t.dapp.unreadableSignatureWarning
                : t.dapp.signatureRiskWarning,
          ),
          const SizedBox(height: AppSpacing.sectionY),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: t.dapp.reject,
                  onPressed: () => Navigator.of(context)
                      .pop(DappConfirmationDecision.rejected),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  label: t.dapp.approve,
                  onPressed: () => Navigator.of(context)
                      .pop(DappConfirmationDecision.approved),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 82, child: Text(label, style: context.appTextStyles.caption)),
          Expanded(
            child: isAddress
                ? Text.rich(
                    highlightedAddressTextSpan(
                      value,
                      style: context.appTextStyles.bodySmall,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  )
                : Text(
                    value,
                    style: context.appTextStyles.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
          ),
        ],
      ),
    );
  }
}
