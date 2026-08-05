import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/assets/application/asset_portfolio_provider.dart';
import '../features/settings/application/background_privacy_shield_setting.dart';
import '../features/settings/application/wallet_auto_lock_setting.dart';
import '../features/staking/application/tron_staking_dashboard_controller.dart';
import '../features/wallet/application/wallet_session_controller.dart';
import '../shared/security/background_route_preservation.dart';
import '../shared/security/inactive_privacy_shield_suppression.dart';
import '../shared/security/sensitive_clipboard.dart';

typedef AppLifecycleClock = DateTime Function();

final appLifecycleClockProvider = Provider<AppLifecycleClock>((ref) {
  return () => DateTime.now().toUtc();
});

final appNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

final class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

final class _AppLifecycleObserverState
    extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  late final GlobalKey<NavigatorState> _navigatorKey;
  OverlayEntry? _privacyShieldEntry;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    _navigatorKey = ref.read(appNavigatorKeyProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removePrivacyShield();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final resumedAt = ref.read(appLifecycleClockProvider)();
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            resumedAt.difference(backgroundedAt) >=
                _autoLockDuration.duration) {
          _lockAndDismissUnpreservedRoutes();
        } else if (backgroundedAt == null) {
          ref
              .read(walletSessionControllerProvider.notifier)
              .expireIfNeeded(now: resumedAt);
        }
        _removePrivacyShield();
        ref.invalidate(assetPortfolioProvider);
        ref.invalidate(tronStakingDashboardControllerProvider);
      case AppLifecycleState.inactive:
        // System UI such as paste permission and biometric prompts can make
        // the app temporarily inactive without sending it to the background.
        if (!_isPrivacyShieldEnabled ||
            ref.read(inactivePrivacyShieldSuppressionProvider).isActive) {
          return;
        }
        _showPrivacyShield();
        return;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(SensitiveClipboardService.instance.clearNow());
        if (_isPrivacyShieldEnabled) {
          _showPrivacyShield();
        } else {
          _removePrivacyShield();
        }
        _backgroundedAt ??= ref.read(appLifecycleClockProvider)();
        if (_autoLockDuration == WalletAutoLockDuration.immediately) {
          _lockAndDismissUnpreservedRoutes();
        }
    }
  }

  bool get _isPrivacyShieldEnabled {
    return ref.read(backgroundPrivacyShieldSettingProvider).value ?? true;
  }

  WalletAutoLockDuration get _autoLockDuration {
    return ref.read(walletAutoLockSettingProvider).value ??
        WalletAutoLockDuration.fiveMinutes;
  }

  void _lockAndDismissUnpreservedRoutes() {
    ref.read(walletSessionControllerProvider.notifier).lock();
    if (ref.read(backgroundRoutePreservationRegistryProvider).hasCurrentRoute) {
      return;
    }
    _popToRoot();
    WidgetsBinding.instance.addPostFrameCallback((_) => _popToRoot());
  }

  void _popToRoot() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    while (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _showPrivacyShield() {
    if (_privacyShieldEntry != null) {
      return;
    }
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPrivacyShield();
        }
      });
      return;
    }
    final entry = OverlayEntry(
      builder: (_) => const Positioned.fill(
        child: ClipRect(
          key: Key('appPrivacyShield'),
          child: _PrivacyGlassShield(),
        ),
      ),
    );
    _privacyShieldEntry = entry;
    overlay.insert(entry);
  }

  void _removePrivacyShield() {
    final entry = _privacyShieldEntry;
    if (entry == null) {
      return;
    }
    _privacyShieldEntry = null;
    entry.remove();
    entry.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backgroundPrivacyShieldSettingProvider);
    ref.watch(walletAutoLockSettingProvider);
    return widget.child;
  }
}

final class _PrivacyGlassShield extends StatelessWidget {
  const _PrivacyGlassShield();

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: ColoredBox(color: backgroundColor.withValues(alpha: 0.1)),
    );
  }
}
