import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors/security_error.dart';
import '../../wallet/application/selected_wallet_controller.dart';
import '../../wallet/application/wallet_repository_provider.dart';
import '../data/security_log_repository.dart';
import '../domain/security_log_entry.dart';

final securityLogControllerProvider = Provider<SecurityLogController>((ref) {
  return SecurityLogController(ref);
});

final class SecurityLogController {
  const SecurityLogController(this._ref);

  final Ref _ref;

  Future<List<SecurityLogEntry>> loadEntries({required String password}) async {
    await _verifyPassword(password);
    return _ref.read(securityLogRepositoryProvider).listEntries();
  }

  Future<void> _verifyPassword(String password) async {
    if (password.isEmpty) {
      throw const SecurityError.checkFailed();
    }
    final repository = _ref.read(walletRepositoryProvider);
    final wallets = await repository.getWallets();
    final selectedWalletId = _ref.read(selectedWalletIdProvider);
    final walletId = selectedWalletId != null &&
            wallets.any((wallet) => wallet.id == selectedWalletId)
        ? selectedWalletId
        : wallets.firstOrNull?.id;
    if (walletId == null) {
      throw const SecurityError.checkFailed();
    }
    await repository.unlock(walletId: walletId, password: password);
  }
}
