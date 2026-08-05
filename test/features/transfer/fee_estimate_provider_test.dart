import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_confirm_controller.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/evm_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/solana_fee_service.dart';
import 'package:safe_wallet/features/transfer/data/sui_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/tron_fee_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/shared/errors/transfer_error.dart';

void main() {
  group('feeEstimateProvider', () {
    late ChainConfig ethereum;
    late ChainConfig bitcoin;
    late ChainConfig tron;
    late ChainConfig solana;
    late ChainConfig sui;

    setUp(() {
      ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      bitcoin = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );
      tron = defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet');
      solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      sui = defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
    });

    test('uses EIP-1559 by default for EVM transfers', () async {
      final container = _container(
        evmFeeService: _FakeEvmFeeService(
          estimate: EvmFeeEstimate.eip1559(
            gasLimit: BigInt.from(21000),
            maxFeePerGasWei: BigInt.from(30),
            maxPriorityFeePerGasWei: BigInt.from(2),
          ),
        ),
      );

      final estimate = await container.read(
        feeEstimateProvider(_feeRequest(chain: ethereum)).future,
      );

      expect(estimate.model, FeeModel.eip1559);
      expect(estimate.maxFeePerGasWei, BigInt.from(30));
      expect(estimate.maxPriorityFeePerGasWei, BigInt.from(2));
      expect(estimate.feeInBaseUnits, BigInt.from(630000));
    });

    test(
      'builds economy standard and fast EVM presets from fee history',
      () async {
        final container = _container(
          evmFeeService: _FakeEvmFeeService(
            estimate: EvmFeeEstimate.eip1559(
              gasLimit: BigInt.from(21000),
              maxFeePerGasWei: BigInt.from(22),
              maxPriorityFeePerGasWei: BigInt.from(2),
              baseFeePerGasWei: BigInt.from(10),
              priorityFeeOptionsWei: [BigInt.one, BigInt.two, BigInt.from(4)],
            ),
          ),
        );

        final estimate = await container.read(
          feeEstimateProvider(_feeRequest(chain: ethereum)).future,
        );

        expect(estimate.options.map((option) => option.speed), [
          FeeSpeed.economy,
          FeeSpeed.standard,
          FeeSpeed.fast,
        ]);
        expect(estimate.options.map((option) => option.maxFeePerGasWei), [
          BigInt.from(21),
          BigInt.from(22),
          BigInt.from(24),
        ]);
        expect(estimate.speed, FeeSpeed.standard);
      },
    );

    test(
      'passes ERC20 contract and base-unit amount into EVM fee estimate',
      () async {
        final feeService = _FakeEvmFeeService(
          estimate: EvmFeeEstimate.eip1559(
            gasLimit: BigInt.from(52000),
            maxFeePerGasWei: BigInt.from(30),
            maxPriorityFeePerGasWei: BigInt.from(2),
          ),
        );
        final container = _container(evmFeeService: feeService);
        final request = _erc20TransferRequest(chain: ethereum);

        final estimate = await container.read(
          feeEstimateProvider(
            _feeRequest(chain: ethereum, request: request),
          ).future,
        );

        expect(estimate.model, FeeModel.eip1559);
        expect(feeService.calls, hasLength(1));
        expect(
          feeService.calls.single.transactionType,
          TransactionType.erc20Transfer,
        );
        expect(feeService.calls.single.amountInWei, BigInt.from(12345600));
        expect(
          feeService.calls.single.tokenContractAddress,
          _usdcContractAddress,
        );
      },
    );

    test(
      'legacy fallback is carried into confirmation before signing',
      () async {
        final container = _container(
          evmFeeService: _FakeEvmFeeService(
            estimate: EvmFeeEstimate.legacy(
              gasLimit: BigInt.from(21000),
              gasPriceWei: BigInt.from(10),
            ),
          ),
        );
        final request = _transferRequest(chain: ethereum);

        final estimate = await container.read(
          feeEstimateProvider(
            _feeRequest(chain: ethereum, request: request),
          ).future,
        );
        final confirmation = container
            .read(transactionConfirmControllerProvider)
            .buildConfirmation(
              chain: ethereum,
              account: _account,
              request: request,
              feeEstimate: estimate,
            );

        expect(estimate.model, FeeModel.legacy);
        expect(confirmation.feeModel, FeeModel.legacy);
        expect(confirmation.feeInBaseUnits, '210000');
      },
    );

    test(
      'native transfer rejects a balance that cannot cover amount and fee',
      () {
        final request = _transferRequest(chain: ethereum);
        final estimate = FeeEstimate.legacy(
          feeAssetSymbol: ethereum.symbol,
          gasLimit: BigInt.from(21000),
          gasPriceWei: BigInt.from(1000000000),
        );
        final amount = BigInt.parse(request.amountInBaseUnits!);

        expect(
          () => const TransactionConfirmController().buildConfirmation(
            chain: ethereum,
            account: _account,
            request: request,
            feeEstimate: estimate,
            availableBalanceInBaseUnits:
                amount + estimate.feeInBaseUnits - BigInt.one,
          ),
          throwsA(
            isA<TransferError>().having(
              (error) => error.code,
              'code',
              'insufficient_balance',
            ),
          ),
        );
      },
    );

    test('native transfer allows an exact amount plus fee balance', () {
      final request = _transferRequest(chain: ethereum);
      final estimate = FeeEstimate.legacy(
        feeAssetSymbol: ethereum.symbol,
        gasLimit: BigInt.from(21000),
        gasPriceWei: BigInt.from(1000000000),
      );
      final amount = BigInt.parse(request.amountInBaseUnits!);

      final confirmation = const TransactionConfirmController()
          .buildConfirmation(
            chain: ethereum,
            account: _account,
            request: request,
            feeEstimate: estimate,
            availableBalanceInBaseUnits: amount + estimate.feeInBaseUnits,
          );

      expect(confirmation.feeInBaseUnits, estimate.feeInBaseUnits.toString());
    });

    test('Solana fee estimate fetches recent blockhash data', () async {
      final service = _FakeSolanaFeeService(
        estimate: SolanaFeeEstimate(
          lamports: BigInt.from(5000),
          recentBlockhash: 'blockhash-1',
        ),
      );
      final container = _container(solanaFeeService: service);

      final estimate = await container.read(
        feeEstimateProvider(
          _feeRequest(
            chain: solana,
            request: _transferRequest(chain: solana),
            headers: const {'x-api-key': 'secret'},
          ),
        ).future,
      );

      expect(estimate.model, FeeModel.solana);
      expect(estimate.feeInBaseUnits, BigInt.from(5000));
      expect(estimate.recentBlockhash, 'blockhash-1');
      expect(service.headers, {'x-api-key': 'secret'});
    });

    test(
      'builds Solana priority fee presets from CU simulation and RPC rates',
      () async {
        final container = _container(
          solanaFeeService: _FakeSolanaFeeService(
            estimate: SolanaFeeEstimate(
              lamports: BigInt.from(5000),
              recentBlockhash: 'blockhash-1',
              computeUnitLimit: 220000,
              priorityFeeOptionsMicroLamports: [
                BigInt.from(1000),
                BigInt.from(2000),
                BigInt.from(5000),
              ],
            ),
          ),
        );

        final estimate = await container.read(
          feeEstimateProvider(
            _feeRequest(
              chain: solana,
              request: _transferRequest(chain: solana),
            ),
          ).future,
        );

        expect(estimate.computeUnitLimit, 220000);
        expect(estimate.microLamportsPerComputeUnit, BigInt.from(2000));
        expect(
          estimate.options.map((option) => option.priorityFeeInBaseUnits),
          [BigInt.from(220), BigInt.from(440), BigInt.from(1100)],
        );
        expect(estimate.feeInBaseUnits, BigInt.from(5440));
      },
    );

    test(
      'Bitcoin fee estimate uses API fee rate and returns satoshis',
      () async {
        final feeService = _FakeBitcoinFeeService(
          estimate: BitcoinFeeEstimate(satoshis: BigInt.from(1410)),
        );
        final container = _container(bitcoinFeeService: feeService);
        final request = _transferRequest(chain: bitcoin);

        final estimate = await container.read(
          feeEstimateProvider(
            _feeRequest(chain: bitcoin, request: request),
          ).future,
        );

        expect(estimate.model, FeeModel.bitcoin);
        expect(estimate.feeAssetSymbol, 'BTC');
        expect(estimate.feeInBaseUnits, BigInt.from(1410));
        expect(feeService.calls.single.apiBaseUrl, 'https://rpc.example.com');
        expect(feeService.calls.single.fromAddress, _account.btcAddress);
        expect(feeService.calls.single.toAddress, request.toAddress);
        expect(feeService.calls.single.satoshis, BigInt.from(10000000));
      },
    );

    test(
      'builds Bitcoin speed presets and keeps sat/vB for custom fees',
      () async {
        final feeService = _FakeBitcoinFeeService(
          estimate: BitcoinFeeEstimate(
            satoshis: BigInt.from(1410),
            satsPerVbyte: 10,
            transactionVbytes: 141,
            feeRateOptions: const [5, 10, 20],
            confirmationBlockOptions: const [12, 3, 1],
          ),
        );
        final container = _container(bitcoinFeeService: feeService);

        final estimate = await container.read(
          feeEstimateProvider(_feeRequest(chain: bitcoin)).future,
        );

        expect(estimate.satsPerVbyte, 10);
        expect(estimate.transactionVbytes, 141);
        expect(estimate.confirmationBlocks, 3);
        expect(estimate.options.map((option) => option.confirmationBlocks), [
          12,
          3,
          1,
        ]);
        expect(estimate.options.map((option) => option.feeInBaseUnits), [
          BigInt.from(705),
          BigInt.from(1410),
          BigInt.from(2820),
        ]);
      },
    );

    test(
      'Bitcoin fee estimate rejects a recipient from the wrong network',
      () async {
        final feeService = _FakeBitcoinFeeService(
          estimate: BitcoinFeeEstimate(satoshis: BigInt.from(1410)),
        );
        final container = _container(bitcoinFeeService: feeService);
        final request = TransactionRequest(
          chainId: bitcoin.chainId,
          chainType: bitcoin.chainType,
          assetSymbol: bitcoin.symbol,
          toAddress: 'tb1qxmt9xgewg6mxc4mvnzvrzu4f2v0gy782fydg0w',
          amount: '0.1',
          amountInBaseUnits: '10000000',
          tokenDecimals: 8,
          transactionType: TransactionType.bitcoinTransfer,
        );
        final provider = feeEstimateProvider(
          _feeRequest(chain: bitcoin, request: request),
        );

        container.listen(provider, (previous, next) {});
        await container.pump();
        final value = container.read(provider);

        expect(value.hasError, isTrue);
        expect(
          value.error,
          isA<TransferError>().having(
            (error) => error.code,
            'code',
            'fee_estimate_failed',
          ),
        );
        expect(feeService.calls, isEmpty);
      },
    );

    test('Tron fee estimate uses API bandwidth fee estimate', () async {
      final feeService = _FakeTronFeeService(
        estimate: TronFeeEstimate(sun: BigInt.from(234000)),
      );
      final container = _container(tronFeeService: feeService);
      final request = _transferRequest(chain: tron);

      final estimate = await container.read(
        feeEstimateProvider(_feeRequest(chain: tron, request: request)).future,
      );

      expect(estimate.model, FeeModel.tron);
      expect(estimate.feeAssetSymbol, 'TRX');
      expect(estimate.feeInBaseUnits, BigInt.from(234000));
      expect(feeService.calls.single.apiBaseUrl, 'https://rpc.example.com');
      expect(feeService.calls.single.fromAddress, _account.tronAddress);
      expect(feeService.calls.single.toAddress, request.toAddress);
      expect(feeService.calls.single.sun, BigInt.from(100000));
      expect(
        feeService.calls.single.transactionType,
        TransactionType.nativeTransfer,
      );
      expect(feeService.calls.single.tokenContractAddress, isNull);
    });

    test('Tron TRC20 fee estimate passes token contract details', () async {
      final feeService = _FakeTronFeeService(
        estimate: TronFeeEstimate(
          sun: BigInt.from(15000000),
          recommendedFeeLimitSun: BigInt.from(18000000),
        ),
      );
      final container = _container(tronFeeService: feeService);
      final request = TransactionRequest(
        chainId: tron.chainId,
        chainType: tron.chainType,
        assetSymbol: 'USDT',
        toAddress: 'TNFRxT9A4Nx2wDU69keYpLcE8TCSyFztgi',
        amount: '12.3456',
        amountInBaseUnits: '12345600',
        tokenDecimals: 6,
        tokenContractAddress: _trc20ContractAddress,
        transactionType: TransactionType.trc20Transfer,
      );

      final estimate = await container.read(
        feeEstimateProvider(_feeRequest(chain: tron, request: request)).future,
      );

      expect(estimate.model, FeeModel.tron);
      expect(estimate.feeInBaseUnits, BigInt.from(15000000));
      expect(estimate.feeLimitSun, BigInt.from(18000000));
      expect(
        feeService.calls.single.transactionType,
        TransactionType.trc20Transfer,
      );
      expect(
        feeService.calls.single.tokenContractAddress,
        _trc20ContractAddress,
      );
    });

    test(
      'Sui fee estimate simulates the transfer and preserves gas budget',
      () async {
        final feeService = _FakeSuiTransactionService(
          simulation: SuiTransactionSimulation(
            estimatedFeeMist: BigInt.from(900),
            gasBudgetMist: BigInt.from(1200),
          ),
        );
        final container = _container(suiTransactionService: feeService);
        final request = _transferRequest(chain: sui);

        final estimate = await container.read(
          feeEstimateProvider(_feeRequest(chain: sui, request: request)).future,
        );

        expect(estimate.model, FeeModel.sui);
        expect(estimate.feeAssetSymbol, 'SUI');
        expect(estimate.feeInBaseUnits, BigInt.from(1200));
        expect(estimate.estimatedFeeInBaseUnits, BigInt.from(900));
        expect(estimate.gasBudgetMist, BigInt.from(1200));
        expect(feeService.calls.single.rpcUrl, 'https://rpc.example.com');
        expect(feeService.calls.single.fromAddress, _account.suiAddress);
        expect(feeService.calls.single.transaction, request);

        final confirmation = container
            .read(transactionConfirmControllerProvider)
            .buildConfirmation(
              chain: sui,
              account: _account,
              request: request,
              feeEstimate: estimate,
            );
        expect(confirmation.fromAddress, _account.suiAddress);
        expect(confirmation.fee, '0.0000009');
        expect(confirmation.maximumFee, '0.0000012');
        expect(confirmation.feeInBaseUnits, '1200');
        expect(confirmation.totalDeduction, '0.1000012 SUI');
      },
    );

    test(
      'Sui fee estimate preserves a localizable insufficient gas error',
      () async {
        final sui = defaultChains.firstWhere(
          (chain) => chain.id == 'sui-mainnet',
        );
        final container = _container(
          suiTransactionService: _FakeSuiTransactionService(
            simulation: SuiTransactionSimulation(
              estimatedFeeMist: BigInt.zero,
              gasBudgetMist: BigInt.zero,
            ),
            error: const TransferError.suiInsufficientGas(),
          ),
        );
        final provider = feeEstimateProvider(_feeRequest(chain: sui));

        container.listen(provider, (previous, next) {});
        await container.pump();
        final value = container.read(provider);

        expect(value.error, isA<TransferError>());
        expect((value.error! as TransferError).code, 'sui_insufficient_gas');
      },
    );

    test('fee failure blocks confirmation', () async {
      final container = _container(
        evmFeeService: _FakeEvmFeeService(error: StateError('fee failed')),
      );
      final request = _transferRequest(chain: ethereum);
      final provider = feeEstimateProvider(
        _feeRequest(chain: ethereum, request: request),
      );

      container.listen(provider, (previous, next) {});
      await container.pump();
      final value = container.read(provider);

      expect(value.hasError, isTrue);
      expect(
        value.error,
        isA<TransferError>().having(
          (error) => error.code,
          'code',
          'fee_estimate_failed',
        ),
      );

      expect(
        () => container
            .read(transactionConfirmControllerProvider)
            .buildConfirmation(
              chain: ethereum,
              account: _account,
              request: request,
              feeEstimate: null,
            ),
        throwsA(isA<TransferError>()),
      );
    });
  });
}

