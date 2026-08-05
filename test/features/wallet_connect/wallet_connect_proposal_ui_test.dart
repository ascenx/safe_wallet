import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_controller.dart';
import 'package:safe_wallet/features/wallet_connect/data/wallet_connect_gateway.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_namespace.dart';
import 'package:safe_wallet/features/wallet_connect/presentation/wallet_connect_request_host.dart';
import 'package:safe_wallet/features/wallet_connect/presentation/wallet_connect_peer_avatar.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/app/app_lifecycle_observer.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';

void main() {
  test('peer icon accepts only bounded HTTPS URLs without credentials', () {
    expect(
      walletConnectPeerIconUri(
        const WalletConnectPeerMetadata(
          name: 'dApp',
          description: '',
          url: 'https://example.com',
          icons: ['https://cdn.example.com/icon.png'],
        ),
      )?.toString(),
      'https://cdn.example.com/icon.png',
    );
    for (final icon in [
      'http://cdn.example.com/icon.png',
      'javascript:alert(1)',
      'https://user:password@cdn.example.com/icon.png',
      'https://localhost/icon.png',
      'https://127.0.0.1/icon.png',
      'https://10.0.0.1/icon.png',
      'https://cdn.example.local/icon.png',
      'https://cdn.example.com:8443/icon.png',
    ]) {
      expect(
        walletConnectPeerIconUri(
          WalletConnectPeerMetadata(
            name: 'dApp',
            description: '',
            url: 'https://example.com',
            icons: [icon],
          ),
        ),
        isNull,
      );
    }
  });

  testWidgets('peer avatar bounds downloads and disables redirects', (
    tester,
  ) async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response.bytes(
        List<int>.filled(5, 1),
        200,
        headers: const {'content-type': 'image/png'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WalletConnectPeerAvatar(
            peer: const WalletConnectPeerMetadata(
              name: 'Example',
              description: '',
              url: 'https://example.com',
              icons: ['https://cdn.example.com/icon.png'],
            ),
            client: client,
            maxImageBytes: 4,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(capturedRequest?.followRedirects, isFalse);
    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('proposal shows peer, wallet, networks, methods, and events', (
    tester,
  ) async {
    final gateway = _ProposalGateway();
    addTearDown(gateway.dispose);
    LocaleSettings.setLocaleSync(AppLocale.zh);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
          walletRepositoryProvider.overrideWithValue(const _WalletRepository()),
          availableChainsProvider.overrideWith((ref) async => const [_chain]),
        ],
        child: TranslationProvider(child: const _TestApp()),
      ),
    );
    await tester.pumpAndSettle();

    gateway.proposalController.add(_proposal);
    await tester.pumpAndSettle();

    expect(find.text('Example dApp'), findsOneWidget);
    expect(find.text('example.com'), findsNWidgets(2));
    expect(find.text('Example description'), findsOneWidget);
    expect(find.textContaining('0xabc'), findsOneWidget);
    expect(find.text('eip155:1'), findsOneWidget);
    expect(find.text('personal_sign'), findsOneWidget);
    expect(find.text('accountsChanged'), findsOneWidget);
  });

  testWidgets('approval is bound to the proposal shown in the dialog', (
    tester,
  ) async {
    final gateway = _ProposalGateway();
    addTearDown(gateway.dispose);
    LocaleSettings.setLocaleSync(AppLocale.zh);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
          walletRepositoryProvider.overrideWithValue(const _WalletRepository()),
          availableChainsProvider.overrideWith((ref) async => const [_chain]),
        ],
        child: TranslationProvider(child: const _TestApp()),
      ),
    );
    await tester.pumpAndSettle();

    gateway.proposalController.add(_proposal);
    await tester.pumpAndSettle();
    gateway.proposalController.add(
      WalletConnectProposal(
        id: 10,
        pairingTopic: 'pairing-b',
        peer: _proposal.peer,
        requiredNamespaces: _proposal.requiredNamespaces,
        optionalNamespaces: _proposal.optionalNamespaces,
        expiry: _proposal.expiry,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('连接'));
    await tester.pumpAndSettle();

    expect(gateway.approvedProposalIds, [9]);
  });

  testWidgets('scam Verify Context is shown and blocks proposal approval', (
    tester,
  ) async {
    final gateway = _ProposalGateway();
    addTearDown(gateway.dispose);
    LocaleSettings.setLocaleSync(AppLocale.zh);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletConnectGatewayProvider.overrideWithValue(gateway),
          walletConnectProjectIdProvider.overrideWithValue('project-id'),
          walletRepositoryProvider.overrideWithValue(const _WalletRepository()),
          availableChainsProvider.overrideWith((ref) async => const [_chain]),
        ],
        child: TranslationProvider(child: const _TestApp()),
      ),
    );
    await tester.pumpAndSettle();

    gateway.proposalController.add(
      WalletConnectProposal(
        id: 11,
        pairingTopic: 'pairing-scam',
        peer: _proposal.peer,
        requiredNamespaces: _proposal.requiredNamespaces,
        optionalNamespaces: const {},
        expiry: DateTime.utc(2030),
        verifyContext: const WalletConnectVerifyContext(
          origin: 'https://phishing.example',
          status: WalletConnectVerifyStatus.scam,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('安全风险：该域名已被标记为恶意站点。'), findsOneWidget);
    final approveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '连接'),
    );
    expect(approveButton.onPressed, isNull);
  });
}

final class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: ref.watch(appNavigatorKeyProvider),
      theme: buildAppTheme(),
      builder: (context, child) =>
          WalletConnectRequestHost(child: child ?? const SizedBox.shrink()),
      home: const Scaffold(body: SizedBox.shrink()),
    );
  }
}

const _chain = ChainConfig(
  id: 'ethereum',
  chainType: ChainType.evm,
  name: 'Ethereum',
  chainId: '1',
  symbol: 'ETH',
  rpcUrls: ['https://rpc.example'],
  blockExplorerUrl: 'https://etherscan.io',
  isTestnet: false,
);

final _proposal = WalletConnectProposal(
  id: 9,
  pairingTopic: 'pairing-a',
  peer: const WalletConnectPeerMetadata(
    name: 'Example dApp',
    description: 'Example description',
    url: 'https://example.com/path',
    icons: [],
  ),
  requiredNamespaces: {
    'eip155': WalletConnectNamespaceProposal(
      chains: {const Caip2ChainId(namespace: 'eip155', reference: '1')},
      methods: const {'personal_sign'},
      events: const {'accountsChanged'},
    ),
  },
  optionalNamespaces: const {},
  expiry: DateTime.utc(2030),
);

final class _ProposalGateway extends UnsupportedWalletConnectGateway {
  final proposalController =
      StreamController<WalletConnectProposal>.broadcast();
  final approvedProposalIds = <int>[];

  @override
  Stream<WalletConnectProposal> get proposals => proposalController.stream;

  @override
  Future<void> initialize(WalletConnectConfiguration configuration) async {}

  @override
  Future<void> rejectProposal(int id) async {}

  @override
  Future<void> approveProposal(
    int id,
    Map<String, WalletConnectApprovedNamespace> namespaces,
  ) async {
    approvedProposalIds.add(id);
  }

  @override
  Future<void> dispose() => proposalController.close();
}

final class _WalletRepository implements WalletRepository {
  const _WalletRepository();

  @override
  Future<List<WalletAccount>> getWallets() async => [_wallet];

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) => throw UnimplementedError();

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) => throw UnimplementedError();

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) => throw UnimplementedError();

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) => throw UnimplementedError();
}

final _wallet = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0xabc',
  solanaAddress: '',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
