import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';

void main() {
  test('new fee estimate selects the standard speed by default', () {
    dynamic estimate = FeeEstimate.eip1559(
      feeAssetSymbol: 'ETH',
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    );

    expect(estimate.speed.toString(), 'FeeSpeed.standard');
    expect(estimate.options, hasLength(1));
    expect(estimate.options.single.speed, FeeSpeed.standard);
  });

  test('EIP-1559 custom fee uses Gwei values and recalculates maximum fee', () {
    dynamic estimate = FeeEstimate.eip1559(
      feeAssetSymbol: 'ETH',
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30) * BigInt.from(1000000000),
      maxPriorityFeePerGasWei: BigInt.from(2) * BigInt.from(1000000000),
    );

    final FeeEstimate custom = estimate.withEvmCustomFee(
      maxFeePerGasWei: BigInt.from(40) * BigInt.from(1000000000),
      maxPriorityFeePerGasWei: BigInt.from(3) * BigInt.from(1000000000),
    );

    expect(custom.speed, FeeSpeed.custom);
    expect(custom.feeInBaseUnits, BigInt.from(840000000000000));
    expect(custom.maxPriorityFeePerGasWei, BigInt.from(3000000000));
  });

  test('EIP-1559 custom fee rejects max fee below priority fee', () {
    dynamic estimate = FeeEstimate.eip1559(
      feeAssetSymbol: 'ETH',
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    );

    expect(
      () => estimate.withEvmCustomFee(
        maxFeePerGasWei: BigInt.one,
        maxPriorityFeePerGasWei: BigInt.two,
      ),
      throwsArgumentError,
    );
  });

  test('Solana custom total priority fee converts to micro-lamports per CU',
      () {
    dynamic estimate = FeeEstimate.solana(
      feeAssetSymbol: 'SOL',
      lamports: BigInt.from(5000),
      recentBlockhash: 'blockhash',
    );

    final FeeEstimate custom = estimate.withSolanaCustomPriorityFee(
      totalPriorityFeeLamports: BigInt.from(10000),
      computeUnitLimit: 220000,
    );

    expect(custom.speed, FeeSpeed.custom);
    expect(custom.computeUnitLimit, 220000);
    expect(custom.microLamportsPerComputeUnit, BigInt.from(45455));
    expect(custom.priorityFeeInBaseUnits, BigInt.from(10001));
    expect(custom.feeInBaseUnits, BigInt.from(15001));
  });

  test('Bitcoin custom sat/vB recalculates the transaction fee', () {
    dynamic estimate = FeeEstimate.bitcoin(
      feeAssetSymbol: 'BTC',
      satoshis: BigInt.from(1410),
    );

    final FeeEstimate custom = estimate.withBitcoinCustomFeeRate(
      satsPerVbyte: 12.5,
      transactionVbytes: 141,
    );

    expect(custom.speed, FeeSpeed.custom);
    expect(custom.satsPerVbyte, 12.5);
    expect(custom.transactionVbytes, 141);
    expect(custom.feeInBaseUnits, BigInt.from(1763));
  });

  test('Tron custom cap does not pretend to change the estimated fee', () {
    dynamic estimate = FeeEstimate.tron(
      feeAssetSymbol: 'TRX',
      sun: BigInt.from(633000),
    );

    final FeeEstimate custom = estimate.withTronFeeLimit(
      feeLimitSun: BigInt.from(30000000),
    );

    expect(custom.speed, FeeSpeed.custom);
    expect(custom.feeLimitSun, BigInt.from(30000000));
    expect(custom.feeInBaseUnits, BigInt.from(633000));
  });

  test('selecting a preset replaces all chain fee parameters together', () {
    dynamic estimate = FeeEstimate.eip1559(
      feeAssetSymbol: 'ETH',
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
      options: [
        FeeOption(
          speed: FeeSpeed.economy,
          feeInBaseUnits: BigInt.from(420000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(20),
          maxPriorityFeePerGasWei: BigInt.one,
        ),
        FeeOption(
          speed: FeeSpeed.standard,
          feeInBaseUnits: BigInt.from(630000),
          gasLimit: BigInt.from(21000),
          maxFeePerGasWei: BigInt.from(30),
          maxPriorityFeePerGasWei: BigInt.two,
        ),
      ],
    );

    final FeeEstimate economy = estimate.selectSpeed(FeeSpeed.economy);

    expect(economy.speed, FeeSpeed.economy);
    expect(economy.maxFeePerGasWei, BigInt.from(20));
    expect(economy.maxPriorityFeePerGasWei, BigInt.one);
    expect(economy.feeInBaseUnits, BigInt.from(420000));
  });

  test('legacy custom gas price recalculates maximum fee', () {
    dynamic estimate = FeeEstimate.legacy(
      feeAssetSymbol: 'BNB',
      gasLimit: BigInt.from(21000),
      gasPriceWei: BigInt.from(3),
    );

    final FeeEstimate custom = estimate.withLegacyCustomGasPrice(
      gasPriceWei: BigInt.from(5),
    );

    expect(custom.speed, FeeSpeed.custom);
    expect(custom.gasPriceWei, BigInt.from(5));
    expect(custom.feeInBaseUnits, BigInt.from(105000));
  });

  test('EIP-1559 distinguishes expected charge from maximum charge', () {
    dynamic estimate = FeeEstimate.eip1559(
      feeAssetSymbol: 'ETH',
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
      baseFeePerGasWei: BigInt.from(10),
    );

    expect(estimate.estimatedFeeInBaseUnits, BigInt.from(252000));
    expect(estimate.feeInBaseUnits, BigInt.from(630000));
  });

  test('low EIP-1559 custom cap never shows an estimate above its maximum', () {
    final estimate = FeeEstimate.eip1559(
      feeAssetSymbol: 'ETH',
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.two,
      baseFeePerGasWei: BigInt.from(20),
    );

    final custom = estimate.withEvmCustomFee(
      maxFeePerGasWei: BigInt.from(21),
      maxPriorityFeePerGasWei: BigInt.two,
    );

    expect(custom.estimatedFeeInBaseUnits, BigInt.from(441000));
    expect(custom.feeInBaseUnits, BigInt.from(441000));
  });
}
