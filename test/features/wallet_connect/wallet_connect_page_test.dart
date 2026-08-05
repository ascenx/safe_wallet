import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/app/app_lifecycle_observer.dart';
import 'package:safe_wallet/features/advanced/presentation/advanced_settings_page.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_project_id_setting.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';
import 'package:safe_wallet/features/wallet_connect/presentation/wallet_connect_page.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

const buildProjectId = '11111111111111111111111111111111';
const customProjectId = '22222222222222222222222222222222';
const replacementProjectId = '33333333333333333333333333333333';

void main() {
  testWidgets('Advanced settings owns the WalletConnect entry', (tester) async {
    final gateway = _PageGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('WalletConnect'), findsOneWidget);
    expect(find.text('合约调用'), findsOneWidget);

    await tester.tap(find.byKey(const Key('advancedWalletConnect')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('walletConnectScan')), findsOneWidget);
    expect(find.byKey(const Key('walletConnectPaste')), findsOneWidget);
    expect(find.text('活跃会话'), findsOneWidget);
    expect(find.textContaining('安全设置'), findsNothing);
  });

  testWidgets('pasting a pairing URI does not show the privacy shield', (
    tester,
  ) async {
    final gateway = _PageGateway();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          return <String, Object?>{'text': 'wc:topic@2?symKey=secret'};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(_lifecycleApp(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('walletConnectPaste')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appPrivacyShield')), findsNothing);
    expect(find.byKey(const Key('walletConnectUriInput')), findsOneWidget);
  });

  testWidgets('shows active sessions and disconnects with confirmation', (
    tester,
  ) async {
    final gateway = _PageGateway(sessions: [_session]);
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advancedWalletConnect')));
    await tester.pumpAndSettle();

    expect(find.text('Example dApp'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.textContaining('eip155:1:0xabc'), findsOneWidget);

    await tester.tap(find.byKey(const Key('walletConnectDisconnect-topic-a')));
    await tester.pumpAndSettle();
    expect(find.text('断开会话'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walletConnectDisconnectConfirm')));
    await tester.pumpAndSettle();

    expect(gateway.disconnectedTopics, ['topic-a']);
    expect(find.text('暂无活跃的 WalletConnect 会话'), findsOneWidget);
  });

  testWidgets('allows configuring Project ID when build value is missing', (
    tester,
  ) async {
    final gateway = _PageGateway();
    final store = InMemoryWalletConnectProjectIdStore();
    await tester.pumpWidget(
      _app(
        gateway,
        buildProjectId: '',
        projectIdStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advancedWalletConnect')));
    await tester.pumpAndSettle();

    expect(find.textContaining('REOWN_PROJECT_ID'), findsOneWidget);
    expect(find.byKey(const Key('walletConnectProjectIdSet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('walletConnectProjectIdSet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('walletConnectProjectIdInput')),
      customProjectId,
    );
    await tester.tap(find.byKey(const Key('walletConnectProjectIdSave')));
    await tester.pumpAndSettle();

    expect(store.readCustomProjectId(), customProjectId);
    expect(find.text('222222…2222'), findsOneWidget);
    expect(find.text('重启 App 后生效'), findsNothing);
    expect(gateway.resetCalls, 1);
    expect(gateway.initializedProjectIds, [customProjectId]);
    final scanButton = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const Key('walletConnectScan')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(scanButton.onPressed, isNotNull);
  });

  testWidgets('deleting custom Project ID falls back to build value', (
    tester,
  ) async {
    final gateway = _PageGateway();
    final store = InMemoryWalletConnectProjectIdStore(
      projectId: customProjectId,
    );
    await tester.pumpWidget(
      _app(
        gateway,
        buildProjectId: buildProjectId,
        projectIdStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advancedWalletConnect')));
    await tester.pumpAndSettle();

    expect(find.text('App 内设置'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walletConnectProjectIdDelete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('walletConnectProjectIdDeleteConfirm')),
    );
    await tester.pumpAndSettle();

    expect(store.readCustomProjectId(), isNull);
    expect(find.text('构建配置'), findsOneWidget);
    expect(find.text('111111…1111'), findsOneWidget);
    expect(find.text('重启 App 后生效'), findsNothing);
    expect(gateway.resetCalls, 1);
    expect(gateway.initializedProjectIds, [customProjectId, buildProjectId]);
  });

  testWidgets('replacing Project ID disconnects active sessions first', (
    tester,
  ) async {
    final gateway = _PageGateway(sessions: [_session]);
    final store = InMemoryWalletConnectProjectIdStore(
      projectId: customProjectId,
    );
    await tester.pumpWidget(
      _app(
        gateway,
        buildProjectId: buildProjectId,
        projectIdStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advancedWalletConnect')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('walletConnectProjectIdSet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('walletConnectProjectIdInput')),
      replacementProjectId,
    );
    await tester.tap(find.byKey(const Key('walletConnectProjectIdSave')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('walletConnectProjectIdDisconnectConfirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('walletConnectProjectIdDisconnectConfirm')),
    );
    await tester.pumpAndSettle();

    expect(gateway.disconnectedTopics, ['topic-a']);
    expect(store.readCustomProjectId(), replacementProjectId);
    expect(gateway.resetCalls, 1);
    expect(gateway.initializedProjectIds, [
      customProjectId,
      replacementProjectId,
    ]);
  });
}

Widget _app(
  _PageGateway gateway, {
  String buildProjectId = buildProjectId,
  WalletConnectProjectIdStore? projectIdStore,
}) {
  LocaleSettings.setLocaleSync(AppLocale.zh);
  return ProviderScope(
    overrides: [
      walletConnectGatewayProvider.overrideWithValue(gateway),
      walletConnectBuildProjectIdProvider.overrideWithValue(buildProjectId),
      walletConnectProjectIdStoreProvider.overrideWithValue(
        projectIdStore ?? InMemoryWalletConnectProjectIdStore(),
      ),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const AdvancedSettingsPage(),
      ),
    ),
  );
}

Widget _lifecycleApp(_PageGateway gateway) {
  LocaleSettings.setLocaleSync(AppLocale.zh);
  return ProviderScope(
    overrides: [
      walletConnectGatewayProvider.overrideWithValue(gateway),
      walletConnectBuildProjectIdProvider.overrideWithValue(buildProjectId),
      walletConnectProjectIdStoreProvider.overrideWithValue(
        InMemoryWalletConnectProjectIdStore(),
      ),
    ],
    child: TranslationProvider(
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          navigatorKey: ref.read(appNavigatorKeyProvider),
          theme: buildAppTheme(),
          home: const AppLifecycleObserver(child: WalletConnectPage()),
        ),
      ),
    ),
  );
}

final _session = WalletConnectSession(
  topic: 'topic-a',
  pairingTopic: 'pairing-a',
  peer: const WalletConnectPeerMetadata(
    name: 'Example dApp',
    description: 'Example',
    url: 'https://example.com/path',
    icons: [],
  ),
  namespaces: {
    'eip155': WalletConnectApprovedNamespace(
      chains: {const Caip2ChainId(namespace: 'eip155', reference: '1')},
      accounts: {
        const Caip10AccountId(
          chain: Caip2ChainId(namespace: 'eip155', reference: '1'),
          address: '0xabc',
        ),
      },
      methods: const {'personal_sign'},
      events: const {'accountsChanged'},
    ),
  },
  expiry: DateTime.utc(2030),
  createdAt: DateTime.utc(2026),
);

final class _PageGateway extends UnsupportedWalletConnectGateway {
  _PageGateway({List<WalletConnectSession>? sessions})
      : sessions = sessions ?? [];

  final List<String> disconnectedTopics = [];
  final List<String> initializedProjectIds = [];
  int resetCalls = 0;
  List<WalletConnectSession> sessions;

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {
    initializedProjectIds.add(configuration.projectId);
  }

  @override
  Future<void> reset() async {
    resetCalls += 1;
  }

  @override
  Future<List<WalletConnectSession>> getActiveSessions() async =>
      List.of(sessions);

  @override
  Future<void> disconnect(String topic) async {
    disconnectedTopics.add(topic);
    sessions.removeWhere((session) => session.topic == topic);
  }

  @override
  Future<void> approveProposal(
    int id,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) async {}

  @override
  Future<void> rejectProposal(int id) async {}

  @override
  Future<void> pair(Uri uri) async {}

  @override
  Future<void> respond(String topic, WalletConnectResponse response) async {}
}
