import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../i18n/generated/translations.g.dart';
import '../../../shared/design/app_colors.dart';
import '../../../shared/design/app_radius.dart';
import '../../../shared/design/app_spacing.dart';
import '../../../shared/design/app_text_styles.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../chains/application/available_chains_provider.dart';
import '../../chains/application/selected_chain_controller.dart';
import '../../chains/domain/chain_config.dart';
import '../../dapp/application/dapp_request_controller.dart';
import '../../dapp/application/dapp_request_coordinator.dart';
import '../../dapp/application/dapp_request_queue.dart';
import '../../dapp/data/dapp_provider_bridge_service.dart';
import '../../dapp/data/dapp_provider_webview_injector.dart';
import '../../dapp/presentation/dapp_authorization_sheet.dart';
import '../../dapp/presentation/dapp_sheet_container.dart';
import '../../dapp/presentation/dapp_signature_confirm_sheet.dart';
import '../../dapp/presentation/dapp_transaction_confirm_sheet.dart';
import '../../wallet/presentation/signing_password_sheet.dart';
import '../../wallet_connect/application/wallet_connect_controller.dart';
import '../../wallet_connect/data/wallet_connect_link_service.dart';
import '../application/dapp_recent_visits_controller.dart';

final class DappBrowserPage extends ConsumerStatefulWidget {
  const DappBrowserPage({
    required this.initialUrl,
    this.onControllerCreated,
    this.onPageFinished,
    super.key,
  });

  final String initialUrl;
  final ValueChanged<WebViewController>? onControllerCreated;
  final ValueChanged<String>? onPageFinished;

  @override
  ConsumerState<DappBrowserPage> createState() => _DappBrowserPageState();
}

final class _DappBrowserPageState extends ConsumerState<DappBrowserPage> {
  late final WebViewController _webViewController;
  late final TextEditingController _urlController;
  late final DappProviderBridgeService _bridgeSession;
  final DappRequestQueue _requestQueue = DappRequestQueue();
  String _currentUrl = '';
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _providerInjectionGeneration = 0;
  int _navigationEpoch = 0;

  static const _earlyProviderInjectionAttempts = 6;
  static const _earlyProviderInjectionRetryDelay = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _urlController = TextEditingController(text: widget.initialUrl);
    _bridgeSession = ref
        .read(dappProviderBridgeServiceProvider)
        .createSession();
    _webViewController = WebViewController();
    widget.onControllerCreated?.call(_webViewController);
    unawaited(_configureWebViewAndLoadInitialUrl());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _BrowserToolbar(
              controller: _urlController,
              canGoBack: _canGoBack,
              canGoForward: _canGoForward,
              onClose: () => Navigator.of(context).maybePop(),
              onBack: _goBack,
              onForward: _goForward,
              onRefresh: _webViewController.reload,
              onSubmitted: _loadFromAddressBar,
            ),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: WebViewWidget(controller: _webViewController)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleJavaScriptMessage(JavaScriptMessage message) async {
    final fallbackOrigin = await _webViewController.currentUrl() ?? _currentUrl;
    if (!_isInjectableWebUrl(fallbackOrigin)) {
      return;
    }
    final requestEpoch = _navigationEpoch;
    return _requestQueue.enqueue(
      () => _processJavaScriptMessage(
        message,
        fallbackOrigin: fallbackOrigin,
        requestEpoch: requestEpoch,
      ),
    );
  }

