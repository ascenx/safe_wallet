import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chain_repository.dart';
import '../domain/chain_config.dart';

final chainRepositoryProvider = Provider<ChainRepository>((ref) {
  throw UnimplementedError('chainRepositoryProvider must be overridden');
});

final availableChainsProvider = FutureProvider<List<ChainConfig>>((ref) {
  return ref.watch(chainRepositoryProvider).getChains();
});
