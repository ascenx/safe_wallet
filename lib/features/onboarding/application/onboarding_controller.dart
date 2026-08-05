import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/application/wallet_session_controller.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_account.dart';
import '../../settings/application/launch_unlock_controller.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);

enum OnboardingImportMethod { mnemonic, privateKey }

final class OnboardingState {
  const OnboardingState({this.account});

  final WalletAccount? account;

  bool get hasWallet => account != null;
}

final class OnboardingController extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    final wallets = await ref.read(walletRepositoryProvider).getWallets();
    final persistedWalletId = ref.read(selectedWalletIdProvider);
    final persistedAccount = persistedWalletId == null
        ? null
        : wallets.where((wallet) => wallet.id == persistedWalletId).firstOrNull;
    final selectedAccount = persistedAccount ?? wallets.firstOrNull;
    if (selectedAccount != null) {
      await ref.read(selectedWalletIdProvider.notifier).select(
            selectedAccount.id,
          );
    }
    return OnboardingState(account: selectedAccount);
  }

  Future<WalletAccount> createWallet({required String password}) async {
    final account = await ref.read(walletRepositoryProvider).createWallet(
          password: password,
        );
    await _activateAccount(account: account, password: password);
    return account;
  }

  Future<WalletAccount> importWallet({
    required OnboardingImportMethod method,
    required String secret,
    required String password,
    WalletPrivateKeyChain privateKeyChain = WalletPrivateKeyChain.evm,
  }) async {
    final repository = ref.read(walletRepositoryProvider);
    final account = switch (method) {
      OnboardingImportMethod.mnemonic => await repository.importMnemonicWallet(
          mnemonic: secret,
          password: password,
        ),
      OnboardingImportMethod.privateKey =>
        await repository.importPrivateKeyWallet(
          privateKey: secret,
          password: password,
          chain: privateKeyChain,
        ),
    };
    await _activateAccount(account: account, password: password);
    return account;
  }

  Future<void> _activateAccount({
    required WalletAccount account,
    required String password,
  }) async {
    await ref.read(walletSessionControllerProvider.notifier).unlock(
          walletId: account.id,
          password: password,
        );
    ref.read(launchUnlockControllerProvider.notifier).markUnlocked();
    await ref.read(selectedWalletIdProvider.notifier).select(account.id);
    state = AsyncData(OnboardingState(account: account));
  }
}
