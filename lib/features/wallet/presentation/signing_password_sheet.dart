import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/biometric_password_store.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_drag_handle.dart';
import '../../../shared/widgets/app_password_text_field.dart';
import '../application/selected_wallet_controller.dart';
import '../application/wallet_repository_provider.dart';
import '../application/wallet_session_controller.dart';
import '../domain/wallet_account.dart';

final class SigningPasswordAuthorization {
  const SigningPasswordAuthorization({
    required this.password,
    required this.rememberPassword,
  });

  final String password;
  final bool rememberPassword;
}

Future<SigningPasswordAuthorization?> showSigningPasswordSheet(
  BuildContext context,
) {
  return showModalBottomSheet<SigningPasswordAuthorization>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (_) => const SigningPasswordSheet(),
  );
}

final class SigningPasswordSheet extends ConsumerStatefulWidget {
  const SigningPasswordSheet({super.key});

  @override
  ConsumerState<SigningPasswordSheet> createState() =>
      _SigningPasswordSheetState();
}

final class _SigningPasswordSheetState
    extends ConsumerState<SigningPasswordSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isCheckingBiometrics = true;
  bool _isSubmitting = false;
  bool _hasBiometricCredential = false;
  bool _showManualPassword = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricAuthorization();
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          0,
          AppSpacing.pageX,
          AppSpacing.pageX + bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppDragHandle(),
            Text(
              t.wallet.signingPasswordTitle,
              style: context.appTextStyles.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              t.wallet.signingPasswordBody,
              style: context.appTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sectionY),
            if (_isCheckingBiometrics)
              const Center(child: CircularProgressIndicator())
            else if (_showManualPassword)
              AppPasswordTextField(
                fieldKey: const Key('signingPasswordInput'),
                controller: _passwordController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: t.onboarding.passwordLabel,
                  errorText: _passwordError,
                ),
                onSubmitted: (_) => _submit(),
              )
            else if (_hasBiometricCredential) ...[
              AppButton.secondary(
                key: const Key('signingUseBiometricButton'),
                label: t.wallet.biometricUseButton,
                onPressed: _isSubmitting ? null : _tryBiometricAuthorization,
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('signingUsePasswordButton'),
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _showManualPassword = true;
                          _passwordError = null;
                        });
                      },
                child: Text(t.wallet.unlockButton),
              ),
            ],
            const SizedBox(height: AppSpacing.sectionY),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: t.actions.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    label: t.actions.confirm,
                    onPressed: _showManualPassword && !_isSubmitting
                        ? _submit
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tryBiometricAuthorization() async {
    final account = await _selectedAccount();
    if (account == null) {
      if (mounted) {
        setState(() {
          _isCheckingBiometrics = false;
          _showManualPassword = true;
          _passwordError = t.errors.securityCheckFailed;
        });
      }
      return;
    }
    final result = await ref
        .read(biometricPasswordStoreProvider)
        .readUnlockMaterialWithStatus(
          walletId: account.id,
          reason: t.wallet.biometricReason,
        );
    if (!mounted) {
      return;
    }
    final hasCredential =
        result.canUseBiometrics && result.hasSavedCredential;
    final walletDeks = result.walletDeks;
    setState(() {
      _isCheckingBiometrics = false;
      _hasBiometricCredential = hasCredential;
      _showManualPassword = !hasCredential;
      _passwordError = null;
    });
    if (walletDeks.isEmpty) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await ref
          .read(walletSessionControllerProvider.notifier)
          .unlockWithWalletKeys(account: account, walletDeks: walletDeks);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        const SigningPasswordAuthorization(
          password: '',
          rememberPassword: true,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showManualPassword = true;
          _passwordError = t.errors.securityCheckFailed;
        });
      }
    }
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = t.onboarding.passwordRequired;
      });
      return;
    }
    final account = await _selectedAccount();
    if (account == null) {
      if (mounted) {
        setState(() {
          _passwordError = t.errors.securityCheckFailed;
        });
      }
      return;
    }
    setState(() {
      _isSubmitting = true;
      _passwordError = null;
    });
    try {
      await ref
          .read(walletSessionControllerProvider.notifier)
          .unlock(walletId: account.id, password: password);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        SigningPasswordAuthorization(
          password: password,
          rememberPassword: true,
        ),
      );
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _passwordError = const ErrorLocalizer().messageFor(error, t);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _passwordError = t.errors.securityCheckFailed;
      });
    }
  }

  Future<WalletAccount?> _selectedAccount() async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    if (selectedWalletId != null) {
      for (final wallet in wallets) {
        if (wallet.id == selectedWalletId) {
          return wallet;
        }
      }
    }
    return wallets.firstOrNull;
  }
}
