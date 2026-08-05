import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';

final class WalletConnectScanPage extends StatefulWidget {
  const WalletConnectScanPage({super.key});

  @override
  State<WalletConnectScanPage> createState() => _WalletConnectScanPageState();
}

final class _WalletConnectScanPageState extends State<WalletConnectScanPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.advanced.walletConnectCameraTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageX),
          child: ClipRRect(
            borderRadius: AppRadius.largeBorder,
            child: ColoredBox(
              color: context.appColors.textPrimary,
              child: MobileScanner(
                onDetect: (capture) {
                  final value = capture.barcodes.firstOrNull?.rawValue;
                  if (!_handled && value != null) {
                    _handled = true;
                    Navigator.of(context).pop(value);
                  }
                },
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.pageX),
                    child: Text(
                      context.t.transfer.scanCameraError,
                      style: context.appTextStyles.bodySmall.copyWith(
                        color: context.appColors.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
