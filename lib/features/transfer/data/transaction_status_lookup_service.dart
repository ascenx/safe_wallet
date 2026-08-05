import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:solana_sdk/solana_sdk.dart' as solana;
import 'package:web3dart/web3dart.dart' as web3;

import '../../../shared/network/bounded_http_client.dart';
import '../../../shared/network/header_http_client.dart';
import '../../chains/domain/chain_config.dart';
import '../../nodes/domain/rpc_node.dart';
import 'sui_transaction_service.dart';
import '../domain/transaction_record.dart';

final class TransactionStatusUpdate {
  const TransactionStatusUpdate({required this.status, this.failureReason});

  final TransactionStatus status;
  final String? failureReason;
}

abstract interface class TransactionStatusLookupService {
  Future<TransactionStatusUpdate?> lookup({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required TransactionRecord record,
  });
}

final class DefaultTransactionStatusLookupService
    implements TransactionStatusLookupService {
  DefaultTransactionStatusLookupService({
    http.Client? bitcoinClient,
    http.Client? tronClient,
    SuiTransactionService? suiService,
  }) : _bitcoinClient = bitcoinClient,
       _tronClient = tronClient,
       _suiService = suiService ?? SdkSuiTransactionService();

  final http.Client? _bitcoinClient;
  final http.Client? _tronClient;
  final SuiTransactionService _suiService;

  Future<void> close() async {
    if (_suiService is SdkSuiTransactionService) {
      await _suiService.close();
    }
  }

  @override
  Future<TransactionStatusUpdate?> lookup({
    required ChainConfig chain,
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) {
    return switch (chain.chainType) {
      ChainType.bitcoin => _lookupBitcoin(rpcNode: rpcNode, record: record),
      ChainType.evm => _lookupEvm(rpcNode: rpcNode, record: record),
      ChainType.tron => _lookupTron(rpcNode: rpcNode, record: record),
      ChainType.solana => _lookupSolana(rpcNode: rpcNode, record: record),
      ChainType.sui => _lookupSui(rpcNode: rpcNode, record: record),
    };
  }

  Future<TransactionStatusUpdate?> _lookupSui({
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    final status = await _suiService.getTransactionStatus(
      rpcUrl: rpcNode.endpointUrl,
      digest: record.transactionHash,
      headers: rpcNode.endpointHeaders,
    );
    return switch (status) {
      SuiTransactionExecutionStatus.success => const TransactionStatusUpdate(
        status: TransactionStatus.success,
      ),
      SuiTransactionExecutionStatus.failed => const TransactionStatusUpdate(
        status: TransactionStatus.failed,
        failureReason: 'suiExecutionStatusFailed',
      ),
      null => null,
    };
  }

  Future<TransactionStatusUpdate?> _lookupEvm({
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    final httpClient = rpcNode.endpointHeaders.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: rpcNode.endpointHeaders);
    final client = web3.Web3Client(rpcNode.endpointUrl, httpClient);
    try {
      final receipt = await client.getTransactionReceipt(
        record.transactionHash,
      );
      final status = receipt?.status;
      if (status == null) {
        return null;
      }
      return TransactionStatusUpdate(
        status: status ? TransactionStatus.success : TransactionStatus.failed,
        failureReason: status ? null : 'evmReceiptStatusFailed',
      );
    } finally {
      client.dispose();
    }
  }

  Future<TransactionStatusUpdate?> _lookupSolana({
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    final httpClient = rpcNode.endpointHeaders.isEmpty
        ? BoundedHttpClient()
        : HeaderHttpClient(headers: rpcNode.endpointHeaders);
    final connection = solana.Connection(
      rpcNode.endpointUrl,
      httpClient: httpClient,
    );
    try {
      final response = await connection.getSignatureStatus(
        record.transactionHash,
        searchTransactionHistory: true,
      );
      final status = response.value;
      if (status == null) {
        return null;
      }
      if (status.err != null) {
        return const TransactionStatusUpdate(
          status: TransactionStatus.failed,
          failureReason: 'solanaSignatureStatusFailed',
        );
      }
      return switch (status.confirmationStatus) {
        'confirmed' || 'finalized' => const TransactionStatusUpdate(
          status: TransactionStatus.success,
        ),
        _ => null,
      };
    } finally {
      await connection.close();
    }
  }

  Future<TransactionStatusUpdate?> _lookupBitcoin({
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    final client = _bitcoinClient ?? BoundedHttpClient();
    final ownsClient = _bitcoinClient == null;
    try {
      final response = await client.get(
        _bitcoinEndpoint(
          rpcNode.endpointUrl,
          '/tx/${Uri.encodeComponent(record.transactionHash)}/status',
        ),
        headers: rpcNode.endpointHeaders,
      );
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Bitcoin status lookup failed with HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return switch (decoded['confirmed']) {
        true => const TransactionStatusUpdate(
          status: TransactionStatus.success,
        ),
        _ => null,
      };
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  Future<TransactionStatusUpdate?> _lookupTron({
    required RpcNode rpcNode,
    required TransactionRecord record,
  }) async {
    final client = _tronClient ?? BoundedHttpClient();
    final ownsClient = _tronClient == null;
    try {
      final response = await client.post(
        _tronEndpoint(
          rpcNode.endpointUrl,
          '/walletsolidity/gettransactioninfobyid',
        ),
        headers: {
          'content-type': 'application/json',
          ...rpcNode.endpointHeaders,
        },
        body: jsonEncode({'value': record.transactionHash}),
      );
      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Tron status lookup failed with HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        return null;
      }
      final receipt = decoded['receipt'];
      if (receipt is! Map<String, dynamic>) {
        return null;
      }
      final result = receipt['result'];
      if (result == 'SUCCESS') {
        return const TransactionStatusUpdate(status: TransactionStatus.success);
      }
      if (result is String && result.isNotEmpty) {
        return const TransactionStatusUpdate(
          status: TransactionStatus.failed,
          failureReason: 'tronReceiptStatusFailed',
        );
      }
      return null;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}

Uri _bitcoinEndpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}

Uri _tronEndpoint(String apiBaseUrl, String path) {
  final base = Uri.parse(apiBaseUrl);
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$normalizedBasePath$path');
}