ProviderContainer _container({
  EvmFeeService? evmFeeService,
  BitcoinFeeService? bitcoinFeeService,
  TronFeeService? tronFeeService,
  SolanaFeeService? solanaFeeService,
  SuiTransactionService? suiTransactionService,
}) {
  final container = ProviderContainer(
    overrides: [
      if (evmFeeService != null)
        evmFeeServiceProvider.overrideWithValue(evmFeeService),
      if (bitcoinFeeService != null)
        bitcoinFeeServiceProvider.overrideWithValue(bitcoinFeeService),
      if (tronFeeService != null)
        tronFeeServiceProvider.overrideWithValue(tronFeeService),
      if (solanaFeeService != null)
        solanaFeeServiceProvider.overrideWithValue(solanaFeeService),
      if (suiTransactionService != null)
        suiTransactionServiceProvider.overrideWithValue(suiTransactionService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

FeeEstimateRequest _feeRequest({
  required ChainConfig chain,
  TransactionRequest? request,
  Map<String, String> headers = const {},
}) {
  return FeeEstimateRequest(
    chain: chain,
    rpcNode: RpcNode(
      id: '${chain.id}-node',
      chainId: chain.chainId,
      name: 'Test RPC',
      url: 'https://rpc.example.com',
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      resolvedHeaders: headers,
    ),
    fromAddress: _account.addressForChainType(chain.chainType),
    request: request ?? _transferRequest(chain: chain),
  );
}

TransactionRequest _transferRequest({required ChainConfig chain}) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: chain.symbol,
    toAddress: switch (chain.chainType) {
      ChainType.evm => '0x2222222222222222222222222222222222222222',
      ChainType.bitcoin => 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      ChainType.tron => 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj',
      ChainType.solana => 'So11111111111111111111111111111111111111112',
      ChainType.sui =>
        '0x0000000000000000000000000000000000000000000000000000000000000002',
    },
    amount: '0.1',
    amountInBaseUnits: switch (chain.chainType) {
      ChainType.evm => '100000000000000000',
      ChainType.bitcoin => '10000000',
      ChainType.tron => '100000',
      ChainType.solana => '100000000',
      ChainType.sui => '100000000',
    },
    tokenDecimals: switch (chain.chainType) {
      ChainType.evm => 18,
      ChainType.bitcoin => 8,
      ChainType.tron => 6,
      ChainType.solana => 9,
      ChainType.sui => 9,
    },
    transactionType: switch (chain.chainType) {
      ChainType.evm => TransactionType.nativeTransfer,
      ChainType.bitcoin => TransactionType.bitcoinTransfer,
      ChainType.tron => TransactionType.nativeTransfer,
      ChainType.solana => TransactionType.solTransfer,
      ChainType.sui => TransactionType.suiTransfer,
    },
  );
}

TransactionRequest _erc20TransferRequest({required ChainConfig chain}) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: 'USDC',
    toAddress: '0x2222222222222222222222222222222222222222',
    amount: '12.3456',
    amountInBaseUnits: '12345600',
    tokenDecimals: 6,
    tokenContractAddress: _usdcContractAddress,
    transactionType: TransactionType.erc20Transfer,
  );
}

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '11111111111111111111111111111111',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  tronAddress: 'TJ4uT7n9LQvz1J9jQK5hJkCcnHJfLgkSnj',
  suiAddress:
      '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
  createdAt: DateTime.utc(2026, 6, 6),
  updatedAt: DateTime.utc(2026, 6, 6),
);