  Future<void> _processJavaScriptMessage(
    JavaScriptMessage message, {
    required String fallbackOrigin,
    required int requestEpoch,
  }) async {
    final latestOrigin = await _webViewController.currentUrl() ?? _currentUrl;
    if (requestEpoch != _navigationEpoch ||
        _originOf(latestOrigin) != _originOf(fallbackOrigin)) {
      return;
    }
    final bridge = _bridgeSession;
    _dappLog('bridge message received', {
      'fallbackOrigin': fallbackOrigin,
      'messageLength': message.message.length,
    });
    final request = bridge.parseRequest(
      message: message.message,
      fallbackOrigin: fallbackOrigin,
    );
    if (request == null) {
      _dappLog('bridge message ignored', {
        'reason': 'invalid_request',
        'fallbackOrigin': fallbackOrigin,
      });
      return;
    }

    _dappLog('request parsed', _requestLogDetails(request));
    final result = await _handleDappRequest(request);
    final latestUrl = await _webViewController.currentUrl() ?? _currentUrl;
    if (requestEpoch != _navigationEpoch ||
        _originOf(latestUrl) != _originOf(fallbackOrigin)) {
      return;
    }
    _dappLog('request result', {
      ..._requestLogDetails(request),
      'status': result.status.name,
      'errorCode': result.errorCode,
      'valueType': _valueType(result.value),
    });
    final callbackScript = bridge.callbackScript(
      request: request,
      result: result,
    );
    _dappLog('callback script sending', {
      ..._requestLogDetails(request),
      'scriptLength': callbackScript.length,
    });
    try {
      await _webViewController.runJavaScript(callbackScript);
      _dappLog('callback script sent', _requestLogDetails(request));
    } catch (error) {
      _dappLog('callback script error', {
        ..._requestLogDetails(request),
        'error': _truncateLogValue(error.toString()),
      });
      rethrow;
    }
  }

  Future<DappRequestResult> _handleDappRequest(DappRpcRequest request) async {
    final coordinator = DappRequestCoordinator(
      handle:
          (
            request, {
            authorizationDecision,
            confirmationDecision,
            signingPassword,
            rememberSigningPassword = true,
          }) {
            if (!mounted) {
              return Future.value(const DappRequestResult.rejected());
            }
            return ref
                .read(dappRequestControllerProvider.notifier)
                .handle(
                  request,
                  authorizationDecision: authorizationDecision,
                  confirmationDecision: confirmationDecision,
                  signingPassword: signingPassword,
                  rememberSigningPassword: rememberSigningPassword,
                );
          },
      showAuthorization: (confirmation) {
        if (!mounted) {
          return Future.value(DappAuthorizationDecision.rejected);
        }
        return showDappAuthorizationSheet(context, confirmation);
      },
      showConfirmation: (confirmation) {
        if (!mounted) {
          return Future.value(DappConfirmationDecision.rejected);
        }
        return _showConfirmation(confirmation);
      },
      requestSigningPassword: () async {
        if (!mounted) {
          return null;
        }
        final authorization = await showSigningPasswordSheet(context);
        if (authorization == null) {
          return null;
        }
        return (
          password: authorization.password,
          rememberPassword: authorization.rememberPassword,
        );
      },
    );
    return coordinator.process(request);
  }

  Future<DappConfirmationDecision> _showConfirmation(
    DappRequestConfirmation confirmation,
  ) {
    return switch (confirmation.kind) {
      DappConfirmationKind.signature => showDappSignatureConfirmSheet(
        context,
        confirmation,
      ),
      DappConfirmationKind.transaction => showDappTransactionConfirmSheet(
        context,
        confirmation,
      ),
      DappConfirmationKind.chainSwitch => _showChainSwitchSheet(confirmation),
      DappConfirmationKind.authorization => Future.value(
        DappConfirmationDecision.rejected,
      ),
    };
  }

