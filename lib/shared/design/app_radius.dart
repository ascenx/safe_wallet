import 'package:flutter/material.dart';

final class AppRadius {
  const AppRadius._();

  static const double small = 8;
  static const double medium = 12;
  static const double large = 18;
  static const double xLarge = 22;
  static const double pill = 999;
  static const double circle = 999;

  static const smallBorder = BorderRadius.all(Radius.circular(small));
  static const mediumBorder = BorderRadius.all(Radius.circular(medium));
  static const largeBorder = BorderRadius.all(Radius.circular(large));
  static const xLargeBorder = BorderRadius.all(Radius.circular(xLarge));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
}
