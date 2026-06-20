import 'package:flutter/material.dart';

class OrbiTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0B0F1A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C5CE7),
        secondary: Color(0xFF00CEC9),
      ),
      cardTheme: const CardThemeData(
        // ← FIXED
        color: Color(0xFF141A2E),
        elevation: 4,
      ),
    );
  }
}
