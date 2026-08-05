import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_lifecycle_observer.dart';
import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../dapp/application/dapp_request_controller.dart';
import '../../dapp/application/dapp_request_coordinator.dart';
import '../../dapp/presentation/dapp_authorization_sheet.dart';
import '../../dapp/presentation/dapp_signature_confirm_sheet.dart';
import '../../dapp/presentation/dapp_transaction_confirm_sheet.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/domain/wallet_account.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../application/wallet_connect_capabilities.dart';
import '../application/wallet_connect_controller.dart';
import '../application/wallet_connect_request_adapter.dart';
import '../data/wallet_connect_gateway.dart';
import '../data/wallet_connect_link_service.dart';
import '../domain/wallet_connect_models.dart';
import '../domain/wallet_connect_namespace.dart';
import 'wallet_connect_peer_avatar.dart';

final class WalletConnectRequestHost extends ConsumerStatefulWidget {
  const WalletConnectRequestHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WalletConnectRequestHost> createState() =>
      _WalletConnectRequestHostState();
}

final class _WalletConnectRequestHostState
    extends ConsumerState<WalletConnectRequestHost> {
  StreamSubscription<WalletConnectRequest>? _requestSubscription;
  StreamSubscription<WalletConnectRequest>? _cancellationSubscription;
  StreamSubscription<String>? _linkSubscription;
  int? _showingProposalId;
  String? _activeRequestKey;
  bool _requestPromptVisible = false;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(walletConnectControllerProvider.notifier);
    _requestSubscription = controller.requestQueue.requests.listen(
      (request) => unawaited(_handleRequest(request)),
    );
    _cancellationSubscription = controller.requestQueue.cancelledRequests
        .listen(_handleCancelledRequest);
    controller.requestQueue.replayActive();
    final linkService = ref.read(walletConnectLinkServiceProvider);
    _linkSubscription = linkService.links.listen(
      (uri) => unawaited(_handleLink(uri)),
    );
    unawaited(
      Future<void>.microtask(() async {
        await controller.initialize();
        final initialUri = await linkService.getInitialUri();
        if (initialUri != null) {
          await _handleLink(initialUri);
        }
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_requestSubscription?.cancel());
    unawaited(_cancellationSubscription?.cancel());
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WalletConnectProposal?>(
      walletConnectControllerProvider.select((state) => state.pendingProposal),
      (_, proposal) {
        if (proposal != null && proposal.id != _showingProposalId) {
          _showingProposalId = proposal.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(_showProposal(proposal));
            }
          });
        }
      },
    );
    return widget.child;
  }

  Future<void> _showProposal(WalletConnectProposal proposal) async {
    final context = _navigatorContext;
    if (context == null) {
      _showingProposalId = null;
      return;
    }
    final capabilities = await _capabilities();
    if (!mounted || capabilities == null) {
      await ref
          .read(walletConnectControllerProvider.notifier)
          .rejectProposalById(proposal.id);
      _showingProposalId = null;
      return;
    }
    final validation = capabilities.validate(
      required: proposal.requiredNamespaces,
      optional: proposal.optionalNamespaces,
    );
    if (!context.mounted) {
      _showingProposalId = null;
      return;
    }
    final verifyBlocksApproval = proposal.verifyContext?.blocksApproval == true;
    final approved = await AppDialog.show<bool>(
      context: context,
      title: context.t.advanced.walletConnectProposalTitle,
      content: _ProposalContent(proposal: proposal, validation: validation),
      cancelCallback: () => Navigator.of(context).pop(false),
      cancelTitle: context.t.advanced.walletConnectReject,
      confirmCallback: validation.canApprove && !verifyBlocksApproval
          ? () => Navigator.of(context).pop(true)
          : null,
      confirmTitle: context.t.advanced.walletConnectApprove,
      showConfirm: true,
      barrierDismissible: false,
    );
    if (!mounted) {
      return;
    }
    if (approved == true && validation.canApprove && !verifyBlocksApproval) {
      await ref
          .read(walletConnectControllerProvider.notifier)
          .approveProposalById(proposal.id, validation.approved);
    } else {
      await ref
          .read(walletConnectControllerProvider.notifier)
          .rejectProposalById(proposal.id);
    }
    _showingProposalId = null;
  }

  Future<void> _handleLink(String uri) async {
    final controller = ref.read(walletConnectControllerProvider.notifier);
    await controller.initialize();
    await controller.pair(uri);
  }

  Future<void> _handleRequest(WalletConnectRequest request) async {
    final controller = ref.read(walletConnectControllerProvider.notifier);
    _activeRequestKey = request.dedupeKey;
    try {
      var session = _session(request.topic);
      final account = await _selectedAccount();
      if (session == null || account == null) {
        await _respondValidation(
          request,
          WalletConnectRequestValidation.invalidSession,
        );
        return;
      }
      var validation = validateWalletConnectRequest(
        request: request,
        session: session,
        accountAddress: _addressFor(request, account),
        now: DateTime.now(),
      );
      if (validation != WalletConnectRequestValidation.valid) {
        await _respondValidation(request, validation);
        return;
      }

      final context = _navigatorContext;
      if (context == null) {
        await _respondValidation(
          request,
          WalletConnectRequestValidation.invalidSession,
        );
        return;
      }
      final coordinator = DappRequestCoordinator(
        handle:
            (
              dappRequest, {
              authorizationDecision,
              confirmationDecision,
              signingPassword,
              rememberSigningPassword = true,
            }) {
              return ref
                  .read(dappRequestControllerProvider.notifier)
                  .handle(
                    dappRequest,
                    authorizationDecision: authorizationDecision,
                    confirmationDecision: confirmationDecision,
                    signingPassword: signingPassword,
                    rememberSigningPassword: rememberSigningPassword,
                  );
            },
        showAuthorization: (confirmation) =>
            _showAuthorizationPrompt(context, confirmation),
        showConfirmation: (confirmation) =>
            _showConfirmationPrompt(context, confirmation),
        requestSigningPassword: () => _showPasswordPrompt(context),
      );
      final result = await coordinator.process(
        walletConnectDappRequest(
          request,
          authorizedAddress: _addressFor(request, account),
        ),
      );

      session = _session(request.topic);
      final currentAccount = await _selectedAccount();
      if (session == null || currentAccount == null) {
        await _respondValidation(
          request,
          WalletConnectRequestValidation.invalidSession,
        );
        return;
      }
      validation = validateWalletConnectRequest(
        request: request,
        session: session,
        accountAddress: _addressFor(request, currentAccount),
        now: DateTime.now(),
      );
      if (validation != WalletConnectRequestValidation.valid) {
        await _respondValidation(request, validation);
        return;
      }
      final response = walletConnectResponse(request, result);
      if (response.error == null) {
        await ref
            .read(walletConnectGatewayProvider)
            .respond(request.topic, response);
      } else {
        await controller.respondError(request.topic, response);
      }
    } catch (_) {
      if (_session(request.topic) != null) {
        await controller.respondError(
          request.topic,
          WalletConnectResponse.error(
            id: request.id,
            error: const WalletConnectResponseError(
              code: -32000,
              message: 'Request failed',
            ),
          ),
        );
      }
    } finally {
      controller.requestQueue.complete(topic: request.topic, id: request.id);
      if (_activeRequestKey == request.dedupeKey) {
        _activeRequestKey = null;
        _requestPromptVisible = false;
      }
    }
  }

  void _handleCancelledRequest(WalletConnectRequest request) {
    if (_activeRequestKey != request.dedupeKey || !_requestPromptVisible) {
      return;
    }
    final navigator = ref.read(appNavigatorKeyProvider).currentState;
    if (navigator?.canPop() == true) {
      navigator!.pop();
    }
  }

  Future<DappAuthorizationDecision> _showAuthorizationPrompt(
    BuildContext context,
    DappRequestConfirmation confirmation,
  ) async {
    _requestPromptVisible = true;
    try {
      return await showDappAuthorizationSheet(context, confirmation);
    } finally {
      _requestPromptVisible = false;
    }
  }

  Future<DappConfirmationDecision> _showConfirmationPrompt(
    BuildContext context,
    DappRequestConfirmation confirmation,
  ) async {
    _requestPromptVisible = true;
    try {
      return await switch (confirmation.kind) {
        DappConfirmationKind.signature => showDappSignatureConfirmSheet(
          context,
          confirmation,
        ),
        DappConfirmationKind.transaction => showDappTransactionConfirmSheet(
          context,
          confirmation,
        ),
        DappConfirmationKind.authorization ||
        DappConfirmationKind.chainSwitch => Future.value(
          DappConfirmationDecision.rejected,
        ),
      };
    } finally {
      _requestPromptVisible = false;
    }
  }

  Future<({String password, bool rememberPassword})?> _showPasswordPrompt(
    BuildContext context,
  ) async {
    _requestPromptVisible = true;
    try {
      final authorization = await showSigningPasswordSheet(context);
      if (authorization == null) {
        return null;
      }
      return (
        password: authorization.password,
        rememberPassword: authorization.rememberPassword,
      );
    } finally {
      _requestPromptVisible = false;
    }
  }

  Future<void> _respondValidation(
    WalletConnectRequest request,
    WalletConnectRequestValidation validation,
  ) {
    return ref
        .read(walletConnectControllerProvider.notifier)
        .respondError(
          request.topic,
          walletConnectValidationError(request, validation),
        );
  }

  WalletConnectSession? _session(String topic) {
    for (final session in ref.read(walletConnectControllerProvider).sessions) {
      if (session.topic == topic) {
        return session;
      }
    }
    return null;
  }

  Future<WalletConnectCapabilities?> _capabilities() async {
    final account = await _selectedAccount();
    if (account == null) {
      return null;
    }
    final chains = await ref.read(availableChainsProvider.future);
    return buildWalletConnectCapabilities(chains: chains, account: account);
  }

  Future<WalletAccount?> _selectedAccount() async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    final selectedId = ref.read(selectedWalletIdProvider);
    for (final wallet in wallets) {
      if (selectedId == null || wallet.id == selectedId) {
        return wallet;
      }
    }
    return null;
  }

  String _addressFor(WalletConnectRequest request, WalletAccount account) {
    return switch (request.chain.namespace) {
      'eip155' => account.evmAddress,
      'solana' => account.solanaAddress,
      _ => '',
    };
  }

  BuildContext? get _navigatorContext =>
      ref.read(appNavigatorKeyProvider).currentContext;
}

