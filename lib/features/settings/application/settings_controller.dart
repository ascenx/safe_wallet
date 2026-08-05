import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/security/biometric_password_store.dart';
import '../../dapp/application/dapp_permission_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';
import '../../transfer/application/transaction_history_provider.dart';
import '../../transfer/data/transaction_history_repository.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../../wallet/application/wallet_session_controller.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet_connect/application/wallet_connect_controller.dart';
import '../data/wallet_deletion_journal.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
      SettingsController.new,
    );

final class SettingsState {
  const SettingsState({this.exportedSecret, this.lastDeletedWalletId});

  final String? exportedSecret;
  final String? lastDeletedWalletId;
}

final class SettingsController extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    await _recoverPendingWalletDeletion();
    return const SettingsState();
  }

  Future<String> exportSecret({
    required String walletId,
    required String password,
    required WalletSecretType secretType,
  }) async {
    state = const AsyncLoading();
    try {
      final secret = await ref
          .read(walletRepositoryProvider)
          .exportSecret(
            walletId: walletId,
            password: password,
            secretType: secretType,
          );
      state = AsyncData(SettingsState(exportedSecret: secret));
      return secret;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteWallet({
    required String walletId,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _recoverPendingWalletDeletion();
      final repository = ref.read(walletRepositoryProvider);
      final wallets = await repository.getWallets();
      final deletedAccount = wallets
          .where((wallet) => wallet.id == walletId)
          .firstOrNull;
      if (deletedAccount == null) {
        throw StateError('Wallet not found: $walletId');
      }
      final journal = ref.read(walletDeletionJournalProvider);
      await journal.write(PendingWalletDeletion(account: deletedAccount));
      try {
        await repository.deleteWallet(walletId: walletId, password: password);
      } catch (_) {
        final remainingWallets = await repository.getWallets();
        if (remainingWallets.any((wallet) => wallet.id == walletId)) {
          await journal.clear();
          rethrow;
        }
      }
      await _recoverPendingWalletDeletion();
      state = AsyncData(SettingsState(lastDeletedWalletId: walletId));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _recoverPendingWalletDeletion() async {
    final journal = ref.read(walletDeletionJournalProvider);
    final pending = await journal.read();
    if (pending == null) {
      return;
    }
    final repository = ref.read(walletRepositoryProvider);
    final remainingWallets = await repository.getWallets();
    final deletedAccount = pending.account;
    if (remainingWallets.any((wallet) => wallet.id == deletedAccount.id)) {
      await journal.clear();
      return;
    }

    final historyRepository = ref.read(transactionHistoryRepositoryProvider);
    if (historyRepository is WalletScopedTransactionHistoryRepository) {
      await (historyRepository as WalletScopedTransactionHistoryRepository)
          .deleteForWallet(deletedAccount.id);
    }
    await ref
        .read(dappPermissionControllerProvider.notifier)
        .clearForWallet(deletedAccount.id);
    await ref
        .read(biometricPasswordStoreProvider)
        .clearWallet(deletedAccount.id);
    final walletConnectCleanupComplete = await ref
        .read(walletConnectControllerProvider.notifier)
        .disconnectWallet(deletedAccount);
    final session = ref.read(walletSessionControllerProvider).value;
    if (session?.walletId == deletedAccount.id) {
      ref.read(walletSessionControllerProvider.notifier).lock();
    }
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    if (selectedWalletId == deletedAccount.id) {
      final replacement = remainingWallets.firstOrNull;
      if (replacement == null) {
        await ref.read(selectedWalletIdProvider.notifier).clear();
      } else {
        await ref
            .read(selectedWalletIdProvider.notifier)
            .select(replacement.id);
      }
    }
    ref.invalidate(onboardingControllerProvider);
    ref.invalidate(transactionHistoryProvider);
    ref.invalidate(recentTransactionsProvider);
    if (walletConnectCleanupComplete) {
      await journal.clear();
    }
  }

  Future<void> changePassword({
    String? walletId,
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(walletRepositoryProvider);
      final resolvedWalletId =
          walletId ?? (await repository.getWallets()).first.id;
      await repository.changePassword(
        walletId: resolvedWalletId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = const AsyncData(SettingsState());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
