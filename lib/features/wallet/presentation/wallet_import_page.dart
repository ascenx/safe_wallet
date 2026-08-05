import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/inactive_privacy_shield_suppression.dart';
import '../../../shared/security/sensitive_screen_protection.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../application/wallet_repository_provider.dart';
import '../data/wallet_repository.dart';

final class WalletImportPage extends ConsumerStatefulWidget {
  const WalletImportPage({
    required this.initialMethod,
    this.initialName = 'Wallet 1',
    super.key,
  });

  final WalletImportMethod initialMethod;
  final String initialName;

  @override
  ConsumerState<WalletImportPage> createState() => _WalletImportPageState();
}

enum WalletImportMethod { mnemonic, privateKey }

final class _WalletImportPageState extends ConsumerState<WalletImportPage> {
  late final TextEditingController _nameController;
  final _secretController = TextEditingController();
  final _passwordController = TextEditingController();

  late final WalletImportMethod _method;
  WalletPrivateKeyChain? _privateKeyChain;
  String? _materialError;
  String? _submitError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _method = widget.initialMethod;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _secretController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveScreenProtectionScope(
      child: Scaffold(
        key: const Key('walletImportPage'),
        appBar: AppBar(
          title: Text(t.wallet.import),
          leading: BackButton(onPressed: _goBack),
        ),
        bottomNavigationBar: _showsSubmitActions
            ? _ImportFormActions(
                isSubmitting: _isSubmitting,
                onCancel: () => Navigator.of(context).pop(false),
                onSubmit: _submit,
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              16,
              AppSpacing.pageX,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [..._buildCurrentStep(context)],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCurrentStep(BuildContext context) {
    final method = _method;
    if (method == WalletImportMethod.privateKey && _privateKeyChain == null) {
      return [
        Text(
          t.onboarding.selectPrivateKeyChain,
          style: context.appTextStyles.bodyLarge,
        ),
        const SizedBox(height: 10),
        _ImportOptionTile(
          icon: AppIcons.network,
          title: t.onboarding.importEvm,
          onTap: () => _selectPrivateKeyChain(WalletPrivateKeyChain.evm),
        ),
        const SizedBox(height: 12),
        _ImportOptionTile(
          icon: AppIcons.bitcoin,
          title: t.onboarding.importBitcoin,
          onTap: () => _selectPrivateKeyChain(WalletPrivateKeyChain.bitcoin),
        ),
        const SizedBox(height: 12),
        _ImportOptionTile(
          icon: AppIcons.lightning,
          title: t.onboarding.importTron,
          onTap: () => _selectPrivateKeyChain(WalletPrivateKeyChain.tron),
        ),
        const SizedBox(height: 12),
        _ImportOptionTile(
          icon: AppIcons.solana,
          title: t.onboarding.importSolana,
          onTap: () => _selectPrivateKeyChain(WalletPrivateKeyChain.solana),
        ),
        const SizedBox(height: 12),
        _ImportOptionTile(
          icon: AppIcons.sui,
          title: t.onboarding.importSui,
          onTap: () => _selectPrivateKeyChain(WalletPrivateKeyChain.sui),
        ),
      ];
    }

    final isMnemonic = method == WalletImportMethod.mnemonic;
    return [
      Text(t.wallet.nameLabel, style: context.appTextStyles.bodyLarge),
      const SizedBox(height: 8),
      TextField(
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        autocorrect: false,
        key: const Key('importWalletName'),
        controller: _nameController,
        enabled: !_isSubmitting,
        decoration: const InputDecoration(),
      ),
      const SizedBox(height: AppSpacing.sectionY),
      Text(
        isMnemonic
            ? t.onboarding.importMnemonic
            : t.onboarding.importPrivateKey,
        style: context.appTextStyles.bodyLarge,
      ),
      const SizedBox(height: 8),
      _ImportSecretTextField(
        fieldKey: isMnemonic
            ? const Key('mnemonicInput')
            : const Key('privateKeyInput'),
        controller: _secretController,
        enabled: !_isSubmitting,
        minLines: 5,
        maxLines: 8,
        helperText: isMnemonic
            ? t.onboarding.mnemonicHint
            : t.onboarding.privateKeyHint,
        errorText: _materialError,
        onPaste: _pasteSecret,
      ),
      const SizedBox(height: AppSpacing.sectionY),
      Text(t.onboarding.passwordLabel, style: context.appTextStyles.bodyLarge),
      const SizedBox(height: 8),
      TextField(
        key: const Key('importWalletPasswordInput'),
        controller: _passwordController,
        enabled: !_isSubmitting,
        obscureText: true,
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        enableSuggestions: false,
        autocorrect: false,
        decoration: const InputDecoration(),
      ),
      if (_submitError != null) ...[
        const SizedBox(height: 8),
        Text(
          _submitError!,
          style: context.appTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    ];
  }

  bool get _showsSubmitActions {
    return _method == WalletImportMethod.mnemonic || _privateKeyChain != null;
  }

  void _selectPrivateKeyChain(WalletPrivateKeyChain chain) {
    setState(() {
      _privateKeyChain = chain;
      _materialError = null;
      _submitError = null;
      _secretController.clear();
    });
  }

  void _goBack() {
    if (_method == WalletImportMethod.privateKey && _privateKeyChain != null) {
      setState(() {
        _privateKeyChain = null;
        _materialError = null;
        _submitError = null;
        _secretController.clear();
      });
      return;
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _pasteSecret() async {
    final data = await ref
        .read(inactivePrivacyShieldSuppressionProvider)
        .whileInactiveShieldSuppressed(
          () => Clipboard.getData(Clipboard.kTextPlain),
        );
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    setState(() {
      _secretController.text = text;
      _secretController.selection = TextSelection.collapsed(
        offset: _secretController.text.length,
      );
      _materialError = null;
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    final method = _method;
    final material = _importMaterial;
    if (material.isEmpty) {
      setState(() {
        _materialError = material.isEmpty
            ? t.onboarding.importMaterialRequired
            : null;
        _submitError = null;
      });
      return;
    }
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _submitError = t.onboarding.passwordRequired;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _materialError = null;
      _submitError = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    try {
      if (method == WalletImportMethod.mnemonic) {
        await ref
            .read(walletRepositoryProvider)
            .importMnemonicWallet(
              mnemonic: material,
              name: _name,
              password: password,
            );
      } else {
        await ref
            .read(walletRepositoryProvider)
            .importPrivateKeyWallet(
              privateKey: material,
              name: _name,
              password: password,
              chain: _privateKeyChain ?? WalletPrivateKeyChain.evm,
            );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = const ErrorLocalizer().messageFor(error, t);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = t.errors.unknown;
      });
    }
  }

  String get _importMaterial => _secretController.text.trim();

  String get _name {
    final name = _nameController.text.trim();
    return name.isEmpty ? widget.initialName : name;
  }
}

final class _ImportFormActions extends StatelessWidget {
  const _ImportFormActions({
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        8,
        AppSpacing.pageX,
        44,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton.text(
              label: t.actions.cancel,
              onPressed: isSubmitting ? null : onCancel,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton.primary(
              label: t.wallet.import,
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

final class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.appTextStyles.bodyLarge),
                  ],
                ),
              ),
              const Icon(AppIcons.chevronRight),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ImportSecretTextField extends StatelessWidget {
  const _ImportSecretTextField({
    required this.fieldKey,
    required this.controller,
    required this.minLines,
    required this.maxLines,
    required this.helperText,
    required this.onPaste,
    this.enabled = true,
    this.errorText,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final String helperText;
  final VoidCallback onPaste;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            TextField(
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              key: fieldKey,
              controller: controller,
              enabled: enabled,
              minLines: minLines,
              maxLines: maxLines,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.fromLTRB(16, 16, 16, 54),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: TextButton.icon(
                onPressed: enabled ? onPaste : null,
                icon: const Icon(AppIcons.paste, size: 18),
                label: Text(t.actions.paste),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(helperText, style: context.appTextStyles.bodySmall),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error,
            style: context.appTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
