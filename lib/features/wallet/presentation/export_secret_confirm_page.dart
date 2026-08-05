import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/application/settings_controller.dart';
import '../../../features/settings/data/security_log_repository.dart';
import '../../../features/settings/domain/security_log_entry.dart';
import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/biometric_password_prompt.dart';
import '../../../shared/security/sensitive_screen_protection.dart';
import '../../../shared/security/sensitive_clipboard.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_password_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/risk_notice.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_account.dart';

Future<void> showExportSecretFlow(
  BuildContext context, {
  required WalletAccount wallet,
  required WalletSecretType secretType,
}) async {
  final secret = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: context.appColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xLarge),
      ),
    ),
    builder: (_) =>
        _ExportSecretPasswordSheet(wallet: wallet, secretType: secretType),
  );
  if (secret == null || !context.mounted) {
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExportSecretConfirmPage(
        secret: secret,
        secretType: secretType,
        wallet: wallet,
      ),
    ),
  );
}

final class ExportSecretConfirmPage extends StatelessWidget {
  const ExportSecretConfirmPage({
    required this.secret,
    required this.secretType,
    this.wallet,
    super.key,
  });

  final String secret;
  final WalletSecretType secretType;
  final WalletAccount? wallet;

  @override
  Widget build(BuildContext context) {
    return SensitiveScreenProtectionScope(
      child: Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: SafeArea(
          child: _ExportSecretContent(
            secret: secret,
            secretType: secretType,
            wallet: wallet,
          ),
        ),
      ),
    );
  }

  String get _title {
    return switch (secretType) {
      WalletSecretType.mnemonic => t.wallet.exportMnemonic,
      WalletSecretType.evmPrivateKey => t.wallet.exportPrivateKey,
      WalletSecretType.btcPrivateKey => t.wallet.exportBtcPrivateKey,
      WalletSecretType.tronPrivateKey => t.wallet.exportPrivateKey,
      WalletSecretType.solanaPrivateKey => t.wallet.exportPrivateKey,
      WalletSecretType.suiPrivateKey => t.wallet.exportPrivateKey,
    };
  }
}

final class _ExportSecretPasswordSheet extends ConsumerStatefulWidget {
  const _ExportSecretPasswordSheet({
    required this.wallet,
    required this.secretType,
  });

  final WalletAccount wallet;
  final WalletSecretType secretType;

  @override
  ConsumerState<_ExportSecretPasswordSheet> createState() =>
      _ExportSecretPasswordSheetState();
}

final class _ExportSecretPasswordSheetState
    extends ConsumerState<_ExportSecretPasswordSheet> {
  final _passwordController = TextEditingController();
  String? _passwordError;
  String? _submitError;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      key: Key('exportSecretPasswordSheet-${widget.secretType.name}'),
      title: t.wallet.exportPasswordTitle,
      subtitle: t.wallet.exportPasswordBody,
      onCancel: _cancel,
      onConfirm: _submit,
      confirmTitle: t.actions.confirm,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPasswordTextField(
            autofocus: true,
            enabled: !_isLoading,
            fieldKey: const Key('exportSecretPasswordInput'),
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: t.onboarding.passwordLabel,
              errorText: _passwordError,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              _submitError!,
              style: context.appTextStyles.bodySmall.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _cancel() {
    if (_isLoading) {
      return;
    }
    Navigator.of(context).pop<String>();
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = t.onboarding.passwordRequired;
      });
      return;
    }

    setState(() {
      _passwordError = null;
      _submitError = null;
    });
    await _exportWithPassword(password, offerBiometricSetup: true);
  }

  Future<void> _exportWithPassword(
    String password, {
    required bool offerBiometricSetup,
  }) async {
    setState(() {
      _isLoading = true;
      _submitError = null;
    });
    try {
      final secret = await ref
          .read(settingsControllerProvider.notifier)
          .exportSecret(
            walletId: widget.wallet.id,
            password: password,
            secretType: widget.secretType,
          );
      if (!mounted) {
        return;
      }
      if (offerBiometricSetup) {
        await offerBiometricPasswordSetup(
          context: context,
          ref: ref,
          password: password,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(secret);
      }
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = const ErrorLocalizer().messageFor(error, t);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = t.errors.securityCheckFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

final class _ExportSecretContent extends ConsumerWidget {
  const _ExportSecretContent({
    required this.secret,
    required this.secretType,
    required this.wallet,
  });

  final String secret;
  final WalletSecretType secretType;
  final WalletAccount? wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageX),
      children: [
        RiskNotice(
          key: const Key('exportSecretRiskNotice'),
          level: RiskLevel.danger,
          message: _riskWarning,
        ),
        const SizedBox(height: AppSpacing.sectionY),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.dangerSoft,
            borderRadius: AppRadius.mediumBorder,
            border: Border.all(color: AppColors.danger),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Text(
              secret,
              key: const Key('exportSecretValue'),
              style: context.appTextStyles.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sectionY),
        AppButton.secondary(
          key: const Key('exportSecretCopyButton'),
          label: t.wallet.copy,
          icon: const Icon(AppIcons.copy),
          onPressed: () => _copySecret(context, ref),
        ),
      ],
    );
  }

  bool get _isMnemonic => secretType == WalletSecretType.mnemonic;

  String get _riskWarning => _isMnemonic
      ? t.wallet.mnemonicRiskWarning
      : t.wallet.privateKeyRiskWarning;

  String get _copiedMessage =>
      _isMnemonic ? t.wallet.mnemonicCopied : t.wallet.privateKeyCopied;

  Future<void> _copySecret(BuildContext context, WidgetRef ref) async {
    await SensitiveClipboardService.instance.copy(secret);
    try {
      await ref
          .read(securityLogRepositoryProvider)
          .record(
            _isMnemonic
                ? SecurityLogEventType.copyMnemonic
                : SecurityLogEventType.copyPrivateKey,
            walletName: wallet?.name,
            chainName: _chainName,
          );
    } catch (_) {
      // Clipboard success must not depend on best-effort audit persistence.
    }
    if (!context.mounted) {
      return;
    }
    AppToast.show(
      context,
      message: _copiedMessage,
      variant: AppToastVariant.success,
    );
  }

  String? get _chainName {
    return switch (secretType) {
      WalletSecretType.mnemonic => null,
      WalletSecretType.evmPrivateKey => 'EVM',
      WalletSecretType.btcPrivateKey => 'Bitcoin',
      WalletSecretType.tronPrivateKey => 'Tron',
      WalletSecretType.solanaPrivateKey => 'Solana',
      WalletSecretType.suiPrivateKey => 'Sui',
    };
  }
}
