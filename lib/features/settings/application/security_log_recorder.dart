import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/security_log_repository.dart';
import '../domain/security_log_entry.dart';

final securityLogRecorderProvider = Provider<SecurityLogRecorder>((ref) {
  return SecurityLogRecorder(ref.read(securityLogRepositoryProvider));
});

final class SecurityLogRecorder {
  const SecurityLogRecorder(this._repository);

  final SecurityLogRepository _repository;

  Future<void> record(
    SecurityLogEventType type, {
    String? walletName,
    String? chainName,
    String? assetSymbol,
    String? amount,
    String? address,
  }) async {
    try {
      await _repository.record(
        type,
        walletName: walletName,
        chainName: chainName,
        assetSymbol: assetSymbol,
        amount: amount,
        address: address,
      );
    } catch (_) {
      // Security logging is best-effort and must not block the signed action.
    }
  }
}
