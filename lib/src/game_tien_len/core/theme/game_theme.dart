import 'package:flutter/material.dart';

abstract final class GameTheme {
  static const Color ink = Color(0xFF071B1B);
  static const Color jade = Color(0xFF0C5C4F);
  static const Color mint = Color(0xFF75D8B4);
  static const Color gold = Color(0xFFE8B84D);
  static const Color ivory = Color(0xFFFFF2CF);

  static final ThemeData theme = _buildTheme();

  static ThemeData _buildTheme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: jade,
      brightness: Brightness.dark,
    );
    return ThemeData(
      fontFamily: 'Baloo2',
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: mint,
        secondary: gold,
        surface: ink,
      ),
      scaffoldBackgroundColor: ink,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF173B35),
        contentTextStyle: TextStyle(
          fontFamily: 'Baloo2',
          color: ivory,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Baloo2', color: ivory),
        titleMedium: TextStyle(
          fontFamily: 'Baloo2',
          color: ivory,
          fontWeight: FontWeight.w700,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Baloo2',
          color: ivory,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
