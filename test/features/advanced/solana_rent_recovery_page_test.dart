import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/application/solana_rent_recovery_controller.dart';
import 'package:safe_wallet/features/advanced/data/solana_rent_recovery_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/solana_rent_recovery_models.dart';
import 'package:safe_wallet/features/advanced/presentation/advanced_settings_page.dart';
import 'package:safe_wallet/features/advanced/presentation/solana_rent_recovery_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';
import 'package:safe_wallet/shared/widgets/app_action_sheet.dart';
import 'package:safe_wallet/shared/widgets/app_picker_field.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;

void main() {
  testWidgets('advanced settings exposes Solana rent recovery', (tester) async {
    await tester.pumpWidget(_materialApp(home: const AdvancedSettingsPage()));

    expect(find.byKey(const Key('advancedSolanaRentRecovery')), findsOneWidget);
    expect(find.text('Solana 租金回收'), findsOneWidget);
  });

  testWidgets('scans and displays recoverable rent using custom pickers', (
    tester,
  ) async {
    final fixture = _Fixture();
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(find.byType(AppPickerField), findsNWidgets(2));
    expect(find.text('Current Wallet'), findsOneWidget);
    expect(find.text('Solana Mainnet'), findsOneWidget);
    expect(find.text('可回收账户'), findsOneWidget);
    expect(find.text('已选账户'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('0.00453928 SOL'), findsOneWidget);
    expect(find.byKey(const Key('solanaRentAccount-token-account-a')),
        findsOneWidget);
    expect(find.byKey(const Key('solanaRentRecoveryButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('solanaRentWalletPicker')));
    await tester.pumpAndSettle();
    expect(find.byType(AppActionSheet<WalletAccount>), findsOneWidget);
  });

  testWidgets('confirms and recovers selected accounts', (tester) async {
    final fixture = _Fixture();
    fixture.cache.unlock(
      walletId: fixture.wallet.id,
      walletDek: const [1, 2, 3],
      now: DateTime.now().toUtc(),
    );
    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('solanaRentRecoveryButton')));
    await tester.pumpAndSettle();

    expect(find.text('确认租金回收'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
    expect(find.text('确认并签名'), findsNothing);
    await tester.tap(find.byKey(const Key('confirmSolanaRentRecovery')));
    await tester.pumpAndSettle();

    expect(fixture.gateway.recoverCalls, 1);
    expect(find.text('租金回收成功'), findsOneWidget);
    expect(find.text('已完成账户'), findsOneWidget);
    expect(find.text('实际回收金额'), findsOneWidget);
    expect(find.text('0.00453928 SOL'), findsWidgets);
    expect(find.text('signature-a'), findsOneWidget);
    expect(find.text('当前没有可安全回收租金的空 Token 账户'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.byKey(const Key('solanaRentAccount-token-account-a')),
        findsNothing);
    expect(find.byKey(const Key('solanaRentAccount-token-account-b')),
        findsNothing);
  });
}

Widget _materialApp({required Widget home}) {
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
}

final class _Fixture {
  _Fixture()
      : keypair = solana.Keypair.generate(),
        accountA = SolanaRentAccount(
          address: 'token-account-a',
          mintAddress: 'mint-a',
          program: SolanaRentTokenProgram.splToken,
          recoverableLamports: BigInt.from(2039280),
        ),
        accountB = SolanaRentAccount(
          address: 'token-account-b',
          mintAddress: 'mint-b',
          program: SolanaRentTokenProgram.token2022,
          recoverableLamports: BigInt.from(2500000),
        ) {
    wallet = WalletAccount(
      id: 'wallet-current',
      name: 'Current Wallet',
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: keypair.publicKey.toBase58(),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    gateway = _PageGateway(
      accounts: [accountA, accountB],
      recoveryResult: SolanaRentRecoveryResult(
        signatures: ['signature-a'],
        completedAccountCount: 2,
        recoveredLamports: BigInt.from(4539280),
      ),
    );
  }

  late final solana.Keypair keypair;
  late final WalletAccount wallet;
  final SolanaRentAccount accountA;
  final SolanaRentAccount accountB;
  late final _PageGateway gateway;
  final SessionKeyCache cache = SessionKeyCache();

  static const network = ChainConfig(
    id: 'solana-mainnet',
    chainType: ChainType.solana,
    name: 'Solana Mainnet',
    chainId: 'mainnet-beta',
    symbol: 'SOL',
    rpcUrls: ['https://solana.example'],
    blockExplorerUrl: 'https://solscan.io',
    isTestnet: false,
  );

  Widget app() {
    return ProviderScope(
      overrides: [
        walletRepositoryProvider.overrideWithValue(
          _PageWalletRepository(wallet: wallet, keypair: keypair),
        ),
        selectedWalletStoreProvider.overrideWithValue(
          _SelectedWalletStore(wallet.id),
        ),
        availableChainsProvider.overrideWith((ref) async => [network]),
        solanaRentRecoveryDefaultNetworkIdProvider.overrideWithValue(
          () async => network.id,
        ),
        solanaRentRecoveryRpcUrlProvider.overrideWithValue(
          (chain) async => chain.rpcUrls.first,
        ),
        solanaRentRecoveryGatewayProvider.overrideWithValue(gateway),
        securityLogRepositoryProvider.overrideWithValue(
          InMemorySecurityLogRepository(),
        ),
        sessionKeyCacheProvider.overrideWithValue(cache),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SolanaRentRecoveryPage(),
        ),
      ),
    );
  }
}

final class _PageGateway implements SolanaRentRecoveryGateway {
  _PageGateway({
    required this.accounts,
    required this.recoveryResult,
  });

  final List<SolanaRentAccount> accounts;
  final SolanaRentRecoveryResult recoveryResult;
  int recoverCalls = 0;

  @override
  Future<SolanaRentScanResult> scan({
    required String rpcUrl,
    required String ownerAddress,
  }) async {
    return SolanaRentScanResult(
      accounts: recoverCalls == 0 ? accounts : const [],
      solBalanceLamports: BigInt.from(100000),
    );
  }

  @override
  Future<SolanaRentRecoveryEstimate> estimate({
    required String rpcUrl,
    required String ownerAddress,
    required List<SolanaRentAccount> accounts,
  }) async {
    return SolanaRentRecoveryEstimate(
      batches: [
        if (accounts.isNotEmpty)
          SolanaRentRecoveryBatch(
            accounts: accounts,
            estimatedFeeLamports: BigInt.from(5000),
          ),
      ],
    );
  }

  @override
  Future<SolanaRentRecoveryResult> recover({
    required String rpcUrl,
    required String ownerAddress,
    required List<int> privateKey,
    required List<SolanaRentRecoveryBatch> batches,
  }) async {
    recoverCalls += 1;
    return recoveryResult;
  }
}

final class _PageWalletRepository implements WalletRepository {
  const _PageWalletRepository({required this.wallet, required this.keypair});

  final WalletAccount wallet;
  final solana.Keypair keypair;

  @override
  Future<List<WalletAccount>> getWallets() async => [wallet];

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    return WalletKeyMaterial(solanaPrivateKey: keypair.secretKey);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SelectedWalletStore implements SelectedWalletStore {
  const _SelectedWalletStore(this.walletId);

  final String walletId;

  @override
  String? readSelectedWalletId() => walletId;

  @override
  Future<void> writeSelectedWalletId(String? walletId) async {}
}
