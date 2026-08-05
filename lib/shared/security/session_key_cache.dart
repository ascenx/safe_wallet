import 'sensitive_bytes.dart';

final class SessionKeyCache {
  SessionKeyCache({this.timeout = const Duration(minutes: 15)});

  final Duration timeout;

  final Map<String, SensitiveBytes> _walletDeks = {};
  DateTime? _lastSensitiveOperationAt;

  void unlock({
    required String walletId,
    required List<int> walletDek,
    required DateTime now,
  }) {
    _walletDeks.remove(walletId)?.destroy();
    _walletDeks[walletId] = SensitiveBytes(walletDek);
    _lastSensitiveOperationAt = now;
  }

  List<int>? readKey(String walletId, {required DateTime now}) {
    if (_isExpired(now)) {
      clear();
      return null;
    }
    return _walletDeks[walletId]?.copyBytes();
  }

  bool hasKey(String walletId, {required DateTime now}) {
    if (_isExpired(now)) {
      clear();
      return false;
    }
    return _walletDeks.containsKey(walletId);
  }

  DateTime? expiresAt(String walletId, {required DateTime now}) {
    if (_isExpired(now)) {
      clear();
      return null;
    }
    if (!_walletDeks.containsKey(walletId)) {
      return null;
    }
    return _lastSensitiveOperationAt?.add(timeout);
  }

  void touch({required DateTime now}) {
    if (_walletDeks.isEmpty) {
      return;
    }
    _lastSensitiveOperationAt = now;
  }

  void clear() {
    for (final walletDek in _walletDeks.values) {
      walletDek.destroy();
    }
    _walletDeks.clear();
    _lastSensitiveOperationAt = null;
  }

  bool _isExpired(DateTime now) {
    final lastOperation = _lastSensitiveOperationAt;
    if (lastOperation == null || _walletDeks.isEmpty) {
      return true;
    }
    return now.difference(lastOperation) >= timeout;
  }
}
