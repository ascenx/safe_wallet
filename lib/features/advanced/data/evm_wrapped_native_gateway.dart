import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/bounded_http_client.dart';
import '../domain/wrapped_native_models.dart';

typedef EvmWrappedNativeRpcFactory =
    EvmWrappedNativeRpc Function(String rpcUrl, Map<String, String> headers);

enum EvmWrappedNativeFeeModel { eip1559, legacy }

final class EvmWrappedNativeBalances {
  const EvmWrappedNativeBalances({
    required this.nativeBalance,
    required this.wrappedBalance,
  });

  final BigInt nativeBalance;
  final BigInt wrappedBalance;
}

final class EvmWrappedNativePreparation {
  const EvmWrappedNativePreparation({
    required this.call,
    required this.feeModel,
    required this.gasLimit,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.gasPriceWei,
  });

  final EvmWrappedNativeCall call;
  final EvmWrappedNativeFeeModel feeModel;
  final BigInt gasLimit;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final BigInt? gasPriceWei;

  BigInt get maximumFeeWei => switch (feeModel) {
    EvmWrappedNativeFeeModel.eip1559 => gasLimit * maxFeePerGasWei!,
    EvmWrappedNativeFeeModel.legacy => gasLimit * gasPriceWei!,
  };
}

abstract interface class EvmWrappedNativeGateway {
  Future<EvmWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    Map<String, String> headers = const {},
  });

  Future<EvmWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    required WrappedNativeOperation operation,
    required BigInt amountInBaseUnits,
    Map<String, String> headers = const {},
  });

  Future<String> submit({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String privateKey,
    required EvmWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  });
}

final class DefaultEvmWrappedNativeGateway implements EvmWrappedNativeGateway {
  DefaultEvmWrappedNativeGateway({EvmWrappedNativeRpcFactory? rpcFactory})
    : _rpcFactory = rpcFactory ?? _defaultRpcFactory;

  final EvmWrappedNativeRpcFactory _rpcFactory;

  @override
  Future<EvmWrappedNativeBalances> loadBalances({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    Map<String, String> headers = const {},
  }) async {
    final rpc = _rpcFactory(rpcUrl, headers);
    try {
      final balances = await Future.wait([
        rpc.getNativeBalance(fromAddress),
        rpc.getWrappedBalance(
          ownerAddress: fromAddress,
          contractAddress: config.wrappedAssetAddress,
        ),
      ]);
      return EvmWrappedNativeBalances(
        nativeBalance: balances[0],
        wrappedBalance: balances[1],
      );
    } finally {
      await rpc.close();
    }
  }

  @override
  Future<EvmWrappedNativePreparation> prepare({
    required String rpcUrl,
    required String fromAddress,
    required WrappedNativeConfig config,
    required WrappedNativeOperation operation,
    required BigInt amountInBaseUnits,
    Map<String, String> headers = const {},
  }) async {
    final rpc = _rpcFactory(rpcUrl, headers);
    try {
      if (!await rpc.hasContractCode(config.wrappedAssetAddress)) {
        throw StateError('wrapped_native_contract_missing');
      }
      final call = buildEvmWrappedNativeCall(
        config: config,
        operation: operation,
        amountInBaseUnits: amountInBaseUnits,
      );
      await rpc.simulate(fromAddress: fromAddress, call: call);
      final baseFee = await rpc.getBaseFeePerGas();
      if (baseFee != null) {
        final priorityOptions = await rpc.getPriorityFeeOptions();
        final priority = priorityOptions.isEmpty
            ? _defaultPriorityFeeWei
            : priorityOptions[priorityOptions.length ~/ 2];
        final maxFee = baseFee * BigInt.two + priority;
        final gas = await rpc.estimateGas(
          fromAddress: fromAddress,
          call: call,
          maxFeePerGasWei: maxFee,
          maxPriorityFeePerGasWei: priority,
        );
        return EvmWrappedNativePreparation(
          call: call,
          feeModel: EvmWrappedNativeFeeModel.eip1559,
          gasLimit: _withGasBuffer(gas),
          maxFeePerGasWei: maxFee,
          maxPriorityFeePerGasWei: priority,
        );
      }
      final gasPrice = await rpc.getGasPrice();
      final gas = await rpc.estimateGas(
        fromAddress: fromAddress,
        call: call,
        gasPriceWei: gasPrice,
      );
      return EvmWrappedNativePreparation(
        call: call,
        feeModel: EvmWrappedNativeFeeModel.legacy,
        gasLimit: _withGasBuffer(gas),
        gasPriceWei: gasPrice,
      );
    } finally {
      await rpc.close();
    }
  }

