import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/chains/application/available_chains_provider.dart';
import 'package:safe_wallet/features/chains/data/chain_repository.dart';
import 'package:safe_wallet/features/chains/data/default_chains.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/dapp/application/dapp_permission_controller.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_controller.dart';
import 'package:safe_wallet/features/dapp/data/dapp_permission_repository.dart';
import 'package:safe_wallet/features/nodes/application/selected_rpc_node_provider.dart';
import 'package:safe_wallet/features/nodes/data/rpc_credential_store.dart';
import 'package:safe_wallet/features/nodes/data/rpc_node_repository.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/settings/data/security_log_repository.dart';
import 'package:safe_wallet/features/settings/domain/security_log_entry.dart';
import 'package:safe_wallet/features/transfer/application/transaction_history_provider.dart';
import 'package:safe_wallet/features/transfer/data/transaction_history_repository.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/wallet/application/selected_wallet_controller.dart';
import 'package:safe_wallet/features/wallet/application/wallet_repository_provider.dart';
import 'package:safe_wallet/features/wallet/application/wallet_session_controller.dart';
import 'package:safe_wallet/features/wallet/data/wallet_repository.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:solana_sdk/solana_sdk.dart' as solana;
import 'package:sui_dart/sui.dart' as sui;
import 'package:sui_dart/types/objects.dart' as sui_types;
import 'package:web3dart/web3dart.dart' as web3;

