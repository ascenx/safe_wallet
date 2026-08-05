import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/biometric_password_prompt.dart';
import '../../../shared/security/biometric_password_store.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_password_text_field.dart';
import '../application/wallet_session_controller.dart';
import '../domain/wallet_account.dart';

final class UnlockWalletPage extends ConsumerStatefulWidget {
  const UnlockWalletPage({
    required this.account,
    this.popOnSuccess = false,
    super.key,
  });

  final WalletAccount account;
  final bool popOnSuccess;

  @override
  ConsumerState<UnlockWalletPage> createState() => _UnlockWalletPageState();
}

final class _UnlockWalletPageState extends ConsumerState<UnlockWalletPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricUnlock();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.popOnSuccess ? AppBar() : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            42,
            AppSpacing.pageX,
            24,
          ),
          children: [
            const _UnlockIcon(),
            const SizedBox(height: 22),
            Text(t.wallet.unlockTitle, style: context.appTextStyles.titleLarge),
            const SizedBox(height: 10),
            Text(t.wallet.unlockBody, style: context.appTextStyles.bodySmall),
            const SizedBox(height: 20),
            Text(
              widget.account.name,
              style: context.appTextStyles.bodyMedium.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppPasswordTextField(
              fieldKey: const Key('unlockPasswordInput'),
              controller: _passwordController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: t.onboarding.passwordLabel,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorMessage(message: _error!),
            ],
            const SizedBox(height: 24),
            AppButton.primary(
              label: t.wallet.unlockButton,
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(t.wallet.unlocking),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _error = t.onboarding.passwordRequired;
      });
      return;
    }

    await _unlockWithPassword(password, offerBiometricSetup: true);
  }

  Future<void> _tryBiometricUnlock() async {
    final result = await ref
        .read(biometricPasswordStoreProvider)
        .readUnlockMaterialWithStatus(
          walletId: widget.account.id,
          reason: t.wallet.biometricReason,
        );
    final walletDeks = result.walletDeks;
    if (!mounted || walletDeks.isEmpty) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref
          .read(walletSessionControllerProvider.notifier)
          .unlockWithWalletKeys(
            account: widget.account,
            walletDeks: walletDeks,
          );
      if (!mounted) {
        return;
      }
      if (widget.popOnSuccess) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = t.errors.securityCheckFailed;
        });
      }
    }
  }

  Future<void> _unlockWithPassword(
    String password, {
    required bool offerBiometricSetup,
  }) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(walletSessionControllerProvider.notifier)
          .unlock(walletId: widget.account.id, password: password);
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
      if (!mounted) {
        return;
      }
      if (widget.popOnSuccess) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = const ErrorLocalizer().messageFor(error, t);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = t.errors.securityCheckFailed;
      });
    }
  }
}

final class _UnlockIcon extends StatelessWidget {
  const _UnlockIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brandColors.primarySoft,
        borderRadius: AppRadius.largeBorder,
      ),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Icon(
          AppIcons.unlock,
          color: Theme.of(context).colorScheme.primary,
          size: 32,
        ),
      ),
    );
  }
}

final class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.dangerSoft,
        borderRadius: AppRadius.mediumBorder,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.error, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: context.appTextStyles.bodySmall.copyWith(
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
