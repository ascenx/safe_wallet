import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors/security_error.dart';
import '../../../shared/security/biometric_password_store.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';

final biometricPasswordSettingProvider =
    AsyncNotifierProvider<
      BiometricPasswordSettingController,
      BiometricPasswordSettingState
    >(BiometricPasswordSettingController.new);

final class BiometricPasswordSettingState {
  const BiometricPasswordSettingState({
    required this.canUseBiometrics,
    required this.hasSavedPassword,
  });

  final bool canUseBiometrics;
  final bool hasSavedPassword;
}

final class BiometricPasswordSettingController
    extends AsyncNotifier<BiometricPasswordSettingState> {
  @override
  Future<BiometricPasswordSettingState> build() {
    return _readState();
  }

  Future<void> enable({required String password}) async {
    if (password.isEmpty) {
      throw const SecurityError.checkFailed();
    }
    final store = ref.read(biometricPasswordStoreProvider);
    if (!await store.canUseBiometrics()) {
      throw const SecurityError.checkFailed();
    }

    final repository = ref.read(walletRepositoryProvider);
    final wallets = await repository.getWallets();
    final selectedWalletId = ref.read(selectedWalletIdProvider);
    final selectedId =
        selectedWalletId != null &&
            wallets.any((wallet) => wallet.id == selectedWalletId)
        ? selectedWalletId
        : wallets.firstOrNull?.id;
    if (selectedId == null) {
      throw const SecurityError.checkFailed();
    }

    final orderedWallets = [
      wallets.firstWhere((wallet) => wallet.id == selectedId),
      ...wallets.where((wallet) => wallet.id != selectedId),
    ];
    final walletDeks = <String, List<int>>{};
    for (final wallet in orderedWallets) {
      final unlockResult = await repository.unlock(
        walletId: wallet.id,
        password: password,
      );
      walletDeks[wallet.id] = unlockResult.walletDek;
    }
    await store.saveWalletKeys(walletDeks);
    state = AsyncData(await _readState());
  }

  Future<void> disable() async {
    await ref.read(biometricPasswordStoreProvider).clearPassword();
    state = AsyncData(await _readState());
  }

  Future<BiometricPasswordSettingState> _readState() async {
    final store = ref.read(biometricPasswordStoreProvider);
    return BiometricPasswordSettingState(
      canUseBiometrics: await store.canUseBiometrics(),
      hasSavedPassword: await store.hasSavedPassword(),
    );
  }
}
