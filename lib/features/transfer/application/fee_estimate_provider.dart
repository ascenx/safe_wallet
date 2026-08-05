import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chains/domain/chain_config.dart';
import '../../nodes/domain/rpc_node.dart';
import '../../../shared/errors/transfer_error.dart';
import '../../../shared/utils/bitcoin_address.dart';
import '../data/bitcoin_fee_service.dart';
import '../data/evm_fee_service.dart';
import '../data/solana_fee_service.dart';
import '../data/sui_transaction_service.dart';
import '../data/tron_fee_service.dart';
import '../domain/transaction_request.dart';

final evmFeeServiceProvider = Provider<EvmFeeService>((ref) {
  return const Web3EvmFeeService();
});

final bitcoinFeeServiceProvider = Provider<BitcoinFeeService>((ref) {
  final service = HttpBitcoinFeeService();
  ref.onDispose(service.close);
  return service;
});

final solanaFeeServiceProvider = Provider<SolanaFeeService>((ref) {
  return const SdkSolanaFeeService();
});

final tronFeeServiceProvider = Provider<TronFeeService>((ref) {
  final service = HttpTronFeeService();
  ref.onDispose(service.close);
  return service;
});

final suiTransactionServiceProvider = Provider<SuiTransactionService>((ref) {
  final service = SdkSuiTransactionService();
  ref.onDispose(() => unawaited(service.close()));
  return service;
});

final feeEstimateInvalidationProvider =
    NotifierProvider<FeeEstimateInvalidationController, int>(
      FeeEstimateInvalidationController.new,
    );

final class FeeEstimateInvalidationController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state++;
  }
}

final feeEstimateProvider =
    FutureProvider.family<FeeEstimate, FeeEstimateRequest>((
      ref,
      request,
    ) async {
      ref.watch(feeEstimateInvalidationProvider);
      try {
        return switch (request.chain.chainType) {
          ChainType.evm => await _estimateEvmFee(ref, request),
          ChainType.bitcoin => await _estimateBitcoinFee(ref, request),
          ChainType.tron => await _estimateTronFee(ref, request),
          ChainType.solana => await _estimateSolanaFee(ref, request),
          ChainType.sui => await _estimateSuiFee(ref, request),
        };
      } on TransferError {
        rethrow;
      } catch (_) {
        throw const TransferError.feeEstimateFailed();
      }
    });

enum FeeModel { eip1559, legacy, bitcoin, tron, solana, sui }

enum FeeSpeed { economy, standard, fast, custom }

final class FeeOption {
  const FeeOption({
    required this.speed,
    required this.feeInBaseUnits,
    this.estimatedFeeInBaseUnits,
    this.gasLimit,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.gasPriceWei,
    this.baseFeePerGasWei,
    this.baseFeeInBaseUnits,
    this.priorityFeeInBaseUnits,
    this.computeUnitLimit,
    this.microLamportsPerComputeUnit,
    this.satsPerVbyte,
    this.transactionVbytes,
    this.feeLimitSun,
    this.gasBudgetMist,
    this.confirmationBlocks,
  });

  final FeeSpeed speed;
  final BigInt feeInBaseUnits;
  final BigInt? estimatedFeeInBaseUnits;
  final BigInt? gasLimit;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final BigInt? gasPriceWei;
  final BigInt? baseFeePerGasWei;
  final BigInt? baseFeeInBaseUnits;
  final BigInt? priorityFeeInBaseUnits;
  final int? computeUnitLimit;
  final BigInt? microLamportsPerComputeUnit;
  final double? satsPerVbyte;
  final int? transactionVbytes;
  final BigInt? feeLimitSun;
  final BigInt? gasBudgetMist;
  final int? confirmationBlocks;
}

final class FeeEstimate {
  const FeeEstimate._({
    required this.model,
    required this.feeInBaseUnits,
    required this.estimatedFeeInBaseUnits,
    required this.feeAssetSymbol,
    this.speed = FeeSpeed.standard,
    required this.options,
    this.gasLimit,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.gasPriceWei,
    this.baseFeePerGasWei,
    this.recentBlockhash,
    this.baseFeeInBaseUnits,
    this.priorityFeeInBaseUnits,
    this.computeUnitLimit,
    this.microLamportsPerComputeUnit,
    this.satsPerVbyte,
    this.transactionVbytes,
    this.feeLimitSun,
    this.gasBudgetMist,
    this.confirmationBlocks,
  });

