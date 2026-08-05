import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/application/solana_rent_recovery_controller.dart';
import 'package:safe_wallet/features/advanced/data/solana_rent_recovery_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/solana_rent_recovery_models.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;

void main() {
  final currentKeypair = solana.Keypair.generate();
  final otherKeypair = solana.Keypair.generate();
  final currentWallet = _wallet(
    id: 'wallet-current',
    address: currentKeypair.publicKey.toBase58(),
  );
  final otherWallet = _wallet(
    id: 'wallet-other',
    address: otherKeypair.publicKey.toBase58(),
  );
  final evmOnlyWallet = _wallet(id: 'wallet-evm', address: '');
  const mainnet = ChainConfig(
    id: 'solana-mainnet',
    chainType: ChainType.solana,
    name: 'Solana Mainnet',
    chainId: 'mainnet-beta',
    symbol: 'SOL',
    rpcUrls: ['https://solana.example'],
    blockExplorerUrl: 'https://solscan.io',
    isTestnet: false,
  );
  const devnet = ChainConfig(
    id: 'solana-devnet',
    chainType: ChainType.solana,
    name: 'Solana Devnet',
    chainId: 'devnet',
    symbol: 'SOL',
    rpcUrls: ['https://devnet.example'],
    blockExplorerUrl: 'https://solscan.io?cluster=devnet',
    isTestnet: true,
  );

  ProviderContainer buildContainer({
    required _FakeRentGateway gateway,
    bool failUnlock = false,
  }) {
    final repository = _FakeWalletRepository(
      wallets: [evmOnlyWallet, otherWallet, currentWallet],
      privateKeys: {
        currentWallet.id: currentKeypair.secretKey,
        otherWallet.id: otherKeypair.secretKey,
      },
      failUnlock: failUnlock,
    );
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(repository),
        selectedWalletStoreProvider.overrideWithValue(
          _SelectedWalletStore(currentWallet.id),
        ),
        chainRepositoryProvider.overrideWithValue(
          _FakeChainRepository([mainnet, devnet]),
        ),
        solanaRentRecoveryDefaultNetworkIdProvider.overrideWithValue(
          () async => devnet.id,
        ),
        solanaRentRecoveryRpcUrlProvider.overrideWithValue(
          (chain) async => chain.rpcUrls.first,
        ),
        solanaRentRecoveryGatewayProvider.overrideWithValue(gateway),
        securityLogRepositoryProvider.overrideWithValue(
          InMemorySecurityLogRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to current Solana wallet and current Solana network',
      () async {
    final container = buildContainer(gateway: _FakeRentGateway());

    final state = await container.read(
      solanaRentRecoveryControllerProvider.future,
    );

    expect(state.wallets.map((wallet) => wallet.id), [
      otherWallet.id,
      currentWallet.id,
    ]);
    expect(state.selectedWalletId, currentWallet.id);
    expect(state.networks, [mainnet, devnet]);
    expect(state.selectedNetworkId, devnet.id);
  });

  test('scan selects all eligible accounts and estimates net recovery',
      () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [account],
        solBalanceLamports: BigInt.from(100000),
      ),
      estimatedFeeLamports: BigInt.from(5000),
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);

    await container.read(solanaRentRecoveryControllerProvider.notifier).scan();

    final state =
        container.read(solanaRentRecoveryControllerProvider).requireValue;
    expect(state.status, SolanaRentRecoveryStatus.ready);
    expect(state.selectedAccountAddresses, {account.address});
    expect(state.estimate?.networkFeeLamports, BigInt.from(5000));
    expect(state.estimate?.netRecoverableLamports, BigInt.from(2034280));
    expect(gateway.lastRpcUrl, devnet.rpcUrls.first);
    expect(gateway.lastOwnerAddress, currentWallet.solanaAddress);
  });

  test('recovery refuses to submit without enough SOL for network fees',
      () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [account],
        solBalanceLamports: BigInt.from(1000),
      ),
      estimatedFeeLamports: BigInt.from(5000),
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();

    final result = await controller.recover();

    expect(result, isNull);
    expect(gateway.recoverCalls, 0);
    expect(
      container.read(solanaRentRecoveryControllerProvider).requireValue.error,
      SolanaRentRecoveryError.insufficientFeeBalance,
    );
  });

  test('recovery refuses to submit when no account is selected', () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [account],
        solBalanceLamports: BigInt.from(100000),
      ),
      estimatedFeeLamports: BigInt.from(5000),
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();
    await controller.toggleAccount(account.address);

    final result = await controller.recover(signingPassword: 'password');

    expect(result, isNull);
    expect(gateway.recoverCalls, 0);
    expect(
      container.read(solanaRentRecoveryControllerProvider).requireValue.error,
      SolanaRentRecoveryError.noAccountsSelected,
    );
  });

  test('late estimates cannot restore an older account selection', () async {
    final accountA = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final accountB = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.token2022,
      recoverableLamports: BigInt.from(2500000),
    );
    final pendingEstimates = <Completer<SolanaRentRecoveryEstimate>>[];
    var estimateCalls = 0;
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [accountA, accountB],
        solBalanceLamports: BigInt.from(100000),
      ),
      estimateHandler: (accounts) {
        estimateCalls += 1;
        if (estimateCalls == 1) {
          return Future.value(_estimateFor(accounts));
        }
        final completer = Completer<SolanaRentRecoveryEstimate>();
        pendingEstimates.add(completer);
        return completer.future;
      },
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();

    final firstToggle = controller.toggleAccount(accountA.address);
    await Future<void>.delayed(Duration.zero);
    final secondToggle = controller.toggleAccount(accountB.address);
    await Future<void>.delayed(Duration.zero);
    expect(pendingEstimates, hasLength(2));

    pendingEstimates[1].complete(_estimateFor(const []));
    await secondToggle;
    pendingEstimates[0].complete(_estimateFor([accountB]));
    await firstToggle;

    final state =
        container.read(solanaRentRecoveryControllerProvider).requireValue;
    expect(state.selectedAccountAddresses, isEmpty);
    expect(state.estimate?.totalRecoverableLamports, BigInt.zero);
  });

  test('failed password unlock keeps the recovery ready for retry', () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [account],
        solBalanceLamports: BigInt.from(100000),
      ),
      estimatedFeeLamports: BigInt.from(5000),
    );
    final container = buildContainer(gateway: gateway, failUnlock: true);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();

    final result = await controller.recover(signingPassword: 'wrong');

    expect(result, isNull);
    expect(gateway.recoverCalls, 0);
    final state =
        container.read(solanaRentRecoveryControllerProvider).requireValue;
    expect(state.status, SolanaRentRecoveryStatus.ready);
    expect(state.error, SolanaRentRecoveryError.walletLocked);
  });

  test('recovery uses the selected wallet key and stores successful result',
      () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.token2022,
      recoverableLamports: BigInt.from(2500000),
    );
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [account],
        solBalanceLamports: BigInt.from(100000),
      ),
      estimatedFeeLamports: BigInt.from(5000),
      recoveryResult: SolanaRentRecoveryResult(
        signatures: ['signature-a'],
        completedAccountCount: 1,
        recoveredLamports: BigInt.from(2500000),
      ),
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();

    final result = await controller.recover(signingPassword: 'password');

    expect(result?.signatures, ['signature-a']);
    expect(gateway.lastPrivateKey, currentKeypair.secretKey);
    expect(
      container.read(solanaRentRecoveryControllerProvider).requireValue.status,
      SolanaRentRecoveryStatus.success,
    );
    final logs =
        await container.read(securityLogRepositoryProvider).listEntries();
    expect(logs.single.type, SecurityLogEventType.solanaRentRecovery);
    expect(logs.single.walletName, currentWallet.name);
    expect(logs.single.chainName, devnet.name);
    expect(logs.single.amount, '0.0025');
  });

  test('successful recovery refreshes accounts while preserving the result',
      () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.splToken,
      recoverableLamports: BigInt.from(2039280),
    );
    var scanCalls = 0;
    final gateway = _FakeRentGateway(
      scanHandler: () async {
        scanCalls += 1;
        return SolanaRentScanResult(
          accounts: scanCalls < 3 ? [account] : const [],
          solBalanceLamports: BigInt.from(100000),
        );
      },
      estimatedFeeLamports: BigInt.from(5000),
      recoveryResult: SolanaRentRecoveryResult(
        signatures: ['signature-a'],
        completedAccountCount: 1,
        recoveredLamports: account.recoverableLamports,
      ),
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();

    final result = await controller.recover(signingPassword: 'password');

    final state =
        container.read(solanaRentRecoveryControllerProvider).requireValue;
    expect(scanCalls, 3);
    expect(state.status, SolanaRentRecoveryStatus.success);
    expect(state.result, same(result));
    expect(state.scanResult?.accounts, isEmpty);
    expect(state.selectedAccountAddresses, isEmpty);
    expect(state.estimate?.totalRecoverableLamports, BigInt.zero);
  });

  test('recovery preserves completed batches as a partial success', () async {
    final account = SolanaRentAccount(
      address: solana.Keypair.generate().publicKey.toBase58(),
      mintAddress: solana.Keypair.generate().publicKey.toBase58(),
      program: SolanaRentTokenProgram.token2022,
      recoverableLamports: BigInt.from(2500000),
    );
    final gateway = _FakeRentGateway(
      scanResult: SolanaRentScanResult(
        accounts: [account],
        solBalanceLamports: BigInt.from(100000),
      ),
      estimatedFeeLamports: BigInt.from(5000),
      recoveryResult: SolanaRentRecoveryResult(
        signatures: ['signature-a'],
        completedAccountCount: 1,
        recoveredLamports: account.recoverableLamports,
        errorMessage: 'later batch failed',
      ),
    );
    final container = buildContainer(gateway: gateway);
    await container.read(solanaRentRecoveryControllerProvider.future);
    final controller = container.read(
      solanaRentRecoveryControllerProvider.notifier,
    );
    await controller.scan();

    final result = await controller.recover(signingPassword: 'password');

    expect(result?.isPartial, isTrue);
    final state =
        container.read(solanaRentRecoveryControllerProvider).requireValue;
    expect(state.status, SolanaRentRecoveryStatus.partialSuccess);
    expect(state.result?.completedAccountCount, 1);
    expect(state.result?.signatures, ['signature-a']);
  });
}

