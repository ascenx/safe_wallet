import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/advanced/application/evm_contract_call_controller.dart';
import 'package:safe_wallet/features/advanced/data/evm_contract_call_gateway.dart';
import 'package:safe_wallet/features/advanced/domain/evm_contract_abi.dart';
import 'package:safe_wallet/features/assets/application/asset_portfolio_provider.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/settings/application/security_log_recorder.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  test('reads and decodes a contract function result', () async {
    final gateway = _FakeGateway()
      ..readResult = '0x${BigInt.from(42).toRadixString(16).padLeft(64, '0')}';
    final controller = _controller(gateway: gateway);
    final function = EvmContractAbi.erc20.functions.firstWhere(
      (item) => item.signature == 'balanceOf(address)',
    );

    final result = await controller.read(
      context: _request,
      contractAddress: _contractAddress,
      calldata: function.encodeCall([_walletAddress]),
      function: function,
    );

    expect(result.decodedValues, ['42']);
    expect(gateway.codeChecks, [_contractAddress]);
  });

  test(
    'submits a prepared write and stores a local transaction record',
    () async {
      final gateway = _FakeGateway()..transactionHash = '0xhash';
      final history = _MemoryHistoryRepository();
      final cache = SessionKeyCache()
        ..unlock(walletId: _account.id, walletDek: const [1, 2, 3], now: _now);
      final controller = _controller(
        gateway: gateway,
        history: history,
        cache: cache,
      );
      final preparation = EvmContractWritePreparation(
        chainId: 1,
        fromAddress: _walletAddress,
        contractAddress: _contractAddress,
        calldata: '0xa9059cbb',
        valueWei: BigInt.zero,
        gasLimit: 30000,
        gasPriceWei: BigInt.from(1000000000),
        nonce: 7,
      );

      final hash = await controller.submitWrite(
        context: _request,
        preparation: preparation,
        functionSignature: 'transfer(address,uint256)',
      );

      expect(hash, '0xhash');
      expect(history.records, hasLength(1));
      expect(history.records.single.transactionHash, '0xhash');
      expect(history.records.single.toAddress, _contractAddress);
      expect(history.records.single.memo, 'transfer(address,uint256)');
    },
  );

  test(
    'completed contract write returns its hash when history save fails',
    () async {
      final gateway = _FakeGateway()..transactionHash = '0xhash';
      final history = _MemoryHistoryRepository(
        saveError: StateError('disk full'),
      );
      final cache = SessionKeyCache()
        ..unlock(walletId: _account.id, walletDek: const [1, 2, 3], now: _now);
      final controller = _controller(
        gateway: gateway,
        history: history,
        cache: cache,
      );

      final hash = await controller.submitWrite(
        context: _request,
        preparation: EvmContractWritePreparation(
          chainId: 1,
          fromAddress: _walletAddress,
          contractAddress: _contractAddress,
          calldata: '0xa9059cbb',
          valueWei: BigInt.zero,
          gasLimit: 30000,
          gasPriceWei: BigInt.from(1000000000),
          nonce: 7,
        ),
      );

      expect(hash, '0xhash');
    },
  );
}

EvmContractCallController _controller({
  required _FakeGateway gateway,
  _MemoryHistoryRepository? history,
  SessionKeyCache? cache,
}) {
  return EvmContractCallController(
    gateway: gateway,
    walletRepository: _FakeWalletRepository(),
    sessionKeyCache: cache ?? SessionKeyCache(),
    transactionHistoryRepository: history ?? _MemoryHistoryRepository(),
    securityLogRecorder: SecurityLogRecorder(InMemorySecurityLogRepository()),
    clock: () => _now,
  );
}

final _chain = defaultChains.first;
final _now = DateTime.utc(2026, 8, 1, 12);
const _walletAddress = '0x2222222222222222222222222222222222222222';
const _contractAddress = '0x1111111111111111111111111111111111111111';
final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: _walletAddress,
  solanaAddress: '',
  createdAt: _now,
  updatedAt: _now,
);
final _request = AssetPortfolioRequest(
  account: _account,
  chain: _chain,
  rpcNode: const RpcNode(
    id: 'rpc-1',
    chainId: '1',
    name: 'RPC',
    url: 'https://rpc.example.com',
    nodeType: RpcNodeType.defaultNode,
    isSelected: true,
    lastTestStatus: RpcNodeTestStatus.available,
  ),
);

final class _FakeGateway implements EvmContractCallGateway {
  final codeChecks = <String>[];
  String readResult = '0x';
  String transactionHash = '0xhash';

  @override
  Future<bool> hasContractCode({
    required String rpcUrl,
    required String contractAddress,
    Map<String, String> headers = const {},
  }) async {
    codeChecks.add(contractAddress);
    return true;
  }

  @override
  Future<String> read({
    required String rpcUrl,
    required String fromAddress,
    required String contractAddress,
    required String calldata,
    Map<String, String> headers = const {},
  }) async => readResult;

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
    return EvmContractWritePreparation(
      chainId: chainId,
      fromAddress: fromAddress,
      contractAddress: contractAddress,
      calldata: calldata,
      valueWei: valueWei,
      gasLimit: 30000,
      gasPriceWei: BigInt.from(1000000000),
      nonce: 7,
    );
  }

  @override
  Future<String> sendWrite({
    required String rpcUrl,
    required String privateKey,
    required EvmContractWritePreparation preparation,
    Map<String, String> headers = const {},
  }) async => transactionHash;
}

final class _MemoryHistoryRepository implements TransactionHistoryRepository {
  _MemoryHistoryRepository({this.saveError});

  final Object? saveError;
  final records = <TransactionRecord>[];

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async => records;

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async => records.take(limit).toList();

  @override
  Future<void> save(TransactionRecord record) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    records.add(record);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _FakeWalletRepository implements WalletRepository {
  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    return WalletKeyMaterial(evmPrivateKey: '01');
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    return WalletUnlockResult(account: _account, walletDek: const [1, 2, 3]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
