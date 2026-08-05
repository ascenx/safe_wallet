import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safe_wallet/shared/widgets/app_buttons.dart';
import 'package:safe_wallet/shared/widgets/app_dialog.dart';
import 'package:safe_wallet/shared/widgets/app_password_text_field.dart';

import '../../../app/shell/main_shell_tab.dart';
import '../../../features/settings/application/settings_controller.dart';
import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_brand_colors.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/utils/address_display.dart';
import '../../../shared/utils/receive_qr_payload.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/domain/chain_config.dart';
import '../../chains/presentation/chain_selector_page.dart';
import '../application/receive_qr_image_saver.dart';
import '../application/receive_qr_image_saver_provider.dart';
import '../application/selected_wallet_controller.dart';
import '../application/wallet_repository_provider.dart';
import '../application/wallet_session_controller.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_account.dart';
import 'export_secret_confirm_page.dart';
import 'unlock_wallet_page.dart';
import 'wallet_import_page.dart';

enum _WalletManagementAction { rename, delete }

enum _WalletExportAction { mnemonic, privateKey }

final class WalletManagementPage extends ConsumerStatefulWidget {
  const WalletManagementPage({super.key});

  @override
  ConsumerState<WalletManagementPage> createState() =>
      _WalletManagementPageState();
}

