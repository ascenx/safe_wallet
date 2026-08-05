import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/biometric_password_store.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_password_text_field.dart';
import '../../settings/application/launch_unlock_controller.dart';
import '../application/wallet_session_controller.dart';
import '../domain/wallet_account.dart';

final class AppUnlockPage extends ConsumerStatefulWidget {
  const AppUnlockPage({required this.account, super.key});

  final WalletAccount account;

  @override
  ConsumerState<AppUnlockPage> createState() => _AppUnlockPageState();
}

final class _AppUnlockPageState extends ConsumerState<AppUnlockPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _showManualPassword = false;
  bool _hasBiometricPassword = false;
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pageX),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    AppIcons.lock,
                    color: Theme.of(context).colorScheme.primary,
                    size: 44,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.wallet.unlockTitle,
                    style: context.appTextStyles.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.wallet.unlockBody,
                    style: context.appTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sectionY),
                  if (_showManualPassword) ...[
                    AppPasswordTextField(
                      fieldKey: const Key('appUnlockPasswordInput'),
                      controller: _passwordController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: t.onboarding.passwordLabel,
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.sectionY),
                    AppButton.primary(
                      key: const Key('appUnlockButton'),
                      label: _isSubmitting
                          ? t.wallet.unlocking
                          : t.wallet.unlockButton,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ] else if (_hasBiometricPassword) ...[
                    AppButton.secondary(
                      label: t.wallet.biometricUseButton,
                      onPressed: _isSubmitting ? null : _tryBiometricUnlock,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('appUnlockUsePasswordButton'),
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _showManualPassword = true;
                                _error = null;
                              });
                            },
                      child: Text(t.wallet.unlockButton),
                    ),
                  ] else ...[
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _tryBiometricUnlock() async {
    final store = ref.read(biometricPasswordStoreProvider);
    final result = await store.readUnlockMaterialWithStatus(
      walletId: widget.account.id,
      reason: t.wallet.biometricReason,
    );
    final canUseSavedBiometricPassword =
        result.canUseBiometrics && result.hasSavedCredential;
    if (!mounted) {
      return;
    }
    setState(() {
      _hasBiometricPassword = canUseSavedBiometricPassword;
      _showManualPassword = !canUseSavedBiometricPassword;
      _error = null;
    });
    final walletDeks = result.walletDeks;
    if (walletDeks.isNotEmpty) {
      await _unlockWithWalletKeys(walletDeks);
      return;
    }
    final password = result.password;
    if (password == null) {
      return;
    }
    await _unlockWithPassword(password, provisionBiometricKey: true);
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _error = t.onboarding.passwordRequired;
      });
      return;
    }
    await _unlockWithPassword(password);
  }

  Future<void> _unlockWithPassword(
    String password, {
    bool provisionBiometricKey = false,
  }) async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final controller = ref.read(walletSessionControllerProvider.notifier);
      if (provisionBiometricKey) {
        await controller.unlockWithBiometricPassword(
          walletId: widget.account.id,
          password: password,
        );
      } else {
        await controller.unlock(
          walletId: widget.account.id,
          password: password,
        );
      }
      if (!mounted) {
        return;
      }
      ref.read(launchUnlockControllerProvider.notifier).markUnlocked();
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

  Future<void> _unlockWithWalletKeys(
    Map<String, List<int>> walletDeks,
  ) async {
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
      ref.read(launchUnlockControllerProvider.notifier).markUnlocked();
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