  Future<DappConfirmationDecision> _showChainSwitchSheet(
    DappRequestConfirmation confirmation,
  ) async {
    final decision = await showModalBottomSheet<DappConfirmationDecision>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => _DappChainSwitchSheet(confirmation: confirmation),
    );
    return decision ?? DappConfirmationDecision.rejected;
  }

  Future<void> _loadFromAddressBar() async {
    final target = resolveDappNavigationTarget(_urlController.text);
    if (target == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.browser.invalidUrl)));
      return;
    }
    if (!target.isSearch &&
        _requiresExternalConfirmation(target.url) &&
        !await _confirmOpenExternalUrl(target.url)) {
      return;
    }
    await _webViewController.loadRequest(Uri.parse(target.url));
  }

  bool _requiresExternalConfirmation(String url) {
    final nextHost = Uri.parse(url).host;
    final currentHost = Uri.tryParse(_currentUrl)?.host;
    return currentHost == null || currentHost != nextHost;
  }

  Future<bool> _confirmOpenExternalUrl(String url) async {
    final domain = Uri.parse(url).host;
    final confirmed = await AppDialog.show<bool>(
      context: context,
      title: t.browser.confirmExternalTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.browser.confirmExternalBody),
          const SizedBox(height: 12),
          Text(domain, style: context.appTextStyles.bodyLarge),
        ],
      ),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmTitle: t.browser.openExternal,
      confirmCallback: () => Navigator.of(context).pop(true),
    );
    return confirmed == true;
  }

  Future<void> _goBack() async {
    if (await _webViewController.canGoBack()) {
      await _webViewController.goBack();
      await _updateNavigationState();
    }
  }

  Future<void> _goForward() async {
    if (await _webViewController.canGoForward()) {
      await _webViewController.goForward();
      await _updateNavigationState();
    }
  }

  void _handlePageStarted(String url) {
    _navigationEpoch += 1;
    _updateCurrentUrl(url);
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    if (!_isInjectableWebUrl(url)) {
      return;
    }
    final generation = _providerInjectionGeneration + 1;
    _providerInjectionGeneration = generation;
    unawaited(_injectProviderScriptWithRetries(generation));
  }

  void _handleUrlChange(UrlChange change) {
    final url = change.url;
    if (url == null) {
      return;
    }
    _updateCurrentUrl(url);
    if (!_isInjectableWebUrl(url)) {
      return;
    }
    final generation = _providerInjectionGeneration + 1;
    _providerInjectionGeneration = generation;
    unawaited(_injectProviderScriptWithRetries(generation));
  }

  Future<void> _handlePageFinished(String url) async {
    _updateCurrentUrl(url);
    await _injectProviderScript();
    await _recordRecentVisit(url);
    await _updateNavigationState();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    widget.onPageFinished?.call(url);
  }

  Future<void> _configureWebViewAndLoadInitialUrl() async {
    await _webViewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    try {
      await _webViewController.setOnConsoleMessage(_handleConsoleMessage);
      _dappLog('webview console logging installed');
    } catch (error) {
      _dappLog('webview console logging unavailable', {
        'error': _truncateLogValue(error.toString()),
      });
    }
    await _webViewController.addJavaScriptChannel(
      'SafeWalletBridge',
      onMessageReceived: _handleJavaScriptMessage,
    );
    await _webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: _handleNavigationRequest,
        onPageStarted: _handlePageStarted,
        onPageFinished: _handlePageFinished,
        onWebResourceError: _handleWebResourceError,
        onUrlChange: _handleUrlChange,
      ),
    );
    if (!mounted) {
      return;
    }
    await _installProviderScriptForNewDocumentsAndLoadInitialUrl();
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = walletConnectUriFromLink(request.url);
    if (uri != null) {
      unawaited(_pairWalletConnectUri(uri));
      return NavigationDecision.prevent;
    }
    if (!request.isMainFrame) {
      return NavigationDecision.navigate;
    }
    if (!_isInjectableWebUrl(request.url)) {
      return NavigationDecision.prevent;
    }
    if (_originOf(request.url) != _originOf(_currentUrl)) {
      final confirmed = await _confirmOpenExternalUrl(request.url);
      return confirmed
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _pairWalletConnectUri(String uri) async {
    final controller = ref.read(walletConnectControllerProvider.notifier);
    await controller.initialize();
    final result = await controller.pair(uri);
    if (!mounted) {
      return;
    }
    final message = switch (result) {
      WalletConnectPairResult.accepted =>
        context.t.advanced.walletConnectPairStarted,
      WalletConnectPairResult.invalidUri =>
        context.t.advanced.walletConnectInvalidUri,
      WalletConnectPairResult.duplicate =>
        context.t.advanced.walletConnectDuplicateUri,
      WalletConnectPairResult.unavailable || WalletConnectPairResult.failure =>
        context.t.advanced.walletConnectPairFailed,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _installProviderScriptForNewDocumentsAndLoadInitialUrl() async {
    if (!_isInjectableWebUrl(widget.initialUrl)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }
    final initialChainId = await _initialProviderChainId();
    _dappLog('initial provider chain', {
      'chainId': initialChainId,
      'url': widget.initialUrl,
    });
    if (!mounted) {
      return;
    }
    final script = _bridgeSession.providerScript(
      initialChainId: initialChainId,
      pageOrigin: widget.initialUrl,
    );
    final installed = await ref
        .read(dappProviderDocumentStartInjectorProvider)
        .install(controller: _webViewController.platform, source: script);
    _dappLog('document-start install result', {
      'installed': installed,
      'scriptLength': script.length,
    });
    if (!mounted) {
      return;
    }
    await _webViewController.loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _injectProviderScriptWithRetries(int generation) async {
    for (
      var attempt = 0;
      attempt < _earlyProviderInjectionAttempts;
      attempt += 1
    ) {
      if (!mounted || generation != _providerInjectionGeneration) {
        return;
      }
      final injected = await _injectProviderScript(ignoreErrors: true);
      if (injected) {
        return;
      }
      if (attempt < _earlyProviderInjectionAttempts - 1) {
        await Future<void>.delayed(_earlyProviderInjectionRetryDelay);
      }
    }
  }

  Future<bool> _injectProviderScript({bool ignoreErrors = false}) async {
    final initialChainId = await _initialProviderChainId();
    if (!mounted) {
      return false;
    }
    final script = _bridgeSession.providerScript(
      initialChainId: initialChainId,
      pageOrigin: _currentUrl,
    );
    if (!ignoreErrors) {
      await _webViewController.runJavaScript(script);
      _dappLog('provider runtime inject success', {
        'ignoreErrors': false,
        'chainId': initialChainId,
        'scriptLength': script.length,
      });
      return true;
    }
    try {
      await _webViewController.runJavaScript(script);
      _dappLog('provider runtime inject success', {
        'ignoreErrors': true,
        'chainId': initialChainId,
        'scriptLength': script.length,
      });
      return true;
    } catch (error) {
      _dappLog('provider runtime inject failed', {
        'ignoreErrors': true,
        'chainId': initialChainId,
        'error': _truncateLogValue(error.toString()),
      });
      // Some WebView engines reject JS while navigation is still provisional.
      return false;
    }
  }

  Future<String?> _initialProviderChainId() async {
    try {
      final chain = await _initialProviderEvmChain();
      if (chain == null) {
        return null;
      }
      return _evmChainIdToHex(chain.chainId);
    } catch (_) {
      return null;
    }
  }

  Future<ChainConfig?> _initialProviderEvmChain() async {
    final selectedChain = await ref.read(
      selectedChainControllerProvider.future,
    );
    if (selectedChain.chainType == ChainType.evm) {
      return selectedChain;
    }

    final chains = await ref.read(availableChainsProvider.future);
    for (final chain in chains) {
      if (chain.chainType == ChainType.evm && chain.id == 'ethereum') {
        return chain;
      }
    }
    for (final chain in chains) {
      if (chain.chainType == ChainType.evm && !chain.isTestnet) {
        return chain;
      }
    }
    for (final chain in chains) {
      if (chain.chainType == ChainType.evm) {
        return chain;
      }
    }
    return null;
  }

  void _handleWebResourceError(WebResourceError error) {
    _dappLog('web resource error', {
      'code': error.errorCode,
      'description': error.description,
      'isForMainFrame': error.isForMainFrame,
      'url': error.url,
    });
    if (error.isForMainFrame == false || !mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.browser.loadFailed)));
  }

  Future<void> _recordRecentVisit(String url) async {
    if (normalizeDappUrl(url) == null) {
      return;
    }

    try {
      final title = await _webViewController.getTitle();
      await ref
          .read(dappRecentVisitsControllerProvider.notifier)
          .recordVisit(title: title ?? '', url: url);
    } catch (_) {
      // Recent visits are useful history, but recording must not break browsing.
    }
  }

  void _updateCurrentUrl(String url) {
    _currentUrl = url;
    _urlController.text = url;
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _webViewController.canGoBack();
    final canGoForward = await _webViewController.canGoForward();
    if (!mounted) {
      return;
    }
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  void _handleConsoleMessage(JavaScriptConsoleMessage message) {
    _dappLog('webview console', {
      'level': message.level.name,
      'message': _truncateLogValue(message.message, 600),
    });
  }
}

bool _isInjectableWebUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;
}

String? _originOf(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  final defaultPort = uri.scheme == 'https' ? 443 : 80;
  final port = uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
  return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}$port';
}