void main() {
  group('DappRequestController', () {
    final now = DateTime.utc(2026, 6, 6, 12);
    final account = WalletAccount(
      id: 'wallet-1',
      name: 'Main Wallet',
      evmAddress: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
      solanaAddress: '11111111111111111111111111111111',
      suiAddress: _suiAddress,
      suiPublicKey: base64Encode(_suiPublicKey),
      createdAt: now,
      updatedAt: now,
    );

    test(
      'transaction simulator performs eth_call against the selected RPC',
      () async {
        final rpcClient = _FakeDappEvmReadRpcClient({
          'eth_call': '0x',
          'eth_estimateGas': '0x5208',
          'eth_gasPrice': '0x3b9aca00',
        });
        final simulator = RpcDappEvmTransactionSimulator(rpcClient: rpcClient);
        final chain = defaultChains.firstWhere(
          (chain) => chain.id == 'ethereum',
        );
        const rpcUrl = 'https://selected-rpc.example.com';
        const transaction = DappEvmTransaction(
          from: '0x9858effd232b4033e47d90003d41ec34ecaeda94',
          to: '0x2222222222222222222222222222222222222222',
        );

        final result = await simulator.simulate(
          chain: chain,
          rpcUrl: rpcUrl,
          transaction: transaction,
          headers: const {'x-api-key': 'secret'},
        );

        expect(result.succeeded, isTrue);
        expect(rpcClient.calls.map((call) => call.method), [
          'eth_call',
          'eth_estimateGas',
          'eth_gasPrice',
        ]);
        expect(rpcClient.calls.first.rpcUrl, rpcUrl);
        expect(rpcClient.calls.first.headers, {'x-api-key': 'secret'});
        expect(rpcClient.calls.first.params, [
          transaction.toRpcJson(),
          'latest',
        ]);
      },
    );

    test('unapproved dApp cannot get accounts', () async {
      final container = _container(account: account);
      container.read(selectedWalletIdProvider.notifier).select(account.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_accounts',
            ),
          );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, isEmpty);
    });

    test('request accounts approval stores permission by domain', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_requestAccounts',
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      final stored = await repository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: account.id,
        chainId: '1',
      );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, [account.evmAddress]);
      expect(stored?.domain, 'https://app.uniswap.org');
      expect(stored?.address, account.evmAddress);
    });

    test('bound EVM request keeps the originally confirmed wallet', () async {
      final otherAccount = WalletAccount(
        id: 'wallet-2',
        name: 'Other Wallet',
        evmAddress: '0x2222222222222222222222222222222222222222',
        solanaAddress: '22222222222222222222222222222222',
        suiAddress:
            '0x2222222222222222222222222222222222222222222222222222222222222222',
        suiPublicKey: base64Encode(_suiPublicKey),
        createdAt: now,
        updatedAt: now,
      );
      final container = _container(
        account: account,
        accounts: [account, otherAccount],
      );
      container.read(selectedWalletIdProvider.notifier).select(otherAccount.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_requestAccounts',
              chainId: 'eip155:1',
              authorizedAddress: account.evmAddress,
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      expect(result.value, [account.evmAddress]);
    });

    test('bound Solana request keeps the confirmed wallet and chain', () async {
      final otherAccount = WalletAccount(
        id: 'wallet-2',
        name: 'Other Wallet',
        evmAddress: '0x2222222222222222222222222222222222222222',
        solanaAddress: '22222222222222222222222222222222',
        suiAddress:
            '0x2222222222222222222222222222222222222222222222222222222222222222',
        suiPublicKey: base64Encode(_suiPublicKey),
        createdAt: now,
        updatedAt: now,
      );
      final container = _container(
        account: account,
        accounts: [account, otherAccount],
        chainRepository: _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        ),
      );
      container.read(selectedWalletIdProvider.notifier).select(otherAccount.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://solana.example',
              method: 'solana_connect',
              chainId: 'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
              authorizedAddress: account.solanaAddress,
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      expect(result.value, {'publicKey': account.solanaAddress});
    });

    test('bound Sui request keeps the confirmed wallet and chain', () async {
      final otherAccount = WalletAccount(
        id: 'wallet-2',
        name: 'Other Wallet',
        evmAddress: '0x2222222222222222222222222222222222222222',
        solanaAddress: '22222222222222222222222222222222',
        suiAddress:
            '0x2222222222222222222222222222222222222222222222222222222222222222',
        suiPublicKey: base64Encode(_suiPublicKey),
        createdAt: now,
        updatedAt: now,
      );
      final container = _container(
        account: account,
        accounts: [account, otherAccount],
        chainRepository: _FakeChainRepository(selectedChainId: 'sui-mainnet'),
      );
      container.read(selectedWalletIdProvider.notifier).select(otherAccount.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://sui.example',
              method: 'sui_connect',
              chainId: 'sui:testnet',
              authorizedAddress: account.suiAddress,
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      expect(result.value, {
        'address': account.suiAddress,
        'publicKey': _suiPublicKey,
        'chain': 'sui:testnet',
      });
    });

    test('EVM account request ignores wallet without an EVM address', () async {
      final repository = InMemoryDappPermissionRepository();
      final btcAccount = WalletAccount(
        id: 'wallet-btc',
        name: 'BTC Wallet',
        evmAddress: '',
        solanaAddress: '',
        btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        source: WalletAccountSource.privateKey,
        createdAt: now,
        updatedAt: now,
      );
      final container = _container(account: btcAccount, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(btcAccount.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_requestAccounts',
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      final stored = await repository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: btcAccount.id,
        chainId: '1',
      );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, isEmpty);
      expect(stored, isNull);
    });

    test('request accounts rejection returns rejected result', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_requestAccounts',
            ),
            authorizationDecision: DappAuthorizationDecision.rejected,
            now: now,
          );

      final stored = await repository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: account.id,
        chainId: '1',
      );

      expect(result.status, DappRequestResultStatus.rejected);
      expect(result.errorCode, 'dapp_user_rejected');
      expect(stored, isNull);
    });

    test('wallet request permissions grants eth accounts permission', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'wallet_requestPermissions',
              params: [
                {'eth_accounts': {}},
              ],
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      final stored = await repository.permissionFor(
        domain: 'app.uniswap.org',
        walletId: account.id,
        chainId: '1',
      );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, [
        {
          'parentCapability': 'eth_accounts',
          'caveats': [
            {
              'type': 'restrictReturnedAccounts',
              'value': [account.evmAddress],
            },
          ],
        },
      ]);
      expect(stored?.address, account.evmAddress);
    });

    test(
      'wallet get permissions returns approved eth accounts permission',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(account: account, repository: repository);
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'wallet_getPermissions',
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, [
          {
            'parentCapability': 'eth_accounts',
            'caveats': [
              {
                'type': 'restrictReturnedAccounts',
                'value': [account.evmAddress],
              },
            ],
          },
        ]);
      },
    );

    test(
      'EVM account request uses default EVM chain when Solana is selected',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        );
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'eth_requestAccounts',
              ),
              authorizationDecision: DappAuthorizationDecision.approved,
              now: now,
            );

        final stored = await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: account.id,
          chainId: '1',
        );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, [account.evmAddress]);
        expect(stored?.address, account.evmAddress);
        expect(chainRepository.selectedChainId, 'solana-mainnet');
      },
    );

    test(
      'EVM account request uses default EVM chain when Bitcoin is selected',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'bitcoin-mainnet',
        );
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'eth_requestAccounts',
              ),
              authorizationDecision: DappAuthorizationDecision.approved,
              now: now,
            );

        final stored = await repository.permissionFor(
          domain: 'app.uniswap.org',
          walletId: account.id,
          chainId: '1',
        );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, [account.evmAddress]);
        expect(stored?.address, account.evmAddress);
        expect(chainRepository.selectedChainId, 'bitcoin-mainnet');
      },
    );

    test(
      'EVM chain id uses default EVM chain when Solana is selected',
      () async {
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        );
        final container = _container(
          account: account,
          chainRepository: chainRepository,
        );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'eth_chainId',
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '0x1');
        expect(chainRepository.selectedChainId, 'solana-mainnet');
      },
    );

    test(
      'EVM chain id uses default EVM chain when Bitcoin is selected',
      () async {
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'bitcoin-mainnet',
        );
        final container = _container(
          account: account,
          chainRepository: chainRepository,
        );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'eth_chainId',
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '0x1');
        expect(chainRepository.selectedChainId, 'bitcoin-mainnet');
      },
    );

    test(
      'WalletConnect request chain is authoritative without switching home',
      () async {
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'ethereum',
        );
        final container = _container(
          account: account,
          chainRepository: chainRepository,
        );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://example.com',
                method: 'eth_chainId',
                source: DappRequestSource.walletConnect,
                chainId: 'eip155:56',
                requestTopic: 'topic-a',
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '0x38');
        expect(chainRepository.selectedChainId, 'ethereum');
      },
    );

    test('WalletConnect request rejects an unsupported CAIP chain', () async {
      final container = _container(account: account);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://example.com',
              method: 'eth_chainId',
              source: DappRequestSource.walletConnect,
              chainId: 'eip155:43114',
            ),
            now: now,
          );

      expect(result.status, DappRequestResultStatus.failure);
      expect(result.errorCode, 'unsupported_chain');
    });

    test(
      'WalletConnect session account bypasses persistent browser permission',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(account: account, repository: repository);
        container.read(selectedWalletIdProvider.notifier).select(account.id);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://example.com',
                method: 'personal_sign',
                params: ['0x6869', account.evmAddress],
                source: DappRequestSource.walletConnect,
                chainId: 'eip155:1',
                requestTopic: 'topic-a',
                authorizedAddress: account.evmAddress,
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.confirmationRequired);
        expect(await repository.listAll(), isEmpty);
      },
    );

    test('signature request can be reviewed before signing password', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'personal_sign',
              params: ['hello', account.evmAddress],
            ),
            now: now,
          );

      expect(result.status, DappRequestResultStatus.confirmationRequired);
      expect(result.confirmation?.kind, DappConfirmationKind.signature);
      expect(result.confirmation?.message, 'hello');
    });

    test(
      'personal_sign rejects a requested account that is not authorized',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(account: account, repository: repository);
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org',
                method: 'personal_sign',
                params: ['hello', '0x2222222222222222222222222222222222222222'],
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.failure);
        expect(result.errorCode, 'dapp_unauthorized');
      },
    );

    test(
      'approved signature uses password and caches signing key by default',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final securityLogs = InMemorySecurityLogRepository();
        final container = _container(
          account: account,
          repository: repository,
          securityLogRepository: securityLogs,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'personal_sign',
                params: ['hello', account.evmAddress],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, isA<String>());
        expect(
          container
              .read(sessionKeyCacheProvider)
              .readKey(account.id, now: now.add(const Duration(minutes: 14))),
          [1, 2, 3, 4],
        );
        final signingEntry = (await securityLogs.listEntries()).single;
        expect(signingEntry.type, SecurityLogEventType.signMessage);
        expect(signingEntry.walletName, 'Main Wallet');
        expect(signingEntry.chainName, 'Ethereum');
      },
    );

    test(
      'personal_sign returns a standard chain-independent signature',
      () async {
        const message = 'Sign in to Polymarket';
        final repository = InMemoryDappPermissionRepository();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: _FakeChainRepository(selectedChainId: 'polygon'),
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'polymarket.com',
              walletId: account.id,
              chainId: '137',
              address: account.evmAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://polymarket.com',
                method: 'personal_sign',
                params: [message, account.evmAddress],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        final signature = web3.hexToBytes(result.value! as String);
        final expectedSignature = web3.EthPrivateKey.fromHex(_evmPrivateKey)
            .signPersonalMessageToUint8List(
              Uint8List.fromList(utf8.encode(message)),
            );
        expect(signature, hasLength(65));
        expect(signature.last, anyOf(27, 28));
        expect(signature, expectedSignature);
      },
    );

    test('transaction from address must match authorized account', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await _unlock(container, account, now);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': '0x1111111111111111111111111111111111111111',
                  'to': '0x2222222222222222222222222222222222222222',
                  'value': '0x1',
                  'gas': '0x5208',
                  'gasPrice': '0x1',
                },
              ],
            ),
            now: now,
          );

      expect(result.status, DappRequestResultStatus.failure);
      expect(result.errorCode, 'dapp_unauthorized');
    });

    test(
      'signature request shows readable message and can be rejected',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(account: account, repository: repository);
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await _unlock(container, account, now);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final confirmationResult = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'personal_sign',
                params: ['hello safe wallet', account.evmAddress],
              ),
              now: now,
            );

        expect(
          confirmationResult.status,
          DappRequestResultStatus.confirmationRequired,
        );
        expect(
          confirmationResult.confirmation?.kind,
          DappConfirmationKind.signature,
        );
        expect(confirmationResult.confirmation?.message, 'hello safe wallet');
        expect(
          confirmationResult.confirmation?.rawMessage,
          'hello safe wallet',
        );

        final rejected = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'personal_sign',
                params: ['hello safe wallet', account.evmAddress],
              ),
              confirmationDecision: DappConfirmationDecision.rejected,
              now: now,
            );

        expect(rejected.status, DappRequestResultStatus.rejected);
        expect(rejected.errorCode, 'dapp_user_rejected');
      },
    );

    test(
      'transaction request previews unparsed data and can be rejected',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(account: account, repository: repository);
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await _unlock(container, account, now);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final request = DappRpcRequest(
          origin: 'https://app.uniswap.org/swap',
          method: 'eth_sendTransaction',
          params: [
            {
              'from': account.evmAddress,
              'to': '0x2222222222222222222222222222222222222222',
              'value': '0x1',
              'gas': '0x5208',
              'gasPrice': '0x1',
              'data': '0x12345678',
            },
          ],
        );

        final confirmationResult = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);

        expect(
          confirmationResult.status,
          DappRequestResultStatus.confirmationRequired,
        );
        final preview = confirmationResult.confirmation?.transaction;
        expect(preview?.to, '0x2222222222222222222222222222222222222222');
        expect(preview?.value, '0.000000000000000001 ETH');
        expect(preview?.estimatedFee, '0.000000000000021 ETH');
        expect(preview?.highRisk, isTrue);

        final rejected = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.rejected,
              now: now,
            );

        expect(rejected.status, DappRequestResultStatus.rejected);
      },
    );

    test(
      'ERC20 transaction request previews decoded transfer as lower risk',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(account: account, repository: repository);
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await _unlock(container, account, now);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final confirmationResult = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'eth_sendTransaction',
                params: [
                  {
                    'from': account.evmAddress,
                    'to': _usdcContractAddress,
                    'value': '0x0',
                    'gas': '0xcb20',
                    'gasPrice': '0x1',
                    'data': _erc20TransferCalldata,
                  },
                ],
              ),
              now: now,
            );

        expect(
          confirmationResult.status,
          DappRequestResultStatus.confirmationRequired,
        );
        final preview = confirmationResult.confirmation?.transaction;
        expect(preview?.contractAddress, _usdcContractAddress);
        expect(
          preview?.decodedInfo,
          'USDC transfer to 0x2222222222222222222222222222222222222222 '
          'amount 12.3456 USDC',
        );
        expect(preview?.estimatedFee, '0.000000000000052 ETH');
        expect(preview?.highRisk, isFalse);
      },
    );

    test('unknown contract cannot masquerade as an ERC20 transfer', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://app.uniswap.org',
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': account.evmAddress,
                  'to': '0x9999999999999999999999999999999999999999',
                  'data': _erc20TransferCalldata,
                },
              ],
            ),
            now: now,
          );

      final preview = result.confirmation?.transaction;
      expect(preview?.highRisk, isTrue);
      expect(preview?.decodedInfo, isNot(contains('ERC20')));
    });

    test(
      'transaction preview estimates a missing gas limit and gas price',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final rpcClient = _FakeDappEvmReadRpcClient({
          'eth_call': '0x',
          'eth_estimateGas': '0x5208',
          'eth_gasPrice': '0x3b9aca00',
        });
        final container = _container(
          account: account,
          repository: repository,
          readRpcClient: rpcClient,
          simulator: RpcDappEvmTransactionSimulator(rpcClient: rpcClient),
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org',
                method: 'eth_sendTransaction',
                params: [
                  {
                    'from': account.evmAddress,
                    'to': '0x2222222222222222222222222222222222222222',
                    'value': '0x1',
                  },
                ],
              ),
              now: now,
            );

        expect(result.confirmation?.transaction?.estimatedFee, '0.000021 ETH');
      },
    );

    test('unlimited ERC20 approval is decoded as high risk', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await _unlock(container, account, now);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );
      final maxUint256 = List.filled(64, 'f').join();
      final spender = '3333333333333333333333333333333333333333';

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://app.uniswap.org',
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': account.evmAddress,
                  'to': _usdcContractAddress,
                  'data':
                      '0x095ea7b3${List.filled(24, '0').join()}$spender$maxUint256',
                },
              ],
            ),
            now: now,
          );

      final preview = result.confirmation?.transaction;
      expect(preview?.decodedInfo, contains('unlimited approval'));
      expect(preview?.decodedInfo, contains('0x$spender'));
      expect(preview?.highRisk, isTrue);
    });

    test('NFT setApprovalForAll is decoded as high risk', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await _unlock(container, account, now);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'opensea.io',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );
      final operator = '4444444444444444444444444444444444444444';
      final trueWord = '${List.filled(63, '0').join()}1';

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://opensea.io',
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': account.evmAddress,
                  'to': '0x5555555555555555555555555555555555555555',
                  'data':
                      '0xa22cb465${List.filled(24, '0').join()}$operator$trueWord',
                },
              ],
            ),
            now: now,
          );

      final preview = result.confirmation?.transaction;
      expect(preview?.decodedInfo, contains('NFT setApprovalForAll'));
      expect(preview?.decodedInfo, contains('0x$operator'));
      expect(preview?.highRisk, isTrue);
    });

    test('failed transaction simulation is shown as high risk', () async {
      final repository = InMemoryDappPermissionRepository();
      final simulator = _FakeDappEvmTransactionSimulator(
        const DappTransactionSimulation.failed('execution reverted'),
      );
      final container = _container(
        account: account,
        repository: repository,
        simulator: simulator,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await _unlock(container, account, now);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://app.uniswap.org',
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': account.evmAddress,
                  'to': _usdcContractAddress,
                  'data': _erc20TransferCalldata,
                },
              ],
            ),
            now: now,
          );

      final preview = result.confirmation?.transaction;
      expect(preview?.simulationWarning, 'execution reverted');
      expect(preview?.highRisk, isTrue);
    });

    test('approved transaction request sends through EVM sender', () async {
      final repository = InMemoryDappPermissionRepository();
      final sender = _FakeDappEvmTransactionSender();
      final securityLogs = InMemorySecurityLogRepository();
      final history = _MemoryTransactionHistoryRepository();
      final container = _container(
        account: account,
        repository: repository,
        sender: sender,
        securityLogRepository: securityLogs,
        transactionHistoryRepository: history,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'app.uniswap.org',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'eth_sendTransaction',
              params: [
                {
                  'from': account.evmAddress,
                  'to': '0x2222222222222222222222222222222222222222',
                  'value': '0x1',
                  'gas': '0x5208',
                  'gasPrice': '0x1',
                },
              ],
            ),
            confirmationDecision: DappConfirmationDecision.approved,
            signingPassword: 'password',
            now: now,
          );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, '0xdapphash');
      expect(sender.calls.single.rpcUrl, 'https://selected-rpc.example.com');
      expect(
        sender.calls.single.privateKey,
        '1111111111111111111111111111111111111111111111111111111111111111',
      );
      expect(
        sender.calls.single.transaction.to,
        '0x2222222222222222222222222222222222222222',
      );
      final signingEntry = (await securityLogs.listEntries()).single;
      expect(signingEntry.type, SecurityLogEventType.signTransaction);
      expect(signingEntry.walletName, 'Main Wallet');
      expect(signingEntry.chainName, 'Ethereum');
      expect(history.records.single.transactionHash, '0xdapphash');
      expect(history.records.single.amount, '0.000000000000000001');
      expect(history.records.single.memo, 'eth_sendTransaction');
    });

    test(
      'dApp broadcast remains successful when history persistence fails',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final history = _MemoryTransactionHistoryRepository(
          saveError: StateError('disk full'),
        );
        final container = _container(
          account: account,
          repository: repository,
          sender: _FakeDappEvmTransactionSender(),
          transactionHistoryRepository: history,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await _unlock(container, account, now);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://app.uniswap.org',
                method: 'eth_sendTransaction',
                params: [
                  {
                    'from': account.evmAddress,
                    'to': '0x2222222222222222222222222222222222222222',
                    'value': '0x1',
                    'gas': '0x5208',
                    'gasPrice': '0x1',
                  },
                ],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '0xdapphash');
      },
    );

    test(
      'eth_signTransaction confirms and returns a signed raw transaction',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappEvmTransactionSigner();
        final container = _container(
          account: account,
          repository: repository,
          transactionSigner: signer,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'app.uniswap.org',
              walletId: account.id,
              chainId: '1',
              address: account.evmAddress,
              now: now,
            );

        final request = DappRpcRequest(
          origin: 'https://app.uniswap.org/swap',
          method: 'eth_signTransaction',
          params: [
            {
              'from': account.evmAddress,
              'to': '0x2222222222222222222222222222222222222222',
              'value': '0x1',
              'nonce': '0x2',
              'gas': '0x5208',
              'gasPrice': '0x1',
            },
          ],
        );
        final preview = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);
        expect(preview.status, DappRequestResultStatus.confirmationRequired);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '0xsignedraw');
        expect(signer.calls.single.transaction.nonce, 2);
        expect(signer.calls.single.chain.chainId, '1');
      },
    );

    test(
      'read-only EVM RPC request is forwarded to selected RPC node',
      () async {
        final rpcClient = _FakeDappEvmReadRpcClient({
          'eth_blockNumber': '0x1234',
        });
        final container = _container(
          account: account,
          readRpcClient: rpcClient,
          rpcNodeRepository: _FakeRpcNodeRepository(withHeaderCredential: true),
          rpcCredentialStore: const _FakeRpcCredentialStore(),
        );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'eth_blockNumber',
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '0x1234');
        expect(rpcClient.calls.single.chain.id, 'ethereum');
        expect(
          rpcClient.calls.single.rpcUrl,
          'https://selected-rpc.example.com',
        );
        expect(rpcClient.calls.single.method, 'eth_blockNumber');
        expect(rpcClient.calls.single.params, isEmpty);
        expect(rpcClient.calls.single.headers, {'x-api-key': 'secret'});
      },
    );

    test('read-only EVM RPC error is returned to the dApp', () async {
      final rpcClient = _FakeDappEvmReadRpcClient({
        'eth_call': const DappEvmReadRpcResponse.error(
          DappJsonRpcError(
            code: -32000,
            message: 'err: insufficient funds for gas * price + value',
          ),
        ),
      });
      final container = _container(account: account, readRpcClient: rpcClient);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://pancakeswap.finance/swap',
              method: 'eth_call',
              params: [
                {
                  'from': '0x9858effd232b4033e47d90003d41ec34ecaeda94',
                  'to': '0x1111111111111111111111111111111111111111',
                  'data': '0x',
                },
                'latest',
              ],
            ),
            now: now,
          );

      expect(result.status, DappRequestResultStatus.failure);
      expect(result.jsonRpcError?.code, -32000);
      expect(
        result.jsonRpcError?.message,
        'err: insufficient funds for gas * price + value',
      );
      expect(rpcClient.calls.single.method, 'eth_call');
    });

    test(
      'net version returns selected EVM chain id without RPC call',
      () async {
        final rpcClient = _FakeDappEvmReadRpcClient({});
        final container = _container(
          account: account,
          readRpcClient: rpcClient,
        );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://app.uniswap.org/swap',
                method: 'net_version',
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, '1');
        expect(rpcClient.calls, isEmpty);
      },
    );

    test('Solana connect approval stores permission by domain', () async {
      final repository = InMemoryDappPermissionRepository();
      final chainRepository = _FakeChainRepository(
        selectedChainId: 'solana-mainnet',
      );
      final container = _container(
        account: account,
        repository: repository,
        chainRepository: chainRepository,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://jup.ag/swap',
              method: 'solana_connect',
            ),
            authorizationDecision: DappAuthorizationDecision.approved,
            now: now,
          );

      final stored = await repository.permissionFor(
        domain: 'jup.ag',
        walletId: account.id,
        chainId: 'mainnet-beta',
      );

      expect(result.status, DappRequestResultStatus.success);
      expect(result.value, {'publicKey': account.solanaAddress});
      expect(stored?.domain, 'https://jup.ag');
      expect(stored?.address, account.solanaAddress);
    });

    test(
      'Solana connect uses default Solana chain when EVM is selected',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final chainRepository = _FakeChainRepository();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://jup.ag/swap',
                method: 'solana_connect',
              ),
              authorizationDecision: DappAuthorizationDecision.approved,
              now: now,
            );

        final stored = await repository.permissionFor(
          domain: 'jup.ag',
          walletId: account.id,
          chainId: 'mainnet-beta',
        );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, {'publicKey': account.solanaAddress});
        expect(stored?.address, account.solanaAddress);
        expect(chainRepository.selectedChainId, 'ethereum');
      },
    );

    test(
      'Sui connect approval stores chain-scoped permission and public key',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'sui-mainnet',
        );
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://trade.sui.io/swap',
                method: 'sui_connect',
              ),
              authorizationDecision: DappAuthorizationDecision.approved,
              now: now,
            );

        final stored = await repository.permissionFor(
          domain: 'trade.sui.io',
          walletId: account.id,
          chainId: 'sui:mainnet',
        );
        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, {
          'address': _suiAddress,
          'publicKey': _suiPublicKey,
          'chain': 'sui:mainnet',
        });
        expect(stored?.address, _suiAddress);
      },
    );

    test('Sui disconnect revokes the current domain permission', () async {
      final repository = InMemoryDappPermissionRepository();
      final chainRepository = _FakeChainRepository(
        selectedChainId: 'sui-mainnet',
      );
      final container = _container(
        account: account,
        repository: repository,
        chainRepository: chainRepository,
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'trade.sui.io',
            walletId: account.id,
            chainId: 'sui:mainnet',
            address: _suiAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://trade.sui.io/swap',
              method: 'sui_disconnect',
            ),
            now: now,
          );

      expect(result.status, DappRequestResultStatus.success);
      expect(
        await repository.permissionFor(
          domain: 'trade.sui.io',
          walletId: account.id,
          chainId: 'sui:mainnet',
        ),
        isNull,
      );
    });

    test(
      'Sui personal message requires review and uses PersonalMessage intent',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSuiSigner();
        final securityLogs = InMemorySecurityLogRepository();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: _FakeChainRepository(selectedChainId: 'sui-mainnet'),
          suiSigner: signer,
          securityLogRepository: securityLogs,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'trade.sui.io',
              walletId: account.id,
              chainId: 'sui:mainnet',
              address: _suiAddress,
              now: now,
            );
        const request = DappRpcRequest(
          origin: 'https://trade.sui.io/swap',
          method: 'sui_signPersonalMessage',
          params: [
            {
              'message': [104, 101, 108, 108, 111],
              'account': _suiAddress,
              'chain': 'sui:mainnet',
            },
          ],
        );

        final confirmation = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);
        expect(
          confirmation.status,
          DappRequestResultStatus.confirmationRequired,
        );
        expect(confirmation.confirmation?.message, 'hello');

        final signed = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(signed.status, DappRequestResultStatus.success);
        expect(signed.value, {
          'bytes': base64Encode([104, 101, 108, 108, 111]),
          'signature': 'sui-personal-signature',
        });
        expect(signer.personalMessages.single, [104, 101, 108, 108, 111]);
        expect(signer.privateKeys.single, _suiPrivateKey);
        final signingEntry = (await securityLogs.listEntries()).single;
        expect(signingEntry.type, SecurityLogEventType.signMessage);
        expect(signingEntry.chainName, 'Sui Mainnet');
      },
    );

    test(
      'Sui transaction signs reviewed bytes and executes via selected RPC',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSuiSigner();
        final executor = _FakeDappSuiTransactionExecutor();
        final history = _MemoryTransactionHistoryRepository();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: _FakeChainRepository(selectedChainId: 'sui-mainnet'),
          suiSigner: signer,
          suiExecutor: executor,
          transactionHistoryRepository: history,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'trade.sui.io',
              walletId: account.id,
              chainId: 'sui:mainnet',
              address: _suiAddress,
              now: now,
            );
        final transactionBytes = await _suiTransactionBytes(_suiAddress);
        final request = DappRpcRequest(
          origin: 'https://trade.sui.io/swap',
          method: 'sui_signAndExecuteTransaction',
          params: [
            {
              'transaction': transactionBytes,
              'account': _suiAddress,
              'chain': 'sui:mainnet',
            },
          ],
        );

        final confirmation = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);
        expect(
          confirmation.status,
          DappRequestResultStatus.confirmationRequired,
        );
        expect(confirmation.confirmation?.transaction?.from, _suiAddress);
        expect(confirmation.confirmation?.transaction?.highRisk, isTrue);
        expect(
          confirmation.confirmation?.transaction?.decodedInfo,
          contains('MoveCall 0x2::safe_wallet_test::review'),
        );
        expect(
          confirmation.confirmation?.transaction?.estimatedFee,
          '0.000001 SUI',
        );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, {'digest': '7SuiDigest'});
        expect(signer.transactions.single, transactionBytes);
        expect(
          executor.calls.single.rpcUrl,
          'https://selected-rpc.example.com',
        );
        expect(executor.calls.single.transactionBytes, transactionBytes);
        expect(executor.calls.single.signature, 'sui-transaction-signature');
        expect(history.records.single.transactionHash, '7SuiDigest');
        expect(history.records.single.memo, 'sui_signAndExecuteTransaction');
      },
    );

    test(
      'Sui signTransaction returns bytes and signature without broadcast',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSuiSigner();
        final executor = _FakeDappSuiTransactionExecutor();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: _FakeChainRepository(selectedChainId: 'sui-mainnet'),
          suiSigner: signer,
          suiExecutor: executor,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'trade.sui.io',
              walletId: account.id,
              chainId: 'sui:mainnet',
              address: _suiAddress,
              now: now,
            );
        final bytes = await _suiTransactionBytes(_suiAddress);

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              DappRpcRequest(
                origin: 'https://trade.sui.io/swap',
                method: 'sui_signTransaction',
                params: [
                  {
                    'transaction': bytes,
                    'account': _suiAddress,
                    'chain': 'sui:mainnet',
                  },
                ],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.value, {
          'bytes': base64Encode(bytes),
          'signature': 'sui-transaction-signature',
        });
        expect(executor.calls, isEmpty);
      },
    );

    test(
      'Sui signing rejects an account or chain mismatch before signing',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSuiSigner();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: _FakeChainRepository(selectedChainId: 'sui-mainnet'),
          suiSigner: signer,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'trade.sui.io',
              walletId: account.id,
              chainId: 'sui:mainnet',
              address: _suiAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://trade.sui.io/swap',
                method: 'sui_signPersonalMessage',
                params: [
                  {
                    'message': [1, 2, 3],
                    'account': '0x2',
                    'chain': 'sui:testnet',
                  },
                ],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.status, DappRequestResultStatus.failure);
        expect(result.errorCode, 'dapp_unauthorized');
        expect(signer.privateKeys, isEmpty);
      },
    );

    test(
      'Solana sign message requires review and signs with Solana key',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSolanaMessageSigner();
        final securityLogs = InMemorySecurityLogRepository();
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        );
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
          solanaMessageSigner: signer,
          securityLogRepository: securityLogs,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'jup.ag',
              walletId: account.id,
              chainId: 'mainnet-beta',
              address: account.solanaAddress,
              now: now,
            );

        const request = DappRpcRequest(
          origin: 'https://jup.ag/swap',
          method: 'solana_signMessage',
          params: [
            [104, 101, 108, 108, 111],
            'utf8',
          ],
        );

        final confirmationResult = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);

        expect(
          confirmationResult.status,
          DappRequestResultStatus.confirmationRequired,
        );
        expect(
          confirmationResult.confirmation?.kind,
          DappConfirmationKind.signature,
        );
        expect(confirmationResult.confirmation?.message, 'hello');

        final signed = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(signed.status, DappRequestResultStatus.success);
        expect(signed.value, {
          'signature': [9, 8, 7],
          'publicKey': account.solanaAddress,
        });
        expect(signer.calls.single.privateKey, _solanaPrivateKey);
        expect(signer.calls.single.message, [104, 101, 108, 108, 111]);
        final signingEntry = (await securityLogs.listEntries()).single;
        expect(signingEntry.type, SecurityLogEventType.signMessage);
        expect(signingEntry.walletName, 'Main Wallet');
        expect(signingEntry.chainName, 'Solana Mainnet');
      },
    );

    test(
      'Solana sign transaction requires review and signs transaction bytes',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSolanaTransactionSigner();
        final securityLogs = InMemorySecurityLogRepository();
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        );
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
          solanaTransactionSigner: signer,
          securityLogRepository: securityLogs,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'jup.ag',
              walletId: account.id,
              chainId: 'mainnet-beta',
              address: account.solanaAddress,
              now: now,
            );

        const request = DappRpcRequest(
          origin: 'https://jup.ag/swap',
          method: 'solana_signTransaction',
          params: [
            [1, 2, 3, 4],
          ],
        );

        final confirmationResult = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);

        expect(
          confirmationResult.status,
          DappRequestResultStatus.confirmationRequired,
        );
        expect(
          confirmationResult.confirmation?.kind,
          DappConfirmationKind.transaction,
        );
        expect(
          confirmationResult.confirmation?.transaction?.from,
          account.solanaAddress,
        );
        expect(confirmationResult.confirmation?.transaction?.highRisk, isTrue);

        final signed = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(signed.status, DappRequestResultStatus.success);
        expect(signed.value, {
          'serializedTransaction': [4, 3, 2, 1],
        });
        expect(signer.calls.single.privateKey, _solanaPrivateKey);
        expect(signer.calls.single.serializedTransaction, [1, 2, 3, 4]);
        final signingEntry = (await securityLogs.listEntries()).single;
        expect(signingEntry.type, SecurityLogEventType.signTransaction);
        expect(signingEntry.walletName, 'Main Wallet');
        expect(signingEntry.chainName, 'Solana Mainnet');
      },
    );

    test(
      'Solana sign-all previews every transaction before approval',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: _FakeChainRepository(
            selectedChainId: 'solana-mainnet',
          ),
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'jup.ag',
              walletId: account.id,
              chainId: 'mainnet-beta',
              address: account.solanaAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://jup.ag/swap',
                method: 'solana_signAllTransactions',
                params: [
                  [
                    [1, 2],
                    [3, 4],
                  ],
                ],
              ),
              now: now,
            );

        expect(result.status, DappRequestResultStatus.confirmationRequired);
        expect(result.confirmation?.transactions, hasLength(2));
        expect(result.confirmation?.transactions[0].data, '0x0102');
        expect(result.confirmation?.transactions[1].data, '0x0304');
      },
    );

    test('Solana SOL transfer preview shows recipient and amount', () async {
      final repository = InMemoryDappPermissionRepository();
      final payer = solana.Keypair.fromSeed(
        Uint8List.fromList(List<int>.filled(32, 7)),
      );
      final solanaAccount = WalletAccount(
        id: 'wallet-solana-preview',
        name: 'Solana Wallet',
        evmAddress: account.evmAddress,
        solanaAddress: payer.publicKey.toBase58(),
        createdAt: now,
        updatedAt: now,
      );
      final recipient = solana.PublicKey.fromBase58(
        '8qbHbw2BbbTHBW1sbeqakYXVKRQM8Ne7pLK7m6CVfeR',
      );
      final instruction = solana.SystemProgram.transfer(
        fromPubkey: payer.publicKey,
        toPubkey: recipient,
        lamports: BigInt.from(100000000),
      );
      final message = solana.Message.compile(
        payerKey: payer.publicKey,
        recentBlockhash: 'CktRuQ2mttgRGkXJtyksdKHjUdc2C4TgDzyB98oEzy8',
        instructions: [instruction],
      );
      final transaction = solana.VersionedTransaction.legacy(message: message);
      final transactionBytes = transaction.serialize().toList();
      final container = _container(
        account: solanaAccount,
        repository: repository,
        chainRepository: _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        ),
      );
      container
          .read(selectedWalletIdProvider.notifier)
          .select(solanaAccount.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'jup.ag',
            walletId: solanaAccount.id,
            chainId: 'mainnet-beta',
            address: solanaAccount.solanaAddress,
            now: now,
          );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://jup.ag',
              method: 'solana_signTransaction',
              params: [transactionBytes],
            ),
            now: now,
          );

      final preview = result.confirmation?.transaction;
      expect(preview?.to, recipient.toBase58());
      expect(preview?.value, '0.1 SOL');
      expect(preview?.decodedInfo, contains('System Program SOL transfer'));
      expect(preview?.highRisk, isFalse);
    });

    test(
      'Solana sign and send transaction broadcasts via selected RPC',
      () async {
        final repository = InMemoryDappPermissionRepository();
        final signer = _FakeDappSolanaTransactionSigner();
        final sender = _FakeDappSolanaRawTransactionSender();
        final chainRepository = _FakeChainRepository(
          selectedChainId: 'solana-mainnet',
        );
        final history = _MemoryTransactionHistoryRepository();
        final container = _container(
          account: account,
          repository: repository,
          chainRepository: chainRepository,
          solanaTransactionSigner: signer,
          solanaRawTransactionSender: sender,
          transactionHistoryRepository: history,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        await container
            .read(dappPermissionControllerProvider.notifier)
            .approve(
              domain: 'jup.ag',
              walletId: account.id,
              chainId: 'mainnet-beta',
              address: account.solanaAddress,
              now: now,
            );

        final result = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              const DappRpcRequest(
                origin: 'https://jup.ag/swap',
                method: 'solana_signAndSendTransaction',
                params: [
                  [1, 2, 3, 4],
                  {'skipPreflight': true},
                ],
              ),
              confirmationDecision: DappConfirmationDecision.approved,
              signingPassword: 'password',
              now: now,
            );

        expect(result.status, DappRequestResultStatus.success);
        expect(result.value, {
          'signature': 'solana-signature',
          'publicKey': account.solanaAddress,
        });
        expect(signer.calls.single.serializedTransaction, [1, 2, 3, 4]);
        expect(sender.calls.single.rpcUrl, 'https://selected-rpc.example.com');
        expect(sender.calls.single.serializedTransaction, [4, 3, 2, 1]);
        expect(history.records.single.transactionHash, 'solana-signature');
        expect(history.records.single.memo, 'solana_signAndSendTransaction');
      },
    );

    test(
      'chain switch requires confirmation before selecting supported chain',
      () async {
        final chainRepository = _FakeChainRepository();
        final container = _container(
          account: account,
          chainRepository: chainRepository,
        );
        container.read(selectedWalletIdProvider.notifier).select(account.id);
        const request = DappRpcRequest(
          origin: 'https://app.uniswap.org/swap',
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': '0x38'},
          ],
        );

        final confirmationResult = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(request, now: now);

        expect(
          confirmationResult.status,
          DappRequestResultStatus.confirmationRequired,
        );
        expect(
          confirmationResult.confirmation?.kind,
          DappConfirmationKind.chainSwitch,
        );
        expect(
          confirmationResult.confirmation?.requestedChain?.id,
          'bnb-smart-chain',
        );
        expect(chainRepository.selectedChainId, 'ethereum');

        final approved = await container
            .read(dappRequestControllerProvider.notifier)
            .handle(
              request,
              confirmationDecision: DappConfirmationDecision.approved,
              now: now,
            );

        expect(approved.status, DappRequestResultStatus.success);
        expect(chainRepository.selectedChainId, 'bnb-smart-chain');
      },
    );

    test('eth_signTypedData_v4 signs an EIP-712 payload', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(
        account: account,
        repository: repository,
        evmPrivateKey: web3.bytesToHex(web3.keccakUtf8('cow')),
      );
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'polymarket.com',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );
      final request = DappRpcRequest(
        origin: 'https://polymarket.com',
        method: 'eth_signTypedData_v4',
        params: [account.evmAddress, jsonEncode(_eip712MailTypedData)],
      );

      final confirmationResult = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(request, now: now);

      expect(
        confirmationResult.status,
        DappRequestResultStatus.confirmationRequired,
      );
      expect(
        confirmationResult.confirmation?.kind,
        DappConfirmationKind.signature,
      );

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            request,
            confirmationDecision: DappConfirmationDecision.approved,
            signingPassword: 'password',
            now: now,
          );
      expect(result.status, DappRequestResultStatus.success);
      expect(
        result.value,
        '0x4355c47d63924e8a72e509b65029052eb6c299d53a04e167c5775fd466751c9d'
        '07299936d304c153f6443dfa05f40ff007d72911b6f72307f996231605b915621c',
      );
    });

    test('eth_signTypedData_v4 rejects a mismatched domain chain id', () async {
      final repository = InMemoryDappPermissionRepository();
      final container = _container(account: account, repository: repository);
      container.read(selectedWalletIdProvider.notifier).select(account.id);
      await container
          .read(dappPermissionControllerProvider.notifier)
          .approve(
            domain: 'polymarket.com',
            walletId: account.id,
            chainId: '1',
            address: account.evmAddress,
            now: now,
          );
      final mismatchedTypedData = <String, Object?>{
        ..._eip712MailTypedData,
        'domain': <String, Object?>{
          ...(_eip712MailTypedData['domain']! as Map<String, Object>),
          'chainId': 137,
        },
      };

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            DappRpcRequest(
              origin: 'https://polymarket.com',
              method: 'eth_signTypedData_v4',
              params: [account.evmAddress, jsonEncode(mismatchedTypedData)],
            ),
            now: now,
          );

      expect(result.status, DappRequestResultStatus.failure);
      expect(result.errorCode, 'dapp_unauthorized');
    });

    test('unsupported method returns unsupported result', () async {
      final container = _container(account: account);

      final result = await container
          .read(dappRequestControllerProvider.notifier)
          .handle(
            const DappRpcRequest(
              origin: 'https://app.uniswap.org/swap',
              method: 'wallet_watchAsset',
            ),
          );

      expect(result.status, DappRequestResultStatus.unsupported);
      expect(result.errorCode, 'dapp_unsupported_method');
    });
  });

  group('SdkDappSuiSigner', () {
    test(
      'signs personal messages with the Sui PersonalMessage intent',
      () async {
        const signer = SdkDappSuiSigner();
        final message = utf8.encode('SafeWallet Sui');

        final signed = await signer.signPersonalMessage(
          privateKey: _suiPrivateKey,
          message: message,
        );
        final account = sui.SuiAccount.fromPrivateKey(
          _hex(_suiPrivateKey),
          sui.SignatureScheme.Ed25519,
        );

        expect(signed.bytes, base64Encode(message));
        expect(
          account.keyPair.verifyPersonalMessage(
            Uint8List.fromList(message),
            signed.signature,
          ),
          isTrue,
        );
      },
    );

    test(
      'signs complete TransactionData bytes with transaction intent',
      () async {
        const signer = SdkDappSuiSigner();
        final account = sui.SuiAccount.fromPrivateKey(
          _hex(_suiPrivateKey),
          sui.SignatureScheme.Ed25519,
        );
        final bytes = await _suiTransactionBytes(account.getAddress());

        final signed = await signer.signTransaction(
          privateKey: _suiPrivateKey,
          transactionBytes: bytes,
        );

        expect(signed.bytes, base64Encode(bytes));
        expect(
          account.keyPair.verifyTransaction(
            Uint8List.fromList(bytes),
            signed.signature,
          ),
          isTrue,
        );
      },
    );
  });
}

