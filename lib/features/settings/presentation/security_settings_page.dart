import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/biometric_password_prompt.dart';
import '../../../shared/security/wallet_password_policy.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_password_text_field.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../dapp/application/dapp_permission_controller.dart';
import '../../dapp/domain/dapp_permission.dart';
import '../application/background_privacy_shield_setting.dart';
import '../application/biometric_password_setting_controller.dart';
import '../application/launch_lock_setting.dart';
import '../application/security_log_controller.dart';
import '../application/settings_controller.dart';
import '../application/wallet_auto_lock_setting.dart';
import '../domain/security_log_entry.dart';
import 'security_log_page.dart';

final class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsValue = ref.watch(dappPermissionControllerProvider);
    final launchLockSetting = ref.watch(launchLockSettingProvider);
    final requirePasswordOnLaunch = launchLockSetting.hasValue
        ? launchLockSetting.value ?? true
        : true;
    final privacyShieldSetting = ref.watch(
      backgroundPrivacyShieldSettingProvider,
    );
    final privacyShieldEnabled = privacyShieldSetting.value ?? true;
    final autoLockSetting = ref.watch(walletAutoLockSettingProvider);
    final autoLockDuration =
        autoLockSetting.value ?? WalletAutoLockDuration.fiveMinutes;
    final biometricSetting = ref.watch(biometricPasswordSettingProvider);
    final biometricState = biometricSetting.value;
    final hasBiometricPassword = biometricState?.hasSavedPassword ?? false;
    final canChangeBiometricPassword =
        biometricState?.canUseBiometrics == true || hasBiometricPassword;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings.security)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.sectionY,
            AppSpacing.pageX,
            AppSpacing.pageX,
          ),
          children: [
            _SecuritySwitchRow(
              icon: AppIcons.resetPassword,
              title: t.settings.requirePasswordOnLaunch,
              subtitle: t.settings.requirePasswordOnLaunchSubtitle,
              value: requirePasswordOnLaunch,
              onChanged: launchLockSetting.isLoading
                  ? null
                  : (value) {
                      ref
                          .read(launchLockSettingProvider.notifier)
                          .setRequirePasswordOnLaunch(value);
                    },
            ),
            _SecuritySwitchRow(
              icon: AppIcons.hidden,
              title: t.settings.backgroundPrivacyShield,
              subtitle: t.settings.backgroundPrivacyShieldSubtitle,
              value: privacyShieldEnabled,
              onChanged: privacyShieldSetting.isLoading
                  ? null
                  : (value) {
                      ref
                          .read(backgroundPrivacyShieldSettingProvider.notifier)
                          .setEnabled(value);
                    },
              switchKey: const Key('backgroundPrivacyShieldSwitch'),
            ),
            _SecurityRow(
              rowKey: const Key('walletAutoLockRow'),
              icon: AppIcons.lock,
              title: t.settings.autoLock,
              subtitle:
                  '${t.settings.autoLockSubtitle} · '
                  '${_autoLockLabel(autoLockDuration)}',
              onTap: autoLockSetting.isLoading
                  ? null
                  : () => _showAutoLockDialog(
                      context,
                      ref,
                      autoLockDuration,
                    ),
            ),
            _SecuritySwitchRow(
              icon: AppIcons.fingerprint,
              title: t.settings.biometricPassword,
              subtitle:
                  biometricState?.canUseBiometrics == false &&
                      !hasBiometricPassword
                  ? t.settings.biometricPasswordUnavailable
                  : t.settings.biometricPasswordSubtitle,
              value: hasBiometricPassword,
              onChanged:
                  biometricSetting.isLoading || !canChangeBiometricPassword
                  ? null
                  : (value) {
                      if (value) {
                        _showBiometricPasswordDialog(context);
                        return;
                      }
                      ref
                          .read(biometricPasswordSettingProvider.notifier)
                          .disable();
                    },
              switchKey: const Key('biometricPasswordSwitch'),
            ),
            _SecurityRow(
              icon: AppIcons.password,
              title: t.wallet.changePassword,
              subtitle: t.settings.changePasswordSubtitle,
              onTap: () => _showChangePasswordDialog(context),
            ),
            _SecurityRow(
              rowKey: const Key('viewSecurityLogsRow'),
              icon: AppIcons.history,
              title: t.settings.securityLog,
              subtitle: t.settings.securityLogSubtitle,
              onTap: () => _openSecurityLogs(context),
            ),
            _SecurityRow(
              icon: AppIcons.linkOff,
              title: t.settings.clearDappPermissions,
              subtitle: t.settings.clearDappPermissionsSubtitle,
              onTap: () => _confirmClearDappPermissions(context, ref),
            ),
            const SizedBox(height: AppSpacing.sectionY),
            _DappPermissionsSection(
              permissionsValue: permissionsValue,
              onRevoke: (permission) {
                _confirmRevokeDappPermission(context, ref, permission);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearDappPermissions(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.settings.clearDappPermissions,
      content: Text(t.settings.clearDappPermissionsSubtitle),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmVariant: AppDialogActionVariant.danger,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(dappPermissionControllerProvider.notifier).clearAll();
  }

  Future<void> _confirmRevokeDappPermission(
    BuildContext context,
    WidgetRef ref,
    DappPermission permission,
  ) async {
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.settings.revokeDappPermission,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.settings.revokeDappPermissionSubtitle),
          const SizedBox(height: 12),
          Text(permission.domain, style: context.appTextStyles.bodyLarge),
        ],
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: t.settings.revoke,
      confirmVariant: AppDialogActionVariant.danger,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(dappPermissionControllerProvider.notifier)
        .revoke(permission.id);
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    await AppDialog.showBuilder<void>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  Future<void> _showBiometricPasswordDialog(BuildContext context) async {
    await AppDialog.showBuilder<void>(
      context: context,
      builder: (_) => const _BiometricPasswordDialog(),
    );
  }

  Future<void> _showAutoLockDialog(
    BuildContext context,
    WidgetRef ref,
    WalletAutoLockDuration current,
  ) async {
    await AppDialog.show<void>(
      context: context,
      title: t.settings.autoLock,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final duration in WalletAutoLockDuration.values)
            ListTile(
              key: _autoLockOptionKey(duration),
              contentPadding: EdgeInsets.zero,
              title: Text(_autoLockLabel(duration)),
              trailing: duration == current
                  ? Icon(
                      AppIcons.checkCircleFilled,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () {
                ref
                    .read(walletAutoLockSettingProvider.notifier)
                    .setDuration(duration);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openSecurityLogs(BuildContext context) async {
    final entries = await AppDialog.showBuilder<List<SecurityLogEntry>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SecurityLogPasswordDialog(),
    );
    if (entries == null || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SecurityLogPage(entries: entries),
      ),
    );
  }
}

String _autoLockLabel(WalletAutoLockDuration duration) {
  return switch (duration) {
    WalletAutoLockDuration.immediately => t.settings.autoLockImmediately,
    WalletAutoLockDuration.oneMinute => t.settings.autoLockOneMinute,
    WalletAutoLockDuration.fiveMinutes => t.settings.autoLockFiveMinutes,
    WalletAutoLockDuration.fifteenMinutes =>
      t.settings.autoLockFifteenMinutes,
    WalletAutoLockDuration.oneHour => t.settings.autoLockOneHour,
  };
}

Key _autoLockOptionKey(WalletAutoLockDuration duration) {
  return switch (duration) {
    WalletAutoLockDuration.immediately =>
      const Key('walletAutoLockOptionImmediately'),
    WalletAutoLockDuration.oneMinute =>
      const Key('walletAutoLockOptionOneMinute'),
    WalletAutoLockDuration.fiveMinutes =>
      const Key('walletAutoLockOptionFiveMinutes'),
    WalletAutoLockDuration.fifteenMinutes =>
      const Key('walletAutoLockOptionFifteenMinutes'),
    WalletAutoLockDuration.oneHour =>
      const Key('walletAutoLockOptionOneHour'),
  };
}

final class _SecurityLogPasswordDialog extends ConsumerStatefulWidget {
  const _SecurityLogPasswordDialog();

  @override
  ConsumerState<_SecurityLogPasswordDialog> createState() =>
      _SecurityLogPasswordDialogState();
}

final class _SecurityLogPasswordDialogState
    extends ConsumerState<_SecurityLogPasswordDialog> {
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
    return AppDialog(
      title: t.settings.securityLogPasswordTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.settings.securityLogPasswordBody),
          const SizedBox(height: AppSpacing.sectionY),
          AppPasswordTextField(
            autofocus: true,
            fieldKey: const Key('securityLogPasswordInput'),
            controller: _passwordController,
            enabled: !_isLoading,
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
            Text(_submitError!, style: context.appTextStyles.bodySmall),
          ],
        ],
      ),
      showCancel: true,
      showConfirm: true,
      cancelCallback: _isLoading ? null : () => Navigator.of(context).pop(),
      confirmKey: const Key('confirmSecurityLogPasswordButton'),
      confirmCallback: _isLoading ? null : _submit,
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = t.onboarding.passwordRequired;
        _submitError = null;
      });
      return;
    }
    setState(() {
      _passwordError = null;
      _submitError = null;
      _isLoading = true;
    });
    try {
      final entries = await ref
          .read(securityLogControllerProvider)
          .loadEntries(password: password);
      if (mounted) {
        Navigator.of(context).pop(entries);
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

final class _BiometricPasswordDialog extends ConsumerStatefulWidget {
  const _BiometricPasswordDialog();

  @override
  ConsumerState<_BiometricPasswordDialog> createState() =>
      _BiometricPasswordDialogState();
}

final class _BiometricPasswordDialogState
    extends ConsumerState<_BiometricPasswordDialog> {
  final _passwordController = TextEditingController();
  String? _passwordError;
  String? _submitError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(biometricPasswordSettingProvider).isLoading;
    return AppDialog(
      title: t.settings.biometricPassword,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.settings.biometricPasswordSetupPrompt),
          const SizedBox(height: AppSpacing.sectionY),
          AppPasswordTextField(
            fieldKey: const Key('biometricPasswordSetupPasswordInput'),
            controller: _passwordController,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: t.onboarding.passwordLabel,
              errorText: _passwordError,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(_submitError!, style: context.appTextStyles.bodySmall),
          ],
        ],
      ),
      showCancel: true,
      showConfirm: true,
      cancelCallback: isLoading ? null : () => Navigator.of(context).pop(),
      confirmKey: const Key('confirmBiometricPasswordSetupButton'),
      confirmCallback: isLoading ? null : _submit,
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = t.onboarding.passwordRequired;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _passwordError = null;
      _submitError = null;
    });

    try {
      await ref
          .read(biometricPasswordSettingProvider.notifier)
          .enable(password: password);
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(t.wallet.biometricEnabled)),
      );
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
    }
  }
}

