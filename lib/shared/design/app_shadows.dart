import 'package:flutter/material.dart';

final class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0F132047),
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
  ];

  static const floating = [
    BoxShadow(
      color: Color(0x1A132047),
      blurRadius: 36,
      offset: Offset(0, 12),
    ),
  ];

  static List<BoxShadow> iconGlow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.16),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