Future<void> _unlock(
  ProviderContainer container,
  WalletAccount account,
  DateTime now,
) async {
  await container
      .read(walletSessionControllerProvider.notifier)
      .unlock(walletId: account.id, password: 'password', now: now);
}

ProviderContainer _container({
  required WalletAccount account,
  List<WalletAccount>? accounts,
  DappPermissionRepository? repository,
  ChainRepository? chainRepository,
  RpcNodeRepository? rpcNodeRepository,
  RpcCredentialStore? rpcCredentialStore,
  DappEvmTransactionSender? sender,
  DappEvmTransactionSigner? transactionSigner,
  DappEvmReadRpcClient? readRpcClient,
  DappEvmTransactionSimulator? simulator,
  DappEvmTokenLookup? tokenLookup,
  DappSolanaMessageSigner? solanaMessageSigner,
  DappSolanaTransactionSigner? solanaTransactionSigner,
  DappSolanaRawTransactionSender? solanaRawTransactionSender,
  DappSuiSigner? suiSigner,
  DappSuiTransactionExecutor? suiExecutor,
  SecurityLogRepository? securityLogRepository,
  TransactionHistoryRepository? transactionHistoryRepository,
  String evmPrivateKey = _evmPrivateKey,
}) {
  final container = ProviderContainer(
    overrides: [
      dappPermissionRepositoryProvider.overrideWithValue(
        repository ?? InMemoryDappPermissionRepository(),
      ),
      walletRepositoryProvider.overrideWithValue(
        _FakeWalletRepository(
          account: account,
          accounts: accounts,
          evmPrivateKey: evmPrivateKey,
        ),
      ),
      chainRepositoryProvider.overrideWithValue(
        chainRepository ?? _FakeChainRepository(),
      ),
      rpcNodeRepositoryProvider.overrideWithValue(
        rpcNodeRepository ?? _FakeRpcNodeRepository(),
      ),
      if (rpcCredentialStore != null)
        rpcCredentialStoreProvider.overrideWithValue(rpcCredentialStore),
      transactionHistoryRepositoryProvider.overrideWithValue(
        transactionHistoryRepository ?? _MemoryTransactionHistoryRepository(),
      ),
      if (securityLogRepository != null)
        securityLogRepositoryProvider.overrideWithValue(securityLogRepository),
      if (sender != null)
        dappEvmTransactionSenderProvider.overrideWithValue(sender),
      if (transactionSigner != null)
        dappEvmTransactionSignerProvider.overrideWithValue(transactionSigner),
      if (readRpcClient != null)
        dappEvmReadRpcClientProvider.overrideWithValue(readRpcClient),
      dappEvmTransactionSimulatorProvider.overrideWithValue(
        simulator ??
            _FakeDappEvmTransactionSimulator(
              const DappTransactionSimulation.succeeded(),
            ),
      ),
      dappEvmTokenLookupProvider.overrideWithValue(
        tokenLookup ??
            ({required chainId, required contractAddress}) async {
              if (chainId == '1' &&
                  contractAddress.toLowerCase() == _usdcContractAddress) {
                return _usdcToken;
              }
              return null;
            },
      ),
      if (solanaMessageSigner != null)
        dappSolanaMessageSignerProvider.overrideWithValue(solanaMessageSigner),
      if (solanaTransactionSigner != null)
        dappSolanaTransactionSignerProvider.overrideWithValue(
          solanaTransactionSigner,
        ),
      if (solanaRawTransactionSender != null)
        dappSolanaRawTransactionSenderProvider.overrideWithValue(
          solanaRawTransactionSender,
        ),
      if (suiSigner != null) dappSuiSignerProvider.overrideWithValue(suiSigner),
      if (suiExecutor != null)
        dappSuiTransactionExecutorProvider.overrideWithValue(suiExecutor),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository({
    required this.account,
    this.accounts,
    required this.evmPrivateKey,
  });

  final WalletAccount account;
  final List<WalletAccount>? accounts;
  final String evmPrivateKey;

  @override
  Future<WalletAccount> createWallet({
    String? password,
    String name = 'Wallet 1',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletAccount>> getWallets() async => accounts ?? [account];

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
  }) async => WalletKeyMaterial(
    evmPrivateKey: evmPrivateKey,
    solanaPrivateKey: _solanaPrivateKey,
    suiPrivateKey: _suiPrivateKey,
  );

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
  }) async => WalletUnlockResult(account: account, walletDek: [1, 2, 3, 4]);
}