final class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

final class _ChangePasswordDialogState
    extends ConsumerState<_ChangePasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  String? _submitError;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(settingsControllerProvider).isLoading;
    return AppDialog(
      title: t.wallet.changePassword,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPasswordTextField(
            fieldKey: const Key('currentPasswordInput'),
            controller: _currentPasswordController,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: t.wallet.currentPasswordLabel,
              errorText: _currentPasswordError,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionY),
          AppPasswordTextField(
            fieldKey: const Key('newPasswordInput'),
            controller: _newPasswordController,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: t.wallet.newPasswordLabel,
              errorText: _newPasswordError,
            ),
          ),
          const SizedBox(height: AppSpacing.sectionY),
          AppPasswordTextField(
            fieldKey: const Key('confirmNewPasswordInput'),
            controller: _confirmPasswordController,
            enabled: !isLoading,
            decoration: InputDecoration(
              labelText: t.wallet.confirmNewPasswordLabel,
              errorText: _confirmPasswordError,
            ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(_submitError!, style: context.appTextStyles.bodySmall),
          ],
        ],
      ),
      showCancel: true,
      showConfirm: true,
      cancelCallback: isLoading ? null : () => Navigator.of(context).pop(),
      confirmCallback: isLoading ? null : _submit,
    );
  }

  Future<void> _submit() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        newPassword != confirmation) {
      setState(() {
        _currentPasswordError = currentPassword.isEmpty
            ? t.onboarding.passwordRequired
            : null;
        _newPasswordError = newPassword.isEmpty
            ? t.wallet.newPasswordRequired
            : null;
        _confirmPasswordError = newPassword == confirmation
            ? null
            : t.onboarding.passwordMismatch;
        _submitError = null;
      });
      return;
    }
    final passwordIssue = WalletPasswordPolicy.issueFor(newPassword);
    if (passwordIssue != null) {
      setState(() {
        _currentPasswordError = null;
        _newPasswordError = switch (passwordIssue) {
          WalletPasswordIssue.tooShort => t.errors.walletPasswordTooShort,
          WalletPasswordIssue.tooCommon => t.errors.walletPasswordTooWeak,
        };
        _confirmPasswordError = null;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _currentPasswordError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
      _submitError = null;
    });

    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!mounted) {
        return;
      }
      await offerBiometricPasswordSetup(
        context: context,
        ref: ref,
        password: newPassword,
      );
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(t.wallet.passwordChanged)));
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
    }
  }
}

