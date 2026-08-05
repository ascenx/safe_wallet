import 'package:grpc/grpc.dart';
import 'package:sui_dart/grpc/grpc_resolution_client.dart';
import 'package:sui_dart/grpc/sui_grpc_client.dart' as sdk;
import 'package:sui_dart/sui.dart' as sui;
import 'package:sui_dart/types/common.dart' show normalizeStructTagString;

import '../../../shared/errors/rpc_error.dart';
import '../../../shared/errors/transfer_error.dart';
import '../../../shared/network/grpc_client_channel.dart';
import '../../../shared/utils/sui_address.dart';
import '../../assets/data/sui_asset_service.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/transaction_request.dart';

final class SuiTransferInput {
  const SuiTransferInput({
    required this.rpcUrl,
    required this.fromAddress,
    required this.transaction,
    this.headers = const {},
  });

  final String rpcUrl;
  final String fromAddress;
  final TransactionRequest transaction;
  final Map<String, String> headers;
}

final class SuiTransactionBroadcastInput extends SuiTransferInput {
  SuiTransactionBroadcastInput({
    required super.rpcUrl,
    required List<int> privateKey,
    required super.fromAddress,
    required super.transaction,
    super.headers,
  }) : privateKey = List.unmodifiable(privateKey);

  final List<int> privateKey;
}

final class SuiTransactionSimulation {
  const SuiTransactionSimulation({
    required this.estimatedFeeMist,
    required this.gasBudgetMist,
  });

  final BigInt estimatedFeeMist;
  final BigInt gasBudgetMist;
}

enum SuiTransactionExecutionStatus { success, failed }

abstract interface class SuiTransactionRpc {
  Future<SuiTransactionSimulation> simulate({
    required String rpcUrl,
    required sui.Transaction transaction,
    Map<String, String> headers = const {},
  });

  Future<String> signAndExecute({
    required String rpcUrl,
    required sui.Transaction transaction,
    required List<int> privateKey,
    Map<String, String> headers = const {},
  });

  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  });
}

abstract interface class SuiTransactionService {
  Future<SuiTransactionSimulation> estimateTransferFee(SuiTransferInput input);

  Future<String> signAndBroadcast(SuiTransactionBroadcastInput input);

  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  });
}

final class SdkSuiTransactionService implements SuiTransactionService {
  SdkSuiTransactionService({SuiTransactionRpc? rpc})
    : _rpc = rpc ?? GrpcSuiTransactionRpc(),
      _ownsRpc = rpc == null;

  final SuiTransactionRpc _rpc;
  final bool _ownsRpc;

  @override
  Future<SuiTransactionSimulation> estimateTransferFee(
    SuiTransferInput input,
  ) async {
    return await _rpc.simulate(
      rpcUrl: input.rpcUrl,
      transaction: _buildTransfer(input),
      headers: input.headers,
    );
  }

  @override
  Future<String> signAndBroadcast(SuiTransactionBroadcastInput input) {
    if (input.privateKey.length != 32) {
      throw ArgumentError.value(
        input.privateKey.length,
        'privateKey',
        'must contain 32 bytes',
      );
    }
    return _rpc.signAndExecute(
      rpcUrl: input.rpcUrl,
      transaction: _buildTransfer(input),
      privateKey: input.privateKey,
      headers: input.headers,
    );
  }

  @override
  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  }) {
    return _rpc.getTransactionStatus(
      rpcUrl: rpcUrl,
      digest: digest,
      headers: headers,
    );
  }

  Future<void> close() async {
    if (_ownsRpc && _rpc is GrpcSuiTransactionRpc) {
      await _rpc.close();
    }
  }

  sui.Transaction _buildTransfer(SuiTransferInput input) {
    final request = input.transaction;
    if (request.chainType != ChainType.sui ||
        request.transactionType != TransactionType.suiTransfer) {
      throw ArgumentError('Unsupported Sui transaction request');
    }
    final amountText = request.amountInBaseUnits;
    final amount = amountText == null ? null : BigInt.tryParse(amountText);
    if (amount == null || amount <= BigInt.zero) {
      throw ArgumentError.value(
        amountText,
        'amountInBaseUnits',
        'must be positive',
      );
    }
    final sender = normalizeSuiAddressInput(input.fromAddress);
    final recipient = normalizeSuiAddressInput(request.toAddress);
    if (sender == null || recipient == null) {
      throw ArgumentError('Invalid Sui sender or recipient address');
    }
    final rawCoinType = request.tokenContractAddress ?? suiNativeCoinType;
    final coinType = normalizeStructTagString(rawCoinType);

    final transaction = sui.Transaction()..setSender(sender);
    final coin = transaction.add(
      sui.coinWithBalance(balance: amount, type: coinType),
    );
    transaction.transferObjects([coin], recipient);
    return transaction;
  }
}

final class GrpcSuiTransactionRpc implements SuiTransactionRpc {
  final Map<String, sdk.SuiGrpcClient> _clients = {};