  @override
  Future<String> submit({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String privateKey,
    required EvmWrappedNativePreparation preparation,
    Map<String, String> headers = const {},
  }) async {
    final rpc = _rpcFactory(rpcUrl, headers);
    try {
      final nonce = await rpc.getPendingNonce(fromAddress);
      return await rpc.send(
        chainId: chainId,
        privateKey: privateKey,
        fromAddress: fromAddress,
        preparation: preparation,
        nonce: nonce,
      );
    } finally {
      await rpc.close();
    }
  }
}

abstract interface class EvmWrappedNativeRpc {
  Future<bool> hasContractCode(String contractAddress);

  Future<BigInt> getNativeBalance(String address);

  Future<BigInt> getWrappedBalance({
    required String ownerAddress,
    required String contractAddress,
  });

  Future<void> simulate({
    required String fromAddress,
    required EvmWrappedNativeCall call,
  });

  Future<BigInt?> getBaseFeePerGas();

  Future<List<BigInt>> getPriorityFeeOptions();

  Future<BigInt> getGasPrice();

  Future<BigInt> estimateGas({
    required String fromAddress,
    required EvmWrappedNativeCall call,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
  });

  Future<int> getPendingNonce(String address);

  Future<String> send({
    required int chainId,
    required String privateKey,
    required String fromAddress,
    required EvmWrappedNativePreparation preparation,
    required int nonce,
  });

  Future<void> close();
}

final class Web3EvmWrappedNativeRpc implements EvmWrappedNativeRpc {
  factory Web3EvmWrappedNativeRpc(
    String rpcUrl, {
    Map<String, String> headers = const {},
    http.Client? httpClient,
  }) {
    final client = httpClient ?? BoundedHttpClient();
    return Web3EvmWrappedNativeRpc._(
      client,
      web3.Web3Client(
        rpcUrl,
        headers.isEmpty ? client : _HeaderClient(client, headers),
      ),
    );
  }

  const Web3EvmWrappedNativeRpc._(this._httpClient, this._client);

  final http.Client _httpClient;
  final web3.Web3Client _client;

  @override
  Future<bool> hasContractCode(String contractAddress) async {
    final code = await _client.getCode(
      wallet.EthereumAddress.fromHex(contractAddress),
    );
    return code.any((byte) => byte != 0);
  }

  @override
  Future<BigInt> getNativeBalance(String address) async {
    return (await _client.getBalance(
      wallet.EthereumAddress.fromHex(address),
    )).getInWei;
  }

  @override
  Future<BigInt> getWrappedBalance({
    required String ownerAddress,
    required String contractAddress,
  }) async {
    final owner = wallet.EthereumAddress.fromHex(ownerAddress);
    final data = Uint8List.fromList([
      ...web3.hexToBytes('70a08231'),
      ...Uint8List(12),
      ...owner.value,
    ]);
    final result = await _client.callRaw(
      sender: owner,
      contract: wallet.EthereumAddress.fromHex(contractAddress),
      data: data,
    );
    final normalized = result.startsWith('0x') ? result.substring(2) : result;
    return normalized.isEmpty
        ? BigInt.zero
        : BigInt.parse(normalized, radix: 16);
  }

  @override
  Future<void> simulate({
    required String fromAddress,
    required EvmWrappedNativeCall call,
  }) async {
    await _client.makeRPCCall<String>('eth_call', [
      _rpcTransaction(fromAddress: fromAddress, call: call),
      'latest',
    ]);
  }