final class _FakeDappEvmTransactionSender implements DappEvmTransactionSender {
  final calls =
      <
        ({
          ChainConfig chain,
          String rpcUrl,
          String privateKey,
          DappEvmTransaction transaction,
          Map<String, String> headers,
        })
      >[];

  @override
  Future<String> send({
    required ChainConfig chain,
    required String rpcUrl,
    required String privateKey,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  }) async {
    calls.add((
      chain: chain,
      rpcUrl: rpcUrl,
      privateKey: privateKey,
      transaction: transaction,
      headers: headers,
    ));
    return '0xdapphash';
  }
}

final class _FakeDappEvmTransactionSigner implements DappEvmTransactionSigner {
  final calls =
      <
        ({
          ChainConfig chain,
          String rpcUrl,
          String privateKey,
          DappEvmTransaction transaction,
          Map<String, String> headers,
        })
      >[];

  @override
  Future<String> sign({
    required ChainConfig chain,
    required String rpcUrl,
    required String privateKey,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  }) async {
    calls.add((
      chain: chain,
      rpcUrl: rpcUrl,
      privateKey: privateKey,
      transaction: transaction,
      headers: headers,
    ));
    return '0xsignedraw';
  }
}

final class _FakeDappEvmReadRpcClient implements DappEvmReadRpcClient {
  _FakeDappEvmReadRpcClient(this.results);

