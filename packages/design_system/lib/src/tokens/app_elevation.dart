import 'package:flutter/material.dart';

/// Elevation tokens for MVision.
class AppElevation {
  const AppElevation._();

  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 2;
  static const double level3 = 4;
  static const double level4 = 8;
  static const double level5 = 16;

  // Semantic elevation
  static const double card = level1;
  static const double dialog = level3;
  static const double bottomSheet = level4;
  static const double fab = level2;
}

/// Shadow tokens for MVision.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get level1 => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get level2 => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get level3 => [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
