import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_input_borders.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/background_route_preservation.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading_state.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/data/chainlist_chain_repository.dart';
import '../../chains/data/chain_logo_uris.dart';
import '../../chains/data/chain_repository.dart';
import '../../chains/data/default_chains.dart';
import '../../chains/domain/chain_config.dart';
import '../../assets/presentation/widgets/token_icon.dart';
import '../../nodes/application/selected_rpc_node_provider.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../nodes/presentation/node_management_page.dart';
import '../application/custom_network_creation_service.dart';

final class NetworkManagementPage extends ConsumerWidget {
  const NetworkManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chainsValue = ref.watch(availableChainsProvider);
    final selectedChain = ref.watch(selectedChainControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings.networkManagement),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddNetworkPage(),
                ),
              );
            },
            tooltip: t.chains.addNetwork,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: chainsValue.when(
          data: (chains) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              12,
              AppSpacing.pageX,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NetworkSection(
                  title: t.settings.evmNetworks,
                  chains: chains
                      .where((chain) => chain.chainType == ChainType.evm)
                      .toList(growable: false),
                  selectedChain: selectedChain,
                  onTap: (chain) => _openChain(context, chain),
                  onDelete: (chain) => _deleteChain(context, ref, chain),
                ),
                const SizedBox(height: AppSpacing.sectionY),
                _NetworkSection(
                  title: t.settings.bitcoinNetworks,
                  chains: chains
                      .where((chain) => chain.chainType == ChainType.bitcoin)
                      .toList(growable: false),
                  selectedChain: selectedChain,
                  onTap: (chain) => _openChain(context, chain),
                  onDelete: (chain) => _deleteChain(context, ref, chain),
                ),
                const SizedBox(height: AppSpacing.sectionY),
                _NetworkSection(
                  title: t.settings.solanaNetworks,
                  chains: chains
                      .where((chain) => chain.chainType == ChainType.solana)
                      .toList(growable: false),
                  selectedChain: selectedChain,
                  onTap: (chain) => _openChain(context, chain),
                  onDelete: (chain) => _deleteChain(context, ref, chain),
                ),
                const SizedBox(height: AppSpacing.sectionY),
                _NetworkSection(
                  title: t.settings.tronNetworks,
                  chains: chains
                      .where((chain) => chain.chainType == ChainType.tron)
                      .toList(growable: false),
                  selectedChain: selectedChain,
                  onTap: (chain) => _openChain(context, chain),
                  onDelete: (chain) => _deleteChain(context, ref, chain),
                ),
                const SizedBox(height: AppSpacing.sectionY),
                _NetworkSection(
                  title: t.settings.suiNetworks,
                  chains: chains
                      .where((chain) => chain.chainType == ChainType.sui)
                      .toList(growable: false),
                  selectedChain: selectedChain,
                  onTap: (chain) => _openChain(context, chain),
                  onDelete: (chain) => _deleteChain(context, ref, chain),
                ),
              ],
            ),
          ),
          error: (error, stackTrace) =>
              AppErrorState(message: t.chains.loadFailed),
          loading: () => const AppLoadingState(),
        ),
      ),
    );
  }

  void _openChain(
    BuildContext context,
    ChainConfig chain,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NodeManagementPage(chain: chain),
      ),
    );
  }

  Future<void> _deleteChain(
    BuildContext context,
    WidgetRef ref,
    ChainConfig chain,
  ) async {
    final repository = ref.read(chainRepositoryProvider);
    if (_isFixedChain(chain) || repository is! RemovableChainRepository) {
      return;
    }
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.chains.removeNetworkTitle,
      content: Text(t.chains.removeNetworkMessage),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: t.chains.confirmRemoveNetwork,
      confirmVariant: AppDialogActionVariant.danger,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(customNetworkCreationServiceProvider).deleteNetwork(chain);
    ref.invalidate(availableChainsProvider);
    ref.invalidate(selectedChainControllerProvider);
  }
}

final class AddNetworkPage extends ConsumerStatefulWidget {
  const AddNetworkPage({super.key});

  @override
  ConsumerState<AddNetworkPage> createState() => _AddNetworkPageState();
}

