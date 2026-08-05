import 'package:flutter/material.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_icons.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../wallet_connect/presentation/wallet_connect_page.dart';
import '../../staking/presentation/tron_staking_page.dart';
import 'evm_contract_call_page.dart';
import 'solana_rent_recovery_page.dart';
import 'wrapped_native_page.dart';

final class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.advanced.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          children: [
            _AdvancedRow(
              icon: AppIcons.code,
              title: context.t.advanced.contractCall,
              subtitle: context.t.advanced.contractCallSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const EvmContractCallPage(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _AdvancedRow(
              key: const Key('advancedWrappedNative'),
              icon: AppIcons.swap,
              title: context.t.advanced.wrappedNative,
              subtitle: context.t.advanced.wrappedNativeSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WrappedNativePage(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _AdvancedRow(
              key: const Key('advancedSolanaRentRecovery'),
              icon: AppIcons.solana,
              title: context.t.advanced.solanaRentRecovery,
              subtitle: context.t.advanced.solanaRentRecoverySubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SolanaRentRecoveryPage(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _AdvancedRow(
              key: const Key('advancedTronStaking'),
              icon: AppIcons.staking,
              title: context.t.tronStaking.title,
              subtitle: context.t.tronStaking.advancedSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TronStakingPage(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _AdvancedRow(
              key: const Key('advancedWalletConnect'),
              icon: AppIcons.link,
              title: context.t.advanced.walletConnect,
              subtitle: context.t.advanced.walletConnectSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WalletConnectPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AdvancedRow extends StatelessWidget {
  const _AdvancedRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.xLargeBorder,
      onTap: onTap,
      child: AppSectionCard(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
        borderRadius: AppRadius.xLargeBorder,
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.appTextStyles.bodyLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: context.appTextStyles.bodySmall),
                ],
              ),
            ),
            const Icon(AppIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}