  final Map<String, Object?> results;
  final calls =
      <
        ({
          ChainConfig chain,
          String rpcUrl,
          String method,
          List<Object?> params,
          Map<String, String> headers,
        })
      >[];

  @override
  Future<DappEvmReadRpcResponse> request({
    required ChainConfig chain,
    required String rpcUrl,
    required String method,
    required List<Object?> params,
    Map<String, String> headers = const {},
  }) async {
    calls.add((
      chain: chain,
      rpcUrl: rpcUrl,
      method: method,
      params: params,
      headers: headers,
    ));
    final result = results[method];
    if (result is DappEvmReadRpcResponse) {
      return result;
    }
    return DappEvmReadRpcResponse.result(result);
  }
}

final class _FakeDappEvmTransactionSimulator
    implements DappEvmTransactionSimulator {
  _FakeDappEvmTransactionSimulator(this.result);

  final DappTransactionSimulation result;

  @override
  Future<DappTransactionSimulation> simulate({
    required ChainConfig chain,
    required String rpcUrl,
    required DappEvmTransaction transaction,
    Map<String, String> headers = const {},
  }) async {
    return result;
  }
}

final class _MemoryTransactionHistoryRepository
    implements TransactionHistoryRepository {
  _MemoryTransactionHistoryRepository({this.saveError});

  final Object? saveError;
  final records = <TransactionRecord>[];

  @override
  Future<void> save(TransactionRecord record) async {
    final error = saveError;
    if (error != null) {
      throw error;
    }
    records.add(record);
  }

  @override
  Future<List<TransactionRecord>> list({String? chainId}) async {
    return records
        .where((record) => chainId == null || record.chainId == chainId)
        .toList(growable: false);
  }

  @override
  Future<List<TransactionRecord>> recent({
    int limit = 4,
    String? chainId,
  }) async {
    final values = await list(chainId: chainId);
    return values.take(limit).toList(growable: false);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required TransactionStatus status,
    String? failureReason,
  }) async {}
}