final class _AddNetworkPageState extends ConsumerState<AddNetworkPage> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localChains = ref.watch(availableChainsProvider).value ?? const [];
    final chainlistChainsValue = ref.watch(chainlistChainsProvider);
    final existingChainIds = localChains.map((chain) => chain.chainId).toSet();

    return BackgroundRoutePreservationScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.chains.addNetwork),
          actions: [
            TextButton(
              onPressed: () => _openCustomNetworkPageAndReturn(context),
              child: Text(t.chains.addCustom),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  12,
                  AppSpacing.pageX,
                  8,
                ),
                child: TextField(
                  spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  controller: _searchController,
                  decoration: InputDecoration(
                    border: AppInputBorders.pill(context),
                    enabledBorder: AppInputBorders.pill(context),
                    focusedBorder: AppInputBorders.pillFocused(context),
                    errorBorder: AppInputBorders.pillError,
                    focusedErrorBorder: AppInputBorders.pillError,
                    prefixIcon: const Icon(AppIcons.search, size: 20),
                    hintText: t.chains.searchNetworkHint,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: chainlistChainsValue.when(
                  data: (chains) {
                    final visibleChains = chains.where((chain) {
                      if (existingChainIds.contains(chain.chainId)) {
                        return false;
                      }
                      if (_query.isEmpty) {
                        return true;
                      }
                      return chain.name.toLowerCase().contains(_query) ||
                          chain.symbol.toLowerCase().contains(_query) ||
                          chain.chainId.contains(_query);
                    }).toList(growable: false);
                    if (visibleChains.isEmpty) {
                      return Center(
                        child: Text(
                          t.chains.emptySearch,
                          style: context.appTextStyles.bodySmall,
                        ),
                      );
                    }
                    return _NetworkGrid(
                      chains: visibleChains,
                      selectedChain: null,
                      onTap: (chain) => _addChainlistChain(context, chain),
                      showRpcLabel: false,
                      shrinkWrap: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageX,
                        8,
                        AppSpacing.pageX,
                        24,
                      ),
                    );
                  },
                  error: (error, stackTrace) =>
                      AppErrorState(message: t.chains.loadFailed),
                  loading: () => const AppLoadingState(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomNetworkPageAndReturn(BuildContext context) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const _AddCustomEvmChainPage(),
      ),
    );
    if (added == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addChainlistChain(
    BuildContext context,
    ChainConfig chain,
  ) async {
    try {
      await ref.read(customNetworkCreationServiceProvider).createEvmNetwork(
            name: chain.name,
            chainId: chain.chainId,
            rpcUrl: chain.rpcUrls.first,
            symbol: chain.symbol,
            blockExplorerUrl: chain.blockExplorerUrl,
            isTestnet: chain.isTestnet,
          );
      ref.invalidate(availableChainsProvider);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on AppError catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(const ErrorLocalizer().messageFor(error, t))),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.errors.unknown)),
      );
    }
  }
}

final chainlistChainsProvider = FutureProvider<List<ChainConfig>>((ref) {
  return ref.read(chainlistChainRepositoryProvider).getChains();
});

final class _AddCustomEvmChainPage extends ConsumerStatefulWidget {
  const _AddCustomEvmChainPage();

  @override
  ConsumerState<_AddCustomEvmChainPage> createState() =>
      _AddCustomEvmChainPageState();
}

final class _AddCustomEvmChainPageState
    extends ConsumerState<_AddCustomEvmChainPage> {
  final _nameController = TextEditingController();
  final _chainIdController = TextEditingController();
  final _rpcUrlController = TextEditingController();
  final _symbolController = TextEditingController();
  final _blockExplorerController = TextEditingController();
  bool _isTestnet = false;
  bool _isSaving = false;
  String? _nameError;
  String? _chainIdError;
  String? _rpcUrlError;
  String? _symbolError;
  String? _blockExplorerError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _chainIdController.dispose();
    _rpcUrlController.dispose();
    _symbolController.dispose();
    _blockExplorerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundRoutePreservationScope(
      child: Scaffold(
        appBar: AppBar(title: Text(t.chains.addCustomEvm)),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pageX),
              child: AppButton.primary(
                label: t.actions.confirm,
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ),
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
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: t.chains.nameLabel,
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _chainIdController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.chains.chainIdLabel,
                  errorText: _chainIdError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _rpcUrlController,
                enabled: !_isSaving,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t.chains.rpcUrlLabel,
                  errorText: _rpcUrlError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _symbolController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: t.chains.symbolLabel,
                  errorText: _symbolError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _blockExplorerController,
                enabled: !_isSaving,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: t.chains.blockExplorerLabel,
                  errorText: _blockExplorerError,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isTestnet,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _isTestnet = value ?? false;
                        });
                      },
                title: Text(t.chains.testnetLabel),
              ),
              if (_formError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _formError!,
                  style: context.appTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final chainId = _chainIdController.text.trim();
    final rpcUrl = _rpcUrlController.text.trim();
    final symbol = _symbolController.text.trim();
    final blockExplorerUrl = _blockExplorerController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? t.chains.nameRequired : null;
      _chainIdError = _chainIdErrorFor(chainId);
      _rpcUrlError = _urlErrorFor(
        rpcUrl,
        requiredMessage: t.chains.rpcUrlRequired,
        invalidMessage: t.chains.invalidRpcUrl,
      );
      _symbolError = symbol.isEmpty ? t.chains.symbolRequired : null;
      _blockExplorerError = blockExplorerUrl.isEmpty
          ? null
          : _urlErrorFor(
              blockExplorerUrl,
              requiredMessage: t.chains.invalidBlockExplorerUrl,
              invalidMessage: t.chains.invalidBlockExplorerUrl,
            );
      _formError = null;
    });
    if (_nameError != null ||
        _chainIdError != null ||
        _rpcUrlError != null ||
        _symbolError != null ||
        _blockExplorerError != null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(customNetworkCreationServiceProvider).createEvmNetwork(
            name: name,
            chainId: chainId,
            rpcUrl: rpcUrl,
            symbol: symbol,
            blockExplorerUrl:
                blockExplorerUrl.isEmpty ? null : blockExplorerUrl,
            isTestnet: _isTestnet,
          );
      ref.invalidate(availableChainsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on StateError {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _formError = t.chains.duplicateChainId;
      });
    } on AppError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _formError = const ErrorLocalizer().messageFor(error, t);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _formError = t.errors.unknown;
      });
    }
  }

  String? _chainIdErrorFor(String value) {
    if (value.isEmpty) {
      return t.chains.chainIdRequired;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return t.chains.invalidChainId;
    }
    return null;
  }

  String? _urlErrorFor(
    String value, {
    required String requiredMessage,
    required String invalidMessage,
  }) {
    if (value.isEmpty) {
      return requiredMessage;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return invalidMessage;
    }
    return null;
  }
}

