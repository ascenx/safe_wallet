import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/transfer/application/fee_estimate_provider.dart';
import 'package:safe_wallet/features/transfer/application/transaction_broadcast_controller.dart';
import 'package:safe_wallet/features/transfer/application/transaction_confirm_controller.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/bitcoin_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/evm_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/solana_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/sui_transaction_service.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/data/tron_transaction_service.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_confirm_page.dart';
import 'package:safe_wallet/features/transfer/presentation/transaction_result_page.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/errors/error_localizer.dart';
import 'package:safe_wallet/shared/errors/transfer_error.dart';
import 'package:safe_wallet/shared/network/external_url_launcher.dart';
import 'package:safe_wallet/shared/security/session_key_cache.dart';

void main() {
  group('TransactionBroadcastController', () {
    late ChainConfig ethereum;
    late ChainConfig bitcoin;
    late ChainConfig tron;
    late ChainConfig solana;
    late ChainConfig sui;

    setUp(() {
      ethereum = defaultChains.firstWhere((chain) => chain.id == 'ethereum');
      bitcoin = defaultChains.firstWhere(
        (chain) => chain.id == 'bitcoin-mainnet',
      );
      tron = defaultChains.firstWhere((chain) => chain.id == 'tron-mainnet');
      solana = defaultChains.firstWhere(
        (chain) => chain.id == 'solana-mainnet',
      );
      sui = defaultChains.firstWhere((chain) => chain.id == 'sui-mainnet');
    });

    test('locked wallet blocks signing', () async {
      final evmService = _FakeEvmTransactionService(result: '0xhash');
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: history,
      );

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(_broadcastRequest(chain: ethereum));

      expect(state.status, TransactionBroadcastStatus.failure);
      expect(state.error?.safeMessageKey, 'errors.walletLocked');
      expect(evmService.calls, isEmpty);
      expect(history.savedRecords, isEmpty);
    });

    test('successful EVM native broadcast saves transaction record', () async {
      final evmService = _FakeEvmTransactionService(result: '0xabc123');
      final history = _RecordingTransactionHistoryRepository();
      final securityLogs = InMemorySecurityLogRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: history,
        securityLogRepository: securityLogs,
      );
      await _unlock(container);

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(_broadcastRequest(chain: ethereum));

      expect(state.status, TransactionBroadcastStatus.success);
      expect(state.transactionHash, '0xabc123');
      expect(evmService.calls.single.privateKey, _evmPrivateKey);
      expect(
        evmService.calls.single.transaction.transactionType,
        TransactionType.nativeTransfer,
      );
      expect(history.savedRecords, hasLength(1));
      expect(history.savedRecords.single.status, TransactionStatus.submitted);
      expect(history.savedRecords.single.transactionHash, '0xabc123');
      expect(history.savedRecords.single.fromAddress, _account.evmAddress);
      final signingEntry = (await securityLogs.listEntries()).single;
      expect(signingEntry.type, SecurityLogEventType.signTransaction);
      expect(signingEntry.walletName, 'Wallet 1');
      expect(signingEntry.chainName, 'Ethereum');
      expect(signingEntry.assetSymbol, 'ETH');
      expect(signingEntry.amount, '0.1');
    });

    test(
      'history failure cannot turn a completed broadcast into failure',
      () async {
        final evmService = _FakeEvmTransactionService(result: '0xabc123');
        final history = _RecordingTransactionHistoryRepository(
          saveError: StateError('disk full'),
        );
        final container = _container(
          walletRepository: _FakeWalletRepository(),
          evmService: evmService,
          historyRepository: history,
        );
        await _unlock(container);

        final state = await container
            .read(transactionBroadcastControllerProvider.notifier)
            .submit(_broadcastRequest(chain: ethereum));

        expect(state.status, TransactionBroadcastStatus.success);
        expect(state.transactionHash, '0xabc123');
        expect(state.record?.transactionHash, '0xabc123');
      },
    );

    test('concurrent submissions share one in-flight broadcast', () async {
      final completer = Completer<String>();
      final evmService = _FakeEvmTransactionService(completer: completer);
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: history,
      );
      await _unlock(container);
      final controller = container.read(
        transactionBroadcastControllerProvider.notifier,
      );
      final request = _broadcastRequest(chain: ethereum);

      final first = controller.submit(request);
      final second = controller.submit(request);
      await Future<void>.delayed(Duration.zero);

      expect(evmService.calls, hasLength(1));
      completer.complete('0xabc123');

      expect((await first).status, TransactionBroadcastStatus.success);
      expect((await second).status, TransactionBroadcastStatus.success);
      expect(history.savedRecords, hasLength(1));
    });

    test('successful broadcast saves transaction memo tag', () async {
      final evmService = _FakeEvmTransactionService(result: '0xabc123');
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: history,
      );
      await _unlock(container);

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(
            _broadcastRequest(
              chain: ethereum,
              transaction: _transactionRequest(
                chain: ethereum,
                memo: 'Invoice 123',
              ),
            ),
          );

      expect(state.status, TransactionBroadcastStatus.success);
      expect(history.savedRecords.single.memo, 'Invoice 123');
    });

    test(
      'signing password authorizes broadcast and caches by default',
      () async {
        final evmService = _FakeEvmTransactionService(result: '0xabc123');
        final history = _RecordingTransactionHistoryRepository();
        final cache = SessionKeyCache();
        final repository = _FakeWalletRepository();
        final container = _container(
          walletRepository: repository,
          evmService: evmService,
          historyRepository: history,
          sessionKeyCache: cache,
        );

        final state = await container
            .read(transactionBroadcastControllerProvider.notifier)
            .submit(
              _broadcastRequest(chain: ethereum),
              signingPassword: 'password',
            );

        expect(state.status, TransactionBroadcastStatus.success);
        expect(repository.unlockCalls, 1);
        expect(evmService.calls.single.privateKey, _evmPrivateKey);
        expect(cache.readKey(_account.id, now: _now), [1, 2, 3, 4]);
      },
    );

    test('signing password can be used without caching', () async {
      final evmService = _FakeEvmTransactionService(result: '0xabc123');
      final cache = SessionKeyCache();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: _RecordingTransactionHistoryRepository(),
        sessionKeyCache: cache,
      );

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(
            _broadcastRequest(chain: ethereum),
            signingPassword: 'password',
            rememberSigningPassword: false,
          );

      expect(state.status, TransactionBroadcastStatus.success);
      expect(cache.readKey(_account.id, now: _now), isNull);
    });

    test('successful ERC20 broadcast submits token transfer request', () async {
      final evmService = _FakeEvmTransactionService(result: '0xerc20hash');
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: history,
      );
      await _unlock(container);

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(
            _broadcastRequest(
              chain: ethereum,
              transaction: _erc20TransactionRequest(chain: ethereum),
              feeEstimate: FeeEstimate.eip1559(
                feeAssetSymbol: ethereum.symbol,
                gasLimit: BigInt.from(52000),
                maxFeePerGasWei: BigInt.from(30),
                maxPriorityFeePerGasWei: BigInt.from(2),
              ),
            ),
          );

      expect(state.status, TransactionBroadcastStatus.success);
      expect(state.transactionHash, '0xerc20hash');
      expect(evmService.calls.single.privateKey, _evmPrivateKey);
      expect(
        evmService.calls.single.transaction.transactionType,
        TransactionType.erc20Transfer,
      );
      expect(
        evmService.calls.single.transaction.tokenContractAddress,
        _usdcContractAddress,
      );
      expect(evmService.calls.single.transaction.amountInBaseUnits, '12345600');
      expect(history.savedRecords, hasLength(1));
      expect(history.savedRecords.single.assetSymbol, 'USDC');
      expect(history.savedRecords.single.amount, '12.3456');
      expect(history.savedRecords.single.transactionHash, '0xerc20hash');
      expect(history.savedRecords.single.fromAddress, _account.evmAddress);
    });

    test('broadcast failure returns localized error', () async {
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: _FakeEvmTransactionService(error: StateError('rpc down')),
        historyRepository: history,
      );
      await _unlock(container);

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(_broadcastRequest(chain: ethereum));

      expect(state.status, TransactionBroadcastStatus.failure);
      expect(history.savedRecords, isEmpty);
      expect(
        const ErrorLocalizer().messageFor(
          state.error!,
          AppLocale.zh.buildSync(),
        ),
        '交易提交失败，请稍后重试',
      );
    });

    testWidgets('confirmation shows loading until successful broadcast', (
      tester,
    ) async {
      final completer = Completer<String>();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: _FakeEvmTransactionService(completer: completer),
        historyRepository: _RecordingTransactionHistoryRepository(),
      );
      final broadcastRequest = _broadcastRequest(chain: ethereum);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(home: _confirmationPage(broadcastRequest)),
          ),
        ),
      );

      await tester.tap(find.text('提交'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('signingPasswordInput')),
        'password',
      );
      await tester.tap(find.text('确认'));
      await tester.pump();

      expect(
        find.byKey(const Key('transactionSubmitLoadingDialog')),
        findsOneWidget,
      );
      expect(find.text('确认转账'), findsOneWidget);
      expect(find.text('转账结果'), findsNothing);

      completer.complete('0xresult');
      await tester.pumpAndSettle();

      expect(find.text('转账结果'), findsOneWidget);
      expect(find.text('0xresult'), findsOneWidget);
      expect(
        find.byKey(const Key('transactionSubmitLoadingDialog')),
        findsNothing,
      );
    });

    testWidgets('selected fee preset is the one sent to EVM broadcaster', (
      tester,
    ) async {
      final evmService = _FakeEvmTransactionService(result: '0xresult');
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: evmService,
        historyRepository: _RecordingTransactionHistoryRepository(),
      );
      await _unlock(container);
      final feeEstimate = FeeEstimate.eip1559(
        feeAssetSymbol: 'ETH',
        gasLimit: BigInt.from(21000),
        maxFeePerGasWei: BigInt.from(30000000000),
        maxPriorityFeePerGasWei: BigInt.from(2000000000),
        options: [
          FeeOption(
            speed: FeeSpeed.standard,
            feeInBaseUnits: BigInt.from(630000000000000),
            gasLimit: BigInt.from(21000),
            maxFeePerGasWei: BigInt.from(30000000000),
            maxPriorityFeePerGasWei: BigInt.from(2000000000),
          ),
          FeeOption(
            speed: FeeSpeed.fast,
            feeInBaseUnits: BigInt.from(840000000000000),
            gasLimit: BigInt.from(21000),
            maxFeePerGasWei: BigInt.from(40000000000),
            maxPriorityFeePerGasWei: BigInt.from(3000000000),
          ),
        ],
      );
      final request = _broadcastRequest(
        chain: ethereum,
        feeEstimate: feeEstimate,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(home: _confirmationPage(request)),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('transactionFeePickerButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feeOption:fast')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交'));
      await tester.pumpAndSettle();

      expect(evmService.calls, hasLength(1));
      expect(
        evmService.calls.single.feeEstimate.maxFeePerGasWei,
        BigInt.from(40000000000),
      );
      expect(
        evmService.calls.single.feeEstimate.maxPriorityFeePerGasWei,
        BigInt.from(3000000000),
      );
    });

    testWidgets('confirmation opens failure result after broadcast finishes', (
      tester,
    ) async {
      final completer = Completer<String>();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: _FakeEvmTransactionService(completer: completer),
        historyRepository: _RecordingTransactionHistoryRepository(),
      );
      final broadcastRequest = _broadcastRequest(chain: ethereum);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(home: _confirmationPage(broadcastRequest)),
          ),
        ),
      );

      await tester.tap(find.text('提交'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('signingPasswordInput')),
        'password',
      );
      await tester.tap(find.text('确认'));
      await tester.pump();

      expect(find.text('转账结果'), findsNothing);

      completer.completeError(StateError('rpc down'));
      await tester.pumpAndSettle();

      expect(find.text('转账结果'), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);
      expect(find.text('交易提交失败，请稍后重试'), findsOneWidget);
    });

    testWidgets('result page copies hash and opens block explorer on success', (
      tester,
    ) async {
      String? copiedText;
      final launcher = _FakeExternalUrlLauncher();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            copiedText = arguments['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: _FakeEvmTransactionService(result: '0xresult'),
        historyRepository: _RecordingTransactionHistoryRepository(),
        externalUrlLauncher: launcher,
      );
      await _unlock(container);
      final broadcastRequest = _broadcastRequest(chain: ethereum);
      await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(broadcastRequest);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: TransactionResultPage(request: broadcastRequest),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0xresult'), findsOneWidget);
      expect(find.text('区块浏览器查看'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('copyTransactionHashButton')))
            .dy,
        tester
            .getTopLeft(find.byKey(const Key('viewTransactionExplorerButton')))
            .dy,
      );

      await tester.tap(find.byKey(const Key('copyTransactionHashButton')));
      await tester.pump();

      expect(copiedText, '0xresult');

      await tester.tap(find.byKey(const Key('viewTransactionExplorerButton')));
      await tester.pump();

      expect(launcher.urls, ['https://etherscan.io/tx/0xresult']);
    });

    testWidgets('Bitcoin result page displays and copies transaction hash', (
      tester,
    ) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            copiedText = arguments['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final bitcoinService = _FakeBitcoinTransactionService(result: 'btctxid');
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        bitcoinService: bitcoinService,
        historyRepository: _RecordingTransactionHistoryRepository(),
      );
      await _unlock(container);
      final broadcastRequest = _broadcastRequest(chain: bitcoin);
      await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(broadcastRequest);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: TransactionResultPage(request: broadcastRequest),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('btctxid'), findsOneWidget);

      await tester.tap(find.byKey(const Key('copyTransactionHashButton')));
      await tester.pump();

      expect(copiedText, 'btctxid');
      expect(bitcoinService.calls, hasLength(1));
    });

    testWidgets('result page back and done actions return to root', (
      tester,
    ) async {
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: _FakeEvmTransactionService(result: '0xresult'),
        historyRepository: _RecordingTransactionHistoryRepository(),
      );
      await _unlock(container);
      final broadcastRequest = _broadcastRequest(chain: ethereum);
      await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(broadcastRequest);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              initialRoute: '/transfer/result',
              routes: {
                '/': (_) => const Scaffold(body: Text('root page')),
                '/transfer': (_) => const Scaffold(body: Text('transfer page')),
                '/transfer/result': (_) =>
                    TransactionResultPage(request: broadcastRequest),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('root page'), findsOneWidget);
      expect(find.text('transfer page'), findsNothing);
    });

    testWidgets('result page back button returns to root', (tester) async {
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        evmService: _FakeEvmTransactionService(result: '0xresult'),
        historyRepository: _RecordingTransactionHistoryRepository(),
      );
      await _unlock(container);
      final broadcastRequest = _broadcastRequest(chain: ethereum);
      await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(broadcastRequest);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              initialRoute: '/transfer/result',
              routes: {
                '/': (_) => const Scaffold(body: Text('root page')),
                '/transfer': (_) => const Scaffold(body: Text('transfer page')),
                '/transfer/result': (_) =>
                    TransactionResultPage(request: broadcastRequest),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('root page'), findsOneWidget);
      expect(find.text('transfer page'), findsNothing);
    });

    test(
      'successful Solana broadcast refreshes blockhash and uses CU fee',
      () async {
        final solanaService = _FakeSolanaTransactionService(result: 'solsig');
        final history = _RecordingTransactionHistoryRepository();
        final container = _container(
          walletRepository: _FakeWalletRepository(),
          solanaService: solanaService,
          historyRepository: history,
        );
        await _unlock(container);

        final state = await container
            .read(transactionBroadcastControllerProvider.notifier)
            .submit(_broadcastRequest(chain: solana));

        expect(state.status, TransactionBroadcastStatus.success);
        expect(state.transactionHash, 'solsig');
        expect(solanaService.calls.single.privateKey, _solanaPrivateKey);
        expect(solanaService.calls.single.recentBlockhash, isNull);
        expect(solanaService.calls.single.computeUnitLimit, 220000);
        expect(
          solanaService.calls.single.microLamportsPerComputeUnit,
          BigInt.from(2000),
        );
        expect(history.savedRecords.single.fromAddress, _account.solanaAddress);
      },
    );

    test('successful Bitcoin broadcast uses Bitcoin key material', () async {
      final bitcoinService = _FakeBitcoinTransactionService(result: 'btctxid');
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        bitcoinService: bitcoinService,
        historyRepository: history,
      );
      await _unlock(container);

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(_broadcastRequest(chain: bitcoin));

      expect(state.status, TransactionBroadcastStatus.success);
      expect(state.transactionHash, 'btctxid');
      expect(bitcoinService.calls.single.privateKey, _btcPrivateKey);
      expect(bitcoinService.calls.single.fromAddress, _account.btcAddress);
      expect(
        bitcoinService.calls.single.transaction.transactionType,
        TransactionType.bitcoinTransfer,
      );
      expect(
        bitcoinService.calls.single.feeEstimate.feeInBaseUnits,
        BigInt.from(1410),
      );
      expect(history.savedRecords.single.fromAddress, _account.btcAddress);
    });

    test('successful Tron broadcast uses Tron key material', () async {
      final tronService = _FakeTronTransactionService(result: 'tron-txid');
      final history = _RecordingTransactionHistoryRepository();
      final container = _container(
        walletRepository: _FakeWalletRepository(),
        tronService: tronService,
        historyRepository: history,
      );
      await _unlock(container);

      final state = await container
          .read(transactionBroadcastControllerProvider.notifier)
          .submit(_broadcastRequest(chain: tron));

      expect(state.status, TransactionBroadcastStatus.success);
      expect(state.transactionHash, 'tron-txid');
      expect(tronService.calls.single.privateKey, _tronPrivateKey);
      expect(tronService.calls.single.fromAddress, _account.tronAddress);
      expect(
        tronService.calls.single.transaction.transactionType,
        TransactionType.nativeTransfer,
      );
      expect(history.savedRecords.single.fromAddress, _account.tronAddress);
    });

    test(
      'successful Sui broadcast uses Ed25519 key and saves digest',
      () async {
        final suiService = _FakeSuiTransactionService(result: '7SuiDigest');
        final history = _RecordingTransactionHistoryRepository();
        final container = _container(
          walletRepository: _FakeWalletRepository(),
          suiService: suiService,
          historyRepository: history,
        );
        await _unlock(container);

        final state = await container
            .read(transactionBroadcastControllerProvider.notifier)
            .submit(_broadcastRequest(chain: sui));

        expect(state.status, TransactionBroadcastStatus.success);
        expect(state.transactionHash, '7SuiDigest');
        expect(suiService.calls.single.privateKey, _suiPrivateKey);
        expect(suiService.calls.single.fromAddress, _account.suiAddress);
        expect(
          suiService.calls.single.transaction.transactionType,
          TransactionType.suiTransfer,
        );
        expect(history.savedRecords.single.chainType, ChainType.sui);
        expect(history.savedRecords.single.fromAddress, _account.suiAddress);
        expect(history.savedRecords.single.transactionHash, '7SuiDigest');
      },
    );

    test(
      'Sui broadcast fails before RPC when key material is missing',
      () async {
        final suiService = _FakeSuiTransactionService(result: '7SuiDigest');
        final history = _RecordingTransactionHistoryRepository();
        final container = _container(
          walletRepository: _FakeWalletRepository(includeSuiKey: false),
          suiService: suiService,
          historyRepository: history,
        );
        await _unlock(container);

        final state = await container
            .read(transactionBroadcastControllerProvider.notifier)
            .submit(_broadcastRequest(chain: sui));

        expect(state.status, TransactionBroadcastStatus.failure);
        expect(suiService.calls, isEmpty);
        expect(history.savedRecords, isEmpty);
      },
    );

    test(
      'Bitcoin broadcast rejects a recipient from the wrong network',
      () async {
        final bitcoinService = _FakeBitcoinTransactionService(
          result: 'btctxid',
        );
        final history = _RecordingTransactionHistoryRepository();
        final container = _container(
          walletRepository: _FakeWalletRepository(),
          bitcoinService: bitcoinService,
          historyRepository: history,
        );
        await _unlock(container);
        final transaction = TransactionRequest(
          chainId: bitcoin.chainId,
          chainType: bitcoin.chainType,
          assetSymbol: bitcoin.symbol,
          toAddress: 'tb1qxmt9xgewg6mxc4mvnzvrzu4f2v0gy782fydg0w',
          amount: '0.1',
          amountInBaseUnits: '10000000',
          tokenDecimals: 8,
          transactionType: TransactionType.bitcoinTransfer,
        );

        final state = await container
            .read(transactionBroadcastControllerProvider.notifier)
            .submit(
              _broadcastRequest(chain: bitcoin, transaction: transaction),
            );

        expect(state.status, TransactionBroadcastStatus.failure);
        expect(
          state.error,
          isA<TransferError>().having(
            (error) => error.code,
            'code',
            'transaction_broadcast_failed',
          ),
        );
        expect(bitcoinService.calls, isEmpty);
        expect(history.savedRecords, isEmpty);
      },
    );
  });
}

