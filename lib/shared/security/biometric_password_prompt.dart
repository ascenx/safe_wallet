import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/generated/translations.g.dart';
import '../../features/wallet/application/selected_wallet_controller.dart';
import '../../features/wallet/application/wallet_repository_provider.dart';
import '../widgets/app_dialog.dart';
import 'biometric_password_store.dart';

Future<String?> readBiometricPassword({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final store = ref.read(biometricPasswordStoreProvider);
  return store.readPassword(reason: t.wallet.biometricReason);
}

Future<void> offerBiometricPasswordSetup({
  required BuildContext context,
  required WidgetRef ref,
  required String password,
}) async {
  if (password.isEmpty) {
    return;
  }

  final store = ref.read(biometricPasswordStoreProvider);
  if (!await store.canUseBiometrics()) {
    return;
  }

  if (!await store.hasSavedPassword()) {
    if (!context.mounted) {
      return;
    }
    final accepted = await AppDialog.show<bool>(
      context: context,
      title: t.wallet.biometricSetupTitle,
      content: Text(t.wallet.biometricSetupBody),
      cancelCallback: () => Navigator.of(context).pop(false),
      confirmKey: const Key('enableBiometricPasswordButton'),
      confirmTitle: t.wallet.biometricSetupConfirm,
      confirmCallback: () => Navigator.of(context).pop(true),
    );

    if (accepted != true) {
      return;
    }
  }
  final provisioned = await _provisionBiometricWalletKey(
    ref: ref,
    store: store,
    password: password,
  );
  if (!provisioned) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(t.wallet.biometricEnabled)));
}

Future<bool> _provisionBiometricWalletKey({
  required WidgetRef ref,
  required BiometricPasswordStore store,
  required String password,
}) async {
  try {
    final repository = ref.read(walletRepositoryProvider);
    final wallets = await repository.getWallets();
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    final selectedWallet = selectedWalletId == null
        ? wallets.firstOrNull
        : wallets.where((item) => item.id == selectedWalletId).firstOrNull ??
              wallets.firstOrNull;
    if (selectedWallet == null) {
      return false;
    }
    final orderedWallets = [
      selectedWallet,
      ...wallets.where((wallet) => wallet.id != selectedWallet.id),
    ];
    final walletDeks = <String, List<int>>{};
    for (final wallet in orderedWallets) {
      final unlocked = await repository.unlock(
        walletId: wallet.id,
        password: password,
      );
      walletDeks[wallet.id] = unlocked.walletDek;
    }
    await store.saveWalletKeys(walletDeks);
    return true;
  } catch (_) {
    return false;
  }
}
