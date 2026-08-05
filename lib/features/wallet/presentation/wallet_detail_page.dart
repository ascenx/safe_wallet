import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/utils/receive_qr_payload.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../chains/domain/chain_config.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_account.dart';
import 'export_secret_confirm_page.dart';

final class WalletDetailPage extends StatelessWidget {
  const WalletDetailPage({
    required this.wallet,
    super.key,
  });

  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(wallet.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          children: [
            if (wallet.evmAddress.isNotEmpty)
              _AddressCard(
                label: t.wallet.evmAddress,
                address: wallet.evmAddress,
                chainType: ChainType.evm,
                walletName: wallet.name,
              ),
            if (wallet.solanaAddress.isNotEmpty)
              _AddressCard(
                label: t.wallet.solanaAddress,
                address: wallet.solanaAddress,
                chainType: ChainType.solana,
                walletName: wallet.name,
              ),
            if (wallet.tronAddress.isNotEmpty)
              _AddressCard(
                label: t.wallet.tronAddress,
                address: wallet.tronAddress,
                chainType: ChainType.tron,
                walletName: wallet.name,
              ),
            if (wallet.btcAddress.isNotEmpty)
              _AddressCard(
                label: t.wallet.btcAddress,
                address: wallet.btcAddress,
                chainType: ChainType.bitcoin,
                walletName: wallet.name,
              ),
            const SizedBox(height: AppSpacing.sectionY),
            ..._exportActions(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _exportActions(BuildContext context) {
    final actions = <Widget>[];
    void addAction(Widget button) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(height: 8));
      }
      actions.add(button);
    }

    if (wallet.source == WalletAccountSource.mnemonic) {
      addAction(
        AppButton.primary(
          key: const Key('exportMnemonicButton'),
          label: t.wallet.exportMnemonic,
          onPressed: () => _pushExport(
            context,
            WalletSecretType.mnemonic,
          ),
        ),
      );
    }
    if (wallet.evmAddress.isNotEmpty) {
      addAction(
        AppButton.secondary(
          key: const Key('exportEvmPrivateKeyButton'),
          label: t.wallet.exportPrivateKey,
          onPressed: () => _pushExport(
            context,
            WalletSecretType.evmPrivateKey,
          ),
        ),
      );
    }
    if (wallet.btcAddress.isNotEmpty) {
      addAction(
        AppButton.secondary(
          key: const Key('exportBtcPrivateKeyButton'),
          label: t.wallet.exportBtcPrivateKey,
          onPressed: () => _pushExport(
            context,
            WalletSecretType.btcPrivateKey,
          ),
        ),
      );
    }
    if (wallet.tronAddress.isNotEmpty) {
      addAction(
        AppButton.secondary(
          key: const Key('exportTronPrivateKeyButton'),
          label: t.wallet.exportPrivateKey,
          onPressed: () => _pushExport(
            context,
            WalletSecretType.tronPrivateKey,
          ),
        ),
      );
    }
    return actions;
  }

  Future<void> _pushExport(
    BuildContext context,
    WalletSecretType secretType,
  ) {
    return showExportSecretFlow(
      context,
      wallet: wallet,
      secretType: secretType,
    );
  }
}

final class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.label,
    required this.address,
    required this.chainType,
    required this.walletName,
  });

  final String label;
  final String address;
  final ChainType chainType;
  final String walletName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: AppRadius.mediumBorder,
          border: Border.all(color: context.appColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.appTextStyles.bodyLarge),
              const SizedBox(height: 8),
              Center(
                child: QrImageView(
                  data: _qrData,
                  size: 180,
                  semanticsLabel: _qrData,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText.rich(
                highlightedAddressTextSpan(
                  address,
                  style: context.appTextStyles.caption,
                  highlightColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _qrData {
    return receiveQrPayloadForChain(
      chainType: chainType,
      address: address,
      chainName: chainType == ChainType.evm ? 'EVM' : null,
      label: chainType == ChainType.evm ? walletName : null,
    );
  }
}
