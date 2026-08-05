import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../application/dapp_request_controller.dart';
import 'dapp_sheet_container.dart';

Future<DappAuthorizationDecision> showDappAuthorizationSheet(
  BuildContext context,
  DappRequestConfirmation confirmation,
) async {
  final decision = await showModalBottomSheet<DappAuthorizationDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => DappAuthorizationSheet(confirmation: confirmation),
  );
  return decision ?? DappAuthorizationDecision.rejected;
}

final class DappAuthorizationSheet extends StatefulWidget {
  const DappAuthorizationSheet({required this.confirmation, super.key});

  final DappRequestConfirmation confirmation;

  @override
  State<DappAuthorizationSheet> createState() => _DappAuthorizationSheetState();
}

final class _DappAuthorizationSheetState extends State<DappAuthorizationSheet> {
  bool _rememberSite = false;

  @override
  Widget build(BuildContext context) {
    final confirmation = widget.confirmation;
    return DappSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.dapp.authorizationTitle,
            style: context.appTextStyles.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            t.dapp.authorizationBody,
            style: context.appTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sectionY),
          _InfoRow(label: t.dapp.domain, value: confirmation.domain),
          _InfoRow(label: t.dapp.chain, value: confirmation.chain.name),
          _InfoRow(
            label: t.dapp.account,
            value: confirmation.address,
            isAddress: true,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _rememberSite,
            title: Text(
              t.dapp.rememberAuthorization,
              style: context.appTextStyles.bodySmall,
            ),
            onChanged: (value) {
              setState(() {
                _rememberSite = value ?? false;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sectionY),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: t.dapp.reject,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DappAuthorizationDecision.rejected),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  label: t.dapp.approve,
                  onPressed: () => Navigator.of(context).pop(
                    _rememberSite
                        ? DappAuthorizationDecision.approved
                        : DappAuthorizationDecision.approvedForSession,
                  ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surfaceSoft,
          borderRadius: AppRadius.smallBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
        ),
      ),
    );
  }
}
