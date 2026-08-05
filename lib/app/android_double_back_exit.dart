import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/generated/translations.g.dart';
import '../shared/widgets/app_toast.dart';

final class AndroidDoubleBackExit extends StatefulWidget {
  const AndroidDoubleBackExit({required this.child, super.key});

  static const confirmationDuration = Duration(seconds: 2);

  final Widget child;

  @override
  State<AndroidDoubleBackExit> createState() => _AndroidDoubleBackExitState();
}

final class _AndroidDoubleBackExitState extends State<AndroidDoubleBackExit> {
  Timer? _confirmationTimer;
  bool _isExitConfirmed = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAndroid) {
      return widget.child;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleRootBack();
      },
      child: widget.child,
    );
  }

  void _handleRootBack() {
    if (_isExitConfirmed) {
      _confirmationTimer?.cancel();
      _isExitConfirmed = false;
      unawaited(SystemNavigator.pop());
      return;
    }

    _isExitConfirmed = true;
    AppToast.show(
      context,
      message: t.actions.exitAppHint,
      duration: AndroidDoubleBackExit.confirmationDuration,
    );
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(AndroidDoubleBackExit.confirmationDuration, () {
      _isExitConfirmed = false;
    });
  }
}
