import 'dart:async';

import 'package:flutter/services.dart';

import 'inactive_privacy_shield_suppression.dart';

abstract interface class SensitiveClipboardPlatform {
  Future<void> copy(String value, {required Duration expiresAfter});

  Future<void> clearIfMatches(String value);
}

final class MethodChannelSensitiveClipboardPlatform
    implements SensitiveClipboardPlatform {
  MethodChannelSensitiveClipboardPlatform({
    MethodChannel channel = const MethodChannel(
      'safe_wallet/sensitive_clipboard',
    ),
    InactivePrivacyShieldSuppression? inactivePrivacyShieldSuppression,
  }) : _channel = channel,
       _inactivePrivacyShieldSuppression =
           inactivePrivacyShieldSuppression ??
           InactivePrivacyShieldSuppression.instance;

  final MethodChannel _channel;
  final InactivePrivacyShieldSuppression _inactivePrivacyShieldSuppression;

  @override
  Future<void> copy(String value, {required Duration expiresAfter}) async {
    try {
      await _channel.invokeMethod<void>('copySensitiveText', {
        'text': value,
        'expiresAfterSeconds': expiresAfter.inSeconds,
      });
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: value));
    } on PlatformException {
      await Clipboard.setData(ClipboardData(text: value));
    }
  }

  @override
  Future<void> clearIfMatches(String value) async {
    try {
      await _channel.invokeMethod<void>('clearSensitiveClipboardIfMatches', {
        'text': value,
      });
    } on MissingPluginException {
      await _clearFallbackIfMatches(value);
    } on PlatformException {
      await _clearFallbackIfMatches(value);
    }
  }

  Future<void> _clearFallbackIfMatches(String value) async {
    try {
      final clipboardData = await _inactivePrivacyShieldSuppression
          .whileInactiveShieldSuppressed(
            () => Clipboard.getData(Clipboard.kTextPlain),
          );
      if (clipboardData?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } on MissingPluginException {
      // The platform does not expose a readable clipboard fallback.
    } on PlatformException {
      // Do not let clipboard cleanup failures interrupt lifecycle handling.
    }
  }
}

final class SensitiveClipboardService {
  SensitiveClipboardService({
    SensitiveClipboardPlatform? platform,
    this.clearAfter = const Duration(seconds: 30),
  }) : _platform = platform ?? MethodChannelSensitiveClipboardPlatform();

  static final SensitiveClipboardService instance = SensitiveClipboardService();

  final SensitiveClipboardPlatform _platform;
  final Duration clearAfter;
  Timer? _clearTimer;
  String? _ownedValue;

  Future<void> copy(String value) async {
    _clearTimer?.cancel();
    _ownedValue = value;
    await _platform.copy(value, expiresAfter: clearAfter);
    _clearTimer = Timer(clearAfter, () {
      unawaited(clearNow());
    });
  }

  Future<void> clearNow() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    final value = _ownedValue;
    _ownedValue = null;
    if (value != null) {
      await _platform.clearIfMatches(value);
    }
  }

  void dispose() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _ownedValue = null;
  }
}
