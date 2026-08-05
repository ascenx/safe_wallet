import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/security/background_route_preservation.dart';
import '../../../shared/errors/rpc_error.dart';
import '../../../shared/chain_clients/solana_client_factory.dart';
import '../../../shared/widgets/app_action_sheet.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_password_text_field.dart';
import '../../../shared/widgets/app_picker_field.dart';
import '../../chains/domain/chain_config.dart';
import '../application/rpc_node_test_controller.dart';
import '../application/selected_rpc_node_provider.dart';
import '../domain/rpc_endpoint.dart';
import '../domain/rpc_node.dart';
import '../domain/rpc_provider_catalog.dart';

final class EditRpcNodePage extends ConsumerStatefulWidget {
  const EditRpcNodePage({
    required this.chain,
    this.node,
    super.key,
  });

  final ChainConfig chain;
  final RpcNode? node;

  @override
  ConsumerState<EditRpcNodePage> createState() => _EditRpcNodePageState();
}

final class _EditRpcNodePageState extends ConsumerState<EditRpcNodePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _noteController;
  late final TextEditingController _credentialController;
  late final TextEditingController _credentialParameterController;
  late RpcProvider _provider;
  late RpcCredentialMode _credentialMode;
  String? _nameError;
  String? _urlError;
  String? _credentialError;
  String? _formError;
  bool _isSaving = false;

  bool get _isEditing => widget.node != null;

  bool get _hasStoredFullEndpoint =>
      _isEditing &&
      widget.node!.credentialMode == RpcCredentialMode.fullEndpoint;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.node?.name);
    _urlController = TextEditingController(
      text: _hasStoredFullEndpoint ? '' : widget.node?.url,
    );
    _noteController = TextEditingController(text: widget.node?.note);
    _credentialController = TextEditingController();
    _credentialParameterController = TextEditingController(
      text: widget.node?.credentialParameter,
    );
    _provider = widget.node?.provider ?? RpcProvider.custom;
    _credentialMode = _hasStoredFullEndpoint
        ? RpcCredentialMode.none
        : widget.node?.credentialMode ?? RpcCredentialMode.none;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    _credentialController.dispose();
    _credentialParameterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundRoutePreservationScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? t.nodes.editNode : t.nodes.addNode),
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
                _isEditing ? t.nodes.editNode : t.nodes.addNode,
                style: context.appTextStyles.titleLarge,
              ),
              const SizedBox(height: 18),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _nameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: t.nodes.nameLabel,
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              AppPickerField(
                key: const Key('rpcProviderSelector'),
                label: t.nodes.providerLabel,
                value: _providerLabel(_provider),
                onTap: _isSaving ? null : _showProviderSheet,
              ),
              if (_provider == RpcProvider.custom ||
                  _provider == RpcProvider.quickNode) ...[
                const SizedBox(height: 12),
                TextField(
                  spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  controller: _urlController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: t.nodes.urlLabel,
                    hintText: _hasStoredFullEndpoint &&
                            widget.node!.provider == _provider
                        ? t.nodes.urlKeepHint
                        : null,
                    errorText: _urlError,
                  ),
                ),
              ],
              if (_provider == RpcProvider.custom) ...[
                const SizedBox(height: 12),
                AppPickerField(
                  key: const Key('rpcAuthModeSelector'),
                  label: t.nodes.authModeLabel,
                  value: _credentialModeLabel(_credentialMode),
                  onTap: _isSaving ? null : _showCredentialModeSheet,
                ),
                if (_credentialMode == RpcCredentialMode.queryParameter ||
                    _credentialMode == RpcCredentialMode.header) ...[
                  const SizedBox(height: 12),
                  TextField(
                    spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                    autocorrect: false,
                    controller: _credentialParameterController,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      labelText: t.nodes.credentialParameterLabel,
                    ),
                  ),
                ],
              ],
              if (_credentialMode != RpcCredentialMode.none) ...[
                const SizedBox(height: 12),
                AppPasswordTextField(
                  controller: _credentialController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: t.nodes.apiKeyLabel,
                    hintText: _isEditing &&
                            widget.node!.credentialMode !=
                                RpcCredentialMode.none
                        ? t.nodes.credentialKeepHint
                        : null,
                    errorText: _credentialError,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                autocorrect: false,
                controller: _noteController,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: t.nodes.noteLabel),
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
              const SizedBox(height: 24),
              AppButton.primary(
                label: t.nodes.save,
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final credential = _credentialController.text.trim();
    final draft = _connectionDraft();
    final requiresNewCredential = _credentialMode != RpcCredentialMode.none &&
        (!_isEditing ||
            widget.node!.provider != _provider ||
            widget.node!.credentialMode == RpcCredentialMode.none);
    setState(() {
      _nameError = name.isEmpty ? t.nodes.nameRequired : null;
      _urlError = draft == null
          ? t.nodes.providerUnsupported
          : _urlValidationError(draft.url);
      _credentialError = requiresNewCredential && credential.isEmpty
          ? t.nodes.credentialRequired
          : null;
      _formError = null;
    });
    if (_nameError != null ||
        _urlError != null ||
        _credentialError != null ||
        draft == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final nodeDraft = RpcNode(
        id: widget.node?.id ?? 'rpc-node-draft',
        chainId: widget.chain.chainId,
        name: name,
        url: draft.url,
        nodeType: RpcNodeType.custom,
        isSelected: widget.node?.isSelected ?? false,
        lastTestStatus: RpcNodeTestStatus.untested,
        provider: _provider,
        credentialMode: draft.credentialMode,
        credentialParameter: draft.credentialParameter,
        credentialRef: widget.node?.credentialRef,
      );
      final resolver = ref.read(rpcEndpointResolverProvider);
      final endpoint = draft.credentialMode == RpcCredentialMode.none
          ? await resolver.resolve(nodeDraft)
          : credential.isNotEmpty
              ? resolver.resolveWithCredential(nodeDraft, credential)
              : await resolver.resolve(nodeDraft);
      await _validateNodeBeforeSave(endpoint);
      final repository = ref.read(rpcNodeRepositoryProvider);
      if (_isEditing) {
        await repository.updateCustomNode(
          chain: widget.chain,
          nodeId: widget.node!.id,
          name: name,
          url: draft.url,
          note: _noteController.text,
          provider: _provider,
          credentialMode: draft.credentialMode,
          credentialParameter: draft.credentialParameter,
          credential: credential.isEmpty ? null : credential,
        );
      } else {
        await repository.addCustomNode(
          chain: widget.chain,
          name: name,
          url: draft.url,
          note: _noteController.text,
          provider: _provider,
          credentialMode: draft.credentialMode,
          credentialParameter: draft.credentialParameter,
          credential: credential.isEmpty ? null : credential,
        );
      }
      ref.invalidate(rpcNodesForChainProvider(widget.chain));
      ref.invalidate(selectedRpcNodeProvider(widget.chain));
      if (mounted) {
        Navigator.of(context).pop();
      }
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

  String? _urlValidationError(String url) {
    if (url.isEmpty) {
      return t.nodes.urlRequired;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && _isLoopbackHost(uri.host)))) {
      return t.errors.invalidRpcUrl;
    }
    return null;
  }

  Future<void> _validateNodeBeforeSave(ResolvedRpcEndpoint endpoint) async {
    final url = endpoint.url;
    try {
      switch (widget.chain.chainType) {
        case ChainType.evm:
          final client = ref.read(evmClientFactoryProvider);
          final actualChainId = await client.readChainId(
            url,
            headers: endpoint.headers,
          );
          if (actualChainId != widget.chain.chainId) {
            throw RpcError.chainMismatch(
              expectedChainId: widget.chain.chainId,
              actualChainId: actualChainId,
            );
          }
          await client.readBlockNumber(url, headers: endpoint.headers);
        case ChainType.solana:
          final solanaClient = ref.read(solanaClientFactoryProvider);
          await solanaClient.checkHealth(url, headers: endpoint.headers);
          final expectedGenesisHashPrefix = expectedSolanaGenesisHashPrefix(
            widget.chain.chainId,
          );
          if (expectedGenesisHashPrefix != null) {
            final actualGenesisHash = await solanaClient.readGenesisHash(
              url,
              headers: endpoint.headers,
            );
            if (!matchesExpectedSolanaGenesisHash(
              widget.chain.chainId,
              actualGenesisHash,
            )) {
              throw RpcError.chainMismatch(
                expectedChainId: expectedGenesisHashPrefix,
                actualChainId: actualGenesisHash,
              );
            }
          }
        case ChainType.bitcoin:
          await ref.read(bitcoinClientFactoryProvider).readBlockHeight(url);
        case ChainType.tron:
          await ref.read(tronClientFactoryProvider).readBlockHeight(
                url,
                headers: endpoint.headers,
              );
        case ChainType.sui:
          await ref.read(suiClientFactoryProvider).getServiceInfo(
                url,
                headers: endpoint.headers,
              );
      }
    } on RpcError {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        RpcError.unavailable(debugMessage: error.toString()),
        stackTrace,
      );
    }
  }

  List<RpcProvider> _availableProviders() {
    final providers = <RpcProvider>[
      RpcProvider.custom,
      RpcProvider.quickNode,
    ];
    for (final provider in const [
      RpcProvider.helius,
      RpcProvider.alchemy,
      RpcProvider.infura,
      RpcProvider.tronGrid,
    ]) {
      if (RpcProviderCatalog.forChain(
            provider: provider,
            chainType: _providerChainType(widget.chain.chainType),
            chainId: widget.chain.chainId,
          ) !=
          null) {
        providers.add(provider);
      }
    }
    if (!providers.contains(_provider)) {
      providers.add(_provider);
    }
    return providers;
  }

  Future<void> _showProviderSheet() async {
    final provider = await showAppActionSheet<RpcProvider>(
      context,
      title: t.nodes.providerLabel,
      actions: [
        for (final provider in _availableProviders())
          AppActionSheetAction<RpcProvider>(
            value: provider,
            title: _providerLabel(provider),
            icon: _providerIcon(provider),
            isSelected: provider == _provider,
          ),
      ],
    );
    if (!mounted || provider == null || provider == _provider) {
      return;
    }
    _changeProvider(provider);
  }

  Future<void> _showCredentialModeSheet() async {
    final mode = await showAppActionSheet<RpcCredentialMode>(
      context,
      title: t.nodes.authModeLabel,
      actions: [
        for (final mode in _availableCredentialModes())
          AppActionSheetAction<RpcCredentialMode>(
            value: mode,
            title: _credentialModeLabel(mode),
            icon: _credentialModeIcon(mode),
            isSelected: mode == _credentialMode,
          ),
      ],
    );
    if (!mounted || mode == null || mode == _credentialMode) {
      return;
    }
    setState(() {
      _credentialMode = mode;
      _credentialError = null;
    });
  }

  void _changeProvider(RpcProvider provider) {
    final preset = RpcProviderCatalog.forChain(
      provider: provider,
      chainType: _providerChainType(widget.chain.chainType),
      chainId: widget.chain.chainId,
    );
    setState(() {
      _provider = provider;
      _credentialMode = provider == RpcProvider.custom
          ? RpcCredentialMode.none
          : provider == RpcProvider.quickNode
              ? RpcCredentialMode.none
              : preset?.credentialMode ?? RpcCredentialMode.none;
      _credentialParameterController.text = preset?.credentialParameter ?? '';
      _credentialController.clear();
      _urlError = null;
      _credentialError = null;
    });
  }

  _RpcNodeConnectionDraft? _connectionDraft() {
    final url = _urlController.text.trim();
    if (_hasStoredFullEndpoint &&
        url.isEmpty &&
        widget.node!.provider == _provider) {
      return _RpcNodeConnectionDraft(
        url: widget.node!.url,
        credentialMode: RpcCredentialMode.fullEndpoint,
      );
    }
    if (_provider == RpcProvider.custom) {
      return _RpcNodeConnectionDraft(
        url: url,
        credentialMode: _credentialMode,
        credentialParameter: _credentialParameterController.text.trim().isEmpty
            ? null
            : _credentialParameterController.text.trim(),
      );
    }
    if (_provider == RpcProvider.quickNode) {
      return _RpcNodeConnectionDraft(
        url: url,
        credentialMode: RpcCredentialMode.none,
      );
    }
    final preset = RpcProviderCatalog.forChain(
      provider: _provider,
      chainType: _providerChainType(widget.chain.chainType),
      chainId: widget.chain.chainId,
    );
    if (preset == null) {
      return null;
    }
    return _RpcNodeConnectionDraft(
      url: preset.url,
      credentialMode: preset.credentialMode,
      credentialParameter: preset.credentialParameter,
    );
  }

  String _providerLabel(RpcProvider provider) {
    return switch (provider) {
      RpcProvider.public => 'Public',
      RpcProvider.custom => t.nodes.customProvider,
      RpcProvider.helius => 'Helius',
      RpcProvider.quickNode => 'QuickNode',
      RpcProvider.alchemy => 'Alchemy',
      RpcProvider.infura => 'Infura',
      RpcProvider.tronGrid => 'TronGrid',
    };
  }

  IconData _providerIcon(RpcProvider provider) {
    return switch (provider) {
      RpcProvider.public => AppIcons.globe,
      RpcProvider.custom => AppIcons.filters,
      RpcProvider.helius => AppIcons.lightning,
      RpcProvider.quickNode => AppIcons.speed,
      RpcProvider.alchemy => AppIcons.lab,
      RpcProvider.infura => AppIcons.cloud,
      RpcProvider.tronGrid => AppIcons.grid,
    };
  }

  String _credentialModeLabel(RpcCredentialMode mode) {
    return switch (mode) {
      RpcCredentialMode.none => t.nodes.authNone,
      RpcCredentialMode.queryParameter => t.nodes.authQuery,
      RpcCredentialMode.pathSegment => t.nodes.authPath,
      RpcCredentialMode.header => t.nodes.authHeader,
      RpcCredentialMode.fullEndpoint => t.nodes.urlLabel,
    };
  }

  IconData _credentialModeIcon(RpcCredentialMode mode) {
    return switch (mode) {
      RpcCredentialMode.none => AppIcons.unlock,
      RpcCredentialMode.queryParameter => AppIcons.help,
      RpcCredentialMode.pathSegment => AppIcons.route,
      RpcCredentialMode.header => AppIcons.http,
      RpcCredentialMode.fullEndpoint => AppIcons.link,
    };
  }

  List<RpcCredentialMode> _availableCredentialModes() {
    return [
      RpcCredentialMode.none,
      RpcCredentialMode.queryParameter,
      RpcCredentialMode.pathSegment,
      if (widget.chain.chainType == ChainType.tron ||
          _credentialMode == RpcCredentialMode.header)
        RpcCredentialMode.header,
    ];
  }
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

final class _RpcNodeConnectionDraft {
  const _RpcNodeConnectionDraft({
    required this.url,
    required this.credentialMode,
    this.credentialParameter,
  });

  final String url;
  final RpcCredentialMode credentialMode;
  final String? credentialParameter;
}

RpcProviderChainType _providerChainType(ChainType chainType) {
  return switch (chainType) {
    ChainType.evm => RpcProviderChainType.evm,
    ChainType.bitcoin => RpcProviderChainType.bitcoin,
    ChainType.tron => RpcProviderChainType.tron,
    ChainType.solana => RpcProviderChainType.solana,
    ChainType.sui => RpcProviderChainType.sui,
  };
}