final class _WalletManagementPageState
    extends ConsumerState<WalletManagementPage> {
  late Future<List<WalletAccount>> _walletsFuture;

  @override
  void initState() {
    super.initState();
    _walletsFuture = _loadWallets();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWalletId = ref.watch(selectedWalletIdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings.walletManagement)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          8,
          AppSpacing.pageX,
          44,
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: t.wallet.create,
                icon: const Icon(AppIcons.add),
                onPressed: _showCreateWalletDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton.secondary(
                label: t.wallet.import,
                icon: const Icon(AppIcons.arrowDown),
                onPressed: _showImportWalletDialog,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<WalletAccount>>(
          future: _walletsFuture,
          builder: (context, snapshot) {
            final wallets = snapshot.data ?? const <WalletAccount>[];
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.pageX),
              children: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (wallets.isEmpty)
                  Text(t.home.noWallet, style: context.appTextStyles.bodySmall)
                else
                  for (final wallet in wallets)
                    _WalletTile(
                      wallet: wallet,
                      isSelected: selectedWalletId == wallet.id,
                      onSelect: () => _selectWallet(wallet),
                      onView: () => _showReceiveQr(wallet),
                      onExport: () => _exportWallet(wallet),
                      onShowActions: () => _showWalletActions(wallet),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<List<WalletAccount>> _loadWallets() {
    return ref.read(walletRepositoryProvider).getWallets();
  }

  void _reloadWallets() {
    setState(() {
      _walletsFuture = _loadWallets();
    });
  }

  Future<void> _selectWallet(WalletAccount wallet) async {
    await ref.read(selectedWalletIdProvider.notifier).select(wallet.id);
    ref.read(mainShellTabProvider.notifier).select(MainShellTab.home);
    if (!mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _exportWallet(WalletAccount wallet) async {
    if (wallet.source == WalletAccountSource.privateKey) {
      final secretType = _privateKeyExportSecretType(wallet);
      if (secretType != null) {
        await _pushExportSecret(wallet, secretType);
      }
      return;
    }

    final exportAction = await showAppActionSheet<_WalletExportAction>(
      context,
      actions: [
        AppActionSheetAction<_WalletExportAction>(
          value: _WalletExportAction.mnemonic,
          icon: AppIcons.edit,
          title: t.wallet.exportMnemonic,
        ),
        AppActionSheetAction<_WalletExportAction>(
          value: _WalletExportAction.privateKey,
          icon: AppIcons.key,
          title: t.wallet.exportPrivateKey,
        ),
      ],
    );
    if (exportAction == null || !mounted) {
      return;
    }

    final secretType = switch (exportAction) {
      _WalletExportAction.mnemonic => WalletSecretType.mnemonic,
      _WalletExportAction.privateKey => await _showPrivateKeyNetworkSheet(
        wallet,
      ),
    };
    if (secretType == null || !mounted) {
      return;
    }
    await _pushExportSecret(wallet, secretType);
  }

  Future<void> _pushExportSecret(
    WalletAccount wallet,
    WalletSecretType secretType,
  ) {
    return showExportSecretFlow(
      context,
      wallet: wallet,
      secretType: secretType,
    );
  }

  WalletSecretType? _privateKeyExportSecretType(WalletAccount wallet) {
    if (wallet.evmAddress.isNotEmpty) {
      return WalletSecretType.evmPrivateKey;
    }
    if (wallet.solanaAddress.isNotEmpty) {
      return WalletSecretType.solanaPrivateKey;
    }
    if (wallet.btcAddress.isNotEmpty) {
      return WalletSecretType.btcPrivateKey;
    }
    if (wallet.suiAddress.isNotEmpty) {
      return WalletSecretType.suiPrivateKey;
    }
    return null;
  }

  Future<WalletSecretType?> _showPrivateKeyNetworkSheet(
    WalletAccount wallet,
  ) async {
    final chain = await showChainSelectorSheet(
      context,
      title: t.wallet.exportPrivateKey,
      selectCurrentChain: false,
      filter: (chain) => wallet.addressForChainType(chain.chainType).isNotEmpty,
    );
    return switch (chain?.chainType) {
      ChainType.evm => WalletSecretType.evmPrivateKey,
      ChainType.bitcoin => WalletSecretType.btcPrivateKey,
      ChainType.tron => WalletSecretType.tronPrivateKey,
      ChainType.solana => WalletSecretType.solanaPrivateKey,
      ChainType.sui => WalletSecretType.suiPrivateKey,
      null => null,
    };
  }

  Future<void> _copyAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: t.wallet.addressCopied,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _saveReceiveQr(GlobalKey boundaryKey, String label) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Receive QR export boundary is unavailable.');
      }

      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Receive QR image encoding failed.');
      }

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      final chain = label.toLowerCase();
      final fileName =
          'safe-wallet-$chain-receive-${DateTime.now().millisecondsSinceEpoch}.png';
      await ref
          .read(receiveQrImageSaverProvider)
          .save(bytes, fileName: fileName);

      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: t.wallet.qrImageSaved,
        variant: AppToastVariant.success,
      );
    } on ReceiveQrImageSaveException catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error.failure) {
        ReceiveQrImageSaveFailure.permissionDenied =>
          t.wallet.qrImagePhotoPermissionRequired,
        ReceiveQrImageSaveFailure.saveFailed => t.wallet.qrImageSaveFailed,
      };
      AppToast.show(context, message: message, variant: AppToastVariant.error);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.show(
        context,
        message: t.wallet.qrImageSaveFailed,
        variant: AppToastVariant.error,
      );
    }
  }

  Future<void> _showReceiveQr(WalletAccount wallet) async {
    List<ChainConfig> availableChains;
    try {
      availableChains = await ref.read(availableChainsProvider.future);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: t.chains.loadFailed,
          variant: AppToastVariant.error,
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }

    final chains = <_ReceiveQrChain>[];
    for (final chain in availableChains) {
      final address = wallet.addressForChainType(chain.chainType);
      if (address.isEmpty) {
        continue;
      }
      chains.add(
        _ReceiveQrChain(
          chain: chain,
          label: chain.name,
          title: t.wallet.receiveQrTitle(
            walletName: wallet.name,
            chainName: chain.name,
          ),
          address: address,
          qrData: receiveQrPayloadForChain(
            chainType: chain.chainType,
            address: address,
            chainId: chain.chainType == ChainType.evm ? chain.chainId : null,
            chainName: chain.name,
            label: wallet.name,
          ),
          onSave: (boundaryKey) => _saveReceiveQr(boundaryKey, chain.id),
          onCopy: () => _copyAddress(address),
        ),
      );
    }
    if (chains.isEmpty) {
      return;
    }

    await AppDialog.show<void>(
      context: context,
      title: t.wallet.receiveQr,
      content: _ReceiveQrDialogContent(chains: chains),
    );
  }

  Future<void> _showWalletActions(WalletAccount wallet) async {
    final action = await showAppActionSheet<_WalletManagementAction>(
      context,
      actions: [
        AppActionSheetAction<_WalletManagementAction>(
          value: _WalletManagementAction.rename,
          icon: AppIcons.edit,
          title: t.wallet.rename,
        ),
        AppActionSheetAction<_WalletManagementAction>(
          value: _WalletManagementAction.delete,
          icon: AppIcons.delete,
          title: t.wallet.delete,
          variant: AppActionSheetActionVariant.danger,
        ),
      ],
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _WalletManagementAction.rename:
        await _showRenameDialog(wallet);
      case _WalletManagementAction.delete:
        await _showDeleteDialog(wallet);
    }
  }

  Future<void> _showRenameDialog(WalletAccount wallet) async {
    final name = await AppDialog.showBuilder<String>(
      context: context,
      builder: (_) => _RenameWalletDialog(initialName: wallet.name),
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await ref
        .read(walletRepositoryProvider)
        .renameWallet(walletId: wallet.id, name: name.trim());
    _reloadWallets();
  }

  Future<void> _showDeleteDialog(WalletAccount wallet) async {
    final deleted = await AppDialog.showBuilder<bool>(
      context: context,
      builder: (_) => _DeleteWalletDialog(wallet: wallet),
    );
    if (deleted == true) {
      if (ref.read(selectedWalletIdProvider) == wallet.id) {
        await ref.read(selectedWalletIdProvider.notifier).clear();
      }
      _reloadWallets();
    }
  }

  Future<void> _showCreateWalletDialog() async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    if (!mounted) {
      return;
    }
    final contentKey = GlobalKey<_CreateWalletDialogContentState>();
    final initialName = _nextDefaultWalletName(wallets);
    var isSubmitting = false;

    Future<void> submit() async {
      if (isSubmitting) {
        return;
      }
      final contentState = contentKey.currentState;
      if (contentState == null) {
        return;
      }
      if (contentState.password.isEmpty) {
        contentState.showSubmitError(t.onboarding.passwordRequired);
        return;
      }
      isSubmitting = true;
      try {
        await ref
            .read(walletRepositoryProvider)
            .createWallet(
              name: contentState.walletName,
              password: contentState.password,
            );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(true);
      } catch (_) {
        if (!mounted) {
          return;
        }
        contentKey.currentState?.showSubmitError(t.errors.unknown);
      } finally {
        isSubmitting = false;
      }
    }

    final created = await AppDialog.show<bool>(
      context: context,
      title: t.wallet.create,
      content: _CreateWalletDialogContent(
        key: contentKey,
        initialName: initialName,
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmCallback: submit,
      confirmTitle: t.wallet.create,
    );
    if (created == true) {
      _reloadWallets();
    }
  }

  Future<void> _showImportWalletDialog() async {
    if (!await _ensureWalletUnlocked() || !mounted) {
      return;
    }
    final method = await showAppActionSheet<WalletImportMethod>(
      context,
      title: t.onboarding.selectImportType,
      actions: [
        AppActionSheetAction<WalletImportMethod>(
          value: WalletImportMethod.mnemonic,
          icon: AppIcons.notes,
          title: t.onboarding.importMnemonicWallet,
          subtitle: t.onboarding.importMnemonicWalletDescription,
        ),
        AppActionSheetAction<WalletImportMethod>(
          value: WalletImportMethod.privateKey,
          icon: AppIcons.key,
          title: t.onboarding.importPrivateKeyWallet,
          subtitle: t.onboarding.importPrivateKeyWalletDescription,
        ),
      ],
    );
    if (method == null || !mounted) {
      return;
    }

    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    if (!mounted) {
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => WalletImportPage(
          initialMethod: method,
          initialName: _nextDefaultWalletName(wallets),
        ),
      ),
    );
    if (imported == true) {
      _reloadWallets();
    }
  }

  Future<bool> _ensureWalletUnlocked() async {
    final session = await ref.read(walletSessionControllerProvider.future);
    if (session?.isUnlocked == true) {
      return true;
    }

    final wallets = await _walletsFuture;
    if (!mounted) {
      return false;
    }
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    final account =
        wallets.where((wallet) => wallet.id == selectedWalletId).firstOrNull ??
        wallets.firstOrNull;
    if (account == null) {
      return false;
    }

    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UnlockWalletPage(account: account, popOnSuccess: true),
      ),
    );
    return mounted && unlocked == true;
  }
}

