import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/header_http_client.dart';
import '../../../shared/network/bounded_http_client.dart';
import '../application/fee_estimate_provider.dart';
import '../domain/transaction_request.dart';

final class EvmTransactionBroadcastInput {
  const EvmTransactionBroadcastInput({
    required this.rpcUrl,
    required this.chainId,
    required this.privateKey,
    required this.fromAddress,
    required this.transaction,
    required this.feeEstimate,
    this.headers = const {},
  });

  final String rpcUrl;
  final int chainId;
  final String privateKey;
  final String fromAddress;
  final TransactionRequest transaction;
  final FeeEstimate feeEstimate;
  final Map<String, String> headers;
}

abstract interface class EvmTransactionService {
  Future<String> signAndBroadcast(EvmTransactionBroadcastInput input);
}

final class Web3EvmTransactionService implements EvmTransactionService {
  const Web3EvmTransactionService();

  @override
  Future<String> signAndBroadcast(EvmTransactionBroadcastInput input) async {
    final httpClient = input.headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: input.headers);
    final client = web3.Web3Client(input.rpcUrl, httpClient);
    try {
      final from = wallet.EthereumAddress.fromHex(input.fromAddress);
      final nonce = await client.getTransactionCount(
        from,
        atBlock: const web3.BlockNum.pending(),
      );
      final transaction = _transactionFor(
        input: input,
        from: from,
        nonce: nonce,
      );
      return client.sendTransaction(
        web3.EthPrivateKey.fromHex(_normalizePrivateKey(input.privateKey)),
        transaction,
        chainId: input.chainId,
        fetchChainIdFromNetworkId: false,
      );
    } finally {
      client.dispose();
    }
  }

  web3.Transaction _transactionFor({
    required EvmTransactionBroadcastInput input,
    required wallet.EthereumAddress from,
    required int nonce,
  }) {
    final request = input.transaction;
    final amount = _amountInBaseUnits(request);
    final gasLimit = input.feeEstimate.gasLimit?.toInt();
    if (gasLimit == null) {
      throw StateError('EVM gas limit is required before signing');
    }

    final fee = _feeFields(input.feeEstimate);
    if (request.transactionType == TransactionType.erc20Transfer) {
      final contractAddress = request.tokenContractAddress;
      if (contractAddress == null) {
        throw StateError('ERC20 transfer requires a token contract address');
      }
      final contract = web3.DeployedContract(
        web3.ContractAbi.fromJson(_erc20TransferAbi, 'ERC20'),
        wallet.EthereumAddress.fromHex(contractAddress),
      );
      return web3.Transaction.callContract(
        contract: contract,
        function: contract.function('transfer'),
        parameters: [wallet.EthereumAddress.fromHex(request.toAddress), amount],
        from: from,
        maxGas: gasLimit,
        nonce: nonce,
        gasPrice: fee.gasPrice,
        maxFeePerGas: fee.maxFeePerGas,
        maxPriorityFeePerGas: fee.maxPriorityFeePerGas,
      );
    }

    return web3.Transaction(
      from: from,
      to: wallet.EthereumAddress.fromHex(request.toAddress),
      value: wallet.EtherAmount.inWei(amount),
      maxGas: gasLimit,
      nonce: nonce,
      gasPrice: fee.gasPrice,
      maxFeePerGas: fee.maxFeePerGas,
      maxPriorityFeePerGas: fee.maxPriorityFeePerGas,
    );
  }

  _EvmFeeFields _feeFields(FeeEstimate estimate) {
    return switch (estimate.model) {
      FeeModel.eip1559 => _EvmFeeFields(
        maxFeePerGas: wallet.EtherAmount.inWei(estimate.maxFeePerGasWei!),
        maxPriorityFeePerGas: wallet.EtherAmount.inWei(
          estimate.maxPriorityFeePerGasWei!,
        ),
      ),
      FeeModel.legacy => _EvmFeeFields(
        gasPrice: wallet.EtherAmount.inWei(estimate.gasPriceWei!),
      ),
      FeeModel.bitcoin => throw StateError('Bitcoin fee cannot sign EVM tx'),
      FeeModel.tron => throw StateError('Tron fee cannot sign EVM tx'),
      FeeModel.solana => throw StateError('Solana fee cannot sign EVM tx'),
      FeeModel.sui => throw StateError('Sui fee cannot sign EVM tx'),
    };
  }
}

final class _EvmFeeFields {
  const _EvmFeeFields({
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
  });

  final wallet.EtherAmount? gasPrice;
  final wallet.EtherAmount? maxFeePerGas;
  final wallet.EtherAmount? maxPriorityFeePerGas;
}

BigInt _amountInBaseUnits(TransactionRequest request) {
  final amount = request.amountInBaseUnits;
  if (amount == null) {
    throw ArgumentError.value(amount, 'amountInBaseUnits', 'must not be null');
  }
  return BigInt.parse(amount);
}

String _normalizePrivateKey(String privateKey) {
  return privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
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
