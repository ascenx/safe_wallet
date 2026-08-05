import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../advanced/presentation/advanced_settings_page.dart';
import '../../address_book/presentation/address_book_page.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../wallet/presentation/wallet_management_page.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import 'about_page.dart';
import 'network_management_page.dart';
import 'preferences_settings_page.dart';
import 'security_settings_page.dart';

final _settingsWalletsProvider = FutureProvider<List<WalletAccount>>((ref) {
  ref.watch(selectedWalletIdProvider);
  return ref.watch(walletRepositoryProvider).getWallets();
});

final class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t;
    final walletsValue = ref.watch(_settingsWalletsProvider);
    final selectedWalletId = ref.watch(selectedWalletIdProvider);
    final selectedChainValue = ref.watch(selectedChainControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            18,
            AppSpacing.pageX,
            0,
          ),
          children: [
            Text(strings.tabs.settings, style: context.appTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sectionY),
            _WalletSummaryCard(
              walletsValue: walletsValue,
              selectedWalletId: selectedWalletId,
              selectedChain: selectedChainValue.value,
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _SettingsRow(
              icon: AppIcons.wallet,
              label: strings.settings.walletManagement,
              onTap: () => _push(context, const WalletManagementPage()),
            ),
            _SettingsRow(
              icon: AppIcons.network,
              label: strings.settings.networkManagement,
              onTap: () => _push(context, const NetworkManagementPage()),
            ),
            _SettingsRow(
              icon: AppIcons.contacts,
              label: strings.settings.addressBook,
              onTap: () => _push(context, const AddressBookPage()),
            ),
            _SettingsRow(
              icon: AppIcons.tools,
              label: strings.settings.advanced,
              onTap: () => _push(context, const AdvancedSettingsPage()),
            ),
            _SettingsRow(
              icon: AppIcons.security,
              label: strings.settings.security,
              onTap: () => _push(context, const SecuritySettingsPage()),
            ),
            _SettingsRow(
              icon: AppIcons.filters,
              label: strings.settings.preferences,
              onTap: () => _push(context, const PreferencesSettingsPage()),
            ),
            _SettingsRow(
              icon: AppIcons.info,
              label: strings.settings.about,
              onTap: () => _push(context, const AboutPage()),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

final class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.walletsValue,
    required this.selectedWalletId,
    required this.selectedChain,
  });

  final AsyncValue<List<WalletAccount>> walletsValue;
  final String? selectedWalletId;
  final ChainConfig? selectedChain;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
      borderRadius: AppRadius.xLargeBorder,
      child: walletsValue.when(
        data: (wallets) {
          final wallet = _currentWallet(wallets);
          if (wallet == null) {
            return Text(t.home.noWallet, style: context.appTextStyles.bodyLarge);
          }
          final address = _currentAddress(wallet);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: context.brandColors.primarySoft,
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(AppIcons.wallet),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wallet.name, style: context.appTextStyles.titleMedium),
                    const SizedBox(height: 6),
                    if (address.value.trim().isEmpty)
                      Text(
                        t.wallet.noAddressForChain,
                        style: context.appTextStyles.bodySmall,
                      )
                    else
                      Text.rich(
                        TextSpan(
                          style: context.appTextStyles.bodySmall,
                          children: [
                            TextSpan(text: '${address.label}: '),
                            highlightedAddressTextSpan(
                              address.value,
                              style: context.appTextStyles.bodySmall,
                              highlightColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${t.dapp.chain}: '
                      '${selectedChain?.name ?? t.settings.currentRpcUnknown}',
                      style: context.appTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        error: (_, _) =>
            Text(t.errors.unknown, style: context.appTextStyles.bodySmall),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  WalletAccount? _currentWallet(List<WalletAccount> wallets) {
    if (wallets.isEmpty) {
      return null;
    }
    final walletId = selectedWalletId;
    if (walletId == null) {
      return wallets.first;
    }
    return wallets.where((wallet) => wallet.id == walletId).firstOrNull;
  }

  ({String label, String value}) _currentAddress(WalletAccount wallet) {
    return switch (selectedChain?.chainType) {
      ChainType.bitcoin => (
        label: t.wallet.btcAddress,
        value: wallet.btcAddress,
      ),
      ChainType.solana => (
        label: t.wallet.solanaAddress,
        value: wallet.solanaAddress,
      ),
      ChainType.tron => (
        label: t.wallet.tronAddress,
        value: wallet.tronAddress,
      ),
      ChainType.sui => (label: t.wallet.suiAddress, value: wallet.suiAddress),
      ChainType.evm ||
      null => (label: t.wallet.evmAddress, value: wallet.evmAddress),
    };
  }
}

final class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: InkWell(
        borderRadius: AppRadius.xLargeBorder,
        onTap: onTap,
        child: AppSectionCard(
          padding: const EdgeInsets.all(AppSpacing.cardPaddingLarge),
          borderRadius: AppRadius.xLargeBorder,
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: context.appTextStyles.bodyLarge)),
              Icon(
                AppIcons.chevronRight,
                color: context.appColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
