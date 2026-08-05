import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/bounded_http_client.dart';

typedef EvmContractHttpClientFactory = http.Client Function();

abstract interface class EvmContractCallGateway {
  Future<bool> hasContractCode({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  });

  Future<String> read({
    required String rpcUrl,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    Map<String, String> headers = const {},
  });

  Future<EvmContractWritePreparation> prepareWrite({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    required BigInt valueWei,
    Map<String, String> headers = const {},
  });

  Future<String> sendWrite({
    required String rpcUrl,
    required String privateKey,
    required EvmContractWritePreparation preparation,
    Map<String, String> headers = const {},
  });
}

final class EvmContractWritePreparation {
  const EvmContractWritePreparation({
    required this.chainId,
    required this.fromAddress,
    required this.contractAddress,
    required this.calldata,
    required this.valueWei,
    required this.gasLimit,
    required this.gasPriceWei,
    required this.nonce,
  });

  final int chainId;
  final String fromAddress;
  final String contractAddress;
  final String calldata;
  final BigInt valueWei;
  final int gasLimit;
  final BigInt gasPriceWei;
  final int nonce;

  BigInt get estimatedFeeWei => BigInt.from(gasLimit) * gasPriceWei;
}

final class HttpEvmContractCallGateway implements EvmContractCallGateway {
  HttpEvmContractCallGateway({EvmContractHttpClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? BoundedHttpClient.new;

  final EvmContractHttpClientFactory _clientFactory;

  @override
  Future<bool> hasContractCode({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async {
    final client = _web3Client(rpcUrl, headers);
    try {
      final code = await client.getCode(
        wallet.EthereumAddress.fromHex(contractAddress),
      );
      return code.any((byte) => byte != 0);
    } finally {
      client.dispose();
    }
  }

  @override
  Future<String> read({
    required String rpcUrl,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    Map<String, String> headers = const {},
  }) async {
    final client = _web3Client(rpcUrl, headers);
    try {
      return client.callRaw(
        sender: wallet.EthereumAddress.fromHex(fromAddress),
        contract: wallet.EthereumAddress.fromHex(contractAddress),
        data: _calldataBytes(calldata),
      );
    } finally {
      client.dispose();
    }
  }

  @override
  Future<EvmContractWritePreparation> prepareWrite({
    required String rpcUrl,
    required int chainId,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    required BigInt valueWei,
    Map<String, String> headers = const {},
  }) async {
    final client = _web3Client(rpcUrl, headers);
    try {
      final from = wallet.EthereumAddress.fromHex(fromAddress);
      final contract = wallet.EthereumAddress.fromHex(contractAddress);
      final data = _calldataBytes(calldata);
      final value = wallet.EtherAmount.inWei(valueWei);
      await client.makeRPCCall<String>('eth_call', [
        {
          'from': from.with0x,
          'to': contract.with0x,
          'data': web3.bytesToHex(data, include0x: true),
          if (valueWei > BigInt.zero)
            'value': '0x${valueWei.toRadixString(16)}',
        },
        'latest',
      ]);
      final gasLimit = await client.estimateGas(
        sender: from,
        to: contract,
        value: value,
        data: data,
      );
      final gasPrice = await client.getGasPrice();
      final nonce = await client.getTransactionCount(
        from,
        atBlock: const web3.BlockNum.pending(),
      );
      return EvmContractWritePreparation(
        chainId: chainId,
        fromAddress: fromAddress,
        contractAddress: contractAddress,
        calldata: calldata,
        valueWei: valueWei,
        gasLimit: gasLimit.toInt(),
        gasPriceWei: gasPrice.getInWei,
        nonce: nonce,
      );
    } finally {
      client.dispose();
    }
  }

  @override
  Future<String> sendWrite({
    required String rpcUrl,
    required String privateKey,
    required EvmContractWritePreparation preparation,
    Map<String, String> headers = const {},
  }) async {
    final client = _web3Client(rpcUrl, headers);
    try {
      return client.sendTransaction(
        web3.EthPrivateKey.fromHex(_normalizePrivateKey(privateKey)),
        web3.Transaction(
          from: wallet.EthereumAddress.fromHex(preparation.fromAddress),
          to: wallet.EthereumAddress.fromHex(preparation.contractAddress),
          data: _calldataBytes(preparation.calldata),
          value: wallet.EtherAmount.inWei(preparation.valueWei),
          maxGas: preparation.gasLimit,
          gasPrice: wallet.EtherAmount.inWei(preparation.gasPriceWei),
          nonce: preparation.nonce,
        ),
        chainId: preparation.chainId,
        fetchChainIdFromNetworkId: false,
      );
    } finally {
      client.dispose();
    }
  }

  web3.Web3Client _web3Client(String rpcUrl, Map<String, String> headers) {
    final client = _clientFactory();
    return web3.Web3Client(
      rpcUrl,
      headers.isEmpty ? client : _HeaderClient(client, headers),
    );
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

Uint8List _calldataBytes(String calldata) {
  final normalized = calldata.trim();
  if (!RegExp(r'^0x(?:[0-9a-fA-F]{2})*$').hasMatch(normalized)) {
    throw const FormatException('Calldata must be an even-length hex value');
  }
  return Uint8List.fromList(web3.hexToBytes(normalized.substring(2)));
}

String _normalizePrivateKey(String privateKey) {
  return privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
}