final class _FakeEvmFeeService implements EvmFeeService {
  _FakeEvmFeeService({this.estimate, this.error});

  final EvmFeeEstimate? estimate;
  final Object? error;
  final calls = <_EvmFeeCall>[];

  @override
  Future<EvmFeeEstimate> estimateTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required TransactionType transactionType,
    required BigInt amountInWei,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  }) async {
    calls.add(
      _EvmFeeCall(
        transactionType: transactionType,
        amountInWei: amountInWei,
        tokenContractAddress: tokenContractAddress,
      ),
    );
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return estimate!;
  }
}

final class _EvmFeeCall {
  const _EvmFeeCall({
    required this.transactionType,
    required this.amountInWei,
    required this.tokenContractAddress,
  });

  final TransactionType transactionType;
  final BigInt amountInWei;
  final String? tokenContractAddress;
}

final class _FakeBitcoinFeeService implements BitcoinFeeService {
  _FakeBitcoinFeeService({required this.estimate});

  final BitcoinFeeEstimate estimate;
  final calls = <_BitcoinFeeCall>[];

  @override
  Future<BitcoinFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt satoshis,
    bool sweep = false,
  }) async {
    calls.add(
      _BitcoinFeeCall(
        apiBaseUrl: apiBaseUrl,
        fromAddress: fromAddress,
        toAddress: toAddress,
        satoshis: satoshis,
      ),
    );
    return estimate;
  }
}

