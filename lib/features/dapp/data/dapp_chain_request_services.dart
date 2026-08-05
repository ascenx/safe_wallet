import 'dart:convert';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:http/http.dart' as http;
import 'package:solana_sdk/solana_sdk.dart' as solana;
import 'package:sui_dart/grpc/sui_grpc_client.dart' as sui_grpc;
import 'package:sui_dart/sui.dart' as sui;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/errors/dapp_error.dart';
import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/network/grpc_client_channel.dart';
import '../../../shared/network/header_http_client.dart';
import '../../chains/domain/chain_config.dart';
import '../application/dapp_request_models.dart';
import 'dapp_transaction.dart';

final class Web3DappEvmTransactionSender implements DappEvmTransactionSender {
  const Web3DappEvmTransactionSender();

  @override
  Future<String> send({
    required ChainConfig chain,
    required String rpcUrl,
    required String privateKey,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  }) async {
    final httpClient = headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: headers);
    final client = web3.Web3Client(rpcUrl, httpClient);
    try {
      return client.sendTransaction(
        web3.EthPrivateKey.fromHex(_normalizePrivateKey(privateKey)),
        transaction.toWeb3Transaction(),
        chainId: int.parse(chain.chainId),
        fetchChainIdFromNetworkId: false,
      );
    } finally {
      client.dispose();
    }
  }
}

final class Web3DappEvmTransactionSigner implements DappEvmTransactionSigner {
  const Web3DappEvmTransactionSigner();

  @override
  Future<String> sign({
    required ChainConfig chain,
    required String rpcUrl,
    required String privateKey,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  }) async {
    final httpClient = headers.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: headers);
    final client = web3.Web3Client(rpcUrl, httpClient);
    try {
      final signed = await client.signTransaction(
        web3.EthPrivateKey.fromHex(_normalizePrivateKey(privateKey)),
        transaction.toWeb3Transaction(),
        chainId: int.parse(chain.chainId),
        fetchChainIdFromNetworkId: false,
      );
      return web3.bytesToHex(signed, include0x: true, padToEvenLength: true);
    } finally {
      client.dispose();
    }
  }
}

final class Web3DappEvmMessageSigner implements DappEvmMessageSigner {
  const Web3DappEvmMessageSigner();

  @override
  Future<String> signPersonalMessage({
    required String privateKey,
    required List<int> message,
  }) async {
    final signature = web3.EthPrivateKey.fromHex(
      _normalizePrivateKey(privateKey),
    ).signPersonalMessageToUint8List(Uint8List.fromList(message));
    return web3.bytesToHex(signature, include0x: true, padToEvenLength: true);
  }

  @override
  Future<String> signTypedData({
    required String privateKey,
    required List<int> payload,
  }) async {
    final signature = web3.EthPrivateKey.fromHex(
      _normalizePrivateKey(privateKey),
    ).signToUint8List(Uint8List.fromList(payload));
    return web3.bytesToHex(signature, include0x: true, padToEvenLength: true);
  }
}

