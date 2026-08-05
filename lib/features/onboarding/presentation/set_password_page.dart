import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/biometric_password_prompt.dart';
import '../../../shared/security/wallet_password_policy.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_password_text_field.dart';

typedef PasswordSubmit = Future<void> Function(String password);

final class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({
    required this.onSubmit,
    required this.progressLabel,
    super.key,
  });

  final PasswordSubmit onSubmit;
  final String progressLabel;

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

final class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.onboarding.setPasswordTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            16,
            AppSpacing.pageX,
            24,
          ),
          children: [
            Text(t.onboarding.setPasswordBody, style: context.appTextStyles.bodySmall),
            const SizedBox(height: 20),
            AppPasswordTextField(
              fieldKey: const Key('passwordInput'),
              controller: _passwordController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: t.onboarding.passwordLabel,
              ),
            ),
            const SizedBox(height: 12),
            AppPasswordTextField(
              fieldKey: const Key('confirmPasswordInput'),
              controller: _confirmController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: t.onboarding.confirmPasswordLabel,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorMessage(message: _error!),
            ],
            const SizedBox(height: 24),
            AppButton.primary(
              label: t.actions.done,
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
                        Text(widget.progressLabel),
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
    final confirmation = _confirmController.text;

    if (password.isEmpty) {
      setState(() {
        _error = t.onboarding.passwordRequired;
      });
      return;
    }

    final passwordIssue = WalletPasswordPolicy.issueFor(password);
    if (passwordIssue != null) {
      setState(() {
        _error = switch (passwordIssue) {
          WalletPasswordIssue.tooShort => t.errors.walletPasswordTooShort,
          WalletPasswordIssue.tooCommon => t.errors.walletPasswordTooWeak,
        };
      });
      return;
    }

    if (password != confirmation) {
      setState(() {
        _error = t.onboarding.passwordMismatch;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    try {
      await widget.onSubmit(password);
      if (!mounted) {
        return;
      }
      await offerBiometricPasswordSetup(
        context: context,
        ref: ref,
        password: password,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
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
        _error = t.errors.unknown;
      });
    }
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
