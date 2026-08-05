// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/browser/application/dapp_recent_visits_controller.dart';
import 'package:safe_wallet/features/browser/data/hive_browser_state_repository.dart';
import 'package:safe_wallet/features/browser/presentation/dapp_browser_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/data/dapp_provider_webview_injector.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_controller.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  group('DappBrowserPage', () {
    late _FakeWebViewPlatform webViewPlatform;

    setUp(() {
      webViewPlatform = _FakeWebViewPlatform();
      WebViewPlatform.instance = webViewPlatform;
    });

    testWidgets('records recent visit when a dApp page finishes loading', (
      tester,
    ) async {
      final repository = InMemoryBrowserStateRepository();
      final visitedAt = DateTime.utc(2026, 6, 6, 12);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            browserStateRepositoryProvider.overrideWithValue(repository),
            browserClockProvider.overrideWithValue(() => visitedAt),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      webViewPlatform.controller.title = 'Uniswap';
      webViewPlatform.navigationDelegate.finish('https://app.uniswap.org/swap');
      await tester.pump();

      final visits = await repository.recentVisits();
      expect(visits, hasLength(1));
      expect(visits.single.domain, 'app.uniswap.org');
      expect(visits.single.title, 'Uniswap');
      expect(visits.single.url, 'https://app.uniswap.org/swap');
      expect(visits.single.visitedAt, visitedAt);
    });

    testWidgets('injects selected EVM chain id into provider on page load', (
      tester,
    ) async {
      final chainRepository = _FakeChainRepository(
        selectedChainId: 'bnb-smart-chain',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chainRepositoryProvider.overrideWithValue(chainRepository),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      webViewPlatform.navigationDelegate.finish('https://app.uniswap.org/swap');
      await tester.pump();

      expect(webViewPlatform.controller.javaScripts, isNotEmpty);
      expect(
        webViewPlatform.controller.javaScripts.last,
        contains('chainId: "0x38"'),
      );
    });

    testWidgets('installs provider for document start before initial load', (
      tester,
    ) async {
      webViewPlatform.javaScriptChannelDelay = const Duration(milliseconds: 50);
      final injector = _RecordingDocumentStartInjector(webViewPlatform.events);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dappProviderDocumentStartInjectorProvider.overrideWithValue(
              injector,
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(injector.scripts, hasLength(1));
      expect(injector.scripts.single, contains('window.ethereum = provider'));
      expect(webViewPlatform.events, [
        'set-console-message',
        'add-channel:SafeWalletBridge',
        'install-document-start-provider',
        'load:https://app.uniswap.org/swap',
      ]);
    });

    testWidgets('registers WebView console diagnostics', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(webViewPlatform.events, contains('set-console-message'));
      expect(webViewPlatform.controller.consoleMessageHandler, isNotNull);
    });

    testWidgets('intercepts WalletConnect navigation and starts pairing', (
      tester,
    ) async {
      final gateway = _FakeWalletConnectGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            walletConnectGatewayProvider.overrideWithValue(gateway),
            walletConnectProjectIdProvider.overrideWithValue('project-id'),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final decision = await webViewPlatform.navigationDelegate.navigate(
        'wc:topic@2?symKey=secret',
      );
      await tester.pump();

      expect(decision, NavigationDecision.prevent);
      expect(gateway.pairedUris, hasLength(1));
    });

    testWidgets('blocks insecure HTTP navigation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final decision = await webViewPlatform.navigationDelegate.navigate(
        'http://app.uniswap.org/swap',
      );

      expect(decision, NavigationDecision.prevent);
    });

    testWidgets('asks before a page link crosses to another origin', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final navigation = webViewPlatform.navigationDelegate.navigate(
        'https://evil.example/phishing',
      );
      await tester.pump();

      expect(find.text('确认打开网站'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();

      expect(await navigation, NavigationDecision.prevent);
    });

    testWidgets('does not inject the wallet provider into HTTP pages', (
      tester,
    ) async {
      final injector = _RecordingDocumentStartInjector(webViewPlatform.events);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dappProviderDocumentStartInjectorProvider.overrideWithValue(
              injector,
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'http://insecure.example',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(injector.scripts, isEmpty);
      expect(webViewPlatform.controller.loadedUrls, isEmpty);
    });

    testWidgets(
      'uses default EVM chain id for provider when Solana is selected',
      (tester) async {
        final injector = _RecordingDocumentStartInjector(
          webViewPlatform.events,
        );
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chainRepositoryProvider.overrideWithValue(chainRepository),
              dappProviderDocumentStartInjectorProvider.overrideWithValue(
                injector,
              ),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: buildAppTheme(),
                home: const DappBrowserPage(
                  initialUrl: 'https://app.uniswap.org/swap',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(injector.scripts, hasLength(1));
        expect(injector.scripts.single, contains('chainId: "0x1"'));
        expect(chainRepository.selectedChainId, 'solana-mainnet');
      },
    );

    testWidgets(
      'uses default EVM chain id for provider when Bitcoin is selected',
      (tester) async {
        final injector = _RecordingDocumentStartInjector(
          webViewPlatform.events,
        );
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'bitcoin-mainnet',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chainRepositoryProvider.overrideWithValue(chainRepository),
              dappProviderDocumentStartInjectorProvider.overrideWithValue(
                injector,
              ),
            ],
            child: TranslationProvider(
              child: MaterialApp(
                theme: buildAppTheme(),
                home: const DappBrowserPage(
                  initialUrl: 'https://app.uniswap.org/swap',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(injector.scripts, hasLength(1));
        expect(injector.scripts.single, contains('chainId: "0x1"'));
        expect(chainRepository.selectedChainId, 'bitcoin-mainnet');
      },
    );

    testWidgets('injects provider when a dApp page starts loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      webViewPlatform.navigationDelegate.start('https://app.uniswap.org/swap');
      await tester.pump();

      expect(webViewPlatform.controller.javaScripts, isNotEmpty);
      expect(
        webViewPlatform.controller.javaScripts.single,
        contains('window.ethereum = provider'),
      );
    });

    testWidgets('retries early provider injection while the page is starting', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      webViewPlatform.controller.javaScriptFailuresBeforeSuccess = 2;
      webViewPlatform.navigationDelegate.start('https://app.uniswap.org/swap');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(webViewPlatform.controller.runJavaScriptCalls, 3);
      expect(webViewPlatform.controller.javaScripts, hasLength(1));
      expect(
        webViewPlatform.controller.javaScripts.single,
        contains('window.ethereum = provider'),
      );
    });

    testWidgets('injects provider when the committed URL changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      webViewPlatform.navigationDelegate.urlChange(
        'https://app.uniswap.org/swap',
      );
      await tester.pump();

      expect(webViewPlatform.controller.javaScripts, isNotEmpty);
      expect(
        webViewPlatform.controller.javaScripts.single,
        contains('window.ethereum = provider'),
      );
    });

    testWidgets('shows localized feedback when a dApp page cannot open', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://missing.example',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      webViewPlatform.navigationDelegate.resourceError(
        const WebResourceError(
          errorCode: -2,
          description: 'Host lookup failed',
          isForMainFrame: true,
          url: 'https://missing.example',
        ),
      );
      await tester.pump();

      expect(find.text('无法打开 dApp，请检查网址或网络后重试'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('address bar confirms a new external domain before loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(webViewPlatform.controller.loadedUrls, [
        'https://app.uniswap.org/swap',
      ]);

      await tester.enterText(find.byType(TextField), 'evil.example');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump(const Duration(milliseconds: 300));

      expect(webViewPlatform.controller.loadedUrls, [
        'https://app.uniswap.org/swap',
      ]);
      expect(find.text('确认打开网站'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('evil.example'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('打开'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(webViewPlatform.controller.loadedUrls, [
        'https://app.uniswap.org/swap',
        'https://evil.example',
      ]);
    });

    testWidgets('address bar searches Google for non URL input', (
      tester,
    ) async {
      final googleSearchUrl = Uri.https('www.google.com', '/search', {
        'q': 'safe wallet app',
      }).toString();
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const DappBrowserPage(
                initialUrl: 'https://app.uniswap.org/swap',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'safe wallet app');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump(const Duration(milliseconds: 300));

      expect(webViewPlatform.controller.loadedUrls, [
        'https://app.uniswap.org/swap',
        googleSearchUrl,
      ]);
      expect(find.text('确认打开网站'), findsNothing);
    });

    testWidgets('toolbar controls navigate refresh and close the page', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(
              theme: buildAppTheme(),
              home: Builder(
                builder: (context) {
                  return FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DappBrowserPage(
                            initialUrl: 'https://app.uniswap.org/swap',
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      webViewPlatform.controller.canGoBackValue = true;
      webViewPlatform.controller.canGoForwardValue = true;
      webViewPlatform.navigationDelegate.finish('https://app.uniswap.org/swap');
      await tester.pump();

      await tester.tap(find.byTooltip('返回'));
      await tester.pump();
      await tester.tap(find.byTooltip('前进'));
      await tester.pump();
      await tester.tap(find.byTooltip('刷新'));
      await tester.pump();

      expect(webViewPlatform.controller.goBackCalls, 1);
      expect(webViewPlatform.controller.goForwardCalls, 1);
      expect(webViewPlatform.controller.reloadCalls, 1);

      await tester.tap(find.byTooltip('关闭'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(DappBrowserPage), findsNothing);
    });
  });
}

final class _FakeWebViewPlatform extends WebViewPlatform {
  late final _FakePlatformWebViewController controller;
  late final _FakePlatformNavigationDelegate navigationDelegate;
  final events = <String>[];
  Duration javaScriptChannelDelay = Duration.zero;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = _FakePlatformWebViewController(
      params,
      events,
      javaScriptChannelDelay,
    );
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return navigationDelegate = _FakePlatformNavigationDelegate(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakePlatformWebViewWidget(params);
  }
}

final class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController(
    super.params,
    this.events,
    this.javaScriptChannelDelay,
  ) : super.implementation();

  final List<String> events;
  final Duration javaScriptChannelDelay;
  String? currentUrlValue;
  String? title;
  bool canGoBackValue = false;
  bool canGoForwardValue = false;
  PlatformNavigationDelegate? navigationDelegate;
  final loadedUrls = <String>[];
  final javaScripts = <String>[];
  int javaScriptFailuresBeforeSuccess = 0;
  int runJavaScriptCalls = 0;
  int goBackCalls = 0;
  int goForwardCalls = 0;
  int reloadCalls = 0;
  void Function(JavaScriptConsoleMessage message)? consoleMessageHandler;

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {
    if (javaScriptChannelDelay > Duration.zero) {
      await Future<void>.delayed(javaScriptChannelDelay);
    }
    events.add('add-channel:${javaScriptChannelParams.name}');
  }

  @override
  Future<bool> canGoBack() async => canGoBackValue;

  @override
  Future<bool> canGoForward() async => canGoForwardValue;

  @override
  Future<String?> currentUrl() async => currentUrlValue;

  @override
  Future<String?> getTitle() async => title;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    currentUrlValue = params.uri.toString();
    loadedUrls.add(currentUrlValue!);
    events.add('load:$currentUrlValue');
  }

  @override
  Future<void> goBack() async {
    goBackCalls += 1;
  }

  @override
  Future<void> goForward() async {
    goForwardCalls += 1;
  }

  @override
  Future<void> reload() async {
    reloadCalls += 1;
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    runJavaScriptCalls += 1;
    if (javaScriptFailuresBeforeSuccess > 0) {
      javaScriptFailuresBeforeSuccess -= 1;
      throw Exception('provisional navigation');
    }
    javaScripts.add(javaScript);
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage consoleMessage) onConsoleMessage,
  ) async {
    consoleMessageHandler = onConsoleMessage;
    events.add('set-console-message');
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigationDelegate = handler;
  }
}

final class _RecordingDocumentStartInjector
    implements DappProviderDocumentStartInjector {
  _RecordingDocumentStartInjector(this.events);

  final List<String> events;
  final scripts = <String>[];

  @override
  Future<bool> install({
    required Object controller,
    required String source,
  }) async {
    events.add('install-document-start-provider');
    scripts.add(source);
    return true;
  }
}

final class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  _FakePlatformNavigationDelegate(super.params) : super.implementation();

  PageEventCallback? _onPageStarted;
  PageEventCallback? _onPageFinished;
  WebResourceErrorCallback? _onWebResourceError;
  UrlChangeCallback? _onUrlChange;
  NavigationRequestCallback? _onNavigationRequest;

  void start(String url) {
    _onPageStarted?.call(url);
  }

  void finish(String url) {
    _onPageFinished?.call(url);
  }

  void resourceError(WebResourceError error) {
    _onWebResourceError?.call(error);
  }

  void urlChange(String url) {
    _onUrlChange?.call(UrlChange(url: url));
  }

  Future<NavigationDecision?> navigate(String url) async {
    return _onNavigationRequest?.call(
      NavigationRequest(url: url, isMainFrame: true),
    );
  }

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    _onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    _onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    _onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    _onWebResourceError = onWebResourceError;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {
    _onUrlChange = onUrlChange;
  }
}

final class _FakePlatformWebViewWidget extends PlatformWebViewWidget {
  _FakePlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

final class _FakeChainRepository implements ChainRepository {
  _FakeChainRepository({required this.selectedChainId});

  String selectedChainId;

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeWalletConnectGateway extends UnsupportedWalletConnectGateway {
  final pairedUris = <Uri>[];

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {}

  @override
  Future<void> pair(Uri uri) async => pairedUris.add(uri);
}