  @override
  Future<SuiTransactionSimulation> simulate({
    required String rpcUrl,
    required sui.Transaction transaction,
    Map<String, String> headers = const {},
  }) async {
    try {
      final client = _clientFor(rpcUrl, headers);
      await client.buildTransaction(transaction);
      final gasBudget = transaction.getData().gasData.budget;
      if (gasBudget == null || gasBudget <= BigInt.zero) {
        throw const RpcError.unavailable(
          debugMessage: 'Sui gas budget is unavailable',
        );
      }
      final response = await client.simulateTransaction(
        transaction,
        include: const sdk.TransactionIncludeOptions(effects: true),
        doGasSelection: false,
      );
      final effects = response.effects;
      final success = effects?.status?.success ?? response.status.success;
      if (!success) {
        throw suiTransferErrorFromFailure(
          effects?.status?.error?.message ??
              effects?.status?.error?.kind ??
              response.status.error?.message ??
              response.status.error?.kind,
        );
      }
      final gasUsed = effects?.gasUsed;
      if (gasUsed == null) {
        throw const RpcError.unavailable(
          debugMessage: 'Sui simulation gas usage is unavailable',
        );
      }
      final computation = BigInt.parse(gasUsed.computationCost);
      final storage = BigInt.parse(gasUsed.storageCost);
      final rebate = BigInt.parse(gasUsed.storageRebate);
      final net = computation + storage - rebate;
      return SuiTransactionSimulation(
        estimatedFeeMist: net < BigInt.zero ? BigInt.zero : net,
        gasBudgetMist: gasBudget,
      );
    } on RpcError {
      rethrow;
    } on GrpcError catch (error) {
      throw _rpcErrorFromGrpc(error);
    } on ArgumentError catch (error) {
      throw suiTransferErrorFromFailure(error.message);
    } on StateError catch (error) {
      throw suiTransferErrorFromFailure(error.message);
    } on FormatException {
      throw const RpcError.unavailable(
        debugMessage: 'Sui gas usage fields are invalid',
      );
    }
  }

  @override
  Future<String> signAndExecute({
    required String rpcUrl,
    required sui.Transaction transaction,
    required List<int> privateKey,
    Map<String, String> headers = const {},
  }) async {
    try {
      final account = sui.SuiAccount.fromPrivateKey(
        _bytesToHex(privateKey),
        sui.SignatureScheme.Ed25519,
      );
      final sender = transaction.getData().sender;
      if (sender == null || account.getAddress() != sender) {
        throw ArgumentError('Sui signing key does not match sender');
      }
      final response = await _clientFor(rpcUrl, headers)
          .signAndExecuteTransaction(
            account,
            transaction,
            include: const sdk.TransactionIncludeOptions(
              effects: true,
              events: true,
              balanceChanges: true,
              objectTypes: true,
            ),
          );
      final success =
          response.effects?.status?.success ?? response.status.success;
      if (!success || response.digest.isEmpty) {
        throw const RpcError.unavailable(
          debugMessage: 'Sui transaction execution failed',
        );
      }
      return response.digest;
    } on RpcError {
      rethrow;
    } on GrpcError catch (error) {
      throw _rpcErrorFromGrpc(error);
    }
  }

  @override
  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  }) async {
    try {
      final response = await _clientFor(rpcUrl, headers).getTransaction(
        digest,
        include: const sdk.TransactionIncludeOptions(effects: true),
      );
      final success =
          response.effects?.status?.success ?? response.status.success;
      return success
          ? SuiTransactionExecutionStatus.success
          : SuiTransactionExecutionStatus.failed;
    } on GrpcError catch (error) {
      if (error.code == StatusCode.notFound) {
        return null;
      }
      throw _rpcErrorFromGrpc(error);
    }
  }

  sdk.SuiGrpcClient _clientFor(String rpcUrl, Map<String, String> headers) {
    final cacheKey = grpcClientCacheKey(rpcUrl, headers);
    return _clients.putIfAbsent(cacheKey, () {
      final endpoint = _parseGrpcEndpoint(rpcUrl);
      return sdk.SuiGrpcClient(
        sdk.SuiGrpcClientOptions(
          baseUrl: endpoint.host,
          port: endpoint.port,
          customChannel: DefaultCallOptionsClientChannel(
            endpoint.host,
            port: endpoint.port,
            headers: headers,
          ),
        ),
      );
    });
  }

  Future<void> close() async {
    final clients = _clients.values.toList(growable: false);
    _clients.clear();
    for (final client in clients) {
      await client.shutdown();
    }
  }
}

TransferError suiTransferErrorFromFailure(Object? failure) {
  final message = failure?.toString().toLowerCase() ?? '';
  if (message.contains('insufficient') && message.contains('gas')) {
    return const TransferError.suiInsufficientGas();
  }
  if (message.contains('insufficient balance') ||
      message.contains('not enough coin')) {
    return const TransferError.suiInsufficientBalance();
  }
  if (message.contains('object') &&
      (message.contains('version') ||
          message.contains('locked') ||
          message.contains('used') ||
          message.contains('conflict'))) {
    return const TransferError.suiObjectConflict();
  }
  return const TransferError.suiSimulationFailed();
}

({String host, int port}) _parseGrpcEndpoint(String rpcUrl) {
  final uri = Uri.tryParse(rpcUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.scheme != 'https' ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const RpcError.invalidUrl();
  }
  return (host: uri.host, port: uri.hasPort ? uri.port : 443);
}

RpcError _rpcErrorFromGrpc(GrpcError error) {
  return switch (error.code) {
    StatusCode.unauthenticated ||
    StatusCode.permissionDenied => const RpcError.invalidCredential(),
    StatusCode.resourceExhausted => const RpcError.rateLimited(),
    _ => RpcError.unavailable(
      debugMessage: 'Sui gRPC request failed with code ${error.code}',
    ),
  };
}

String _bytesToHex(List<int> bytes) {
  return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
