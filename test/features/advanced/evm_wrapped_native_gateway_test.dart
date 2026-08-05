import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/data/evm_wrapped_native_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/wrapped_native_models.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';

void main() {
  final config = wrappedNativeConfigFor(
    defaultChains.firstWhere((chain) => chain.chainId == '1'),
  )!;
  const from = '0x1563915e194D8CfBA1943570603F7606A3115508';
  const privateKey =
      '0x4f3edf983ac63ad7c19c5878a1f4c8f365f46b29a6606658049c3d7ad4a3d0a1';

  test('loads native and wrapped balances from the trusted contract', () async {
    final rpc = _FakeEvmWrappedNativeRpc(
      nativeBalance: BigInt.from(10),
      wrappedBalance: BigInt.from(4),
    );
    final gateway = DefaultEvmWrappedNativeGateway(rpcFactory: (_, _) => rpc);

    final balances = await gateway.loadBalances(
      rpcUrl: 'https://rpc.example.com',
      fromAddress: from,
      config: config,
    );

    expect(balances.nativeBalance, BigInt.from(10));
    expect(balances.wrappedBalance, BigInt.from(4));
    expect(rpc.lastContractAddress, config.wrappedAssetAddress);
  });

  test('prepares EIP-1559 wrap after simulation with a gas buffer', () async {
    final rpc = _FakeEvmWrappedNativeRpc(
      baseFeePerGas: BigInt.from(20),
      priorityFees: [BigInt.one, BigInt.two, BigInt.from(3)],
      estimatedGas: BigInt.from(30000),
    );
    final gateway = DefaultEvmWrappedNativeGateway(rpcFactory: (_, _) => rpc);

    final preparation = await gateway.prepare(
      rpcUrl: 'https://rpc.example.com',
      fromAddress: from,
      config: config,
      operation: WrappedNativeOperation.wrap,
      amountInBaseUnits: BigInt.from(123),
    );

    expect(preparation.feeModel, EvmWrappedNativeFeeModel.eip1559);
    expect(preparation.gasLimit, BigInt.from(33000));
    expect(preparation.maxPriorityFeePerGasWei, BigInt.two);
    expect(preparation.maxFeePerGasWei, BigInt.from(42));
    expect(preparation.maximumFeeWei, BigInt.from(33000 * 42));
    expect(rpc.simulatedCall?.calldata, '0xd0e30db0');
    expect(rpc.simulatedCall?.valueWei, BigInt.from(123));
  });

  test('falls back to legacy gas when the node has no base fee', () async {
    final rpc = _FakeEvmWrappedNativeRpc(
      gasPrice: BigInt.from(7),
      estimatedGas: BigInt.from(21000),
    );
    final gateway = DefaultEvmWrappedNativeGateway(rpcFactory: (_, _) => rpc);

    final preparation = await gateway.prepare(
      rpcUrl: 'https://rpc.example.com',
      fromAddress: from,
      config: config,
      operation: WrappedNativeOperation.unwrap,
      amountInBaseUnits: BigInt.one,
    );

    expect(preparation.feeModel, EvmWrappedNativeFeeModel.legacy);
    expect(preparation.gasPriceWei, BigInt.from(7));
    expect(preparation.gasLimit, BigInt.from(23100));
    expect(preparation.maximumFeeWei, BigInt.from(23100 * 7));
  });

  test('submit fetches a fresh pending nonce and broadcasts once', () async {
    final rpc = _FakeEvmWrappedNativeRpc(
      pendingNonce: 9,
      transactionHash: '0xhash',
    );
    final gateway = DefaultEvmWrappedNativeGateway(rpcFactory: (_, _) => rpc);
    final preparation = EvmWrappedNativePreparation(
      call: buildEvmWrappedNativeCall(
        config: config,
        operation: WrappedNativeOperation.wrap,
        amountInBaseUnits: BigInt.one,
      ),
      feeModel: EvmWrappedNativeFeeModel.legacy,
      gasLimit: BigInt.from(30000),
      gasPriceWei: BigInt.from(7),
    );

    final hash = await gateway.submit(
      rpcUrl: 'https://rpc.example.com',
      chainId: 1,
      fromAddress: from,
      privateKey: privateKey,
      preparation: preparation,
    );

    expect(hash, '0xhash');
    expect(rpc.pendingNonceCalls, 1);
    expect(rpc.sentNonces, [9]);
  });

  test('submit keeps the RPC open until broadcasting completes', () async {
    final sendCompleter = Completer<String>();
    final rpc = _FakeEvmWrappedNativeRpc(
      pendingNonce: 9,
      sendCompleter: sendCompleter,
    );
    final gateway = DefaultEvmWrappedNativeGateway(rpcFactory: (_, _) => rpc);
    final preparation = EvmWrappedNativePreparation(
      call: buildEvmWrappedNativeCall(
        config: config,
        operation: WrappedNativeOperation.unwrap,
        amountInBaseUnits: BigInt.one,
      ),
      feeModel: EvmWrappedNativeFeeModel.legacy,
      gasLimit: BigInt.from(30000),
      gasPriceWei: BigInt.from(7),
    );

    final result = gateway.submit(
      rpcUrl: 'https://rpc.example.com',
      chainId: 56,
      fromAddress: from,
      privateKey: privateKey,
      preparation: preparation,
    );
    await Future<void>.delayed(Duration.zero);

    expect(rpc.sentNonces, [9]);
    expect(rpc.closeCalls, 0);

    sendCompleter.complete('0xhash');
    expect(await result, '0xhash');
    expect(rpc.closeCalls, 1);
  });
}