final class _ProposalContent extends StatelessWidget {
  const _ProposalContent({required this.proposal, required this.validation});

  final WalletConnectProposal proposal;
  final WalletConnectNamespaceValidation validation;

  @override
  Widget build(BuildContext context) {
    final namespaces = <WalletConnectNamespaceProposal>[
      ...proposal.requiredNamespaces.values,
      ...proposal.optionalNamespaces.values,
    ];
    final chains = namespaces
        .expand((namespace) => namespace.chains)
        .map((chain) => chain.toString())
        .toSet()
        .join('\n');
    final methods = namespaces
        .expand((namespace) => namespace.methods)
        .toSet()
        .join('\n');
    final events = namespaces
        .expand((namespace) => namespace.events)
        .toSet()
        .join('\n');
    final accounts = validation.approved.values
        .expand((namespace) => namespace.accounts)
        .map((account) => account.toString())
        .toSet()
        .join('\n');
    final domain = Uri.tryParse(proposal.peer.url)?.host ?? proposal.peer.url;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WalletConnectPeerAvatar(peer: proposal.peer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.peer.name,
                        style: context.appTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        domain,
                        style: context.appTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _VerifyContextBanner(
              context: proposal.verifyContext,
              fallbackOrigin: domain,
            ),
            if (proposal.peer.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                proposal.peer.description.trim(),
                style: context.appTextStyles.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.sectionY),
            _ProposalSection(
              label: context.t.advanced.walletConnectProposalAccounts,
              value: accounts,
            ),
            _ProposalSection(
              label: context.t.advanced.walletConnectProposalNetworks,
              value: chains,
            ),
            _ProposalSection(
              label: context.t.advanced.walletConnectProposalMethods,
              value: methods,
            ),
            _ProposalSection(
              label: context.t.advanced.walletConnectProposalEvents,
              value: events,
            ),
            if (!validation.canApprove)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.t.advanced.walletConnectUnsupportedProposal,
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

final class _VerifyContextBanner extends StatelessWidget {
  const _VerifyContextBanner({
    required this.context,
    required this.fallbackOrigin,
  });

  final WalletConnectVerifyContext? context;
  final String fallbackOrigin;

  @override
  Widget build(BuildContext buildContext) {
    final verifyContext = context;
    final status = verifyContext?.status ?? WalletConnectVerifyStatus.unknown;
    final origin = verifyContext?.origin.isNotEmpty == true
        ? verifyContext!.origin
        : fallbackOrigin;
    final (background, foreground, message) = switch (status) {
      WalletConnectVerifyStatus.valid => (
        buildContext.appColors.successSoft,
        AppColors.success,
        buildContext.t.advanced.walletConnectVerifyValid,
      ),
      WalletConnectVerifyStatus.invalid => (
        buildContext.appColors.dangerSoft,
        AppColors.danger,
        buildContext.t.advanced.walletConnectVerifyInvalid,
      ),
      WalletConnectVerifyStatus.scam => (
        buildContext.appColors.dangerSoft,
        AppColors.danger,
        buildContext.t.advanced.walletConnectVerifyScam,
      ),
      WalletConnectVerifyStatus.unknown => (
        buildContext.appColors.warningSoft,
        AppColors.warning,
        buildContext.t.advanced.walletConnectVerifyUnknown,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: buildContext.appTextStyles.bodySmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (origin.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                origin,
                style: buildContext.appTextStyles.caption.copyWith(
                  color: foreground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ProposalSection extends StatelessWidget {
  const _ProposalSection({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.appTextStyles.caption),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: context.appTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
