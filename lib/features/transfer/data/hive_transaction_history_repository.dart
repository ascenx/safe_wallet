import '../../../shared/storage/hive_box_registry.dart';
import '../../../shared/storage/json_codec.dart';
import '../../chains/domain/chain_config.dart';
import '../domain/transaction_record.dart';
import 'transaction_history_repository.dart';

final class HiveTransactionHistoryRepository
    implements
        TransactionHistoryRepository,
        WalletScopedTransactionHistoryRepository {
  HiveTransactionHistoryRepository({
    required HiveBoxRegistry registry,
    StorageJsonCodec codec = const StorageJsonCodec(),
  }) : _registry = registry,
       _codec = codec;

  final HiveBoxRegistry _registry;
  final StorageJsonCodec _codec;

  @override
  Future<void> save(TransactionRecord record) async {
    await _registry.transactionsBox.put(
      record.id,
      _codec.encode(_recordToJson(record)),
    );
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {
    final stored = _registry.transactionsBox.get(id);
    if (stored is! String) {
      return;
    }
    final record = _codec.tryDecode(stored, _recordFromJson);
    if (record == null) {
      return;
    }
    await save(
      TransactionRecord(
        id: record.id,
        walletId: record.walletId,
        chainId: record.chainId,
        chainType: record.chainType,
        assetSymbol: record.assetSymbol,
        direction: record.direction,
        amount: record.amount,
        status: status,
        transactionHash: record.transactionHash,
        createdAt: record.createdAt,
        fromAddress: record.fromAddress,
        toAddress: record.toAddress,
        memo: record.memo,
        failureReason: failureReason,
        operation: record.operation,
        resource: record.resource,
      ),
    );
  }

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    final records =
        _registry.transactionsBox.values
            .whereType<String>()
            .map((value) => _codec.tryDecode(value, _recordFromJson))
            .whereType<TransactionRecord>()
            .where((record) => chainId == null || record.chainId == chainId)
            .toList()
          ..sort(_newestFirst);
    return List.unmodifiable(records);
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    final records = await list(chainId: chainId);
    return List.unmodifiable(records.take(limit));
  }

  @override
  Future<List<TransactionRecord>> listForWallet({
    required String walletId,
    String? chainId,
  }) async {
    final records = (await list(
      chainId: chainId,
    )).where((record) => record.walletId == walletId).toList(growable: false);
    return List.unmodifiable(records);
  }

  @override
  Future<List<TransactionRecord>> recentForWallet({
    required String walletId,
    int limit = 4,
    String? chainId,
  }) async {
    final records = await listForWallet(walletId: walletId, chainId: chainId);
    return List.unmodifiable(records.take(limit));
  }

  @override
  Future<void> deleteForWallet(String walletId) async {
    final keys = <dynamic>[];
    for (final key in _registry.transactionsBox.keys) {
      final stored = _registry.transactionsBox.get(key);
      if (stored is! String) {
        continue;
      }
      final record = _codec.tryDecode(stored, _recordFromJson);
      if (record == null) {
        continue;
      }
      if (record.walletId == walletId) {
        keys.add(key);
      }
    }
    await _registry.transactionsBox.deleteAll(keys);
  }

  int _newestFirst(TransactionRecord left, TransactionRecord right) {
    return right.createdAt.compareTo(left.createdAt);
  }

  Map<String, Object?> _recordToJson(TransactionRecord record) {
    return {
      'id': record.id,
      'walletId': record.walletId,
      'chainId': record.chainId,
      'chainType': record.chainType.name,
      'assetSymbol': record.assetSymbol,
      'direction': record.direction.name,
      'amount': record.amount,
      'status': record.status.name,
      'transactionHash': record.transactionHash,
      'createdAt': record.createdAt.toIso8601String(),
      'fromAddress': record.fromAddress,
      'toAddress': record.toAddress,
      'memo': record.memo,
      'failureReason': record.failureReason,
      'operation': record.operation.name,
      'resource': record.resource,
    };
  }

  TransactionRecord _recordFromJson(Map<String, Object?> json) {
    return TransactionRecord(
      id: json['id'] as String,
      walletId: json['walletId'] as String?,
      chainId: json['chainId'] as String,
      chainType: ChainType.values.byName(json['chainType'] as String),
      assetSymbol: json['assetSymbol'] as String,
      direction: TransactionDirection.values.byName(
        json['direction'] as String,
      ),
      amount: json['amount'] as String,
      status: TransactionStatus.values.byName(json['status'] as String),
      transactionHash: json['transactionHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      fromAddress: json['fromAddress'] as String?,
      toAddress: json['toAddress'] as String?,
      memo: json['memo'] as String?,
      failureReason: json['failureReason'] as String?,
      operation: _operationFromJson(json['operation']),
      resource: json['resource'] as String?,
    );
  }
}

TransactionOperation _operationFromJson(Object? value) {
  if (value is! String) {
    return TransactionOperation.transfer;
  }
  return TransactionOperation.values
          .where((operation) => operation.name == value)
          .firstOrNull ??
      TransactionOperation.transfer;
}
