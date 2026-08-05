import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _securityChannel = MethodChannel('safe_wallet/security');

int _activeProtectionScopes = 0;

Future<void> setSensitiveScreenProtectionEnabled(bool enabled) async {
  try {
    await _securityChannel.invokeMethod<void>(
      'setSensitiveScreenProtection',
      {'enabled': enabled},
    );
  } on MissingPluginException {
    // Some platforms do not expose screenshot protection.
  } on PlatformException {
    // Platform screenshot protection is best-effort and must not break UI flow.
  }
}

Future<void> excludeWalletStorageFromBackup() async {
  try {
    await _securityChannel.invokeMethod<void>('excludeWalletStorageFromBackup');
  } on MissingPluginException {
    // Platforms without automatic backup exclusion do not need this hook.
  } on PlatformException {
    // Backup exclusion is defense in depth and must not block app startup.
  }
}

final class SensitiveScreenProtectionScope extends StatefulWidget {
  const SensitiveScreenProtectionScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<SensitiveScreenProtectionScope> createState() =>
      _SensitiveScreenProtectionScopeState();
}

final class _SensitiveScreenProtectionScopeState
    extends State<SensitiveScreenProtectionScope> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _activate();
  }

  @override
  void dispose() {
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _activate() {
    if (_active) {
      return;
    }
    _active = true;
    _activeProtectionScopes += 1;
    if (_activeProtectionScopes == 1) {
      unawaited(setSensitiveScreenProtectionEnabled(true));
    }
  }

  void _deactivate() {
    if (!_active) {
      return;
    }
    _active = false;
    if (_activeProtectionScopes > 0) {
      _activeProtectionScopes -= 1;
    }
    if (_activeProtectionScopes == 0) {
      unawaited(setSensitiveScreenProtectionEnabled(false));
    }
  }
}
