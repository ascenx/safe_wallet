import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../domain/security_log_entry.dart';

final class SecurityLogPage extends StatelessWidget {
  const SecurityLogPage({required this.entries, super.key});

  final List<SecurityLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.settings.securityLog)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          children: [
            RiskNotice(
              level: RiskLevel.warning,
              message: t.settings.securityLogSafetyNotice,
            ),
            const SizedBox(height: AppSpacing.sectionY),
            if (entries.isEmpty)
              AppSectionCard(
                child: AppEmptyState(
                  icon: AppIcons.history,
                  message: t.settings.securityLogEmpty,
                ),
              )
            else
              for (final entry in entries) _SecurityLogEntryCard(entry: entry),
          ],
        ),
      ),
    );
  }
}

final class _SecurityLogEntryCard extends StatelessWidget {
  const _SecurityLogEntryCard({required this.entry});

  final SecurityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final amountText = _amountText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSectionCard(
        borderRadius: AppRadius.largeBorder,
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.appColors.warningSoft,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(_icon, color: AppColors.warning),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: context.appTextStyles.bodyLarge),
                  if (entry.walletName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${t.settings.securityLogWalletLabel}'
                      '${entry.walletName}',
                      style: context.appTextStyles.bodySmall,
                    ),
                  ],
                  if (entry.chainName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${t.settings.securityLogChainLabel}'
                      '${entry.chainName}',
                      style: context.appTextStyles.bodySmall,
                    ),
                  ],
                  if (amountText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${t.settings.securityLogAmountLabel}$amountText',
                      style: context.appTextStyles.bodySmall,
                    ),
                  ],
                  if (entry.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${t.settings.securityLogAddressLabel}'
                      '${entry.address}',
                      style: context.appTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(entry.occurredAt),
                    style: context.appTextStyles.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (entry.type) {
      SecurityLogEventType.viewMnemonic ||
      SecurityLogEventType.viewPrivateKey => AppIcons.visible,
      SecurityLogEventType.copyMnemonic ||
      SecurityLogEventType.copyPrivateKey => AppIcons.copy,
      SecurityLogEventType.createWallet => AppIcons.addCircle,
      SecurityLogEventType.importWallet => AppIcons.importWallet,
      SecurityLogEventType.deleteWallet => AppIcons.delete,
      SecurityLogEventType.changePassword => AppIcons.password,
      SecurityLogEventType.signMessage => AppIcons.edit,
      SecurityLogEventType.signTransaction => AppIcons.receipt,
      SecurityLogEventType.wrapNative ||
      SecurityLogEventType.unwrapNative => AppIcons.swap,
      SecurityLogEventType.solanaRentRecovery => AppIcons.solana,
      SecurityLogEventType.tronStake ||
      SecurityLogEventType.tronUnstake ||
      SecurityLogEventType.tronWithdrawUnfreeze ||
      SecurityLogEventType.tronCancelUnfreeze ||
      SecurityLogEventType.tronDelegateResource ||
      SecurityLogEventType.tronUndelegateResource ||
      SecurityLogEventType.tronVote ||
      SecurityLogEventType.tronClaimReward => AppIcons.staking,
    };
  }

  String get _title {
    return switch (entry.type) {
      SecurityLogEventType.viewMnemonic => t.settings.securityLogViewMnemonic,
      SecurityLogEventType.viewPrivateKey =>
        t.settings.securityLogViewPrivateKey,
      SecurityLogEventType.copyMnemonic => t.settings.securityLogCopyMnemonic,
      SecurityLogEventType.copyPrivateKey =>
        t.settings.securityLogCopyPrivateKey,
      SecurityLogEventType.createWallet => t.settings.securityLogCreateWallet,
      SecurityLogEventType.importWallet => t.settings.securityLogImportWallet,
      SecurityLogEventType.deleteWallet => t.settings.securityLogDeleteWallet,
      SecurityLogEventType.changePassword =>
        t.settings.securityLogChangePassword,
      SecurityLogEventType.signMessage => t.settings.securityLogSignMessage,
      SecurityLogEventType.signTransaction =>
        t.settings.securityLogSignTransaction,
      SecurityLogEventType.wrapNative => t.settings.securityLogWrapNative,
      SecurityLogEventType.unwrapNative => t.settings.securityLogUnwrapNative,
      SecurityLogEventType.solanaRentRecovery =>
        t.settings.securityLogSolanaRentRecovery,
      SecurityLogEventType.tronStake => t.settings.securityLogTronStake,
      SecurityLogEventType.tronUnstake => t.settings.securityLogTronUnstake,
      SecurityLogEventType.tronWithdrawUnfreeze =>
        t.settings.securityLogTronWithdrawUnfreeze,
      SecurityLogEventType.tronCancelUnfreeze =>
        t.settings.securityLogTronCancelUnfreeze,
      SecurityLogEventType.tronDelegateResource =>
        t.settings.securityLogTronDelegateResource,
      SecurityLogEventType.tronUndelegateResource =>
        t.settings.securityLogTronUndelegateResource,
      SecurityLogEventType.tronVote => t.settings.securityLogTronVote,
      SecurityLogEventType.tronClaimReward =>
        t.settings.securityLogTronClaimReward,
    };
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String? get _amountText {
    final parts = [entry.amount, entry.assetSymbol]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? null : parts.join(' ');
  }
}
