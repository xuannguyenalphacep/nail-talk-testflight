import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const seed = Color(0xFF1B74E4);
    const accent = Color(0xFF0F8E7C);
    const tertiary = Color(0xFF4F46E5);
    const canvas = Color(0xFFF3F6FB);
    const surface = Color(0xFFFFFFFF);
    const ink = Color(0xFF16263C);
    const muted = Color(0xFF6F8096);
    const line = Color(0xFFE4EBF5);

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: accent,
      tertiary: tertiary,
      surface: surface,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final bodyTextTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final textTheme = bodyTextTheme.copyWith(
      headlineMedium: GoogleFonts.sora(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.06,
      ),
      titleLarge: GoogleFonts.sora(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.14,
      ),
      titleMedium: GoogleFonts.sora(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 1.52,
        color: ink,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 1.55,
        color: muted,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        height: 1.45,
        color: muted,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.05,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF7FAFF),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FBFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        labelStyle: textTheme.bodyMedium,
        helperStyle: textTheme.bodySmall,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF90A1B7),
        ),
        prefixIconColor: const Color(0xFF5E728C),
        suffixIconColor: const Color(0xFF5E728C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD8E2EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD8E2EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: seed, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFD3485A), width: 1.2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        indicatorColor: seed.withValues(alpha: 0.12),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? ink : const Color(0xFF7C8DA2),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? seed : const Color(0xFF7C8DA2),
            size: selected ? 26 : 24,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB7CCEF),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          backgroundColor: surface,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: line)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return seed.withValues(alpha: 0.10);
            }
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return ink;
            }
            return muted;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFF1F5FB),
        selectedColor: seed.withValues(alpha: 0.12),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
