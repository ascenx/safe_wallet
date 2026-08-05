import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/security/biometric_password_store.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_account.dart';
import '../domain/wallet_session.dart';
import 'wallet_repository_provider.dart';

final walletSessionControllerProvider =
    AsyncNotifierProvider<WalletSessionController, WalletSession?>(
      WalletSessionController.new,
    );

final class WalletSessionController extends AsyncNotifier<WalletSession?> {
  static const unlockDuration = Duration(minutes: 15);

  @override
  Future<WalletSession?> build() async {
    return null;
  }

  Future<WalletSession> unlock({
    required String walletId,
    required String password,
    DateTime? now,
  }) async {
    final unlockedAt = now ?? DateTime.now().toUtc();
    final unlocked = await _unlockWallets(
      walletId: walletId,
      password: password,
    );
    return _establishSession(
      result: unlocked.selected,
      walletDeks: unlocked.walletDeks,
      unlockedAt: unlockedAt,
    );
  }

  Future<WalletSession> unlockWithBiometricPassword({
    required String walletId,
    required String password,
    DateTime? now,
  }) async {
    final unlockedAt = now ?? DateTime.now().toUtc();
    final unlocked = await _unlockWallets(
      walletId: walletId,
      password: password,
    );
    final session = _establishSession(
      result: unlocked.selected,
      walletDeks: unlocked.walletDeks,
      unlockedAt: unlockedAt,
    );
    unawaited(
      ref
          .read(biometricPasswordStoreProvider)
          .saveWalletKeys(unlocked.walletDeks)
          .catchError((_) {}),
    );
    return session;
  }

  Future<WalletSession> unlockWithWalletKey({
    required WalletAccount account,
    required List<int> walletDek,
    DateTime? now,
  }) {
    return unlockWithWalletKeys(
      account: account,
      walletDeks: {account.id: walletDek},
      now: now,
    );
  }

  Future<WalletSession> unlockWithWalletKeys({
    required WalletAccount account,
    required Map<String, List<int>> walletDeks,
    DateTime? now,
  }) async {
    final unlockedAt = now ?? DateTime.now().toUtc();
    return _establishSession(
      result: WalletUnlockResult(
        account: account,
        walletDek: walletDeks[account.id]!,
      ),
      walletDeks: walletDeks,
      unlockedAt: unlockedAt,
    );
  }

  Future<({
    WalletUnlockResult selected,
    Map<String, List<int>> walletDeks,
  })> _unlockWallets({
    required String walletId,
    required String password,
  }) async {
    final repository = ref.read(walletRepositoryProvider);
    final wallets = await repository.getWallets();
    final orderedWalletIds = [
      walletId,
      ...wallets.map((wallet) => wallet.id).where((id) => id != walletId),
    ];
    final walletDeks = <String, List<int>>{};
    WalletUnlockResult? selected;
    for (final currentWalletId in orderedWalletIds) {
      final result = await repository.unlock(
        walletId: currentWalletId,
        password: password,
      );
      walletDeks[currentWalletId] = result.walletDek;
      if (currentWalletId == walletId) {
        selected = result;
      }
    }
    return (selected: selected!, walletDeks: walletDeks);
  }

  WalletSession _establishSession({
    required WalletUnlockResult result,
    required Map<String, List<int>> walletDeks,
    required DateTime unlockedAt,
  }) {
    final cache = ref.read(sessionKeyCacheProvider);
    for (final entry in walletDeks.entries) {
      cache.unlock(
        walletId: entry.key,
        walletDek: entry.value,
        now: unlockedAt,
      );
    }

    final session = WalletSession(
      walletId: result.account.id,
      isUnlocked: true,
      unlockedUntil: cache.expiresAt(result.account.id, now: unlockedAt),
    );
    state = AsyncData(session);
    return session;
  }

  void lock() {
    final previousSession = state.value;
    ref.read(sessionKeyCacheProvider).clear();
    state = AsyncData(
      previousSession == null
          ? null
          : WalletSession(
              walletId: previousSession.walletId,
              isUnlocked: false,
              unlockedUntil: null,
            ),
    );
  }

  void expireIfNeeded({DateTime? now}) {
    final session = state.value;
    if (session == null) {
      return;
    }
    final checkedAt = now ?? DateTime.now().toUtc();
    final cache = ref.read(sessionKeyCacheProvider);
    if (!cache.hasKey(session.walletId, now: checkedAt)) {
      lock();
      return;
    }
    final expiresAt = cache.expiresAt(session.walletId, now: checkedAt);
    if (expiresAt == null) {
      if (session.unlockedUntil != null) {
        state = AsyncData(
          WalletSession(
            walletId: session.walletId,
            isUnlocked: true,
            unlockedUntil: null,
          ),
        );
      }
      return;
    }
    if (!expiresAt.isAfter(checkedAt)) {
      lock();
      return;
    }
    if (session.unlockedUntil != expiresAt) {
      state = AsyncData(
        WalletSession(
          walletId: session.walletId,
          isUnlocked: true,
          unlockedUntil: expiresAt,
        ),
      );
    }
  }
}
