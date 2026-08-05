import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/address_book/domain/address_book_contact.dart';
import 'package:safe_wallet/features/assets/domain/asset_balance.dart';
import 'package:safe_wallet/features/assets/domain/token_info.dart';
import 'package:safe_wallet/features/browser/domain/dapp_entry.dart';
import 'package:safe_wallet/features/chains/domain/chain_config.dart';
import 'package:safe_wallet/features/dapp/domain/dapp_permission.dart';
import 'package:safe_wallet/features/nodes/domain/rpc_node.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_record.dart';
import 'package:safe_wallet/features/transfer/domain/transaction_request.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_account.dart';
import 'package:safe_wallet/features/wallet/domain/wallet_session.dart';

void main() {
  group('Domain models', () {
    test('wallet account uses value equality', () {
      final createdAt = DateTime.utc(2026, 6, 6);
      final updatedAt = DateTime.utc(2026, 6, 7);

      final first = WalletAccount(
        id: 'wallet-1',
        name: 'Main Wallet',
        evmAddress: '0x1111111111111111111111111111111111111111',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final second = WalletAccount(
        id: 'wallet-1',
        name: 'Main Wallet',
        evmAddress: '0x1111111111111111111111111111111111111111',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('wallet account returns the matching address for each chain type', () {
      final account = WalletAccount(
        id: 'wallet-1',
        name: 'Main Wallet',
        evmAddress: '0x1111111111111111111111111111111111111111',
        tronAddress: 'TBXSw8fVY3vQ2rhxQqCiuXj5RYnCcGLBZj',
        solanaAddress: 'So11111111111111111111111111111111111111112',
        btcAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
        suiAddress:
            '0xa2d14fad60c56049ecf75246a481934691214ce413e6a8ae2fe6834c173a6133',
        createdAt: DateTime.utc(2026, 6, 6),
        updatedAt: DateTime.utc(2026, 6, 7),
      );

      expect(
        account.addressForChainType(ChainType.evm),
        account.evmAddress,
      );
      expect(
        account.addressForChainType(ChainType.bitcoin),
        account.btcAddress,
      );
      expect(
        account.addressForChainType(ChainType.tron),
        account.tronAddress,
      );
      expect(
        account.addressForChainType(ChainType.solana),
        account.solanaAddress,
      );
      expect(
        account.addressForChainType(ChainType.sui),
        account.suiAddress,
      );
    });

    test('chain and rpc node models keep chain boundaries explicit', () {
      const ethereum = ChainConfig(
        id: 'ethereum',
        chainType: ChainType.evm,
        name: 'Ethereum',
        chainId: '1',
        symbol: 'ETH',
        rpcUrls: ['https://rpc.ankr.com/eth'],
        blockExplorerUrl: 'https://etherscan.io',
        isTestnet: false,
      );

      const node = RpcNode(
        id: 'node-1',
        chainId: '1',
        name: 'Default Ethereum',
        url: 'https://rpc.ankr.com/eth',
        nodeType: RpcNodeType.defaultNode,
        isSelected: true,
        lastTestStatus: RpcNodeTestStatus.untested,
      );

      expect(ethereum.chainType, ChainType.evm);
      expect(ethereum.rpcUrls, ['https://rpc.ankr.com/eth']);
      expect(node.chainId, ethereum.chainId);
      expect(node.nodeType, RpcNodeType.defaultNode);
    });

    test('asset and token models represent loading state separately', () {
      const token = TokenInfo(
        chainId: '1',
        contractAddress: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        source: TokenSource.builtIn,
        isHidden: false,
      );

      const balance = AssetBalance(
        chainId: '1',
        token: token,
        balance: '1200000',
        formattedBalance: '1.2',
        status: AssetBalanceStatus.loaded,
      );

      expect(balance.token, token);
      expect(balance.status, AssetBalanceStatus.loaded);
      expect(balance.formattedBalance, '1.2');
    });

    test('transaction models separate draft request and local record', () {
      const request = TransactionRequest(
        chainId: '1',
        chainType: ChainType.evm,
        assetSymbol: 'ETH',
        toAddress: '0x2222222222222222222222222222222222222222',
        amount: '0.1',
        transactionType: TransactionType.nativeTransfer,
      );

      final record = TransactionRecord(
        id: 'tx-1',
        chainId: '1',
        chainType: ChainType.evm,
        assetSymbol: 'ETH',
        direction: TransactionDirection.outgoing,
        amount: '0.1',
        status: TransactionStatus.submitted,
        transactionHash: '0xabc',
        createdAt: DateTime.utc(2026, 6, 6),
      );

      expect(request.transactionType, TransactionType.nativeTransfer);
      expect(record.direction, TransactionDirection.outgoing);
      expect(record.status, TransactionStatus.submitted);
    });

    test('dapp entry list fields use value equality', () {
      const first = DappEntry(
        id: 'uniswap',
        name: 'Uniswap',
        url: 'https://app.uniswap.org',
        category: DappCategory.swap,
        supportedChainIds: ['1', '137'],
        isFavorite: false,
      );

      const second = DappEntry(
        id: 'uniswap',
        name: 'Uniswap',
        url: 'https://app.uniswap.org',
        category: DappCategory.swap,
        supportedChainIds: ['1', '137'],
        isFavorite: false,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('permission, session, and address book models expose core fields', () {
      final grantedAt = DateTime.utc(2026, 6, 6);
      final contact = AddressBookContact(
        id: 'contact-1',
        name: 'Treasury',
        address: '0x3333333333333333333333333333333333333333',
        chainType: ChainType.evm,
        note: 'Main payee',
        createdAt: grantedAt,
        updatedAt: grantedAt,
      );

      final permission = DappPermission(
        id: 'permission-1',
        domain: 'app.uniswap.org',
        walletId: 'wallet-1',
        chainId: '1',
        address: contact.address,
        grantedAt: grantedAt,
        lastUsedAt: grantedAt,
      );

      final session = WalletSession(
        walletId: 'wallet-1',
        isUnlocked: true,
        unlockedUntil: grantedAt.add(const Duration(minutes: 15)),
      );

      expect(contact.chainType, ChainType.evm);
      expect(permission.domain, 'app.uniswap.org');
      expect(permission.walletId, 'wallet-1');
      expect(session.isUnlocked, isTrue);
    });
  });
}