String _nextDefaultWalletName(List<WalletAccount> wallets) {
  var highestIndex = wallets.length;
  final defaultNamePattern = RegExp(r'^Wallet\s+(\d+)$');
  for (final wallet in wallets) {
    final match = defaultNamePattern.firstMatch(wallet.name.trim());
    final index = match == null ? null : int.tryParse(match.group(1)!);
    if (index != null) {
      highestIndex = math.max(highestIndex, index);
    }
  }
  return 'Wallet ${highestIndex + 1}';
}

final class _CreateWalletDialogContent extends StatefulWidget {
  const _CreateWalletDialogContent({required this.initialName, super.key});

  final String initialName;

  @override
  State<_CreateWalletDialogContent> createState() =>
      _CreateWalletDialogContentState();
}

final class _CreateWalletDialogContentState
    extends State<_CreateWalletDialogContent> {
  late final TextEditingController _nameController;
  final _passwordController = TextEditingController();
  String? _submitError;

  String get walletName {
    final name = _nameController.text.trim();
    return name.isEmpty ? widget.initialName : name;
  }

  String get password => _passwordController.text;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  void showSubmitError(String error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _submitError = error;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('createWalletNameInput'),
          spellCheckConfiguration: SpellCheckConfiguration.disabled(),
          autocorrect: false,
          controller: _nameController,
          decoration: InputDecoration(
            hintText: t.wallet.nameLabel,
            hintStyle: context.appTextStyles.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('createWalletPasswordInput'),
          controller: _passwordController,
          obscureText: true,
          spellCheckConfiguration: SpellCheckConfiguration.disabled(),
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(labelText: t.onboarding.passwordLabel),
        ),
        if (_submitError != null) ...[
          const SizedBox(height: 8),
          Text(_submitError!, style: context.appTextStyles.bodySmall),
        ],
      ],
    );
  }
}

