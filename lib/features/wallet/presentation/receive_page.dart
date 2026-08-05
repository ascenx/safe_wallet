import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/receive_qr_payload.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../assets/application/asset_portfolio_provider.dart';
import '../../assets/data/asset_repository.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../application/receive_qr_image_saver.dart';
import '../application/receive_qr_image_saver_provider.dart';
import '../application/selected_wallet_controller.dart';
import '../application/wallet_repository_provider.dart';
import '../domain/wallet_account.dart';
import 'widgets/address_qr_card.dart';

final class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage({super.key});

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

final class _ReceivePageState extends ConsumerState<ReceivePage> {
  final GlobalKey _receiveQrBoundaryKey = GlobalKey();
  late final Future<WalletAccount?> _selectedWalletFuture;
  String? _requestedAmount;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedWalletFuture = _selectedWallet();
  }

  @override
  Widget build(BuildContext context) {
    final selectedChain = ref.watch(selectedChainControllerProvider);
    final portfolioValue = ref.watch(assetPortfolioProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.actions.receive)),
      body: SafeArea(
        child: selectedChain.when(
          data: (chain) => FutureBuilder<WalletAccount?>(
            future: _selectedWalletFuture,
            builder: (context, snapshot) {
              final wallet = snapshot.data;
              if (wallet == null) {
                return Center(
                  child: Text(t.home.noWallet, style: context.appTextStyles.bodySmall),
                );
              }
              final address = _addressFor(chain, wallet);
              if (address.trim().isEmpty) {
                return AppEmptyState(message: t.wallet.noAddressForChain);
              }
              final amount = _requestedAmount;
              final qrData = receiveQrPayloadForChain(
                chainType: chain.chainType,
                address: address,
                chainId: chain.chainId,
                decimal: chain.chainType == ChainType.evm ? '18' : null,
                symbol: chain.symbol,
                chainName: chain.name,
                label: wallet.name,
                amount: amount,
              );
              final amountSummary = amount == null
                  ? null
                  : _amountSummary(
                      amount: amount,
                      symbol: chain.symbol,
                      priceUsd: _nativePriceUsd(
                        portfolioValue.value,
                        chain,
                      ),
                    );
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  16,
                  AppSpacing.pageX,
                  24,
                ),
                children: [
                  AddressQrCard(
                    title: t.wallet.receiveQrTitle(
                      walletName: wallet.name,
                      chainName: chain.name,
                    ),
                    address: address,
                    qrData: qrData,
                    amountSummary: amountSummary,
                    exportBoundaryKey: _receiveQrBoundaryKey,
                    isSaving: _isSaving,
                    onEditAmount: _showAmountDialog,
                    onRemoveAmount: _removeAmount,
                    onSave: () => _saveReceiveQr(
                      _receiveQrBoundaryKey,
                      chain.name,
                    ),
                    onCopy: () => _copyAddress(context, address),
                  ),
                ],
              );
            },
          ),
          error: (_, _) => Center(
            child: Text(t.chains.loadFailed, style: context.appTextStyles.bodySmall),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<WalletAccount?> _selectedWallet() async {
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

  String _addressFor(ChainConfig chain, WalletAccount wallet) {
    return switch (chain.chainType) {
      ChainType.evm => wallet.evmAddress,
      ChainType.bitcoin => wallet.btcAddress,
      ChainType.tron => wallet.tronAddress,
      ChainType.solana => wallet.solanaAddress,
      ChainType.sui => wallet.suiAddress,
    };
  }

  double? _nativePriceUsd(AssetPortfolio? portfolio, ChainConfig chain) {
    if (portfolio == null || portfolio.status != AssetPortfolioStatus.loaded) {
      return null;
    }
    for (final balance in portfolio.balances) {
      if (balance.chainId == chain.chainId &&
          balance.token.contractAddress == null) {
        return balance.priceUsd;
      }
    }
    return null;
  }

  String _amountSummary({
    required String amount,
    required String symbol,
    required double? priceUsd,
  }) {
    final amountValue = double.tryParse(amount);
    if (amountValue == null || priceUsd == null) {
      return '$amount $symbol';
    }
    final fiatValue = formatUsdValue(amountValue * priceUsd);
    return '$amount $symbol ${t.wallet.amountApproxPrefix} '
        '$fiatValue ${t.wallet.usdCode}';
  }

  Future<void> _showAmountDialog() async {
    final amount = await AppDialog.showBuilder<String>(
      context: context,
      builder: (_) => _ReceiveAmountDialog(initialAmount: _requestedAmount),
    );
    if (amount == null || !mounted) {
      return;
    }
    setState(() {
      _requestedAmount = amount;
    });
  }

  void _removeAmount() {
    setState(() {
      _requestedAmount = null;
    });
  }

  Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) {
      return;
    }
    AppToast.show(
      context,
      message: t.wallet.addressCopied,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _saveReceiveQr(GlobalKey boundaryKey, String chainName) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Receive QR export boundary is unavailable.');
      }

      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Receive QR image encoding failed.');
      }

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final fileName =
          'safe-wallet-${_chainFileNameSegment(chainName)}-receive-${DateTime.now().millisecondsSinceEpoch}.png';
      await ref.read(receiveQrImageSaverProvider).save(
            bytes,
            fileName: fileName,
          );

      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: t.wallet.qrImageSaved,
        variant: AppToastVariant.success,
      );
    } on ReceiveQrImageSaveException catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error.failure) {
        ReceiveQrImageSaveFailure.permissionDenied =>
          t.wallet.qrImagePhotoPermissionRequired,
        ReceiveQrImageSaveFailure.saveFailed => t.wallet.qrImageSaveFailed,
      };
      AppToast.show(
        context,
        message: message,
        variant: AppToastVariant.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: t.wallet.qrImageSaveFailed,
        variant: AppToastVariant.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _chainFileNameSegment(String chainName) {
    final segment = chainName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return segment.isEmpty ? 'chain' : segment;
  }
}

final class _ReceiveAmountDialog extends StatefulWidget {
  const _ReceiveAmountDialog({required this.initialAmount});

  final String? initialAmount;

  @override
  State<_ReceiveAmountDialog> createState() => _ReceiveAmountDialogState();
}

final class _ReceiveAmountDialogState extends State<_ReceiveAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAmount ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: t.wallet.enterAmountTitle,
      content: TextField(
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        autocorrect: false,
        autofocus: true,
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_DecimalAmountInputFormatter()],
        decoration: InputDecoration(labelText: t.wallet.amount),
      ),
      cancelCallback: () => Navigator.of(context).pop(),
      confirmTitle: t.wallet.amountConfirm,
      confirmCallback: () {
        Navigator.of(context).pop(_normalizedAmount(_controller.text));
      },
    );
  }
}

final class _DecimalAmountInputFormatter extends TextInputFormatter {
  static final _validAmountInput = RegExp(r'^\d*\.?\d*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_validAmountInput.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

String? _normalizedAmount(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final normalized = trimmed.startsWith('.') ? '0$trimmed' : trimmed;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) {
    return null;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return normalized;
}