  @override
  Future<BigInt?> getBaseFeePerGas() async {
    try {
      return (await _client.getBlockInformation()).baseFeePerGas?.getInWei;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<BigInt>> getPriorityFeeOptions() async {
    try {
      final history = await _client.getFeeHistory(
        15,
        rewardPercentiles: const [25, 50, 75],
      );
      final rewards = history['reward'];
      if (rewards is! List || rewards.isEmpty) {
        return _fallbackPriorityFees;
      }
      return List<BigInt>.generate(3, (index) {
        final values =
            rewards
                .whereType<List<dynamic>>()
                .where((row) => row.length > index)
                .map((row) => row[index])
                .whereType<BigInt>()
                .where((value) => value > BigInt.zero)
                .toList()
              ..sort();
        return values.isEmpty
            ? _fallbackPriorityFees[index]
            : values[values.length ~/ 2];
      });
    } catch (_) {
      return _fallbackPriorityFees;
    }
  }

  @override
  Future<BigInt> getGasPrice() async => (await _client.getGasPrice()).getInWei;

  @override
  Future<BigInt> estimateGas({
    required String fromAddress,
    required EvmWrappedNativeCall call,
    BigInt? gasPriceWei,
    BigInt? maxFeePerGasWei,
    BigInt? maxPriorityFeePerGasWei,
  }) {
    return _client.estimateGas(
      sender: wallet.EthereumAddress.fromHex(fromAddress),
      to: wallet.EthereumAddress.fromHex(call.contractAddress),
      value: wallet.EtherAmount.inWei(call.valueWei),
      data: Uint8List.fromList(web3.hexToBytes(call.calldata.substring(2))),
      gasPrice: gasPriceWei == null
          ? null
          : wallet.EtherAmount.inWei(gasPriceWei),
      maxFeePerGas: maxFeePerGasWei == null
          ? null
          : wallet.EtherAmount.inWei(maxFeePerGasWei),
      maxPriorityFeePerGas: maxPriorityFeePerGasWei == null
          ? null
          : wallet.EtherAmount.inWei(maxPriorityFeePerGasWei),
    );
  }

  @override
  Future<int> getPendingNonce(String address) {
    return _client.getTransactionCount(
      wallet.EthereumAddress.fromHex(address),
      atBlock: const web3.BlockNum.pending(),
    );
  }

  @override
  Future<String> send({
    required int chainId,
    required String privateKey,
    required String fromAddress,
    required EvmWrappedNativePreparation preparation,
    required int nonce,
  }) {
    final credentials = web3.EthPrivateKey.fromHex(
      privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey,
    );
    if (credentials.address.with0x.toLowerCase() != fromAddress.toLowerCase()) {
      throw StateError('wrapped_native_signer_mismatch');
    }
    return _client.sendTransaction(
      credentials,
      web3.Transaction(
        from: wallet.EthereumAddress.fromHex(fromAddress),
        to: wallet.EthereumAddress.fromHex(preparation.call.contractAddress),
        data: Uint8List.fromList(
          web3.hexToBytes(preparation.call.calldata.substring(2)),
        ),
        value: wallet.EtherAmount.inWei(preparation.call.valueWei),
        maxGas: preparation.gasLimit.toInt(),
        nonce: nonce,
        gasPrice: preparation.gasPriceWei == null
            ? null
            : wallet.EtherAmount.inWei(preparation.gasPriceWei!),
        maxFeePerGas: preparation.maxFeePerGasWei == null
            ? null
            : wallet.EtherAmount.inWei(preparation.maxFeePerGasWei!),
        maxPriorityFeePerGas: preparation.maxPriorityFeePerGasWei == null
            ? null
            : wallet.EtherAmount.inWei(preparation.maxPriorityFeePerGasWei!),
      ),
      chainId: chainId,
      fetchChainIdFromNetworkId: false,
    );
  }

  Map<String, Object> _rpcTransaction({
    required String fromAddress,
    required EvmWrappedNativeCall call,
  }) {
    return {
      'from': wallet.EthereumAddress.fromHex(fromAddress).with0x,
      'to': wallet.EthereumAddress.fromHex(call.contractAddress).with0x,
      'data': call.calldata,
      if (call.valueWei > BigInt.zero)
        'value': '0x${call.valueWei.toRadixString(16)}',
    };
  }

  @override
  Future<void> close() async {
    _client.dispose();
    _httpClient.close();
  }
}

final class _HeaderClient extends http.BaseClient {
  _HeaderClient(this._delegate, this._headers);

  final http.Client _delegate;
  final Map<String, String> _headers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _delegate.send(request);
  }

  @override
  void close() {
    _delegate.close();
    super.close();
  }
}

EvmWrappedNativeRpc _defaultRpcFactory(
  String rpcUrl,
  Map<String, String> headers,
) {
  return Web3EvmWrappedNativeRpc(rpcUrl, headers: headers);
}

BigInt _withGasBuffer(BigInt gasLimit) {
  return (gasLimit * BigInt.from(110) + BigInt.from(99)) ~/ BigInt.from(100);
}

final _defaultPriorityFeeWei = BigInt.from(2000000000);
final _fallbackPriorityFees = [
  _defaultPriorityFeeWei ~/ BigInt.two,
  _defaultPriorityFeeWei,
  _defaultPriorityFeeWei * BigInt.two,
];