final class HttpDappEvmReadRpcClient implements DappEvmReadRpcClient {
  HttpDappEvmReadRpcClient({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<DappEvmReadRpcResponse> request({
    required ChainConfig chain,
    required String rpcUrl,
    required String method,
    required List<Object?> params,
    Map<String, String> headers = const {},
  }) async {
    final response = await _client.post(
      Uri.parse(rpcUrl),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DappError.requestFailed();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const DappError.requestFailed();
    }
    final error = decoded['error'];
    if (error != null) {
      final jsonRpcError = _decodeJsonRpcError(error);
      if (jsonRpcError == null) {
        throw const DappError.requestFailed();
      }
      return DappEvmReadRpcResponse.error(jsonRpcError);
    }
    return DappEvmReadRpcResponse.result(decoded['result']);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

final class RpcDappEvmTransactionSimulator
    implements DappEvmTransactionSimulator {
  const RpcDappEvmTransactionSimulator({
    required DappEvmReadRpcClient rpcClient,
  }) : _rpcClient = rpcClient;

  final DappEvmReadRpcClient _rpcClient;

  @override
  Future<DappTransactionSimulation> simulate({
    required ChainConfig chain,
    required String rpcUrl,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  }) async {
    try {
      final response = await _rpcClient.request(
        chain: chain,
        rpcUrl: rpcUrl,
        method: 'eth_call',
        params: [transaction.toRpcJson(), 'latest'],
        headers: headers,
      );
      final error = response.error;
      if (error != null) {
        return DappTransactionSimulation.failed(error.message);
      }
      var gasLimit = transaction.gasLimit;
      if (gasLimit == null) {
        final estimateResponse = await _rpcClient.request(
          chain: chain,
          rpcUrl: rpcUrl,
          method: 'eth_estimateGas',
          params: [transaction.toRpcJson()],
          headers: headers,
        );
        if (estimateResponse.error == null &&
            estimateResponse.result is String) {
          gasLimit = _quantityToInt(estimateResponse.result as String);
        }
      }
      var gasPriceWei = transaction.maxFeePerGasWei ?? transaction.gasPriceWei;
      if (gasPriceWei == null) {
        final gasPriceResponse = await _rpcClient.request(
          chain: chain,
          rpcUrl: rpcUrl,
          method: 'eth_gasPrice',
          params: const [],
          headers: headers,
        );
        if (gasPriceResponse.error == null &&
            gasPriceResponse.result is String) {
          gasPriceWei = _quantityToBigInt(gasPriceResponse.result as String);
        }
      }
      return DappTransactionSimulation.succeeded(
        gasLimit: gasLimit,
        gasPriceWei: gasPriceWei,
      );
    } catch (_) {
      return const DappTransactionSimulation.failed(
        'Transaction simulation unavailable',
      );
    }
  }
}

DappJsonRpcError? _decodeJsonRpcError(Object? value) {
  if (value is! Map) {
    return null;
  }
  final code = value['code'];
  final message = value['message'];
  if (code is! int || message is! String || message.isEmpty) {
    return null;
  }
  return DappJsonRpcError(code: code, message: message, data: value['data']);
}

final class SdkDappSolanaTransactionSigner
    implements DappSolanaTransactionSigner {
  const SdkDappSolanaTransactionSigner();

  @override
  Future<List<int>> sign({
    required List<int> privateKey,
    required List<int> serializedTransaction,
  }) async {
    final keypair = solana.Keypair.fromSecretKey(
      Uint8List.fromList(privateKey),
    );
    final transaction = solana.VersionedTransaction.deserialize(
      Uint8List.fromList(serializedTransaction),
    );
    transaction.sign([keypair]);
    return transaction.serialize().toList();
  }
}

final class HttpDappSolanaRawTransactionSender
    implements DappSolanaRawTransactionSender {
  HttpDappSolanaRawTransactionSender({http.Client? client})
    : _client = client ?? BoundedHttpClient(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<String> send({
    required ChainConfig chain,
    required String rpcUrl,
    required List<int> serializedTransaction,
    Map<String, String> headers = const {},
  }) async {
    final response = await _client.post(
      Uri.parse(rpcUrl),
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'sendRawTransaction',
        'params': [
          base64Encode(serializedTransaction),
          {'encoding': 'base64'},
        ],
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DappError.requestFailed();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['error'] != null) {
      throw const DappError.requestFailed();
    }
    final result = decoded['result'];
    if (result is! String || result.isEmpty) {
      throw const DappError.requestFailed();
    }
    return result;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

final class SdkDappSolanaMessageSigner implements DappSolanaMessageSigner {
  const SdkDappSolanaMessageSigner();

  @override
  Future<List<int>> sign({
    required List<int> privateKey,
    required List<int> message,
  }) async {
    final keypair = solana.Keypair.fromSecretKey(
      Uint8List.fromList(privateKey),
    );
    return keypair.sign(Uint8List.fromList(message)).toList();
  }
}

final class SdkDappSuiSigner implements DappSuiSigner {
  const SdkDappSuiSigner();

  @override
  Future<DappSuiSignedData> signPersonalMessage({
    required List<int> privateKey,
    required List<int> message,
  }) async {
    final account = _suiAccount(privateKey);
    final signed = account.keyPair.signPersonalMessage(
      Uint8List.fromList(message),
    );
    return DappSuiSignedData(
      bytes: base64Encode(message),
      signature: signed.signature,
    );
  }

  @override
  Future<DappSuiSignedData> signTransaction({
    required List<int> privateKey,
    required List<int> transactionBytes,
  }) async {
    final account = _suiAccount(privateKey);
    final signed = account.keyPair.signTransactionBlock(
      Uint8List.fromList(transactionBytes),
    );
    return DappSuiSignedData(
      bytes: base64Encode(transactionBytes),
      signature: signed.signature,
    );
  }
}

final class GrpcDappSuiTransactionExecutor
    implements DappSuiTransactionExecutor {
  const GrpcDappSuiTransactionExecutor();

  @override
  Future<String> execute({
    required ChainConfig chain,
    required String rpcUrl,
    required List<int> transactionBytes,
    required String signature,
    Map<String, String> headers = const {},
  }) async {
    if (chain.chainType != ChainType.sui) {
      throw const DappError.requestFailed();
    }
    final endpoint = _suiGrpcEndpoint(rpcUrl);
    final client = sui_grpc.SuiGrpcClient(
      sui_grpc.SuiGrpcClientOptions(
        baseUrl: endpoint.host,
        port: endpoint.port,
        customChannel: DefaultCallOptionsClientChannel(
          endpoint.host,
          port: endpoint.port,
          headers: headers,
        ),
      ),
    );
    try {
      final response = await client.executeTransaction(
        Uint8List.fromList(transactionBytes),
        [signature],
        include: const sui_grpc.TransactionIncludeOptions(effects: true),
      );
      final success =
          response.effects?.status?.success ?? response.status.success;
      if (!success || response.digest.isEmpty) {
        throw const DappError.requestFailed();
      }
      return response.digest;
    } on GrpcError {
      throw const DappError.requestFailed();
    } finally {
      await client.shutdown();
    }
  }
}

BigInt? _quantityToBigInt(String? value) {
  if (value == null) {
    return null;
  }
  if (value.startsWith('0x')) {
    return BigInt.parse(
      value.substring(2).isEmpty ? '0' : value.substring(2),
      radix: 16,
    );
  }
  return BigInt.tryParse(value);
}

int? _quantityToInt(String? value) {
  return _quantityToBigInt(value)?.toInt();
}

String _normalizePrivateKey(String privateKey) {
  return privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
}

sui.SuiAccount _suiAccount(List<int> privateKey) {
  if (privateKey.length != 32) {
    throw const DappError.requestFailed();
  }
  return sui.SuiAccount.fromPrivateKey(
    _bytesToHexString(privateKey),
    sui.SignatureScheme.Ed25519,
  );
}

String _bytesToHexString(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

({String host, int port}) _suiGrpcEndpoint(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.scheme != 'https' ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const DappError.requestFailed();
  }
  return (host: uri.host, port: uri.hasPort ? uri.port : 443);
}
