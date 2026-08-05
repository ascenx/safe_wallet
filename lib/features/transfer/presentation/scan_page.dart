import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/utils/address_parser.dart';
import '../../../shared/utils/bitcoin_address.dart';
import '../../assets/application/asset_portfolio_provider.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../application/transfer_draft_controller.dart';
import 'transfer_page.dart';

final class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({this.initialScanValue, this.autoNavigate = true, super.key});

  final String? initialScanValue;
  final bool autoNavigate;

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

final class _ScanPageState extends ConsumerState<ScanPage> {
  String? _error;
  bool _handledScan = false;

  @override
  void initState() {
    super.initState();
    final initialScanValue = widget.initialScanValue;
    if (initialScanValue != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleRawValue(initialScanValue);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialScanValue = widget.initialScanValue;

    return Scaffold(
      appBar: AppBar(title: Text(t.transfer.scanTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.transfer.scanInstruction,
                style: context.appTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sectionY),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.appColors.textPrimary,
                    borderRadius: AppRadius.largeBorder,
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.largeBorder,
                    child: initialScanValue == null
                        ? _buildScanner()
                        : Center(
                            child: Text(
                              t.transfer.scanSuccess,
                              style: context.appTextStyles.bodySmall.copyWith(
                                color: context.appColors.surface,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sectionY),
                Text(
                  _error!,
                  style: context.appTextStyles.bodySmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return MobileScanner(
      onDetect: _handleBarcodeCapture,
      errorBuilder: _buildScannerError,
    );
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue != null) {
      _handleRawValue(rawValue);
    }
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        t.transfer.scanCameraPermissionDenied,
      MobileScannerErrorCode.unsupported => t.transfer.scanCameraUnsupported,
      _ => t.transfer.scanCameraError,
    };
    return _ScannerErrorView(message: message);
  }

  Future<void> _handleRawValue(String rawValue) async {
    if (_handledScan) {
      return;
    }
    final parsed = parseWalletAddress(rawValue);
    if (parsed == null) {
      setState(() {
        _error = t.transfer.scanInvalid;
      });
      return;
    }

    _handledScan = true;
    await _selectScannedChain(parsed);
    if (!mounted) {
      return;
    }
    final initialAmount = await _resolveScannedAmount(parsed);
    if (!mounted) {
      return;
    }
    ref
        .read(transferDraftControllerProvider.notifier)
        .prefillRecipient(parsed.address);
    if (!widget.autoNavigate) {
      setState(() {
        _error = null;
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TransferPage(
          initialRecipient: parsed.address,
          initialContractAddress: parsed.transferContractAddress,
          initialAmount: initialAmount,
          initialMemo: parsed.memo,
        ),
      ),
    );
  }

  Future<void> _selectScannedChain(ParsedWalletAddress parsed) async {
    final current = await ref.read(selectedChainControllerProvider.future);
    if (_chainMatchesParsedAddress(current, parsed)) {
      return;
    }
    final chains = await ref.read(availableChainsProvider.future);
    for (final chain in chains) {
      if (_chainMatchesParsedAddress(chain, parsed)) {
        await ref
            .read(selectedChainControllerProvider.notifier)
            .selectChain(chain.id);
        return;
      }
    }
  }

  bool _chainMatchesParsedAddress(
    ChainConfig chain,
    ParsedWalletAddress parsed,
  ) {
    if (chain.chainType != parsed.chainType) {
      return false;
    }
    final evmChainId = parsed.evmChainId;
    if (evmChainId != null && chain.chainId != evmChainId) {
      return false;
    }
    final bitcoinNetwork = parsed.bitcoinNetwork;
    if (bitcoinNetwork == null) {
      return true;
    }
    return chain.isTestnet == (bitcoinNetwork == BitcoinAddressNetwork.testnet);
  }

  Future<String?> _resolveScannedAmount(ParsedWalletAddress parsed) async {
    final amount = parsed.amount;
    if (amount != null) {
      return amount;
    }
    final baseUnits = parsed.amountBaseUnits;
    final contractAddress = parsed.transferContractAddress;
    if (baseUnits == null || contractAddress == null) {
      return null;
    }
    try {
      final portfolio = await ref.read(assetPortfolioProvider.future);
      final normalizedContract = contractAddress.toLowerCase();
      final balance = portfolio.balances.firstWhere(
        (candidate) =>
            candidate.token.contractAddress?.toLowerCase() ==
            normalizedContract,
      );
      return _formatScannedBaseUnits(
        BigInt.parse(baseUnits),
        balance.token.decimals,
      );
    } catch (_) {
      return null;
    }
  }
}

String _formatScannedBaseUnits(BigInt value, int decimals) {
  if (decimals <= 0) {
    return value.toString();
  }
  final base = BigInt.from(10).pow(decimals);
  final whole = value ~/ base;
  final fraction = (value % base).toString().padLeft(decimals, '0');
  final trimmedFraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  if (trimmedFraction.isEmpty) {
    return whole.toString();
  }
  return '$whole.$trimmedFraction';
}

final class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionY),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.cameraOff,
              color: context.appColors.surface,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.appTextStyles.bodySmall.copyWith(
                color: context.appColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