  factory FeeEstimate.eip1559({
    required String feeAssetSymbol,
    required BigInt gasLimit,
    required BigInt maxFeePerGasWei,
    required BigInt maxPriorityFeePerGasWei,
    FeeSpeed speed = FeeSpeed.standard,
    List<FeeOption> options = const [],
    BigInt? baseFeePerGasWei,
  }) {
    final fee = gasLimit * maxFeePerGasWei;
    final estimatedFee = _eip1559EstimatedFee(
      gasLimit: gasLimit,
      maxFeePerGasWei: maxFeePerGasWei,
      baseFeePerGasWei: baseFeePerGasWei,
      priorityFeePerGasWei: maxPriorityFeePerGasWei,
    );
    return FeeEstimate._(
      model: FeeModel.eip1559,
      feeInBaseUnits: fee,
      estimatedFeeInBaseUnits: estimatedFee,
      feeAssetSymbol: feeAssetSymbol,
      speed: speed,
      options: options.isEmpty
          ? [
              FeeOption(
                speed: speed,
                feeInBaseUnits: fee,
                estimatedFeeInBaseUnits: estimatedFee,
                gasLimit: gasLimit,
                maxFeePerGasWei: maxFeePerGasWei,
                maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
              ),
            ]
          : List.unmodifiable(options),
      gasLimit: gasLimit,
      maxFeePerGasWei: maxFeePerGasWei,
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
      baseFeePerGasWei: baseFeePerGasWei,
    );
  }

  factory FeeEstimate.legacy({
    required String feeAssetSymbol,
    required BigInt gasLimit,
    required BigInt gasPriceWei,
    FeeSpeed speed = FeeSpeed.standard,
    List<FeeOption> options = const [],
  }) {
    final fee = gasLimit * gasPriceWei;
    return FeeEstimate._(
      model: FeeModel.legacy,
      feeInBaseUnits: fee,
      estimatedFeeInBaseUnits: fee,
      feeAssetSymbol: feeAssetSymbol,
      speed: speed,
      options: options.isEmpty
          ? [
              FeeOption(
                speed: speed,
                feeInBaseUnits: fee,
                estimatedFeeInBaseUnits: fee,
                gasLimit: gasLimit,
                gasPriceWei: gasPriceWei,
              ),
            ]
          : List.unmodifiable(options),
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
    );
  }

  factory FeeEstimate.solana({
    required String feeAssetSymbol,
    required BigInt lamports,
    required String recentBlockhash,
    FeeSpeed speed = FeeSpeed.standard,
    List<FeeOption> options = const [],
    int? computeUnitLimit,
    BigInt? microLamportsPerComputeUnit,
    BigInt? priorityFeeLamports,
  }) {
    final priorityFee = priorityFeeLamports ?? BigInt.zero;
    final totalFee = lamports + priorityFee;
    return FeeEstimate._(
      model: FeeModel.solana,
      feeInBaseUnits: totalFee,
      estimatedFeeInBaseUnits: totalFee,
      feeAssetSymbol: feeAssetSymbol,
      speed: speed,
      options: options.isEmpty
          ? [
              FeeOption(
                speed: speed,
                feeInBaseUnits: totalFee,
                estimatedFeeInBaseUnits: totalFee,
                baseFeeInBaseUnits: lamports,
                priorityFeeInBaseUnits: priorityFee,
                computeUnitLimit: computeUnitLimit,
                microLamportsPerComputeUnit: microLamportsPerComputeUnit,
              ),
            ]
          : List.unmodifiable(options),
      recentBlockhash: recentBlockhash,
      baseFeeInBaseUnits: lamports,
      priorityFeeInBaseUnits: priorityFee,
      computeUnitLimit: computeUnitLimit,
      microLamportsPerComputeUnit: microLamportsPerComputeUnit,
    );
  }

