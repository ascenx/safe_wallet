import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet/wallet.dart' show isValidTronAddress;
import 'package:sui_dart/types/common.dart' show isValidStructTag;

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_input_borders.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/errors/app_error.dart';
import '../../../shared/errors/error_localizer.dart';
import '../../../shared/utils/evm_address.dart';
import '../../../shared/security/background_route_preservation.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../chains/domain/chain_config.dart';
import '../application/hidden_tokens_controller.dart';
import '../application/manual_token_add_controller.dart';
import '../application/token_discovery_controller.dart';
import '../application/token_repository_provider.dart';
import '../domain/token_info.dart';
import 'widgets/token_icon.dart';

final class TokenManagementPage extends ConsumerWidget {
  const TokenManagementPage({
    required this.chain,
    required this.rpcUrl,
    required this.walletAddress,
    this.rpcHeaders = const {},
    super.key,
  });

  final ChainConfig chain;
  final String rpcUrl;
  final String walletAddress;
  final Map<String, String> rpcHeaders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensValue = ref.watch(allTokensForChainProvider(chain.chainId));
    final discoveryValue = ref.watch(tokenDiscoveryControllerProvider);
    ref.listen(tokenDiscoveryControllerProvider, (previous, next) {
      if (previous?.isLoading != true || next.isLoading) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      next.when(
        data: (result) {
          if (result == null) {
            return;
          }
          final message = result.errorMessage != null
              ? t.tokens.discoveryFailed
              : result.tokens.isEmpty
              ? t.tokens.discoveryEmpty
              : t.tokens.discoverySuccess(count: result.tokens.length);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        error: (error, stackTrace) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(t.tokens.discoveryFailed)));
        },
        loading: () {},
      );
    });
    final hasWalletAddress = walletAddress.trim().isNotEmpty;
    final supportsManualTokenAdd =
        chain.chainType != ChainType.bitcoin && hasWalletAddress;
    final supportsTokenDiscovery =
        chain.chainType == ChainType.evm && hasWalletAddress;
    final showContractTokenActions =
        supportsManualTokenAdd || supportsTokenDiscovery;

    return Scaffold(
      appBar: AppBar(title: Text(t.tokens.managementTitle)),
      body: SafeArea(
        child: tokensValue.when(
          data: (tokens) {
            if (tokens.isEmpty) {
              return Center(
                child: Text(
                  t.tokens.empty,
                  style: context.appTextStyles.bodySmall,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                16,
                AppSpacing.pageX,
                96,
              ),
              itemBuilder: (context, index) {
                final token = tokens[index];
                return _TokenRow(
                  token: token,
                  onToggleHidden: () {
                    final contractAddress = token.contractAddress;
                    if (contractAddress == null) {
                      return;
                    }
                    final controller = ref.read(
                      hiddenTokensControllerProvider.notifier,
                    );
                    if (token.isHidden) {
                      controller.unhide(
                        chainId: token.chainId,
                        contractAddress: contractAddress,
                      );
                    } else {
                      controller.hide(
                        chainId: token.chainId,
                        contractAddress: contractAddress,
                      );
                    }
                  },
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sectionY),
              itemCount: tokens.length,
            );
          },
          error: (error, stackTrace) => Center(
            child: Text(
              t.tokens.loadFailed,
              style: context.appTextStyles.bodySmall,
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      bottomNavigationBar: showContractTokenActions
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pageX),
                child: Row(
                  children: [
                    if (supportsManualTokenAdd)
                      Expanded(
                        child: AppButton.secondary(
                          label: t.tokens.addToken,
                          icon: const Icon(AppIcons.add),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TokenUniversePage(
                                  chain: chain,
                                  rpcUrl: rpcUrl,
                                  walletAddress: walletAddress,
                                  rpcHeaders: rpcHeaders,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (supportsManualTokenAdd && supportsTokenDiscovery)
                      const SizedBox(width: 12),
                    if (supportsTokenDiscovery)
                      Expanded(
                        child: AppButton.primary(
                          label: discoveryValue.isLoading
                              ? t.tokens.discovering
                              : t.tokens.runDiscovery,
                          icon: discoveryValue.isLoading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(AppIcons.discover),
                          onPressed: discoveryValue.isLoading
                              ? null
                              : () {
                                  ref
                                      .read(
                                        tokenDiscoveryControllerProvider
                                            .notifier,
                                      )
                                      .discover(
                                        chain: chain,
                                        rpcUrl: rpcUrl,
                                        walletAddress: walletAddress,
                                        rpcHeaders: rpcHeaders,
                                      );
                                },
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

final class TokenUniversePage extends ConsumerStatefulWidget {
  const TokenUniversePage({
    required this.chain,
    required this.rpcUrl,
    required this.walletAddress,
    this.rpcHeaders = const {},
    super.key,
  });

  final ChainConfig chain;
  final String rpcUrl;
  final String walletAddress;
  final Map<String, String> rpcHeaders;

  @override
  ConsumerState<TokenUniversePage> createState() => _TokenUniversePageState();
}

final class _TokenUniversePageState extends ConsumerState<TokenUniversePage> {
  late final Future<List<TokenInfo>> _tokensFuture;
  String _query = '';
  String? _savingContractAddress;

  @override
  void initState() {
    super.initState();
    _tokensFuture = ref
        .read(tokenUniverseRepositoryProvider)
        .getTopTokens(chain: widget.chain, limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundRoutePreservationScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.tokens.addToken),
          actions: [
            TextButton(
              onPressed: _savingContractAddress == null
                  ? _showCustomTokenDialog
                  : null,
              child: Text(t.tokens.addCustomToken),
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
                  decoration: InputDecoration(
                    border: AppInputBorders.pill(context),
                    enabledBorder: AppInputBorders.pill(context),
                    focusedBorder: AppInputBorders.pillFocused(context),
                    errorBorder: AppInputBorders.pillError,
                    focusedErrorBorder: AppInputBorders.pillError,
                    prefixIcon: const Icon(AppIcons.search, size: 20),
                    hintText: t.tokens.searchTokenHint,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder<List<TokenInfo>>(
                  future: _tokensFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          t.tokens.loadFailed,
                          style: context.appTextStyles.bodySmall,
                        ),
                      );
                    }
                    final tokens = _filteredTokens(snapshot.data ?? const []);
                    if (tokens.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? t.tokens.empty
                              : t.tokens.emptySearch,
                          style: context.appTextStyles.bodySmall,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageX,
                        8,
                        AppSpacing.pageX,
                        24,
                      ),
                      itemBuilder: (context, index) {
                        final token = tokens[index];
                        return _UniverseTokenRow(
                          token: token,
                          isSaving:
                              token.contractAddress == _savingContractAddress,
                          onTap: _savingContractAddress == null
                              ? () => _addToken(token)
                              : null,
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemCount: tokens.length,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TokenInfo> _filteredTokens(List<TokenInfo> tokens) {
    if (_query.isEmpty) {
      return tokens;
    }
    return tokens
        .where((token) {
          return token.name.toLowerCase().contains(_query) ||
              token.symbol.toLowerCase().contains(_query) ||
              (token.contractAddress?.toLowerCase().contains(_query) ?? false);
        })
        .toList(growable: false);
  }

  Future<void> _addToken(TokenInfo token) async {
    setState(() {
      _savingContractAddress = token.contractAddress;
    });
    try {
      await ref.read(tokenRepositoryProvider).saveToken(token);
      ref.invalidate(tokensForChainProvider(widget.chain.chainId));
      ref.invalidate(allTokensForChainProvider(widget.chain.chainId));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _savingContractAddress = null;
      });
      final message = error is AppError
          ? const ErrorLocalizer().messageFor(error, t)
          : t.errors.unknown;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showCustomTokenDialog() async {
    final added = await showAddCustomTokenDialog(
      context: context,
      chain: widget.chain,
      rpcUrl: widget.rpcUrl,
      walletAddress: widget.walletAddress,
      rpcHeaders: widget.rpcHeaders,
    );
    if (added == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

Future<bool?> showAddCustomTokenDialog({
  required BuildContext context,
  required ChainConfig chain,
  required String rpcUrl,
  required String walletAddress,
  Map<String, String> rpcHeaders = const {},
}) {
  return AppDialog.showBuilder<bool>(
    context: context,
    builder: (_) => _AddTokenDialog(
      chain: chain,
      rpcUrl: rpcUrl,
      walletAddress: walletAddress,
      rpcHeaders: rpcHeaders,
    ),
  );
}

final class _AddTokenDialog extends ConsumerStatefulWidget {
  const _AddTokenDialog({
    required this.chain,
    required this.rpcUrl,
    required this.walletAddress,
    required this.rpcHeaders,
  });

  final ChainConfig chain;
  final String rpcUrl;
  final String walletAddress;
  final Map<String, String> rpcHeaders;

  @override
  ConsumerState<_AddTokenDialog> createState() => _AddTokenDialogState();
}

final class _AddTokenDialogState extends ConsumerState<_AddTokenDialog> {
  final _contractController = TextEditingController();
  final _symbolController = TextEditingController();
  final _nameController = TextEditingController();
  final _decimalsController = TextEditingController(text: '18');
  String? _contractError;
  String? _symbolError;
  String? _nameError;
  String? _decimalsError;
  String? _formError;
  bool _isSaving = false;

  @override
  void dispose() {
    _contractController.dispose();
    _symbolController.dispose();
    _nameController.dispose();
    _decimalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: t.tokens.addToken,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              controller: _contractController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: t.tokens.contractAddressLabel,
                errorText: _contractError,
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
                labelText: t.tokens.symbolLabel,
                errorText: _symbolError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              controller: _nameController,
              enabled: !_isSaving,
              decoration: InputDecoration(
                labelText: t.tokens.nameLabel,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              autocorrect: false,
              controller: _decimalsController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.tokens.decimalsLabel,
                errorText: _decimalsError,
              ),
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
      showCancel: true,
      showConfirm: true,
      cancelCallback: _isSaving ? null : () => Navigator.of(context).pop(false),
      confirmCallback: _isSaving ? null : _save,
      confirmChild: _isSaving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }

  Future<void> _save() async {
    final contractAddress = _contractController.text.trim();
    final symbol = _symbolController.text.trim();
    final name = _nameController.text.trim();
    final decimalsText = _decimalsController.text.trim();
    final decimals = decimalsText.isEmpty ? null : int.tryParse(decimalsText);
    final requiresManualMetadata =
        widget.chain.chainType == ChainType.solana ||
        widget.chain.chainType == ChainType.tron;
    setState(() {
      _contractError = _contractAddressError(contractAddress);
      _symbolError = requiresManualMetadata && symbol.isEmpty
          ? t.tokens.metadataRequired
          : null;
      _nameError = requiresManualMetadata && name.isEmpty
          ? t.tokens.metadataRequired
          : null;
      _decimalsError = _decimalsErrorFor(
        decimalsText,
        decimals,
        requiresManualMetadata,
      );
      _formError = null;
    });
    if (_contractError != null ||
        _symbolError != null ||
        _nameError != null ||
        _decimalsError != null ||
        (requiresManualMetadata && decimals == null)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(manualTokenAddControllerProvider.notifier)
          .addToken(
            chain: widget.chain,
            rpcUrl: widget.rpcUrl,
            walletAddress: widget.walletAddress,
            rpcHeaders: widget.rpcHeaders,
            contractAddress: contractAddress,
            symbol: _blankToNull(symbol),
            name: _blankToNull(name),
            decimals: decimals,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ManualTokenMetadataRequired {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _symbolError = symbol.isEmpty
            ? t.tokens.metadataRequired
            : _symbolError;
        _nameError = name.isEmpty ? t.tokens.metadataRequired : _nameError;
        _decimalsError = decimals == null
            ? t.tokens.invalidDecimals
            : _decimalsError;
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

  String? _contractAddressError(String value) {
    if (value.isEmpty) {
      return t.tokens.contractAddressRequired;
    }
    final isValid = switch (widget.chain.chainType) {
      ChainType.bitcoin => false,
      ChainType.tron => isValidTronAddress(value),
      ChainType.evm => isValidEvmAddressInput(value),
      ChainType.solana => RegExp(
        r'^[1-9A-HJ-NP-Za-km-z]{32,44}$',
      ).hasMatch(value),
      ChainType.sui => isValidStructTag(value),
    };
    return isValid ? null : t.tokens.invalidContractAddress;
  }

  String? _decimalsErrorFor(String decimalsText, int? decimals, bool required) {
    if (decimalsText.isEmpty) {
      return required ? t.tokens.invalidDecimals : null;
    }
    if (decimals == null || decimals < 0) {
      return t.tokens.invalidDecimals;
    }
    return null;
  }
}

final class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.token, required this.onToggleHidden});

  final TokenInfo token;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: AppRadius.largeBorder,
        border: Border.all(color: context.appColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          children: [
            TokenIcon(
              symbol: token.symbol,
              logoUri: token.logoUri,
              muted: token.isHidden,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token.name, style: context.appTextStyles.bodyLarge),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge(label: token.symbol),
                      _Badge(label: _sourceLabel(token.source)),
                      if (token.isHidden) _Badge(label: t.tokens.hidden),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onToggleHidden,
              child: Text(token.isHidden ? t.tokens.unhide : t.tokens.hide),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(TokenSource source) {
    return switch (source) {
      TokenSource.builtIn => t.tokens.builtIn,
      TokenSource.userAdded => t.tokens.userAdded,
      TokenSource.discovered => t.tokens.discovered,
    };
  }
}

final class _UniverseTokenRow extends StatelessWidget {
  const _UniverseTokenRow({
    required this.token,
    required this.isSaving,
    required this.onTap,
  });

  final TokenInfo token;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeBorder,
        side: BorderSide(color: context.appColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              TokenIcon(symbol: token.symbol, logoUri: token.logoUri),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      token.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      token.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.bodySmall,
                    ),
                    if (token.contractAddress case final address?) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isSaving)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(AppIcons.chevronRight, color: context.appColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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