WalletAccount _wallet({required String id, required String address}) {
  return WalletAccount(
    id: id,
    name: id,
    evmAddress: '0x1111111111111111111111111111111111111111',
    solanaAddress: address,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

final class _FakeRentGateway implements SolanaRentRecoveryGateway {
  _FakeRentGateway({
    SolanaRentScanResult? scanResult,
    BigInt? estimatedFeeLamports,
    SolanaRentRecoveryResult? recoveryResult,
    this.scanHandler,
    this.estimateHandler,
  })  : scanResult = scanResult ??
            SolanaRentScanResult(
              accounts: const [],
              solBalanceLamports: BigInt.zero,
            ),
        estimatedFeeLamports = estimatedFeeLamports ?? BigInt.zero,
        recoveryResult = recoveryResult ??
            SolanaRentRecoveryResult(
              signatures: const [],
              completedAccountCount: 0,
              recoveredLamports: BigInt.zero,
            );

  final SolanaRentScanResult scanResult;
  final BigInt estimatedFeeLamports;
  final SolanaRentRecoveryResult recoveryResult;
  final Future<SolanaRentScanResult> Function()? scanHandler;
  final Future<SolanaRentRecoveryEstimate> Function(
      List<SolanaRentAccount> accounts)? estimateHandler;
  String? lastRpcUrl;
  String? lastOwnerAddress;
  List<int>? lastPrivateKey;
  int recoverCalls = 0;

  @override
  Future<SolanaRentScanResult> scan({
    required String rpcUrl,
    required String ownerAddress,
  }) async {
    lastRpcUrl = rpcUrl;
    lastOwnerAddress = ownerAddress;
    final handler = scanHandler;
    if (handler != null) {
      return handler();
    }
    return scanResult;
  }

  @override
  Future<SolanaRentRecoveryEstimate> estimate({
    required String rpcUrl,
    required String ownerAddress,
    required List<SolanaRentAccount> accounts,
  }) async {
    final handler = estimateHandler;
    if (handler != null) {
      return handler(accounts);
    }
    return SolanaRentRecoveryEstimate(
      batches: [
        if (accounts.isNotEmpty)
          SolanaRentRecoveryBatch(
            accounts: accounts,
            estimatedFeeLamports: estimatedFeeLamports,
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
    lastPrivateKey = List.of(privateKey);
    return recoveryResult;
  }
}

SolanaRentRecoveryEstimate _estimateFor(List<SolanaRentAccount> accounts) {
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

final class _SelectedWalletStore implements SelectedWalletStore {
  _SelectedWalletStore(this.walletId);

  final String walletId;

  @override
  String? readSelectedWalletId() => walletId;

  @override
  Future<void> writeSelectedWalletId(String? walletId) async {}
}

final class _FakeChainRepository implements ChainRepository {
  _FakeChainRepository(this.chains);

  final List<ChainConfig> chains;

  @override
  Future<List<ChainConfig>> getChains() async => chains;

  @override
  Future<ChainConfig> getSelectedChain() async => chains.first;

  @override
  Future<ChainConfig> selectChain(String chainId) async =>
      chains.firstWhere((chain) => chain.id == chainId);

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) async {
    throw UnimplementedError();
  }
}

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({
    required this.wallets,
    required this.privateKeys,
    this.failUnlock = false,
  });

  final List<WalletAccount> wallets;
  final Map<String, List<int>> privateKeys;
  final bool failUnlock;

  @override
  Future<List<WalletAccount>> getWallets() async => wallets;

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    if (failUnlock) {
      throw StateError('invalid password');
    }
    return WalletUnlockResult(
      account: wallets.firstWhere((wallet) => wallet.id == walletId),
      walletDek: [1, 2, 3],
    );
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    return WalletKeyMaterial(solanaPrivateKey: privateKeys[walletId]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
