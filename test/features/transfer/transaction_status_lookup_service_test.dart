import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/data/transaction_status_lookup_service.dart';
import 'package:safe_wallet/features/transfer/data/sui_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';

void main() {
  group('DefaultTransactionStatusLookupService Bitcoin', () {
    test('returns success for confirmed transactions', () async {
      final service = DefaultTransactionStatusLookupService(
        bitcoinClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://blockstream.info/api/tx/abc123/status',
          );
          return http.Response(jsonEncode({'confirmed': true}), 200);
        }),
      );

      final update = await service.lookup(
        chain: _bitcoin,
        rpcNode: _bitcoinNode,
        record: _record(transactionHash: 'abc123'),
      );

      expect(update?.status, TransactionStatus.success);
      expect(update?.failureReason, isNull);
    });

    test('returns null for unconfirmed transactions', () async {
      final service = DefaultTransactionStatusLookupService(
        bitcoinClient: MockClient((request) async {
          return http.Response(jsonEncode({'confirmed': false}), 200);
        }),
      );

      final update = await service.lookup(
        chain: _bitcoin,
        rpcNode: _bitcoinNode,
        record: _record(transactionHash: 'abc123'),
      );

      expect(update, isNull);
    });
  });

  group('DefaultTransactionStatusLookupService Tron', () {
    test('returns success for confirmed successful transactions', () async {
      final service = DefaultTransactionStatusLookupService(
        tronClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.trongrid.io/walletsolidity/gettransactioninfobyid',
          );
          expect(jsonDecode(request.body), {'value': 'tronTxId'});
          return http.Response(
            jsonEncode({
              'id': 'tronTxId',
              'receipt': {'result': 'SUCCESS'},
            }),
            200,
          );
        }),
      );

      final update = await service.lookup(
        chain: _tron,
        rpcNode: _tronNode,
        record: _record(
          transactionHash: 'tronTxId',
          chainType: _tron.chainType,
          chainId: _tron.chainId,
          assetSymbol: 'TRX',
        ),
      );

      expect(update?.status, TransactionStatus.success);
      expect(update?.failureReason, isNull);
    });

    test('returns failed for confirmed failed transactions', () async {
      final service = DefaultTransactionStatusLookupService(
        tronClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 'tronTxId',
              'receipt': {'result': 'OUT_OF_ENERGY'},
            }),
            200,
          );
        }),
      );

      final update = await service.lookup(
        chain: _tron,
        rpcNode: _tronNode,
        record: _record(
          transactionHash: 'tronTxId',
          chainType: _tron.chainType,
          chainId: _tron.chainId,
          assetSymbol: 'TRX',
        ),
      );

      expect(update?.status, TransactionStatus.failed);
      expect(update?.failureReason, 'tronReceiptStatusFailed');
    });

    test('returns null while transaction info is not available yet', () async {
      final service = DefaultTransactionStatusLookupService(
        tronClient: MockClient((request) async {
          return http.Response(jsonEncode({}), 200);
        }),
      );

      final update = await service.lookup(
        chain: _tron,
        rpcNode: _tronNode,
        record: _record(
          transactionHash: 'tronTxId',
          chainType: _tron.chainType,
          chainId: _tron.chainId,
          assetSymbol: 'TRX',
        ),
      );

      expect(update, isNull);
    });
  });

  group('DefaultTransactionStatusLookupService Sui', () {
    test('maps successful execution and forwards digest to gRPC service',
        () async {
      final suiService = _FakeSuiTransactionService(
        status: SuiTransactionExecutionStatus.success,
      );
      final service = DefaultTransactionStatusLookupService(
        suiService: suiService,
      );

      final update = await service.lookup(
        chain: _sui,
        rpcNode: _suiNode,
        record: _record(
          transactionHash: '7SuiDigest',
          chainType: ChainType.sui,
          chainId: _sui.chainId,
          assetSymbol: 'SUI',
        ),
      );

      expect(update?.status, TransactionStatus.success);
      expect(update?.failureReason, isNull);
      expect(suiService.digests, ['7SuiDigest']);
      expect(suiService.rpcUrls, ['https://fullnode.mainnet.sui.io:443']);
    });

    test('maps failed execution to a stable failure reason', () async {
      final service = DefaultTransactionStatusLookupService(
        suiService: _FakeSuiTransactionService(
          status: SuiTransactionExecutionStatus.failed,
        ),
      );

      final update = await service.lookup(
        chain: _sui,
        rpcNode: _suiNode,
        record: _record(
          transactionHash: 'failedDigest',
          chainType: ChainType.sui,
          chainId: _sui.chainId,
          assetSymbol: 'SUI',
        ),
      );

      expect(update?.status, TransactionStatus.failed);
      expect(update?.failureReason, 'suiExecutionStatusFailed');
    });

    test('returns null while a Sui digest is not available', () async {
      final service = DefaultTransactionStatusLookupService(
        suiService: _FakeSuiTransactionService(status: null),
      );

      final update = await service.lookup(
        chain: _sui,
        rpcNode: _suiNode,
        record: _record(
          transactionHash: 'pendingDigest',
          chainType: ChainType.sui,
          chainId: _sui.chainId,
          assetSymbol: 'SUI',
        ),
      );

      expect(update, isNull);
    });
  });
}

final _bitcoin =
    defaultChains.firstWhere((chain) => chain.id == 'bitcoin-mainnet');
final _tron = defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet');
final _sui = defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');

const _bitcoinNode = RpcNode(
  id: 'bitcoin-mainnet-default',
  chainId: 'bitcoin-mainnet',
  name: 'Blockstream',
  url: 'https://blockstream.info/api',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.untested,
);

const _tronNode = RpcNode(
  id: 'tron-mainnet-default',
  chainId: 'tron-mainnet',
  name: 'TronGrid',
  url: 'https://api.trongrid.io',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.untested,
);

const _suiNode = RpcNode(
  id: 'sui-mainnet-default',
  chainId: 'sui:mainnet',
  name: 'Sui Fullnode',
  url: 'https://fullnode.mainnet.sui.io:443',
  nodeType: RpcNodeType.defaultNode,
  isSelected: true,
  lastTestStatus: RpcNodeTestStatus.untested,
);

TransactionRecord _record({
  required String transactionHash,
  ChainType? chainType,
  String? chainId,
  String? assetSymbol,
}) {
  return TransactionRecord(
    id: 'tx-1',
    chainId: chainId ?? 'bitcoin-mainnet',
    chainType: chainType ?? _bitcoin.chainType,
    assetSymbol: assetSymbol ?? 'BTC',
    direction: TransactionDirection.outgoing,
    amount: '0.01',
    status: TransactionStatus.submitted,
    transactionHash: transactionHash,
    createdAt: DateTime(2026),
  );
}

final class _FakeSuiTransactionService implements SuiTransactionService {
  _FakeSuiTransactionService({required this.status});

  final SuiTransactionExecutionStatus? status;
  final digests = <String>[];
  final rpcUrls = <String>[];

  @override
  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  }) async {
    rpcUrls.add(rpcUrl);
    digests.add(digest);
    return status;
  }

  @override
  Future<SuiTransactionSimulation> estimateTransferFee(
    SuiTransferInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<String> signAndBroadcast(SuiTransactionBroadcastInput input) {
    throw UnimplementedError();
  }
}
