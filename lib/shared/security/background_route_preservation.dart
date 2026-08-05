import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backgroundRoutePreservationRegistryProvider =
    Provider<BackgroundRoutePreservationRegistry>((ref) {
  return BackgroundRoutePreservationRegistry();
});

final class BackgroundRoutePreservationRegistry {
  final _routes = <ModalRoute<dynamic>>{};

  bool get hasCurrentRoute => _routes.any((route) => route.isCurrent);

  void register(ModalRoute<dynamic> route) {
    _routes.add(route);
  }

  void unregister(ModalRoute<dynamic> route) {
    _routes.remove(route);
  }
}

final class BackgroundRoutePreservationScope extends ConsumerStatefulWidget {
  const BackgroundRoutePreservationScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<BackgroundRoutePreservationScope> createState() =>
      _BackgroundRoutePreservationScopeState();
}

final class _BackgroundRoutePreservationScopeState
    extends ConsumerState<BackgroundRoutePreservationScope> {
  BackgroundRoutePreservationRegistry? _registry;
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) {
      return;
    }
    _unregisterRoute();
    final registry = ref.read(backgroundRoutePreservationRegistryProvider);
    _registry = registry;
    _route = route;
    if (route != null) {
      registry.register(route);
    }
  }

  @override
  void dispose() {
    _unregisterRoute();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _unregisterRoute() {
    final route = _route;
    if (route == null) {
      return;
    }
    _registry?.unregister(route);
    _registry = null;
    _route = null;
  }
}