final class _FakeEvmWrappedNativeRpc implements EvmWrappedNativeRpc {
  _FakeEvmWrappedNativeRpc({
    BigInt? nativeBalance,
    BigInt? wrappedBalance,
    this.baseFeePerGas,
    this.priorityFees = const [],
    BigInt? gasPrice,
    BigInt? estimatedGas,
    this.pendingNonce = 0,
    this.transactionHash = '0xhash',
    this.sendCompleter,
  }) : nativeBalance = nativeBalance ?? BigInt.zero,
       wrappedBalance = wrappedBalance ?? BigInt.zero,
       gasPrice = gasPrice ?? BigInt.zero,
       estimatedGas = estimatedGas ?? BigInt.zero;

  final BigInt nativeBalance;
  final BigInt wrappedBalance;
  final BigInt? baseFeePerGas;
  final List<BigInt> priorityFees;
  final BigInt gasPrice;
  final BigInt estimatedGas;
  final int pendingNonce;
  final String transactionHash;
  final Completer<String>? sendCompleter;

  String? lastContractAddress;
  EvmWrappedNativeCall? simulatedCall;
  int pendingNonceCalls = 0;
  int closeCalls = 0;
  final sentNonces = <int>[];

  @override
  Future<void> close() async {
    closeCalls += 1;
  }

  @override
  Future<BigInt?> getBaseFeePerGas() async => baseFeePerGas;

  @override
  Future<BigInt> getGasPrice() async => gasPrice;

  @override
  Future<BigInt> getNativeBalance(String address) async => nativeBalance;

  @override
  Future<int> getPendingNonce(String address) async {
    pendingNonceCalls += 1;
    return pendingNonce;
  }

  @override
  Future<List<BigInt>> getPriorityFeeOptions() async => priorityFees;

  @override
  Future<BigInt> getWrappedBalance({
    required String ownerAddress,
    required String contractAddress,
  }) async {
    lastContractAddress = contractAddress;
    return wrappedBalance;
  }

  @override
  Future<bool> hasContractCode(String contractAddress) async => true;

  @override
  Future<void> simulate({
    required String fromAddress,
    required EvmWrappedNativeCall call,
  }) async {
    simulatedCall = call;
  }

  @override
  Future<BigInt> estimateGas({
    required String fromAddress,
    required EvmWrappedNativeCall call,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
  }) async {
    return estimatedGas;
  }

  @override
  Future<String> send({
    required int chainId,
    required String privateKey,
    required String fromAddress,
    required EvmWrappedNativePreparation preparation,
    required int nonce,
  }) async {
    sentNonces.add(nonce);
    return sendCompleter?.future ?? transactionHash;
  }
}