  factory FeeEstimate.bitcoin({
    required String feeAssetSymbol,
    required BigInt satoshis,
    FeeSpeed speed = FeeSpeed.standard,
    List<FeeOption> options = const [],
    double? satsPerVbyte,
    int? transactionVbytes,
    int? confirmationBlocks,
  }) {
    return FeeEstimate._(
      model: FeeModel.bitcoin,
      feeInBaseUnits: satoshis,
      estimatedFeeInBaseUnits: satoshis,
      feeAssetSymbol: feeAssetSymbol,
      speed: speed,
      options: options.isEmpty
          ? [
              FeeOption(
                speed: speed,
                feeInBaseUnits: satoshis,
                estimatedFeeInBaseUnits: satoshis,
                satsPerVbyte: satsPerVbyte,
                transactionVbytes: transactionVbytes,
                confirmationBlocks: confirmationBlocks,
              ),
            ]
          : List.unmodifiable(options),
      satsPerVbyte: satsPerVbyte,
      transactionVbytes: transactionVbytes,
      confirmationBlocks: confirmationBlocks,
    );
  }

  factory FeeEstimate.tron({
    required String feeAssetSymbol,
    required BigInt sun,
    BigInt? feeLimitSun,
  }) {
    return FeeEstimate._(
      model: FeeModel.tron,
      feeInBaseUnits: sun,
      estimatedFeeInBaseUnits: sun,
      feeAssetSymbol: feeAssetSymbol,
      options: [
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: sun,
          estimatedFeeInBaseUnits: sun,
          feeLimitSun: feeLimitSun,
        ),
      ],
      feeLimitSun: feeLimitSun,
    );
  }

  factory FeeEstimate.sui({
    required String feeAssetSymbol,
    required BigInt estimatedFeeMist,
    required BigInt gasBudgetMist,
  }) {
    return FeeEstimate._(
      model: FeeModel.sui,
      feeInBaseUnits: gasBudgetMist,
      estimatedFeeInBaseUnits: estimatedFeeMist,
      feeAssetSymbol: feeAssetSymbol,
      options: [
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: gasBudgetMist,
          estimatedFeeInBaseUnits: estimatedFeeMist,
          gasBudgetMist: gasBudgetMist,
        ),
      ],
      gasBudgetMist: gasBudgetMist,
    );
  }

  final FeeModel model;
  final BigInt feeInBaseUnits;
  final BigInt estimatedFeeInBaseUnits;
  final String feeAssetSymbol;
  final FeeSpeed speed;
  final List<FeeOption> options;
  final BigInt? gasLimit;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final BigInt? gasPriceWei;
  final BigInt? baseFeePerGasWei;
  final String? recentBlockhash;
  final BigInt? baseFeeInBaseUnits;
  final BigInt? priorityFeeInBaseUnits;
  final int? computeUnitLimit;
  final BigInt? microLamportsPerComputeUnit;
  final double? satsPerVbyte;
  final int? transactionVbytes;
  final BigInt? feeLimitSun;
  final BigInt? gasBudgetMist;
  final int? confirmationBlocks;

  FeeEstimate selectSpeed(FeeSpeed speed) {
    final option = options.firstWhere(
      (candidate) => candidate.speed == speed,
      orElse: () => throw ArgumentError.value(speed, 'speed', 'not available'),
    );
    return FeeEstimate._(
      model: model,
      feeInBaseUnits: option.feeInBaseUnits,
      estimatedFeeInBaseUnits:
          option.estimatedFeeInBaseUnits ?? option.feeInBaseUnits,
      feeAssetSymbol: feeAssetSymbol,
      speed: option.speed,
      options: options,
      gasLimit: option.gasLimit,
      maxFeePerGasWei: option.maxFeePerGasWei,
      maxPriorityFeePerGasWei: option.maxPriorityFeePerGasWei,
      gasPriceWei: option.gasPriceWei,
      baseFeePerGasWei: baseFeePerGasWei,
      recentBlockhash: recentBlockhash,
      baseFeeInBaseUnits: option.baseFeeInBaseUnits,
      priorityFeeInBaseUnits: option.priorityFeeInBaseUnits,
      computeUnitLimit: option.computeUnitLimit,
      microLamportsPerComputeUnit: option.microLamportsPerComputeUnit,
      satsPerVbyte: option.satsPerVbyte,
      transactionVbytes: option.transactionVbytes,
      feeLimitSun: option.feeLimitSun,
      gasBudgetMist: option.gasBudgetMist,
      confirmationBlocks: option.confirmationBlocks,
    );
  }

  FeeEstimate withEvmCustomFee({
    required BigInt maxFeePerGasWei,
    required BigInt maxPriorityFeePerGasWei,
  }) {
    if (model != FeeModel.eip1559) {
      throw StateError('Custom EIP-1559 fee requires an EIP-1559 estimate');
    }
    if (maxFeePerGasWei <= BigInt.zero ||
        maxPriorityFeePerGasWei < BigInt.zero ||
        maxFeePerGasWei < maxPriorityFeePerGasWei) {
      throw ArgumentError('Invalid EIP-1559 fee values');
    }
    return FeeEstimate._(
      model: model,
      feeInBaseUnits: gasLimit! * maxFeePerGasWei,
      estimatedFeeInBaseUnits: _eip1559EstimatedFee(
        gasLimit: gasLimit!,
        maxFeePerGasWei: maxFeePerGasWei,
        baseFeePerGasWei: baseFeePerGasWei,
        priorityFeePerGasWei: maxPriorityFeePerGasWei,
      ),
      feeAssetSymbol: feeAssetSymbol,
      speed: FeeSpeed.custom,
      options: options,
      gasLimit: gasLimit,
      maxFeePerGasWei: maxFeePerGasWei,
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
      baseFeePerGasWei: baseFeePerGasWei,
    );
  }

  FeeEstimate withLegacyCustomGasPrice({required BigInt gasPriceWei}) {
    if (model != FeeModel.legacy) {
      throw StateError('Custom gas price requires a legacy estimate');
    }
    if (gasPriceWei <= BigInt.zero) {
      throw ArgumentError('Gas price must be positive');
    }
    return FeeEstimate._(
      model: model,
      feeInBaseUnits: gasLimit! * gasPriceWei,
      estimatedFeeInBaseUnits: gasLimit! * gasPriceWei,
      feeAssetSymbol: feeAssetSymbol,
      speed: FeeSpeed.custom,
      options: options,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      baseFeePerGasWei: baseFeePerGasWei,
    );
  }

  FeeEstimate withSolanaCustomPriorityFee({
    required BigInt totalPriorityFeeLamports,
    required int computeUnitLimit,
  }) {
    if (model != FeeModel.solana) {
      throw StateError('Custom priority fee requires a Solana estimate');
    }
    if (totalPriorityFeeLamports < BigInt.zero || computeUnitLimit <= 0) {
      throw ArgumentError('Invalid Solana priority fee values');
    }
    final limit = BigInt.from(computeUnitLimit);
    final microLamports =
        (totalPriorityFeeLamports * BigInt.from(1000000) +
            limit -
            BigInt.one) ~/
        limit;
    final actualPriorityFee =
        (microLamports * limit + BigInt.from(999999)) ~/ BigInt.from(1000000);
    final baseFee = baseFeeInBaseUnits ?? feeInBaseUnits;
    return FeeEstimate._(
      model: model,
      feeInBaseUnits: baseFee + actualPriorityFee,
      estimatedFeeInBaseUnits: baseFee + actualPriorityFee,
      feeAssetSymbol: feeAssetSymbol,
      speed: FeeSpeed.custom,
      options: options,
      recentBlockhash: recentBlockhash,
      baseFeeInBaseUnits: baseFee,
      priorityFeeInBaseUnits: actualPriorityFee,
      computeUnitLimit: computeUnitLimit,
      microLamportsPerComputeUnit: microLamports,
    );
  }

  FeeEstimate withBitcoinCustomFeeRate({
    required double satsPerVbyte,
    required int transactionVbytes,
  }) {
    if (model != FeeModel.bitcoin) {
      throw StateError('Custom sat/vB requires a Bitcoin estimate');
    }
    if (!satsPerVbyte.isFinite || satsPerVbyte <= 0 || transactionVbytes <= 0) {
      throw ArgumentError('Invalid Bitcoin fee rate');
    }
    return FeeEstimate._(
      model: model,
      feeInBaseUnits: BigInt.from((satsPerVbyte * transactionVbytes).ceil()),
      estimatedFeeInBaseUnits: BigInt.from(
        (satsPerVbyte * transactionVbytes).ceil(),
      ),
      feeAssetSymbol: feeAssetSymbol,
      speed: FeeSpeed.custom,
      options: options,
      satsPerVbyte: satsPerVbyte,
      transactionVbytes: transactionVbytes,
      confirmationBlocks: _nearestBitcoinConfirmationBlocks(satsPerVbyte),
    );
  }

  FeeEstimate withTronFeeLimit({required BigInt feeLimitSun}) {
    if (model != FeeModel.tron) {
      throw StateError('TRX fee limit requires a Tron estimate');
    }
    if (feeLimitSun <= BigInt.zero) {
      throw ArgumentError('TRX fee limit must be positive');
    }
    return FeeEstimate._(
      model: model,
      feeInBaseUnits: feeInBaseUnits,
      estimatedFeeInBaseUnits: estimatedFeeInBaseUnits,
      feeAssetSymbol: feeAssetSymbol,
      speed: FeeSpeed.custom,
      options: options,
      feeLimitSun: feeLimitSun,
    );
  }

  int? _nearestBitcoinConfirmationBlocks(double rate) {
    final candidates = options
        .where(
          (option) =>
              option.satsPerVbyte != null && option.confirmationBlocks != null,
        )
        .toList();
    if (candidates.isEmpty) {
      return confirmationBlocks;
    }
    candidates.sort((left, right) {
      final leftDistance = (left.satsPerVbyte! - rate).abs();
      final rightDistance = (right.satsPerVbyte! - rate).abs();
      return leftDistance.compareTo(rightDistance);
    });
    return candidates.first.confirmationBlocks;
  }
}