String _evmChainIdToHex(String chainId) {
  final parsed = int.tryParse(chainId);
  if (parsed == null) {
    return chainId;
  }
  return '0x${parsed.toRadixString(16)}';
}

Map<String, Object?> _requestLogDetails(DappRpcRequest request) {
  return {
    'id': request.id,
    'method': request.method,
    'domain': request.domain,
    'paramsCount': request.params.length,
  };
}

String _valueType(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is List) {
    return 'list';
  }
  if (value is Map) {
    return 'map';
  }
  return value.runtimeType.toString();
}

void _dappLog(String message, [Map<String, Object?> details = const {}]) {
  if (!kDebugMode) {
    return;
  }
  if (details.isEmpty) {
    debugPrint('[SafeWalletDapp] $message');
    return;
  }
  debugPrint('[SafeWalletDapp] $message ${jsonEncode(_safeLogMap(details))}');
}

Map<String, Object?> _safeLogMap(Map<String, Object?> details) {
  return details.map((key, value) => MapEntry(key, _safeLogValue(value)));
}

Object? _safeLogValue(Object? value) {
  if (value == null || value is num || value is bool) {
    return value;
  }
  if (value is String) {
    return _truncateLogValue(value);
  }
  return _truncateLogValue(value.toString());
}

String _truncateLogValue(String value, [int maxLength = 240]) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength)}...';
}