ProviderContainer _container({
  required WalletRepository walletRepository,
  required TransactionHistoryRepository historyRepository,
  EvmTransactionService? evmService,
  BitcoinTransactionService? bitcoinService,
  TronTransactionService? tronService,
  SolanaTransactionService? solanaService,
  SuiTransactionService? suiService,
  SessionKeyCache? sessionKeyCache,
  ExternalUrlLauncher? externalUrlLauncher,
  SecurityLogRepository? securityLogRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      walletRepositoryProvider.overrideWithValue(walletRepository),
      sessionKeyCacheProvider.overrideWithValue(
        sessionKeyCache ?? SessionKeyCache(),
      ),
      transactionHistoryRepositoryProvider.overrideWithValue(historyRepository),
      transactionBroadcastClockProvider.overrideWithValue(() => _now),
      if (securityLogRepository != null)
        securityLogRepositoryProvider.overrideWithValue(securityLogRepository),
      if (evmService != null)
        evmTransactionServiceProvider.overrideWithValue(evmService),
      if (bitcoinService != null)
        bitcoinTransactionServiceProvider.overrideWithValue(bitcoinService),
      if (tronService != null)
        tronTransactionServiceProvider.overrideWithValue(tronService),
      if (solanaService != null)
        solanaTransactionServiceProvider.overrideWithValue(solanaService),
      if (suiService != null)
        suiTransactionServiceProvider.overrideWithValue(suiService),
      if (externalUrlLauncher != null)
        externalUrlLauncherProvider.overrideWithValue(externalUrlLauncher),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

TransactionConfirmPage _confirmationPage(
  TransactionBroadcastRequest broadcastRequest,
) {
  final transaction = broadcastRequest.transaction;
  return TransactionConfirmPage(
    chain: broadcastRequest.chain,
    rpcNode: broadcastRequest.rpcNode,
    account: broadcastRequest.account,
    request: transaction,
    feeEstimate: broadcastRequest.feeEstimate,
    confirmation: const TransactionConfirmController().buildConfirmation(
      chain: broadcastRequest.chain,
      account: broadcastRequest.account,
      request: transaction,
      feeEstimate: broadcastRequest.feeEstimate,
    ),
  );
}

Future<void> _unlock(ProviderContainer container) async {
  await container
      .read(walletSessionControllerProvider.notifier)
      .unlock(walletId: _account.id, password: 'password', now: _now);
}

TransactionBroadcastRequest _broadcastRequest({
  required ChainConfig chain,
  TransactionRequest? transaction,
  FeeEstimate? feeEstimate,
}) {
  return TransactionBroadcastRequest(
    chain: chain,
    rpcNode: RpcNode(
      id: '${chain.id}-node',
      chainId: chain.chainId,
      name: 'Test RPC',
      url: 'https://rpc.example.com',
      nodeType: RpcNodeType.defaultNode,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
    ),
    account: _account,
    transaction: transaction ?? _transactionRequest(chain: chain),
    feeEstimate: feeEstimate ?? _feeEstimate(chain: chain),
  );
}

FeeEstimate _feeEstimate({required ChainConfig chain}) {
  return switch (chain.chainType) {
    ChainType.evm => FeeEstimate.eip1559(
      feeAssetSymbol: chain.symbol,
      gasLimit: BigInt.from(21000),
      maxFeePerGasWei: BigInt.from(30),
      maxPriorityFeePerGasWei: BigInt.from(2),
    ),
    ChainType.bitcoin => FeeEstimate.bitcoin(
      feeAssetSymbol: chain.symbol,
      satoshis: BigInt.from(1410),
    ),
    ChainType.tron => FeeEstimate.tron(
      feeAssetSymbol: chain.symbol,
      sun: BigInt.zero,
    ),
    ChainType.solana => FeeEstimate.solana(
      feeAssetSymbol: chain.symbol,
      lamports: BigInt.from(5000),
      recentBlockhash: 'blockhash-1',
      computeUnitLimit: 220000,
      microLamportsPerComputeUnit: BigInt.from(2000),
    ),
    ChainType.sui => FeeEstimate.sui(
      feeAssetSymbol: chain.symbol,
      estimatedFeeMist: BigInt.from(900),
      gasBudgetMist: BigInt.from(1200),
    ),
  };
}

TransactionRequest _transactionRequest({
  required ChainConfig chain,
  String? memo,
}) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: chain.symbol,
    toAddress: switch (chain.chainType) {
      ChainType.evm => '0x2222222222222222222222222222222222222222',
      ChainType.bitcoin => 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      ChainType.tron => 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj',
      ChainType.solana => 'So11111111111111111111111111111111111111112',
      ChainType.sui =>
        '0x0000000000000000000000000000000000000000000000000000000000000002',
    },
    amount: '0.1',
    amountInBaseUnits: switch (chain.chainType) {
      ChainType.evm => '100000000000000000',
      ChainType.bitcoin => '10000000',
      ChainType.tron => '100000',
      ChainType.solana => '100000000',
      ChainType.sui => '100000000',
    },
    tokenDecimals: switch (chain.chainType) {
      ChainType.evm => 18,
      ChainType.bitcoin => 8,
      ChainType.tron => 6,
      ChainType.solana => 9,
      ChainType.sui => 9,
    },
    transactionType: switch (chain.chainType) {
      ChainType.evm => TransactionType.nativeTransfer,
      ChainType.bitcoin => TransactionType.bitcoinTransfer,
      ChainType.tron => TransactionType.nativeTransfer,
      ChainType.solana => TransactionType.solTransfer,
      ChainType.sui => TransactionType.suiTransfer,
    },
    memo: memo,
  );
}

