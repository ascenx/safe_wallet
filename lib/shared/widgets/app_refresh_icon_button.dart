import 'dart:async';

import 'package:flutter/material.dart';

import 'package:safe_wallet/shared/design/app_icons.dart';

final class AppRefreshIconButton extends StatefulWidget {
  const AppRefreshIconButton({
    required this.isRefreshing,
    required this.onPressed,
    required this.tooltip,
    this.buttonKey,
    this.spinnerKey,
    this.duration = const Duration(milliseconds: 900),
    super.key,
  });

  final bool isRefreshing;
  final VoidCallback? onPressed;
  final String tooltip;
  final Key? buttonKey;
  final Key? spinnerKey;
  final Duration duration;

  @override
  State<AppRefreshIconButton> createState() => _AppRefreshIconButtonState();
}

final class _AppRefreshIconButtonState extends State<AppRefreshIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  var _isAnimating = false;
  var _minimumRotationCompleted = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.isRefreshing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_startRotation());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppRefreshIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _rotationController.duration = widget.duration;
    }
    if (widget.isRefreshing && !_isAnimating) {
      unawaited(_startRotation());
      return;
    }
    if (!widget.isRefreshing &&
        oldWidget.isRefreshing &&
        _minimumRotationCompleted) {
      _stopRotation();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const iconSize = 20.0;
    return IconButton(
      key: widget.buttonKey,
      tooltip: widget.tooltip,
      onPressed: widget.onPressed == null || widget.isRefreshing || _isAnimating
          ? null
          : _handlePressed,
      icon: _isAnimating
          ? RotationTransition(
              key: widget.spinnerKey,
              turns: _rotationController,
              child: const Icon(
                AppIcons.refresh,
                size: iconSize,
              ),
            )
          : const Icon(
              AppIcons.refresh,
              size: iconSize,
            ),
    );
  }

  void _handlePressed() {
    unawaited(_startRotation());
    widget.onPressed?.call();
  }

  Future<void> _startRotation() async {
    if (_isAnimating) {
      return;
    }
    setState(() {
      _isAnimating = true;
      _minimumRotationCompleted = false;
    });
    await _rotationController.forward(from: 0);
    if (!mounted) {
      return;
    }
    _minimumRotationCompleted = true;
    if (widget.isRefreshing) {
      _rotationController.repeat();
      return;
    }
    _stopRotation();
  }

  void _stopRotation() {
    _rotationController.stop();
    if (!_isAnimating) {
      return;
    }
    setState(() {
      _isAnimating = false;
    });
  }
}
