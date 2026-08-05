import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../application/dapp_request_controller.dart';
import 'dapp_sheet_container.dart';

Future<DappConfirmationDecision> showDappTransactionConfirmSheet(
  BuildContext context,
  DappRequestConfirmation confirmation,
) async {
  final decision = await showModalBottomSheet<DappConfirmationDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => DappTransactionConfirmSheet(confirmation: confirmation),
  );
  return decision ?? DappConfirmationDecision.rejected;
}

final class DappTransactionConfirmSheet extends StatelessWidget {
  const DappTransactionConfirmSheet({required this.confirmation, super.key});

  final DappRequestConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final transactions = confirmation.transactionPreviews;

    return DappSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.dapp.transactionTitle,
            style: context.appTextStyles.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sectionY),
          _InfoRow(label: t.dapp.domain, value: confirmation.domain),
          _InfoRow(label: t.dapp.chain, value: confirmation.chain.name),
          for (var index = 0; index < transactions.length; index++) ...[
            if (index > 0) const Divider(height: AppSpacing.sectionY),
            _TransactionDetails(transaction: transactions[index]),
          ],
          const SizedBox(height: AppSpacing.sectionY),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: t.dapp.reject,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DappConfirmationDecision.rejected),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  label: t.dapp.approve,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DappConfirmationDecision.approved),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transaction});

  final DappTransactionPreview transaction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoRow(label: t.dapp.from, value: transaction.from, isAddress: true),
        _InfoRow(
          label: t.dapp.to,
          value: transaction.to ?? '-',
          isAddress: transaction.to != null,
        ),
        _InfoRow(label: t.dapp.value, value: transaction.value ?? '0'),
        _InfoRow(
          label: t.dapp.contract,
          value: transaction.contractAddress ?? '-',
          isAddress: transaction.contractAddress != null,
        ),
        _InfoRow(
          label: t.dapp.feeEstimate,
          value: transaction.estimatedFee ?? '-',
        ),
        _InfoRow(
          label: t.dapp.decodedInfo,
          value: transaction.decodedInfo ?? '-',
        ),
        if (transaction.data != null)
          _InfoRow(label: t.dapp.rawTransactionData, value: transaction.data!),
        if (transaction.highRisk) ...[
          const SizedBox(height: 8),
          RiskNotice(
            level: RiskLevel.danger,
            message: transaction.simulationWarning == null
                ? t.dapp.unparsedTransactionWarning
                : t.dapp.simulationFailedWarning(
                    reason: transaction.simulationWarning!,
                  ),
          ),
        ],
      ],
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
          SizedBox(
            width: 96,
            child: Text(label, style: context.appTextStyles.caption),
          ),
          Expanded(
            child: isAddress
                ? Text.rich(
                    highlightedAddressTextSpan(
                      value,
                      style: context.appTextStyles.bodySmall,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Text(value, style: context.appTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