TransactionRequest _erc20TransactionRequest({required ChainConfig chain}) {
  return TransactionRequest(
    chainId: chain.chainId,
    chainType: chain.chainType,
    assetSymbol: 'USDC',
    toAddress: '0x2222222222222222222222222222222222222222',
    amount: '12.3456',
    amountInBaseUnits: '12345600',
    tokenDecimals: 6,
    tokenContractAddress: _usdcContractAddress,
    transactionType: TransactionType.erc20Transfer,
  );
}

final _now = DateTime.utc(2026, 6, 6, 12);

const _evmPrivateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _btcPrivateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _tronPrivateKey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _usdcContractAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
final _solanaPrivateKey = List<int>.generate(64, (index) => index);
final _suiPrivateKey = List<int>.generate(32, (index) => index + 1);

final _account = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  evmAddress: '0x1111111111111111111111111111111111111111',
  solanaAddress: '11111111111111111111111111111111',
  btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  tronAddress: 'TJ4uT7n9LQvz1J9jQK5hJkCcnHJfLgkSnj',
  suiAddress:
      '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
  createdAt: _now,
  updatedAt: _now,
);

final class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({this.includeSuiKey = true});

  final bool includeSuiKey;
  int unlockCalls = 0;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => [_account];

  @override
  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> changePassword({
    required String walletId,
    required String currentPassword,
    required String newPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importMnemonicWallet({
    required String mnemonic,
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletAccount> importPrivateKeyWallet({
    required String privateKey,
    String? password,
    String name = 'Wallet 1',
    WalletPrivateKeyChain chain = WalletPrivateKeyChain.evm,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletKeyMaterial> readKeyMaterial({
    required String walletId,
    required List<int> walletDek,
  }) async {
    return WalletKeyMaterial(
      evmPrivateKey: _evmPrivateKey,
      btcPrivateKey: _btcPrivateKey,
      tronPrivateKey: _tronPrivateKey,
      solanaPrivateKey: _solanaPrivateKey,
      suiPrivateKey: includeSuiKey ? _suiPrivateKey : null,
    );
  }

  @override
  Future<WalletAccount> renameWallet({
    required String walletId,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletUnlockResult> unlock({
    required String walletId,
    required String password,
  }) async {
    unlockCalls += 1;
    return WalletUnlockResult(account: _account, walletDek: [1, 2, 3, 4]);
  }
}

final class _RecordingTransactionHistoryRepository
    implements TransactionHistoryRepository {
  _RecordingTransactionHistoryRepository({this.saveError});

  final Object? saveError;
  final savedRecords = <TransactionRecord>[];

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return savedRecords
        .where((record) => chainId == null || record.chainId == chainId)
        .toList(growable: false);
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    return (await list(chainId: chainId)).take(limit).toList(growable: false);
  }

  @override
  Future<void> save(TransactionRecord record) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    savedRecords.add(record);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {
    final index = savedRecords.indexWhere((record) => record.id == id);
    if (index == -1) {
      return;
    }
    final previous = savedRecords[index];
    savedRecords[index] = TransactionRecord(
      id: previous.id,
      chainId: previous.chainId,
      chainType: previous.chainType,
      assetSymbol: previous.assetSymbol,
      direction: previous.direction,
      amount: previous.amount,
      status: status,
      transactionHash: previous.transactionHash,
      createdAt: previous.createdAt,
      fromAddress: previous.fromAddress,
      toAddress: previous.toAddress,
      failureReason: failureReason,
    );
  }
}

final class _FakeEvmTransactionService implements EvmTransactionService {
  _FakeEvmTransactionService({this.result, this.error, this.completer});

  final String? result;
  final Object? error;
  final Completer<String>? completer;
  final calls = <EvmTransactionBroadcastInput>[];

  @override
  Future<String> signAndBroadcast(EvmTransactionBroadcastInput input) async {
    calls.add(input);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    final completer = this.completer;
    if (completer != null) {
      return completer.future;
    }
    return result!;
  }
}

final class _FakeBitcoinTransactionService
    implements BitcoinTransactionService {
  _FakeBitcoinTransactionService({required this.result});

  final String result;
  final calls = <BitcoinTransactionBroadcastInput>[];

  @override
  Future<String> signAndBroadcast(
    BitcoinTransactionBroadcastInput input,
  ) async {
    calls.add(input);
    return result;
  }
}

final class _FakeTronTransactionService implements TronTransactionService {
  _FakeTronTransactionService({required this.result});

  final String result;
  final calls = <TronTransactionBroadcastInput>[];

  @override
  Future<String> signAndBroadcast(TronTransactionBroadcastInput input) async {
    calls.add(input);
    return result;
  }
}

final class _FakeSolanaTransactionService implements SolanaTransactionService {
  _FakeSolanaTransactionService({required this.result});

  final String result;
  final calls = <SolanaTransactionBroadcastInput>[];

  @override
  Future<String> signAndBroadcast(SolanaTransactionBroadcastInput input) async {
    calls.add(input);
    return result;
  }
}

final class _FakeSuiTransactionService implements SuiTransactionService {
  _FakeSuiTransactionService({required this.result});

  final String result;
  final calls = <SuiTransactionBroadcastInput>[];

  @override
  Future<String> signAndBroadcast(SuiTransactionBroadcastInput input) async {
    calls.add(input);
    return result;
  }

  @override
  Future<SuiTransactionSimulation> estimateTransferFee(SuiTransferInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SuiTransactionExecutionStatus?> getTransactionStatus({
    required String rpcUrl,
    required String digest,
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }
}

final class _FakeExternalUrlLauncher implements ExternalUrlLauncher {
  final urls = <String>[];

  @override
  Future<bool> openExternal(String url) async {
    urls.add(url);
    return true;
  }
}