final class _FakeDappSolanaMessageSigner implements DappSolanaMessageSigner {
  final calls = <({List<int> privateKey, List<int> message})>[];

  @override
  Future<List<int>> sign({
    required List<int> privateKey,
    required List<int> message,
  }) async {
    calls.add((privateKey: privateKey, message: message));
    return [9, 8, 7];
  }
}

final class _FakeDappSolanaTransactionSigner
    implements DappSolanaTransactionSigner {
  final calls = <({List<int> privateKey, List<int> serializedTransaction})>[];

  @override
  Future<List<int>> sign({
    required List<int> privateKey,
    required List<int> serializedTransaction,
  }) async {
    calls.add((
      privateKey: privateKey,
      serializedTransaction: serializedTransaction,
    ));
    return serializedTransaction.reversed.toList();
  }
}

final class _FakeDappSolanaRawTransactionSender
    implements DappSolanaRawTransactionSender {
  final calls =
      <
        ({
          ChainConfig chain,
          String rpcUrl,
          List<int> serializedTransaction,
          Map<String, String> headers,
        })
      >[];

  @override
  Future<String> send({
    required ChainConfig chain,
    required String rpcUrl,
    required List<int> serializedTransaction,
    Map<String, String> headers = const {},
  }) async {
    calls.add((
      chain: chain,
      rpcUrl: rpcUrl,
      serializedTransaction: serializedTransaction,
      headers: headers,
    ));
    return 'solana-signature';
  }
}

