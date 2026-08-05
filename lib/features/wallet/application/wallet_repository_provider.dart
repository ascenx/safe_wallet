import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/security/session_key_cache.dart';
import '../data/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  throw UnimplementedError('walletRepositoryProvider must be overridden');
});

final sessionKeyCacheProvider = Provider<SessionKeyCache>((ref) {
  return SessionKeyCache();
});
