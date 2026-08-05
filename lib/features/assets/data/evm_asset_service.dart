import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../../../shared/network/header_http_client.dart';
import '../../../shared/network/bounded_http_client.dart';

abstract interface class EvmAssetService {
  Future<BigInt> getNativeBalance({
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  });

  Future<BigInt> getErc20Balance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  });

  Future<Map<String, BigInt>> getErc20Balances({
    required String rpcUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  });
}

final class Web3EvmAssetService implements EvmAssetService {
  const Web3EvmAssetService();

  @override
  Future<BigInt> getNativeBalance({
    required String rpcUrl,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final httpClient = headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: headers);
    final client = Web3Client(rpcUrl, httpClient);
    try {
      final balance = await client.getBalance(
        EthereumAddress.fromHex(walletAddress),
      );
      return balance.getInWei;
    } finally {
      client.dispose();
    }
  }

  @override
  Future<BigInt> getErc20Balance({
    required String rpcUrl,
    required String contractAddress,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    final balances = await getErc20Balances(
      rpcUrl: rpcUrl,
      contractAddresses: [contractAddress],
      walletAddress: walletAddress,
      headers: headers,
    );
    return balances[contractAddress.toLowerCase()] ?? BigInt.zero;
  }

  @override
  Future<Map<String, BigInt>> getErc20Balances({
    required String rpcUrl,
    required List<String> contractAddresses,
    required String walletAddress,
    Map<String, String> headers = const {},
  }) async {
    if (contractAddresses.isEmpty) {
      return const {};
    }
    final httpClient = headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: headers);
    final client = Web3Client(rpcUrl, httpClient);
    try {
      final ownerAddress = EthereumAddress.fromHex(walletAddress);
      final balances = <String, BigInt>{};
      for (final contractAddress in contractAddresses) {
        balances[contractAddress
            .toLowerCase()] = await _getErc20BalanceWithClient(
          client: client,
          contractAddress: contractAddress,
          ownerAddress: ownerAddress,
        );
      }
      return balances;
    } finally {
      client.dispose();
    }
  }

  Future<BigInt> _getErc20BalanceWithClient({
    required Web3Client client,
    required String contractAddress,
    required EthereumAddress ownerAddress,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20Abi, 'ERC20'),
      EthereumAddress.fromHex(contractAddress),
    );
    final result = await client.call(
      contract: contract,
      function: contract.function('balanceOf'),
      params: [ownerAddress],
    );
    return result.first as BigInt;
  }
}

const _erc20Abi = '''
[
  {
    "constant": true,
    "inputs": [{"name": "account", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  }
]
''';
