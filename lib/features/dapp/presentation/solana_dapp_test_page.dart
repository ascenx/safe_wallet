import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';

final class SolanaDappTestPage extends ConsumerWidget {
  const SolanaDappTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChain = ref.watch(selectedChainControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.dapp.solanaTestTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            16,
            AppSpacing.pageX,
            24,
          ),
          children: [
            Text(t.dapp.solanaTestBody, style: context.appTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.sectionY),
            _BoundaryStatus(),
            const SizedBox(height: AppSpacing.sectionY),
            selectedChain.when(
              data: (chain) => _InfoRow(
                label: t.dapp.chain,
                value: chain.chainType == ChainType.solana
                    ? chain.name
                    : t.dapp.solanaNonSolanaChain,
              ),
              error: (_, _) => _InfoRow(
                label: t.dapp.chain,
                value: t.errors.unknown,
              ),
              loading: () => _InfoRow(
                label: t.dapp.chain,
                value: t.onboarding.loadingWallet,
              ),
            ),
            FutureBuilder<WalletAccount?>(
              future: _selectedWallet(ref),
              builder: (context, snapshot) {
                final wallet = snapshot.data;
                return _InfoRow(
                  label: t.wallet.solanaAddress,
                  value: wallet?.solanaAddress.isNotEmpty == true
                      ? wallet!.solanaAddress
                      : t.dapp.solanaUnavailable,
                  isAddress: wallet?.solanaAddress.isNotEmpty == true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<WalletAccount?> _selectedWallet(WidgetRef ref) async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    if (selectedWalletId == null) {
      return wallets.isEmpty ? null : wallets.first;
    }
    for (final wallet in wallets) {
      if (wallet.id == selectedWalletId) {
        return wallet;
      }
    }
    return wallets.isEmpty ? null : wallets.first;
  }
}

final class _BoundaryStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: AppRadius.largeBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.dapp.solanaBoundaryReserved,
              style: context.appTextStyles.titleMedium,
            ),
            const SizedBox(height: 12),
            _CheckRow(text: t.dapp.solanaConnectCheck),
            _CheckRow(text: t.dapp.solanaSignCheck),
            _CheckRow(text: t.dapp.solanaTransactionCheck),
          ],
        ),
      ),
    );
  }
}

final class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(AppIcons.checkCircleFilled,
              size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.appTextStyles.bodySmall)),
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
          borderRadius: AppRadius.mediumBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.appTextStyles.caption),
              const SizedBox(height: 4),
              if (isAddress)
                Text.rich(
                  highlightedAddressTextSpan(
                    value,
                    style: context.appTextStyles.bodySmall,
                    highlightColor: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                Text(value, style: context.appTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