final class _BrowserToolbar extends StatelessWidget {
  const _BrowserToolbar({
    required this.controller,
    required this.canGoBack,
    required this.canGoForward,
    required this.onClose,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(AppIcons.close),
              tooltip: t.actions.close,
            ),
            IconButton(
              onPressed: canGoBack ? onBack : null,
              icon: const Icon(AppIcons.back),
              tooltip: t.actions.back,
            ),
            IconButton(
              onPressed: canGoForward ? onForward : null,
              icon: const Icon(AppIcons.forward),
              tooltip: t.browser.forward,
            ),
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                  autocorrect: false,
                  controller: controller,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => onSubmitted(),
                  style: context.appTextStyles.bodySmall,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    prefixIcon: const Icon(AppIcons.lock, size: 18),
                    hintText: t.browser.urlHint,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(AppIcons.refresh),
              tooltip: t.browser.refresh,
            ),
          ],
        ),
      ),
    );
  }
}

final class _DappChainSwitchSheet extends StatelessWidget {
  const _DappChainSwitchSheet({required this.confirmation});

  final DappRequestConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final requestedChain = confirmation.requestedChain;

    return DappSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.dapp.chainSwitchTitle,
            style: context.appTextStyles.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(t.dapp.chainSwitchBody, style: context.appTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.sectionY),
          _SheetRow(label: t.dapp.domain, value: confirmation.domain),
          _SheetRow(label: t.dapp.chain, value: confirmation.chain.name),
          _SheetRow(
            label: t.dapp.requestedChain,
            value: requestedChain?.name ?? '-',
          ),
          const SizedBox(height: AppSpacing.sectionY),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: t.dapp.reject,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DappConfirmationDecision.rejected),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  label: t.dapp.approve,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(DappConfirmationDecision.approved),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surfaceSoft,
          borderRadius: AppRadius.smallBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label, style: context.appTextStyles.caption),
              ),
              Expanded(
                child: Text(
                  value,
                  style: context.appTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