final class _ReceiveQrChain {
  const _ReceiveQrChain({
    required this.chain,
    required this.label,
    required this.title,
    required this.address,
    required this.qrData,
    required this.onSave,
    required this.onCopy,
  });

  final ChainConfig chain;
  final String label;
  final String title;
  final String address;
  final String qrData;
  final Future<void> Function(GlobalKey boundaryKey) onSave;
  final VoidCallback onCopy;
}

final class _ReceiveQrDialogContent extends StatefulWidget {
  const _ReceiveQrDialogContent({required this.chains});

  final List<_ReceiveQrChain> chains;

  @override
  State<_ReceiveQrDialogContent> createState() =>
      _ReceiveQrDialogContentState();
}

final class _ReceiveQrDialogContentState
    extends State<_ReceiveQrDialogContent> {
  late final List<GlobalKey> _exportBoundaryKeys;
  int _selectedIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _exportBoundaryKeys = [
      for (var index = 0; index < widget.chains.length; index++) GlobalKey(),
    ];
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await widget.chains[_selectedIndex].onSave(
        _exportBoundaryKeys[_selectedIndex],
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectNetwork() async {
    final supportedChainIds = widget.chains
        .map((chain) => chain.chain.id)
        .toSet();
    final selected = await showChainSelectorSheet(
      context,
      selectCurrentChain: false,
      title: t.chains.selectorTitle,
      filter: (chain) => supportedChainIds.contains(chain.id),
    );
    if (!mounted || selected == null) {
      return;
    }
    final selectedIndex = widget.chains.indexWhere(
      (chain) => chain.chain.id == selected.id,
    );
    if (selectedIndex < 0 || selectedIndex == _selectedIndex) {
      return;
    }
    setState(() {
      _selectedIndex = selectedIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedChain = widget.chains[_selectedIndex];
    final contentHeight = _contentHeight(context);

    return SingleChildScrollView(
      child: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReceiveQrNetworkSelector(
              selectedChain: selectedChain,
              onTap: _selectNetwork,
            ),
            const SizedBox(height: AppSpacing.sectionY),
            DecoratedBox(
              key: const Key('receiveQrCard'),
              decoration: BoxDecoration(color: context.appColors.surfaceSoft),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: contentHeight,
                    child: _ReceiveQrPageContent(
                      chain: selectedChain,
                      boundaryKey: _exportBoundaryKeys[_selectedIndex],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          key: Key(
                            'saveReceiveQrButton-${selectedChain.label}',
                          ),
                          height: 40,
                          label: t.wallet.saveQrImage,
                          icon: const Icon(AppIcons.save),
                          onPressed: _isSaving ? null : _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton.secondary(
                          key: Key(
                            'copyReceiveQrButton-${selectedChain.label}',
                          ),
                          height: 40,
                          label: t.wallet.copy,
                          icon: const Icon(AppIcons.copy),
                          onPressed: selectedChain.onCopy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _contentHeight(BuildContext context) {
    const contentWidth = 260 - AppSpacing.cardPadding * 2;
    const qrSize = 180.0;
    const contentMaxHeight = 360.0;
    var maxHeight = 0.0;

    for (final chain in widget.chains) {
      final labelHeight = _textHeight(
        context,
        text: chain.title,
        style: context.appTextStyles.bodyLarge,
        maxWidth: contentWidth,
      );
      final addressHeight = _textHeight(
        context,
        text: chain.address,
        style: context.appTextStyles.bodySmall,
        maxWidth: contentWidth,
      );
      final height =
          AppSpacing.cardPadding +
          labelHeight +
          10 +
          qrSize +
          10 +
          addressHeight +
          AppSpacing.cardPadding;
      maxHeight = math.max(maxHeight, height);
    }

    return math.min(contentMaxHeight, maxHeight);
  }

  double _textHeight(
    BuildContext context, {
    required String text,
    required TextStyle style,
    required double maxWidth,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }
}

final class _ReceiveQrNetworkSelector extends StatelessWidget {
  const _ReceiveQrNetworkSelector({
    required this.selectedChain,
    required this.onTap,
  });

  final _ReceiveQrChain selectedChain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.divider,
      borderRadius: AppRadius.mediumBorder,
      child: InkWell(
        key: const Key('receiveQrNetworkSelector'),
        borderRadius: AppRadius.mediumBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                selectedChain.label,
                style: context.appTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const Icon(AppIcons.chevronDown, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReceiveQrPageContent extends StatelessWidget {
  const _ReceiveQrPageContent({required this.chain, required this.boundaryKey});

  final _ReceiveQrChain chain;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    final label = chain.label;
    final title = chain.title;
    final address = chain.address;
    final qrData = chain.qrData;

    return SizedBox.expand(
      key: Key('receiveQrPageContent-$label'),
      child: RepaintBoundary(
        key: boundaryKey,
        child: ColoredBox(
          key: Key('receiveQrExportContent-$label'),
          color: context.appColors.surfaceSoft,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(title, style: context.appTextStyles.bodyLarge),
                ),
                const SizedBox(height: 10),
                SizedBox.square(
                  dimension: 180,
                  child: QrImageView(
                    data: qrData,
                    size: 180,
                    semanticsLabel: qrData,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  highlightedAddressTextSpan(
                    address,
                    style: context.appTextStyles.bodySmall,
                    highlightColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _RenameWalletDialog extends StatefulWidget {
  const _RenameWalletDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameWalletDialog> createState() => _RenameWalletDialogState();
}

final class _RenameWalletDialogState extends State<_RenameWalletDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: t.wallet.rename,
      content: TextField(
        spellCheckConfiguration: SpellCheckConfiguration.disabled(),
        autocorrect: false,
        controller: _controller,
        decoration: InputDecoration(labelText: t.wallet.nameLabel),
      ),
      cancelCallback: () => Navigator.of(context).pop(),
      confirmTitle: t.wallet.rename,
      confirmCallback: () => Navigator.of(context).pop(_controller.text),
    );
  }
}

final class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.wallet,
    required this.isSelected,
    required this.onSelect,
    required this.onView,
    required this.onExport,
    required this.onShowActions,
  });

  final WalletAccount wallet;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onView;
  final VoidCallback onExport;
  final VoidCallback onShowActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sectionY),
      child: Material(
        color: context.appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorder,
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : context.appColors.border,
          ),
        ),
        child: InkWell(
          key: Key('walletTile-${wallet.id}'),
          borderRadius: AppRadius.mediumBorder,
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final sourceLabel = _walletSourceLabel(wallet.source);
                    final badgeWidth =
                        _textWidth(
                          context,
                          sourceLabel,
                          context.appTextStyles.caption,
                        ) +
                        18;
                    final selectedWidth = isSelected
                        ? _textWidth(
                                context,
                                t.wallet.selected,
                                context.appTextStyles.caption,
                              ) +
                              16
                        : 0;
                    final maxNameWidth = math.max(
                      0.0,
                      constraints.maxWidth - badgeWidth - selectedWidth - 16,
                    );
                    final nameWidth = math.min(
                      _textWidth(
                        context,
                        wallet.name,
                        context.appTextStyles.bodyLarge,
                      ),
                      maxNameWidth,
                    );

                    return Row(
                      children: [
                        SizedBox(
                          width: nameWidth,
                          child: Text(
                            wallet.name,
                            style: context.appTextStyles.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _WalletSourceBadge(label: sourceLabel),
                        if (isSelected) ...[
                          const Spacer(),
                          const SizedBox(width: 8),
                          Text(
                            t.wallet.selected,
                            style: context.appTextStyles.caption,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (wallet.evmAddress.isNotEmpty)
                  Text.rich(
                    highlightedAddressTextSpan(
                      wallet.evmAddress,
                      style: context.appTextStyles.caption,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (wallet.solanaAddress.isNotEmpty)
                  Text.rich(
                    highlightedAddressTextSpan(
                      wallet.solanaAddress,
                      style: context.appTextStyles.caption,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (wallet.tronAddress.isNotEmpty)
                  Text.rich(
                    highlightedAddressTextSpan(
                      wallet.tronAddress,
                      style: context.appTextStyles.caption,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (wallet.btcAddress.isNotEmpty)
                  Text.rich(
                    highlightedAddressTextSpan(
                      wallet.btcAddress,
                      style: context.appTextStyles.caption,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (wallet.suiAddress.isNotEmpty)
                  Text.rich(
                    highlightedAddressTextSpan(
                      wallet.suiAddress,
                      style: context.appTextStyles.caption,
                      highlightColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionChipButton(label: t.wallet.view, onPressed: onView),
                    const SizedBox(width: 8),
                    _ActionChipButton(
                      label: t.wallet.exportSecret,
                      onPressed: onExport,
                    ),
                    const Spacer(),
                    IconButton(
                      key: Key('walletActions-${wallet.id}'),
                      tooltip: t.wallet.moreActions,
                      onPressed: onShowActions,
                      icon: const Icon(AppIcons.more),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _WalletSourceBadge extends StatelessWidget {
  const _WalletSourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brandColors.primarySoft,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: context.appTextStyles.caption),
      ),
    );
  }
}

String _walletSourceLabel(WalletAccountSource source) {
  return switch (source) {
    WalletAccountSource.mnemonic => t.wallet.mnemonicWallet,
    WalletAccountSource.privateKey => t.wallet.privateKeyWallet,
  };
}

double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();
  return painter.width.ceilToDouble();
}

final class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onPressed);
  }
}

final class _DeleteWalletDialog extends ConsumerStatefulWidget {
  const _DeleteWalletDialog({required this.wallet});

  final WalletAccount wallet;

  @override
  ConsumerState<_DeleteWalletDialog> createState() =>
      _DeleteWalletDialogState();
}

final class _DeleteWalletDialogState
    extends ConsumerState<_DeleteWalletDialog> {
  final _passwordController = TextEditingController();
  bool _acknowledged = false;
  String? _passwordError;
  String? _confirmationError;
  String? _submitError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(settingsControllerProvider).isLoading;

    return AppDialog(
      title: t.wallet.deleteTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.wallet.deleteMessage, style: context.appTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.sectionY),
          AppPasswordTextField(
            fieldKey: const Key('deleteWalletPasswordInput'),
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: t.onboarding.passwordLabel,
              errorText: _passwordError,
            ),
          ),
          CheckboxListTile(
            key: const Key('deleteWalletAcknowledgeCheckbox'),
            value: _acknowledged,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _acknowledged = value ?? false;
                _confirmationError = null;
              });
            },
            title: Text(t.wallet.deleteAcknowledge),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_confirmationError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _confirmationError!,
                style: context.appTextStyles.bodySmall,
              ),
            ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(_submitError!, style: context.appTextStyles.bodySmall),
          ],
        ],
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      showConfirm: true,
      confirmKey: const Key('confirmDeleteWalletButton'),
      confirmTitle: t.wallet.delete,
      confirmVariant: AppDialogActionVariant.danger,
      confirmCallback: isLoading ? null : _submit,
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    if (password.isEmpty || !_acknowledged) {
      setState(() {
        _passwordError = password.isEmpty
            ? t.onboarding.passwordRequired
            : null;
        _confirmationError = _acknowledged
            ? null
            : t.wallet.deleteRequiresConfirmation;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _passwordError = null;
      _confirmationError = null;
      _submitError = null;
    });

    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .deleteWallet(walletId: widget.wallet.id, password: password);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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
