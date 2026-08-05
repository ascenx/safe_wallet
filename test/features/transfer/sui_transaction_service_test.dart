import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/transfer/data/sui_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/shared/errors/transfer_error.dart';
import 'package:sui_dart/core/sui_core_client.dart';
import 'package:sui_dart/grpc/types.dart';
import 'package:sui_dart/sui.dart' as sui;

void main() {
  const from =
      '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133';
  const to =
      '0x0000000000000000000000000000000000000000000000000000000000000002';

  test('builds and simulates a native SUI transfer with the gas coin',
      () async {
    final rpc = _FakeSuiTransactionRpc();
    final service = SdkSuiTransactionService(rpc: rpc);
    const request = TransactionRequest(
      chainId: 'sui:mainnet',
      chainType: ChainType.sui,
      assetSymbol: 'SUI',
      toAddress: to,
      amount: '0.000000123',
      amountInBaseUnits: '123',
      tokenDecimals: 9,
      transactionType: TransactionType.suiTransfer,
    );

    final estimate = await service.estimateTransferFee(
      const SuiTransferInput(
        rpcUrl: 'https://fullnode.mainnet.sui.io:443',
        fromAddress: from,
        transaction: request,
      ),
    );

    expect(estimate.estimatedFeeMist, BigInt.from(900));
    expect(estimate.gasBudgetMist, BigInt.from(1200));
    final transaction = rpc.simulatedTransactions.single;
    expect(transaction.getData().sender, from);
    final intent = transaction.getData().commands!.first[r'$Intent'] as Map;
    expect(intent['name'], 'CoinWithBalance');
    expect(intent['data']['type'], 'gas');
    expect(intent['data']['balance'], BigInt.from(123));
    expect(
      transaction.getData().commands!.last[r'$kind'],
      'TransferObjects',
    );
  });

  test('builds a custom Coin transfer and signs with Ed25519 key material',
      () async {
    final rpc = _FakeSuiTransactionRpc();
    final service = SdkSuiTransactionService(rpc: rpc);
    const request = TransactionRequest(
      chainId: 'sui:mainnet',
      chainType: ChainType.sui,
      assetSymbol: 'USDC',
      toAddress: to,
      amount: '1.2345',
      amountInBaseUnits: '1234500',
      tokenDecimals: 6,
      transactionType: TransactionType.suiTransfer,
      tokenContractAddress: '0xabc::usdc::USDC',
    );
    final privateKey = List<int>.generate(32, (index) => index + 1);

    final digest = await service.signAndBroadcast(
      SuiTransactionBroadcastInput(
        rpcUrl: 'https://fullnode.mainnet.sui.io:443',
        privateKey: privateKey,
        fromAddress: from,
        transaction: request,
      ),
    );

    expect(digest, '7SuiDigest');
    expect(rpc.executedPrivateKeys.single, privateKey);
    final transaction = rpc.executedTransactions.single;
    final intent = transaction.getData().commands!.first[r'$Intent'] as Map;
    expect(
      intent['data']['type'],
      '0x0000000000000000000000000000000000000000000000000000000000000abc::usdc::USDC',
    );
    expect(intent['data']['balance'], BigInt.from(1234500));
  });

  test('rejects missing or non-positive transfer base units', () async {
    final service = SdkSuiTransactionService(rpc: _FakeSuiTransactionRpc());
    for (final amount in const [null, '0', '-1']) {
      final request = TransactionRequest(
        chainId: 'sui:mainnet',
        chainType: ChainType.sui,
        assetSymbol: 'SUI',
        toAddress: to,
        amount: '0',
        amountInBaseUnits: amount,
        tokenDecimals: 9,
        transactionType: TransactionType.suiTransfer,
      );

      await expectLater(
        service.estimateTransferFee(
          SuiTransferInput(
            rpcUrl: 'https://fullnode.mainnet.sui.io:443',
            fromAddress: from,
            transaction: request,
          ),
        ),
        throwsArgumentError,
      );
    }
  });

  test('custom Coin resolution merges multiple objects and splits exact amount',
      () async {
    final rpc = _FakeSuiTransactionRpc();
    final service = SdkSuiTransactionService(rpc: rpc);
    const request = TransactionRequest(
      chainId: 'sui:mainnet',
      chainType: ChainType.sui,
      assetSymbol: 'USDC',
      toAddress: to,
      amount: '0.001',
      amountInBaseUnits: '1000',
      tokenDecimals: 6,
      transactionType: TransactionType.suiTransfer,
      tokenContractAddress: '0xabc::usdc::USDC',
    );
    await service.estimateTransferFee(
      const SuiTransferInput(
        rpcUrl: 'https://fullnode.mainnet.sui.io:443',
        fromAddress: from,
        transaction: request,
      ),
    );
    final transaction = rpc.simulatedTransactions.single;

    await transaction.prepareForSerialization(
      sui.SerializeTransactionOptions(
        client: _FakeSuiCoreClient([
          _coin(objectId: '0x1', balance: '600'),
          _coin(objectId: '0x2', balance: '700'),
        ]),
      ),
    );

    final commandKinds = transaction
        .getData()
        .commands!
        .map((command) => command[r'$kind'])
        .toList();
    expect(commandKinds, contains('MergeCoins'));
    expect(commandKinds, contains('SplitCoins'));
    expect(commandKinds.last, 'TransferObjects');
  });

  test('custom Coin resolution rejects insufficient aggregate balance',
      () async {
    final rpc = _FakeSuiTransactionRpc();
    final service = SdkSuiTransactionService(rpc: rpc);
    const request = TransactionRequest(
      chainId: 'sui:mainnet',
      chainType: ChainType.sui,
      assetSymbol: 'USDC',
      toAddress: to,
      amount: '0.001',
      amountInBaseUnits: '1000',
      tokenDecimals: 6,
      transactionType: TransactionType.suiTransfer,
      tokenContractAddress: '0xabc::usdc::USDC',
    );
    await service.estimateTransferFee(
      const SuiTransferInput(
        rpcUrl: 'https://fullnode.mainnet.sui.io:443',
        fromAddress: from,
        transaction: request,
      ),
    );

    await expectLater(
      rpc.simulatedTransactions.single.prepareForSerialization(
        sui.SerializeTransactionOptions(
          client: _FakeSuiCoreClient([
            _coin(objectId: '0x1', balance: '999'),
          ]),
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Insufficient balance'),
        ),
      ),
    );
  });

  test('custom Coin resolution excludes objects already used by the PTB',
      () async {
    final rpc = _FakeSuiTransactionRpc();
    final service = SdkSuiTransactionService(rpc: rpc);
    const request = TransactionRequest(
      chainId: 'sui:mainnet',
      chainType: ChainType.sui,
      assetSymbol: 'USDC',
      toAddress: to,
      amount: '0.001',
      amountInBaseUnits: '1000',
      tokenDecimals: 6,
      transactionType: TransactionType.suiTransfer,
      tokenContractAddress: '0xabc::usdc::USDC',
    );
    await service.estimateTransferFee(
      const SuiTransferInput(
        rpcUrl: 'https://fullnode.mainnet.sui.io:443',
        fromAddress: from,
        transaction: request,
      ),
    );
    final transaction = rpc.simulatedTransactions.single;
    transaction.object('0x1');

    await expectLater(
      transaction.prepareForSerialization(
        sui.SerializeTransactionOptions(
          client: _FakeSuiCoreClient([
            _coin(objectId: '0x1', balance: '1000'),
            _coin(objectId: '0x2', balance: '500'),
          ]),
        ),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('classifies insufficient gas, Coin balance, and stale object failures',
      () {
    expect(
      suiTransferErrorFromFailure('Insufficient gas balance'),
      isA<TransferError>().having(
        (error) => error.code,
        'code',
        'sui_insufficient_gas',
      ),
    );
    expect(
      suiTransferErrorFromFailure('Insufficient balance of 0xabc::coin::USDC'),
      isA<TransferError>().having(
        (error) => error.code,
        'code',
        'sui_insufficient_balance',
      ),
    );
    expect(
      suiTransferErrorFromFailure('Object version is stale'),
      isA<TransferError>().having(
        (error) => error.code,
        'code',
        'sui_object_conflict',
      ),
    );
  });
}

final class _FakeSuiTransactionRpc implements SuiTransactionRpc {
  final simulatedTransactions = <sui.Transaction>[];
  final executedTransactions = <sui.Transaction>[];
  final executedPrivateKeys = <List<int>>[];

  @override
  Future<SuiTransactionSimulation> simulate({
    required String rpcUrl,
    required sui.Transaction transaction,
    Map<String, String> headers = const {},
  }) async {
    simulatedTransactions.add(transaction);
    return SuiTransactionSimulation(
      estimatedFeeMist: BigInt.from(900),
      gasBudgetMist: BigInt.from(1200),
    );
  }

  @override
  Future<String> signAndExecute({
    required String rpcUrl,
    required sui.Transaction transaction,
    required List<int> privateKey,
    Map<String, String> headers = const {},
  }) async {
    executedTransactions.add(transaction);
    executedPrivateKeys.add(List.unmodifiable(privateKey));
    return '7SuiDigest';
  }

  @override
  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  }) async {
    return null;
  }
}

CoinData _coin({required String objectId, required String balance}) {
  return CoinData(
    objectId: objectId,
    version: '1',
    digest: '11111111111111111111111111111111',
    owner: const AddressOwner('0x1'),
    type:
        '0x0000000000000000000000000000000000000000000000000000000000000abc::usdc::USDC',
    balance: balance,
  );
}

final class _FakeSuiCoreClient implements SuiCoreClient {
  _FakeSuiCoreClient(this.coins);

  final List<CoinData> coins;

  @override
  Future<Page<CoinData>> getCoins(
    String address, {
    String coinType = '0x2::sui::SUI',
    String? cursor,
    int? limit,
  }) async {
    return Page(data: coins, hasNextPage: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