final class _FakeDappSuiSigner implements DappSuiSigner {
  final privateKeys = <List<int>>[];
  final personalMessages = <List<int>>[];
  final transactions = <List<int>>[];

  @override
  Future<DappSuiSignedData> signPersonalMessage({
    required List<int> privateKey,
    required List<int> message,
  }) async {
    privateKeys.add(List.unmodifiable(privateKey));
    personalMessages.add(List.unmodifiable(message));
    return DappSuiSignedData(
      bytes: base64Encode(message),
      signature: 'sui-personal-signature',
    );
  }

  @override
  Future<DappSuiSignedData> signTransaction({
    required List<int> privateKey,
    required List<int> transactionBytes,
  }) async {
    privateKeys.add(List.unmodifiable(privateKey));
    transactions.add(List.unmodifiable(transactionBytes));
    return DappSuiSignedData(
      bytes: base64Encode(transactionBytes),
      signature: 'sui-transaction-signature',
    );
  }
}

final class _FakeDappSuiTransactionExecutor
    implements DappSuiTransactionExecutor {
  final calls =
      <
        ({
          ChainConfig chain,
          String rpcUrl,
          List<int> transactionBytes,
          String signature,
          Map<String, String> headers,
        })
      >[];

  @override
  Future<String> execute({
    required ChainConfig chain,
    required String rpcUrl,
    required List<int> transactionBytes,
    required String signature,
    Map<String, String> headers = const {},
  }) async {
    calls.add((
      chain: chain,
      rpcUrl: rpcUrl,
      transactionBytes: List.unmodifiable(transactionBytes),
      signature: signature,
      headers: headers,
    ));
    return '7SuiDigest';
  }
}

