import 'package:flutter_riverpod/flutter_riverpod.dart';

final inactivePrivacyShieldSuppressionProvider =
    Provider<InactivePrivacyShieldSuppression>(
      (ref) => InactivePrivacyShieldSuppression.instance,
    );

final class InactivePrivacyShieldSuppression {
  InactivePrivacyShieldSuppression();

  static final instance = InactivePrivacyShieldSuppression();

  int _activeOperations = 0;

  bool get isActive => _activeOperations > 0;

  Future<T> whileInactiveShieldSuppressed<T>(
    Future<T> Function() operation,
  ) async {
    _activeOperations += 1;
    try {
      return await operation();
    } finally {
      _activeOperations -= 1;
    }
  }
}