final class _BitcoinFeeCall {
  const _BitcoinFeeCall({
    required this.apiBaseUrl,
    required this.fromAddress,
    required this.toAddress,
    required this.satoshis,
  });

  final String apiBaseUrl;
  final String fromAddress;
  final String toAddress;
  final BigInt satoshis;
}

final class _FakeTronFeeService implements TronFeeService {
  _FakeTronFeeService({required this.estimate});

  final TronFeeEstimate estimate;
  final calls = <_TronFeeCall>[];

  @override
  Future<TronFeeEstimate> estimateTransferFee({
    required String apiBaseUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt sun,
    required TransactionType transactionType,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  }) async {
    calls.add(
      _TronFeeCall(
        apiBaseUrl: apiBaseUrl,
        fromAddress: fromAddress,
        toAddress: toAddress,
        sun: sun,
        transactionType: transactionType,
        tokenContractAddress: tokenContractAddress,
      ),
    );
    return estimate;
  }
}

final class _TronFeeCall {
  const _TronFeeCall({
    required this.apiBaseUrl,
    required this.fromAddress,
    required this.toAddress,
    required this.sun,
    required this.transactionType,
    required this.tokenContractAddress,
  });

  final String apiBaseUrl;
  final String fromAddress;
  final String toAddress;
  final BigInt sun;
  final TransactionType transactionType;
  final String? tokenContractAddress;
}

final class _FakeSolanaFeeService implements SolanaFeeService {
  _FakeSolanaFeeService({required this.estimate});

  final SolanaFeeEstimate estimate;
  Map<String, String>? headers;

  @override
  Future<SolanaFeeEstimate> estimateSolTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required BigInt lamports,
    Map<String, String> headers = const {},
  }) async {
    this.headers = headers;
    return estimate;
  }
}

final class _FakeSuiTransactionService implements SuiTransactionService {
  _FakeSuiTransactionService({required this.simulation, this.error});

  final SuiTransactionSimulation simulation;
  final Object? error;
  final calls = <SuiTransferInput>[];

  @override
  Future<SuiTransactionSimulation> estimateTransferFee(
    SuiTransferInput input,
  ) async {
    calls.add(input);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return simulation;
  }

  @override
  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  }) async {
    return null;
  }

  @override
  Future<String> signAndBroadcast(SuiTransactionBroadcastInput input) {
    throw UnimplementedError();
  }
}

const _usdcContractAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _trc20ContractAddress = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
