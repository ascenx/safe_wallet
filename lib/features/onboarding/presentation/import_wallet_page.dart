import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/security/inactive_privacy_shield_suppression.dart';
import '../../../shared/security/sensitive_screen_protection.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../wallet/data/wallet_repository.dart';
import '../application/onboarding_controller.dart';
import 'set_password_page.dart';

final class ImportWalletPage extends ConsumerStatefulWidget {
  const ImportWalletPage({super.key});

  @override
  ConsumerState<ImportWalletPage> createState() => _ImportWalletPageState();
}

final class _ImportWalletPageState extends ConsumerState<ImportWalletPage> {
  final TextEditingController _secretController = TextEditingController();
  OnboardingImportMethod? _method;
  WalletPrivateKeyChain? _privateKeyChain;
  String? _error;
  bool _isImportMethodSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showImportMethodSheet();
    });
  }

  @override
  void dispose() {
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveScreenProtectionScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.onboarding.importWallet),
          leading: _method == null ? null : BackButton(onPressed: _goBack),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              16,
              AppSpacing.pageX,
              24,
            ),
            children: [
              Text(
                t.onboarding.importBody,
                style: context.appTextStyles.bodySmall,
              ),
              const SizedBox(height: 20),
              ..._buildCurrentStep(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCurrentStep() {
    final method = _method;
    if (method == null) {
      return const <Widget>[];
    }

    if (method == OnboardingImportMethod.privateKey &&
        _privateKeyChain == null) {
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

    final isMnemonic = method == OnboardingImportMethod.mnemonic;
    return [
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
        enabled: true,
        minLines: 5,
        maxLines: 8,
        helperText: isMnemonic
            ? t.onboarding.mnemonicHint
            : t.onboarding.privateKeyHint,
        errorText: _error,
        onPaste: _pasteSecret,
      ),
      const SizedBox(height: 24),
      AppButton.primary(
        label: t.actions.kContinue,
        onPressed: _continueToPassword,
      ),
    ];
  }

  void _selectMethod(OnboardingImportMethod method) {
    setState(() {
      _method = method;
      _privateKeyChain = null;
      _error = null;
      _secretController.clear();
    });
  }

  Future<void> _showImportMethodSheet() async {
    if (!mounted || _method != null || _isImportMethodSheetOpen) {
      return;
    }
    _isImportMethodSheetOpen = true;
    final method = await showAppActionSheet<OnboardingImportMethod>(
      context,
      title: t.onboarding.selectImportType,
      actions: [
        AppActionSheetAction<OnboardingImportMethod>(
          value: OnboardingImportMethod.mnemonic,
          icon: AppIcons.notes,
          title: t.onboarding.importMnemonicWallet,
        ),
        AppActionSheetAction<OnboardingImportMethod>(
          value: OnboardingImportMethod.privateKey,
          icon: AppIcons.key,
          title: t.onboarding.importPrivateKeyWallet,
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    _isImportMethodSheetOpen = false;
    if (method != null) {
      _selectMethod(method);
    }
  }

  void _selectPrivateKeyChain(WalletPrivateKeyChain chain) {
    setState(() {
      _privateKeyChain = chain;
      _error = null;
      _secretController.clear();
    });
  }

  void _goBack() {
    var shouldShowImportMethodSheet = false;
    setState(() {
      if (_method == OnboardingImportMethod.privateKey &&
          _privateKeyChain != null) {
        _privateKeyChain = null;
      } else {
        _method = null;
        _privateKeyChain = null;
        shouldShowImportMethodSheet = true;
      }
      _error = null;
      _secretController.clear();
    });
    if (shouldShowImportMethodSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showImportMethodSheet();
      });
    }
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
      _error = null;
    });
  }

  void _continueToPassword() {
    final method = _method;
    if (method == null) {
      return;
    }
    final secret = _secretController.text.trim();
    if (secret.isEmpty) {
      setState(() {
        _error = t.onboarding.importMaterialRequired;
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SetPasswordPage(
          progressLabel: t.onboarding.importingWallet,
          onSubmit: (password) async {
            await ref
                .read(onboardingControllerProvider.notifier)
                .importWallet(
                  method: method,
                  secret: secret,
                  password: password,
                  privateKeyChain:
                      _privateKeyChain ?? WalletPrivateKeyChain.evm,
                );
          },
        ),
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
                child: Text(title, style: context.appTextStyles.bodyLarge),
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