BigInt _eip1559EstimatedFee({
  required BigInt gasLimit,
  required BigInt maxFeePerGasWei,
  required BigInt? baseFeePerGasWei,
  required BigInt priorityFeePerGasWei,
}) {
  if (baseFeePerGasWei == null) {
    return gasLimit * maxFeePerGasWei;
  }
  final expectedRate = baseFeePerGasWei + priorityFeePerGasWei;
  final cappedRate = expectedRate > maxFeePerGasWei
      ? maxFeePerGasWei
      : expectedRate;
  return gasLimit * cappedRate;
}

final class FeeEstimateRequest {
  const FeeEstimateRequest({
    required this.chain,
    required this.rpcNode,
    required this.fromAddress,
    required this.request,
    this.isMaxTransfer = false,
  });

  final ChainConfig chain;
  final RpcNode rpcNode;
  final String fromAddress;
  final TransactionRequest request;
  final bool isMaxTransfer;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FeeEstimateRequest &&
            other.chain == chain &&
            other.rpcNode == rpcNode &&
            other.fromAddress == fromAddress &&
            other.request == request &&
            other.isMaxTransfer == isMaxTransfer;
  }

  @override
  int get hashCode =>
      Object.hash(chain, rpcNode, fromAddress, request, isMaxTransfer);
}