final class _FakeRpcNodeRepository implements RpcNodeRepository {
  const _FakeRpcNodeRepository({this.withHeaderCredential = false});

  final bool withHeaderCredential;

  @override
  Future<RpcNode> getSelectedNode(ChainConfig chain) async {
    return RpcNode(
      id: '${chain.id}-selected',
      chainId: chain.chainId,
      name: 'Selected RPC',
      url: 'https://selected-rpc.example.com',
      nodeType: RpcNodeType.custom,
      isSelected: true,
      lastTestStatus: RpcNodeTestStatus.available,
      credentialMode: withHeaderCredential
          ? RpcCredentialMode.header
          : RpcCredentialMode.none,
      credentialParameter: withHeaderCredential ? 'x-api-key' : null,
      credentialRef: withHeaderCredential ? 'rpc-secret' : null,
    );
  }

  @override
  Future<List<RpcNode>> getNodesForChain(ChainConfig chain) async {
    return [await getSelectedNode(chain)];
  }

  @override
  Future<RpcNode> addCustomNode({
    required ChainConfig chain,
    required String name,
    required String url,
    String? note,
    RpcProvider provider = RpcProvider.custom,
    RpcCredentialMode credentialMode = RpcCredentialMode.none,
    String? credentialParameter,
    String? credential,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNode({
    required ChainConfig chain,
    required String nodeId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> selectNode({
    required ChainConfig chain,
    required String nodeId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> updateCustomNode({
    required ChainConfig chain,
    required String nodeId,
    required String name,
    required String url,
    String? note,
    RpcProvider? provider,
    RpcCredentialMode? credentialMode,
    String? credentialParameter,
    String? credential,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<RpcNode> updateTestStatus({
    required String nodeId,
    required RpcNodeTestStatus status,
    required DateTime testedAt,
    int? blockHeight,
    int? latencyMs,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeRpcCredentialStore implements RpcCredentialStore {
  const _FakeRpcCredentialStore();

  @override
  Future<String?> read(String credentialRef) async => 'secret';

  @override
  Future<void> write(String credentialRef, String credential) async {}

  @override
  Future<void> delete(String credentialRef) async {}
}

final class _FakeChainRepository implements ChainRepository {
  _FakeChainRepository({this.selectedChainId = 'ethereum'});

  String selectedChainId = 'ethereum';

  @override
  Future<List<ChainConfig>> getChains() async => defaultChains;

  @override
  Future<ChainConfig> addCustomEvmChain({
    required String name,
    required String chainId,
    required String rpcUrl,
    required String symbol,
    String? blockExplorerUrl,
    bool isTestnet = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChainConfig> getSelectedChain() async {
    return defaultChains.firstWhere((chain) => chain.id == selectedChainId);
  }

  @override
  Future<ChainConfig> selectChain(String chainId) async {
    selectedChainId = chainId;
    return getSelectedChain();
  }
}

const _usdcContractAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const _usdcToken = TokenInfo(
  chainId: '1',
  contractAddress: _usdcContractAddress,
  symbol: 'USDC',
  name: 'USD Coin',
  decimals: 6,
  source: TokenSource.builtIn,
  isHidden: false,
);
const _evmPrivateKey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _eip712MailTypedData = {
  'types': {
    'EIP712Domain': [
      {'name': 'name', 'type': 'string'},
      {'name': 'version', 'type': 'string'},
      {'name': 'chainId', 'type': 'uint256'},
      {'name': 'verifyingContract', 'type': 'address'},
    ],
    'Person': [
      {'name': 'name', 'type': 'string'},
      {'name': 'wallet', 'type': 'address'},
    ],
    'Mail': [
      {'name': 'from', 'type': 'Person'},
      {'name': 'to', 'type': 'Person'},
      {'name': 'contents', 'type': 'string'},
    ],
  },
  'primaryType': 'Mail',
  'domain': {
    'name': 'Ether Mail',
    'version': '1',
    'chainId': 1,
    'verifyingContract': '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  'message': {
    'from': {
      'name': 'Cow',
      'wallet': '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
    },
    'to': {
      'name': 'Bob',
      'wallet': '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
    },
    'contents': 'Hello, Bob!',
  },
};
const _erc20TransferCalldata =
    '0xa9059cbb'
    '0000000000000000000000002222222222222222222222222222222222222222'
    '0000000000000000000000000000000000000000000000000000000000bc6100';
final _solanaPrivateKey = List<int>.generate(64, (index) => index);
final _suiPrivateKey = List<int>.generate(32, (index) => index + 1);
final _suiPublicKey = List<int>.generate(32, (index) => 32 - index);
const _suiAddress =
    '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133';

Future<List<int>> _suiTransactionBytes(String sender) async {
  final transaction = sui.Transaction()
    ..setSender(sender)
    ..setGasOwner(sender)
    ..setGasPrice(BigInt.one)
    ..setGasBudget(BigInt.from(1000))
    ..setGasPayment([
      sui_types.SuiObjectRef(
        '11111111111111111111111111111111',
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        1,
      ),
    ])
    ..moveCall('0x2::safe_wallet_test::review');
  return (await transaction.build()).toList(growable: false);
}

String _hex(List<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
