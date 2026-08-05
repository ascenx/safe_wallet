import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/security/session_key_cache.dart';
import '../../assets/application/asset_portfolio_provider.dart';
import '../../chains/domain/chain_config.dart';
import '../../settings/application/security_log_recorder.dart';
import '../../settings/domain/security_log_entry.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../transfer/data/transaction_history_repository.dart';
import '../../transfer/domain/transaction_record.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/evm_contract_call_gateway.dart';
import '../domain/evm_contract_abi.dart';

typedef EvmContractCallClock = DateTime Function();

final evmContractCallGatewayProvider = Provider<EvmContractCallGateway>((ref) {
  return HttpEvmContractCallGateway();
});

final evmContractCallClockProvider = Provider<EvmContractCallClock>((ref) {
  return () => DateTime.now().toUtc();
});

final evmContractCallControllerProvider = Provider<EvmContractCallController>((
  ref,
) {
  return EvmContractCallController(
    gateway: ref.watch(evmContractCallGatewayProvider),
    walletRepository: ref.watch(walletRepositoryProvider),
    sessionKeyCache: ref.watch(sessionKeyCacheProvider),
    transactionHistoryRepository: ref.watch(
      transactionHistoryRepositoryProvider,
    ),
    securityLogRecorder: ref.watch(securityLogRecorderProvider),
    clock: ref.watch(evmContractCallClockProvider),
  );
});

final class EvmContractReadResult {
  const EvmContractReadResult({
    required this.rawValue,
    required this.decodedValues,
  });

  final String rawValue;
  final List<String> decodedValues;
}

final class EvmContractCallController {
  const EvmContractCallController({
    required EvmContractCallGateway gateway,
    required WalletRepository walletRepository,
    required SessionKeyCache sessionKeyCache,
    required TransactionHistoryRepository transactionHistoryRepository,
    required SecurityLogRecorder securityLogRecorder,
    required EvmContractCallClock clock,
  }) : _gateway = gateway,
       _walletRepository = walletRepository,
       _sessionKeyCache = sessionKeyCache,
       _transactionHistoryRepository = transactionHistoryRepository,
       _securityLogRecorder = securityLogRecorder,
       _clock = clock;

  final EvmContractCallGateway _gateway;
  final WalletRepository _walletRepository;
  final SessionKeyCache _sessionKeyCache;
  final TransactionHistoryRepository _transactionHistoryRepository;
  final SecurityLogRecorder _securityLogRecorder;
  final EvmContractCallClock _clock;

  Future<EvmContractReadResult> read({
    required AssetPortfolioRequest context,
    required String contractAddress,
    required String calldata,
    EvmContractFunction? function,
  }) async {
    _requireEvm(context);
    await _requireContractCode(context, contractAddress);
    final rawValue = await _gateway.read(
      rpcUrl: context.rpcNode.endpointUrl,
      headers: context.rpcNode.endpointHeaders,
      fromAddress: context.account.evmAddress,
      contractAddress: contractAddress,
      calldata: calldata,
    );
    return EvmContractReadResult(
      rawValue: rawValue,
      decodedValues: function?.decodeResult(rawValue) ?? const [],
    );
  }

  Future<EvmContractWritePreparation> prepareWrite({
    required AssetPortfolioRequest context,
    required String contractAddress,
    required String calldata,
    required BigInt valueWei,
  }) async {
    _requireEvm(context);
    await _requireContractCode(context, contractAddress);
    return _gateway.prepareWrite(
      rpcUrl: context.rpcNode.endpointUrl,
      headers: context.rpcNode.endpointHeaders,
      chainId: int.parse(context.chain.chainId),
      fromAddress: context.account.evmAddress,
      contractAddress: contractAddress,
      calldata: calldata,
      valueWei: valueWei,
    );
  }

  Future<String> submitWrite({
    required AssetPortfolioRequest context,
    required EvmContractWritePreparation preparation,
    String? functionSignature,
    String? signingPassword,
    bool rememberSigningPassword = true,
  }) async {
    _requireEvm(context);
    final now = _clock();
    final keyMaterial = await _readKeyMaterial(
      context,
      now: now,
      signingPassword: signingPassword,
      rememberSigningPassword: rememberSigningPassword,
    );
    final privateKey = keyMaterial.evmPrivateKey;
    if (privateKey == null || privateKey.isEmpty) {
      throw const EvmContractCallException('missingEvmPrivateKey');
    }
    final hash = await _gateway.sendWrite(
      rpcUrl: context.rpcNode.endpointUrl,
      headers: context.rpcNode.endpointHeaders,
      privateKey: privateKey,
      preparation: preparation,
    );
    await _securityLogRecorder.record(
      SecurityLogEventType.signTransaction,
      walletName: context.account.name,
      chainName: context.chain.name,
      assetSymbol: context.chain.symbol,
      amount: _formatUnits(preparation.valueWei, 18),
    );
    try {
      await _transactionHistoryRepository.save(
        TransactionRecord(
          id: 'contract-${now.microsecondsSinceEpoch}',
          walletId: context.account.id,
          chainId: context.chain.chainId,
          chainType: context.chain.chainType,
          assetSymbol: context.chain.symbol,
          direction: TransactionDirection.outgoing,
          amount: _formatUnits(preparation.valueWei, 18),
          status: TransactionStatus.submitted,
          transactionHash: hash,
          createdAt: now,
          fromAddress: context.account.evmAddress,
          toAddress: preparation.contractAddress,
          memo: functionSignature ?? 'raw calldata',
        ),
      );
    } catch (_) {
      // A transaction hash proves the write was submitted. Local history is a
      // secondary effect and must not turn this into a retryable send error.
    }
    return hash;
  }

  Future<WalletKeyMaterial> _readKeyMaterial(
    AssetPortfolioRequest context, {
    required DateTime now,
    required String? signingPassword,
    required bool rememberSigningPassword,
  }) async {
    var walletDek = _sessionKeyCache.readKey(context.account.id, now: now);
    if (walletDek == null) {
      if (signingPassword == null || signingPassword.isEmpty) {
        throw const EvmContractCallException('walletLocked');
      }
      final unlockResult = await _walletRepository.unlock(
        walletId: context.account.id,
        password: signingPassword,
      );
      walletDek = unlockResult.walletDek;
      if (rememberSigningPassword) {
        _sessionKeyCache.unlock(
          walletId: context.account.id,
          walletDek: walletDek,
          now: now,
        );
      }
    } else {
      _sessionKeyCache.touch(now: now);
    }
    return _walletRepository.readKeyMaterial(
      walletId: context.account.id,
      walletDek: walletDek,
    );
  }

  Future<void> _requireContractCode(
    AssetPortfolioRequest context,
    String contractAddress,
  ) async {
    final hasCode = await _gateway.hasContractCode(
      rpcUrl: context.rpcNode.endpointUrl,
      headers: context.rpcNode.endpointHeaders,
      contractAddress: contractAddress,
    );
    if (!hasCode) {
      throw const EvmContractCallException('notContract');
    }
  }

  void _requireEvm(AssetPortfolioRequest context) {
    if (context.chain.chainType != ChainType.evm) {
      throw const EvmContractCallException('unsupportedChain');
    }
  }
}

final class EvmContractCallException implements Exception {
  const EvmContractCallException(this.code);

  final String code;

  @override
  String toString() => code;
}

String _formatUnits(BigInt value, int decimals) {
  final base = BigInt.from(10).pow(decimals);
  final whole = value ~/ base;
  final fraction = (value % base)
      .toString()
      .padLeft(decimals, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}
