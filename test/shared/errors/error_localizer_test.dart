import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/i18n/generated/translations.g.dart';
import 'package:safe_wallet/shared/errors/asset_error.dart';
import 'package:safe_wallet/shared/errors/dapp_error.dart';
import 'package:safe_wallet/shared/errors/error_localizer.dart';
import 'package:safe_wallet/shared/errors/rpc_error.dart';
import 'package:safe_wallet/shared/errors/transfer_error.dart';
import 'package:safe_wallet/shared/errors/wallet_error.dart';

void main() {
  group('ErrorLocalizer', () {
    final translations = AppLocale.zh.buildSync();
    const localizer = ErrorLocalizer();

    test('localizes wallet errors with safe messages', () {
      const locked = WalletError.walletLocked();
      const invalidMnemonic = WalletError.invalidMnemonic();
      const attemptLocked = WalletError.passwordAttemptLocked();

      expect(locked.code, 'wallet_locked');
      expect(locked.safeMessageKey, 'errors.walletLocked');
      expect(localizer.messageFor(locked, translations), '钱包已锁定，请先解锁');
      expect(
          localizer.messageFor(invalidMnemonic, translations), '助记词格式或校验和无效');
      expect(attemptLocked.code, 'password_attempt_locked');
      expect(
        localizer.messageFor(attemptLocked, translations),
        '密码错误次数过多，请稍后再试',
      );
    });

    test('localizes chain and rpc errors with safe messages', () {
      const mismatch = RpcError.chainMismatch(
        expectedChainId: '1',
        actualChainId: '137',
      );

      expect(mismatch.code, 'rpc_chain_mismatch');
      expect(mismatch.debugMessage, contains('expected=1'));
      expect(localizer.messageFor(mismatch, translations), 'RPC 节点与当前链不匹配');
      expect(
        localizer.messageFor(
          const RpcError.invalidCredential(),
          translations,
        ),
        'RPC 凭据无效或已失效',
      );
      expect(
        localizer.messageFor(const RpcError.rateLimited(), translations),
        'RPC 请求过于频繁或额度已用尽',
      );
      expect(
        localizer.messageFor(
          const RpcError.accessDenied(),
          translations,
        ),
        'RPC 拒绝访问，请检查节点权限、IP 或 VPN 设置',
      );
    });

    test('localizes asset, transfer, and dapp errors', () {
      const balanceError = AssetError.balanceQueryFailed();
      const feeError = TransferError.feeEstimateFailed();
      const rejected = DappError.userRejected();

      expect(
          localizer.messageFor(balanceError, translations), '余额查询失败，请检查网络节点');
      expect(localizer.messageFor(feeError, translations), '手续费估算失败，暂不能发送交易');
      expect(localizer.messageFor(rejected, translations), '用户已拒绝 dApp 请求');
      expect(
        localizer.messageFor(
          const TransferError.suiInsufficientGas(),
          translations,
        ),
        'SUI Gas 余额不足',
      );
      expect(
        localizer.messageFor(
          const TransferError.suiObjectConflict(),
          translations,
        ),
        'Sui Coin 对象已被占用或版本已过期，请刷新后重试',
      );
    });
  });
}