Future<FeeEstimate> _estimateEvmFee(Ref ref, FeeEstimateRequest request) async {
  final estimate = await ref
      .read(evmFeeServiceProvider)
      .estimateTransferFee(
        rpcUrl: request.rpcNode.endpointUrl,
        fromAddress: request.fromAddress,
        toAddress: request.request.toAddress,
        transactionType: request.request.transactionType,
        amountInWei: _amountInBaseUnits(request.request),
        tokenContractAddress: request.request.tokenContractAddress,
        headers: request.rpcNode.endpointHeaders,
      );
  return switch (estimate.model) {
    EvmFeeModel.eip1559 => FeeEstimate.eip1559(
      feeAssetSymbol: request.chain.symbol,
      gasLimit: estimate.gasLimit,
      maxFeePerGasWei: estimate.maxFeePerGasWei!,
      maxPriorityFeePerGasWei: estimate.maxPriorityFeePerGasWei!,
      baseFeePerGasWei: estimate.baseFeePerGasWei,
      options: _eip1559Options(estimate),
    ),
    EvmFeeModel.legacy => FeeEstimate.legacy(
      feeAssetSymbol: request.chain.symbol,
      gasLimit: estimate.gasLimit,
      gasPriceWei: estimate.gasPriceWei!,
      options: _legacyOptions(estimate),
    ),
  };
}