final class _DappPermissionsSection extends StatelessWidget {
  const _DappPermissionsSection({
    required this.permissionsValue,
    required this.onRevoke,
  });

  final AsyncValue<List<DappPermission>> permissionsValue;
  final ValueChanged<DappPermission> onRevoke;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.settings.connectedDapps,
            style: context.appTextStyles.titleMedium,
          ),
          const SizedBox(height: 8),
          permissionsValue.when(
            data: (permissions) {
              if (permissions.isEmpty) {
                return AppSectionCard(
                  child: Text(
                    t.settings.noConnectedDapps,
                    style: context.appTextStyles.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final permission in permissions)
                    _DappPermissionRow(
                      permission: permission,
                      onRevoke: () => onRevoke(permission),
                    ),
                ],
              );
            },
            error: (_, _) => AppSectionCard(
              child: Text(
                t.errors.unknown,
                style: context.appTextStyles.bodySmall,
              ),
            ),
            loading: () => const AppSectionCard(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

final class _DappPermissionRow extends StatelessWidget {
  const _DappPermissionRow({required this.permission, required this.onRevoke});

  final DappPermission permission;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppSectionCard(
        child: Row(
          children: [
            Icon(AppIcons.globe, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permission.domain,
                    style: context.appTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      style: context.appTextStyles.bodySmall,
                      children: [
                        TextSpan(
                          text:
                              '${t.dapp.chain}: ${permission.chainId} · '
                              '${t.dapp.account}: ',
                        ),
                        highlightedAddressTextSpan(
                          permission.address,
                          style: context.appTextStyles.bodySmall,
                          highlightColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRevoke, child: Text(t.settings.revoke)),
          ],
        ),
      ),
    );
  }
}

final class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.rowKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: InkWell(
        key: rowKey,
        borderRadius: AppRadius.mediumBorder,
        onTap: onTap,
        child: AppSectionCard(
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.appTextStyles.bodyLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.appTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SecuritySwitchRow extends StatelessWidget {
  const _SecuritySwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: AppSectionCard(
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.appTextStyles.bodyLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: context.appTextStyles.bodySmall),
                ],
              ),
            ),
            Switch(
              key: switchKey ?? const Key('requirePasswordOnLaunchSwitch'),
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
