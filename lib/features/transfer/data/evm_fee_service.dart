import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/header_http_client.dart';
import '../../../shared/network/bounded_http_client.dart';
import '../domain/transaction_request.dart';

enum EvmFeeModel { eip1559, legacy }

final class EvmFeeEstimate {
  const EvmFeeEstimate._({
    required this.model,
    required this.gasLimit,
    this.maxFeePerGasWei,
    this.maxPriorityFeePerGasWei,
    this.gasPriceWei,
    this.baseFeePerGasWei,
    this.priorityFeeOptionsWei = const [],
    this.gasPriceOptionsWei = const [],
  });

  factory EvmFeeEstimate.eip1559({
    required BigInt gasLimit,
    required BigInt maxFeePerGasWei,
    required BigInt maxPriorityFeePerGasWei,
    BigInt? baseFeePerGasWei,
    List<BigInt> priorityFeeOptionsWei = const [],
  }) {
    return EvmFeeEstimate._(
      model: EvmFeeModel.eip1559,
      gasLimit: gasLimit,
      maxFeePerGasWei: maxFeePerGasWei,
      maxPriorityFeePerGasWei: maxPriorityFeePerGasWei,
      baseFeePerGasWei: baseFeePerGasWei,
      priorityFeeOptionsWei: List.unmodifiable(priorityFeeOptionsWei),
    );
  }

  factory EvmFeeEstimate.legacy({
    required BigInt gasLimit,
    required BigInt gasPriceWei,
    List<BigInt> gasPriceOptionsWei = const [],
  }) {
    return EvmFeeEstimate._(
      model: EvmFeeModel.legacy,
      gasLimit: gasLimit,
      gasPriceWei: gasPriceWei,
      gasPriceOptionsWei: List.unmodifiable(gasPriceOptionsWei),
    );
  }

  final EvmFeeModel model;
  final BigInt gasLimit;
  final BigInt? maxFeePerGasWei;
  final BigInt? maxPriorityFeePerGasWei;
  final BigInt? gasPriceWei;
  final BigInt? baseFeePerGasWei;
  final List<BigInt> priorityFeeOptionsWei;
  final List<BigInt> gasPriceOptionsWei;

  BigInt get feeInWei {
    return switch (model) {
      EvmFeeModel.eip1559 => gasLimit * maxFeePerGasWei!,
      EvmFeeModel.legacy => gasLimit * gasPriceWei!,
    };
  }
}

abstract interface class EvmFeeService {
  Future<EvmFeeEstimate> estimateTransferFee({
    required String rpcUrl,
    required String fromAddress,
    required String toAddress,
    required TransactionType transactionType,
    required BigInt amountInWei,
    String? tokenContractAddress,
    Map<String, String> headers = const {},
  });
}

final class Web3EvmFeeService implements EvmFeeService {
  const Web3EvmFeeService();

  static final _defaultPriorityFeeWei = BigInt.from(2000000000);

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
    final httpClient = headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: headers);
    final client = web3.Web3Client(rpcUrl, httpClient);
    try {
      final transaction = _transactionFor(
        fromAddress: fromAddress,
        toAddress: toAddress,
        transactionType: transactionType,
        amountInWei: amountInWei,
        tokenContractAddress: tokenContractAddress,
      );
      try {
        return await _estimateEip1559(client, transaction);
      } catch (_) {
        return await _estimateLegacy(client, transaction);
      }
    } finally {
      client.dispose();
    }
  }

  web3.Transaction _transactionFor({
    required String fromAddress,
    required String toAddress,
    required TransactionType transactionType,
    required BigInt amountInWei,
    String? tokenContractAddress,
  }) {
    final from = wallet.EthereumAddress.fromHex(fromAddress);
    final to = wallet.EthereumAddress.fromHex(toAddress);
    if (transactionType == TransactionType.erc20Transfer) {
      final contract = web3.DeployedContract(
        web3.ContractAbi.fromJson(_erc20TransferAbi, 'ERC20'),
        wallet.EthereumAddress.fromHex(tokenContractAddress!),
      );
      return web3.Transaction.callContract(
        contract: contract,
        function: contract.function('transfer'),
        parameters: [to, amountInWei],
        from: from,
      );
    }

    return web3.Transaction(
      from: from,
      to: to,
      value: wallet.EtherAmount.inWei(amountInWei),
    );
  }

  Future<EvmFeeEstimate> _estimateEip1559(
    web3.Web3Client client,
    web3.Transaction transaction,
  ) async {
    final block = await client.getBlockInformation();
    final baseFeePerGas = block.baseFeePerGas;
    if (baseFeePerGas == null) {
      throw StateError('RPC does not provide baseFeePerGas');
    }

    final priorityFees = await _priorityFees(client);
    final standardPriorityFee = priorityFees[1];
    final maxPriorityFeePerGas = wallet.EtherAmount.inWei(standardPriorityFee);
    final maxFeePerGas = wallet.EtherAmount.inWei(
      baseFeePerGas.getInWei * BigInt.from(2) + standardPriorityFee,
    );
    final gasLimit = await client.estimateGas(
      sender: transaction.from,
      to: transaction.to,
      value: transaction.value,
      data: transaction.data,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
    );
    return EvmFeeEstimate.eip1559(
      gasLimit: _withGasBuffer(gasLimit),
      maxFeePerGasWei: maxFeePerGas.getInWei,
      maxPriorityFeePerGasWei: maxPriorityFeePerGas.getInWei,
      baseFeePerGasWei: baseFeePerGas.getInWei,
      priorityFeeOptionsWei: priorityFees,
    );
  }

  Future<List<BigInt>> _priorityFees(web3.Web3Client client) async {
    try {
      final history = await client.getFeeHistory(
        15,
        rewardPercentiles: const [25, 50, 75],
      );
      return evmPriorityFeesFromHistory(history);
    } catch (_) {
      return [
        _defaultPriorityFeeWei ~/ BigInt.two,
        _defaultPriorityFeeWei,
        _defaultPriorityFeeWei * BigInt.two,
      ];
    }
  }

  Future<EvmFeeEstimate> _estimateLegacy(
    web3.Web3Client client,
    web3.Transaction transaction,
  ) async {
    final gasPrice = await client.getGasPrice();
    final gasLimit = await client.estimateGas(
      sender: transaction.from,
      to: transaction.to,
      value: transaction.value,
      data: transaction.data,
      gasPrice: gasPrice,
    );
    final price = gasPrice.getInWei;
    return EvmFeeEstimate.legacy(
      gasLimit: _withGasBuffer(gasLimit),
      gasPriceWei: gasPrice.getInWei,
      gasPriceOptionsWei: [
        (price * BigInt.from(9) + BigInt.from(9)) ~/ BigInt.from(10),
        price,
        (price * BigInt.from(12) + BigInt.from(9)) ~/ BigInt.from(10),
      ],
    );
  }
}

List<BigInt> evmPriorityFeesFromHistory(Map<String, dynamic> history) {
  final rewards = history['reward'];
  if (rewards is! List || rewards.isEmpty) {
    throw StateError('Fee history has no rewards');
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
    if (values.isEmpty) {
      throw StateError('Fee history percentile is empty');
    }
    return values[values.length ~/ 2];
  });
}

BigInt _withGasBuffer(BigInt gasLimit) {
  return (gasLimit * BigInt.from(110) + BigInt.from(99)) ~/ BigInt.from(100);
}

const _erc20TransferAbi = '''
[
  {
    "constant": false,
    "inputs": [
      {"name": "to", "type": "address"},
      {"name": "value", "type": "uint256"}
    ],
    "name": "transfer",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  }
]
''';