List<FeeOption> _eip1559Options(EvmFeeEstimate estimate) {
  final baseFee = estimate.baseFeePerGasWei;
  final priorities = estimate.priorityFeeOptionsWei;
  if (baseFee == null || priorities.length != 3) {
    return const [];
  }
  return List.generate(3, (index) {
    final priority = priorities[index];
    final maxFee = baseFee * BigInt.two + priority;
    return FeeOption(
      speed: FeeSpeed.values[index],
      feeInBaseUnits: estimate.gasLimit * maxFee,
      estimatedFeeInBaseUnits: estimate.gasLimit * (baseFee + priority),
      gasLimit: estimate.gasLimit,
      maxFeePerGasWei: maxFee,
      maxPriorityFeePerGasWei: priority,
      baseFeePerGasWei: baseFee,
    );
  });
}

List<FeeOption> _legacyOptions(EvmFeeEstimate estimate) {
  final prices = estimate.gasPriceOptionsWei;
  if (prices.length != 3) {
    return const [];
  }
  return List.generate(3, (index) {
    final price = prices[index];
    return FeeOption(
      speed: FeeSpeed.values[index],
      feeInBaseUnits: estimate.gasLimit * price,
      gasLimit: estimate.gasLimit,
      gasPriceWei: price,
    );
  });
}

Future<FeeEstimate> _estimateSolanaFee(
  Ref ref,
  FeeEstimateRequest request,
) async {
  final estimate = await ref
      .read(solanaFeeServiceProvider)
      .estimateSolTransferFee(
        rpcUrl: request.rpcNode.endpointUrl,
        fromAddress: request.fromAddress,
        toAddress: request.request.toAddress,
        lamports: _amountInBaseUnits(request.request),
        headers: request.rpcNode.endpointHeaders,
      );
  return FeeEstimate.solana(
    feeAssetSymbol: request.chain.symbol,
    lamports: estimate.lamports,
    recentBlockhash: estimate.recentBlockhash,
    computeUnitLimit: estimate.computeUnitLimit,
    microLamportsPerComputeUnit:
        estimate.priorityFeeOptionsMicroLamports.length == 3
        ? estimate.priorityFeeOptionsMicroLamports[1]
        : null,
    priorityFeeLamports: _solanaPriorityFee(
      estimate.computeUnitLimit,
      estimate.priorityFeeOptionsMicroLamports.length == 3
          ? estimate.priorityFeeOptionsMicroLamports[1]
          : null,
    ),
    options: _solanaOptions(estimate),
  );
}

List<FeeOption> _solanaOptions(SolanaFeeEstimate estimate) {
  final limit = estimate.computeUnitLimit;
  final prices = estimate.priorityFeeOptionsMicroLamports;
  if (limit == null || prices.length != 3) {
    return const [];
  }
  return List.generate(3, (index) {
    final priority = _solanaPriorityFee(limit, prices[index])!;
    return FeeOption(
      speed: FeeSpeed.values[index],
      feeInBaseUnits: estimate.lamports + priority,
      baseFeeInBaseUnits: estimate.lamports,
      priorityFeeInBaseUnits: priority,
      computeUnitLimit: limit,
      microLamportsPerComputeUnit: prices[index],
    );
  });
}

BigInt? _solanaPriorityFee(int? limit, BigInt? microLamports) {
  if (limit == null || microLamports == null) {
    return null;
  }
  return (BigInt.from(limit) * microLamports + BigInt.from(999999)) ~/
      BigInt.from(1000000);
}

