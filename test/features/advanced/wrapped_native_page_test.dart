import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/application/wrapped_native_controller.dart';
import 'package:safe_wallet/features/advanced/data/evm_wrapped_native_gateway.dart';
import 'package:safe_wallet/features/advanced/data/solana_wrapped_native_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/wrapped_native_models.dart';
import 'package:safe_wallet/features/advanced/presentation/advanced_settings_page.dart';
import 'package:safe_wallet/features/advanced/presentation/wrapped_native_page.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/design/app_theme.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  testWidgets('advanced settings exposes wrapped native tool', (tester) async {
    await tester.pumpWidget(_app(home: const AdvancedSettingsPage()));

    expect(find.byKey(const Key('advancedWrappedNative')), findsOneWidget);
    expect(find.text('原生币封装'), findsOneWidget);
  });

  testWidgets('shows wallet network operations balances and amount input', (
    tester,
  ) async {
    final ethereum = defaultChains.firstWhere((chain) => chain.chainId == '1');
    final wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_WalletRepository(wallet)),
          selectedWalletStoreProvider.overrideWithValue(
            _SelectedWalletStore(wallet.id),
          ),
          availableChainsProvider.overrideWith((ref) async => [ethereum]),
          wrappedNativeDefaultNetworkIdProvider.overrideWithValue(
            () async => ethereum.id,
          ),
          wrappedNativeRpcNodeResolverProvider.overrideWithValue(
            (chain) async => RpcNode(
              id: 'node-1',
              chainId: chain.chainId,
              name: chain.name,
              url: chain.rpcUrls.first,
              nodeType: RpcNodeType.defaultNode,
              isSelected: true,
              lastTestStatus: RpcNodeTestStatus.available,
            ),
          ),
          evmWrappedNativeGatewayProvider.overrideWithValue(_EvmGateway()),
          solanaWrappedNativeGatewayProvider.overrideWithValue(
            _SolanaGateway(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const WrappedNativePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wrappedNativeWalletPicker')), findsOneWidget);
    expect(find.byKey(const Key('wrappedNativeNetworkPicker')), findsOneWidget);
    expect(find.text('Main Wallet'), findsOneWidget);
    expect(find.text(ethereum.name), findsOneWidget);
    expect(find.text('2 ETH'), findsOneWidget);
    expect(find.text('1 WETH'), findsOneWidget);
    final amountInput = find.byKey(const Key('wrappedNativeAmountInput'));
    final operationPicker = find.byKey(
      const Key('wrappedNativeOperationPicker'),
    );
    expect(amountInput, findsOneWidget);
    expect(operationPicker, findsOneWidget);
    expect(find.byType(SegmentedButton<WrappedNativeOperation>), findsNothing);
    expect(find.text('ETH → WETH'), findsOneWidget);
    expect(
      tester.getTopLeft(amountInput).dy,
      lessThan(tester.getTopLeft(operationPicker).dy),
    );

    await tester.tap(operationPicker);
    await tester.pumpAndSettle();

    expect(find.text('WETH → ETH'), findsOneWidget);
    expect(find.byKey(const Key('wrappedNativeReviewButton')), findsOneWidget);
  });

  testWidgets('reviews confirms and submits a wrap transaction', (
    tester,
  ) async {
    final ethereum = defaultChains.firstWhere((chain) => chain.chainId == '1');
    final wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x1111111111111111111111111111111111111111',
      solanaAddress: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final gateway = _EvmGateway();
    final cache = SessionKeyCache()
      ..unlock(
        walletId: wallet.id,
        walletDek: const [1, 2, 3],
        now: DateTime.now().toUtc(),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(_WalletRepository(wallet)),
          selectedWalletStoreProvider.overrideWithValue(
            _SelectedWalletStore(wallet.id),
          ),
          sessionKeyCacheProvider.overrideWithValue(cache),
          availableChainsProvider.overrideWith((ref) async => [ethereum]),
          wrappedNativeDefaultNetworkIdProvider.overrideWithValue(
            () async => ethereum.id,
          ),
          wrappedNativeRpcNodeResolverProvider.overrideWithValue(
            (chain) async => RpcNode(
              id: 'node-1',
              chainId: chain.chainId,
              name: chain.name,
              url: chain.rpcUrls.first,
              nodeType: RpcNodeType.defaultNode,
              isSelected: true,
              lastTestStatus: RpcNodeTestStatus.available,
            ),
          ),
          evmWrappedNativeGatewayProvider.overrideWithValue(gateway),
          solanaWrappedNativeGatewayProvider.overrideWithValue(
            _SolanaGateway(),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const WrappedNativePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('wrappedNativeAmountInput')),
      '0.5',
    );
    await tester.ensureVisible(
      find.byKey(const Key('wrappedNativeReviewButton')),
    );
    await tester.tap(find.byKey(const Key('wrappedNativeReviewButton')));
    await tester.pumpAndSettle();

    expect(find.text('确认原生币转换'), findsOneWidget);
    expect(find.text('0.5 ETH'), findsOneWidget);
    expect(find.text('0.5 WETH'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    final networkValue = find.descendant(
      of: dialog,
      matching: find.text(ethereum.name),
    );
    final fromValue = find.descendant(
      of: dialog,
      matching: find.text('0.5 ETH'),
    );
    final toValue = find.descendant(
      of: dialog,
      matching: find.text('0.5 WETH'),
    );
    final valueRightEdge = tester.getTopRight(networkValue).dx;
    expect(tester.getTopRight(fromValue).dx, closeTo(valueRightEdge, 0.1));
    expect(tester.getTopRight(toValue).dx, closeTo(valueRightEdge, 0.1));
    await tester.tap(find.byKey(const Key('confirmWrappedNative')));
    await tester.pumpAndSettle();

    expect(gateway.submitCalls, 1);
    expect(find.text('封装交易已提交'), findsOneWidget);
    expect(find.text('0xhash'), findsOneWidget);
  });
}

Widget _app({required Widget home}) => ProviderScope(
  child: TranslationProvider(
    child: MaterialApp(theme: buildAppTheme(), home: home),
  ),
);

final class _WalletRepository implements WalletRepository {
  const _WalletRepository(this.wallet);

  final WalletAccount wallet;

  @override
  Future<List<WalletAccount>> getWallets() async => [wallet];

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async => WalletKeyMaterial(evmPrivateKey: 'private-key');

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

final class _EvmGateway implements EvmWrappedNativeGateway {
  int submitCalls = 0;

  @override
  Future<EvmWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    Map<String, String> headers = const {},
  }) async => EvmWrappedNativeBalances(
    nativeBalance: BigInt.from(2) * BigInt.from(10).pow(18),
    wrappedBalance: BigInt.from(10).pow(18),
  );

  @override
  Future<EvmWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    required WrappedNativeOperation operation,
    required BigInt amountInBaseUnits,
    Map<String, String> headers = const {},
  }) async => EvmWrappedNativePreparation(
    call: buildEvmWrappedNativeCall(
      config: config,
      operation: operation,
      amountInBaseUnits: amountInBaseUnits,
    ),
    feeModel: EvmWrappedNativeFeeModel.legacy,
    gasLimit: BigInt.from(30000),
    gasPriceWei: BigInt.one,
  );

  @override
  Future<String> submit({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String privateKey,
    required EvmWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  }) async {
    submitCalls += 1;
    return '0xhash';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SolanaGateway implements SolanaWrappedNativeGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
