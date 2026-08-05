import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/token_repository.dart';
import '../data/token_universe_repository.dart';
import '../domain/token_info.dart';

final tokenRepositoryProvider = Provider<TokenRepository>((ref) {
  throw UnimplementedError('tokenRepositoryProvider must be overridden');
});

final tokenUniverseRepositoryProvider =
    Provider<TokenUniverseRepository>((ref) {
  return const JsonTokenUniverseRepository();
});

final tokensForChainProvider =
    FutureProvider.family<List<TokenInfo>, String>((ref, chainId) {
  return ref.watch(tokenRepositoryProvider).getTokens(chainId: chainId);
});

final allTokensForChainProvider =
    FutureProvider.family<List<TokenInfo>, String>((ref, chainId) {
  return ref.watch(tokenRepositoryProvider).getTokens(
        chainId: chainId,
        includeHidden: true,
      );
});