Future<FeeEstimate> _estimateBitcoinFee(
  Ref ref,
  FeeEstimateRequest request,
) async {
  if (!_isBitcoinAddressForChain(request.fromAddress, request.chain) ||
      !_isBitcoinAddressForChain(request.request.toAddress, request.chain)) {
    throw StateError('Bitcoin address network does not match chain');
  }
  final estimate = await ref
      .read(bitcoinFeeServiceProvider)
      .estimateTransferFee(
        apiBaseUrl: request.rpcNode.endpointUrl,
        fromAddress: request.fromAddress,
        toAddress: request.request.toAddress,
        satoshis: _amountInBaseUnits(request.request),
        sweep: request.isMaxTransfer,
      );
  return FeeEstimate.bitcoin(
    feeAssetSymbol: request.chain.symbol,
    satoshis: estimate.satoshis,
    satsPerVbyte: estimate.satsPerVbyte,
    transactionVbytes: estimate.transactionVbytes,
    confirmationBlocks:
        estimate.confirmationBlocks ??
        (estimate.confirmationBlockOptions.length == 3
            ? estimate.confirmationBlockOptions[1]
            : null),
    options: _bitcoinOptions(estimate),
  );
}

List<FeeOption> _bitcoinOptions(BitcoinFeeEstimate estimate) {
  final rates = estimate.feeRateOptions;
  final sizes = estimate.transactionVbytesOptions.length == 3
      ? estimate.transactionVbytesOptions
      : estimate.transactionVbytes == null
      ? const <int>[]
      : List<int>.filled(3, estimate.transactionVbytes!);
  if (rates.length != 3 || sizes.length != 3) {
    return const [];
  }
  return List.generate(3, (index) {
    final fee = estimate.feeOptionsSatoshis.length == 3
        ? estimate.feeOptionsSatoshis[index]
        : BigInt.from((rates[index] * sizes[index]).ceil());
    return FeeOption(
      speed: FeeSpeed.values[index],
      feeInBaseUnits: fee,
      satsPerVbyte: rates[index],
      transactionVbytes: sizes[index],
      confirmationBlocks: estimate.confirmationBlockOptions.length == 3
          ? estimate.confirmationBlockOptions[index]
          : null,
    );
  });
}

Future<FeeEstimate> _estimateTronFee(
  Ref ref,
  FeeEstimateRequest request,
) async {
  final estimate = await ref
      .read(tronFeeServiceProvider)
      .estimateTransferFee(
        apiBaseUrl: request.rpcNode.endpointUrl,
        fromAddress: request.fromAddress,
        toAddress: request.request.toAddress,
        sun: _amountInBaseUnits(request.request),
        transactionType: request.request.transactionType,
        tokenContractAddress: request.request.tokenContractAddress,
        headers: request.rpcNode.endpointHeaders,
      );
  return FeeEstimate.tron(
    feeAssetSymbol: request.chain.symbol,
    sun: estimate.sun,
    feeLimitSun: estimate.recommendedFeeLimitSun,
  );
}

Future<FeeEstimate> _estimateSuiFee(Ref ref, FeeEstimateRequest request) async {
  final estimate = await ref
      .read(suiTransactionServiceProvider)
      .estimateTransferFee(
        SuiTransferInput(
          rpcUrl: request.rpcNode.endpointUrl,
          fromAddress: request.fromAddress,
          transaction: request.request,
          headers: request.rpcNode.endpointHeaders,
        ),
      );
  return FeeEstimate.sui(
    feeAssetSymbol: request.chain.symbol,
    estimatedFeeMist: estimate.estimatedFeeMist,
    gasBudgetMist: estimate.gasBudgetMist,
  );
}

bool _isBitcoinAddressForChain(String address, ChainConfig chain) {
  return isBitcoinAddressForNetwork(address, isTestnet: chain.isTestnet);
}

BigInt _amountInBaseUnits(TransactionRequest request) {
  final amount = request.amountInBaseUnits;
  if (amount == null) {
    throw ArgumentError.value(amount, 'amountInBaseUnits', 'must not be null');
  }
  return BigInt.parse(amount);
}