final class _NetworkSection extends StatelessWidget {
  const _NetworkSection({
    required this.title,
    required this.chains,
    required this.selectedChain,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final List<ChainConfig> chains;
  final ChainConfig? selectedChain;
  final ValueChanged<ChainConfig> onTap;
  final ValueChanged<ChainConfig> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.appTextStyles.titleMedium),
        const SizedBox(height: 8),
        _NetworkGrid(
          chains: chains,
          selectedChain: selectedChain,
          onTap: onTap,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

final class _NetworkGrid extends StatelessWidget {
  const _NetworkGrid({
    required this.chains,
    required this.selectedChain,
    required this.onTap,
    this.onDelete,
    this.showRpcLabel = true,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding,
  });

  final List<ChainConfig> chains;
  final ChainConfig? selectedChain;
  final ValueChanged<ChainConfig> onTap;
  final ValueChanged<ChainConfig>? onDelete;
  final bool showRpcLabel;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.18,
        mainAxisExtent: showRpcLabel ? 208 : 176,
      ),
      itemCount: chains.length,
      itemBuilder: (context, index) {
        final chain = chains[index];
        return _NetworkChainCard(
          chain: chain,
          isSelected: selectedChain?.id == chain.id,
          onTap: () => onTap(chain),
          onDelete: onDelete == null || _isFixedChain(chain)
              ? null
              : () => onDelete!(chain),
          showRpcLabel: showRpcLabel,
        );
      },
    );
  }
}

final class _NetworkChainCard extends ConsumerWidget {
  const _NetworkChainCard({
    required this.chain,
    required this.isSelected,
    required this.onTap,
    required this.showRpcLabel,
    this.onDelete,
  });

  final ChainConfig chain;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showRpcLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNode =
        showRpcLabel ? ref.watch(selectedRpcNodeProvider(chain)).value : null;

    return InkWell(
      borderRadius: AppRadius.mediumBorder,
      onTap: onTap,
      child: AppSectionCard(
        borderColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : context.appColors.border,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TokenIcon(
                  symbol: chain.symbol,
                  logoUri: chainLogoUri(chain),
                  size: 32,
                  muted: !isSelected,
                  logoKeyPrefix: 'networkManagementChainLogo',
                  fallbackKeyPrefix: 'networkManagementChainLogoFallback',
                ),
                const Spacer(),
                if (isSelected) _Badge(label: t.chains.current),
                if (onDelete != null)
                  SizedBox.square(
                    dimension: 30,
                    child: IconButton(
                      tooltip: t.chains.removeNetwork,
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      onPressed: onDelete,
                      icon: const Icon(AppIcons.close),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              chain.name,
              style: context.appTextStyles.bodyLarge,
              maxLines: showRpcLabel ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Badge(label: '${t.chains.chainIdLabel}: ${chain.chainId}'),
                _Badge(
                  label: chain.isTestnet ? t.chains.testnet : t.chains.mainnet,
                ),
                _Badge(label: chain.symbol),
              ],
            ),
            if (showRpcLabel) ...[
              const Spacer(),
              Text(
                _rpcLabel(selectedNode),
                style: context.appTextStyles.caption.copyWith(
                  color: context.appColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _rpcLabel(RpcNode? node) {
    if (node == null) {
      return t.settings.currentRpcUnknown;
    }
    return node.name;
  }
}

bool _isFixedChain(ChainConfig chain) {
  return defaultChains.any((defaultChain) => defaultChain.id == chain.id);
}

final class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceSoft,
        borderRadius: AppRadius.smallBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: context.appTextStyles.caption),
      ),
    );
  }
}
