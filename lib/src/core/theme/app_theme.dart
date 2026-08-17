import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/metro_ui.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    const seed = kMetroPrimary;
    const accent = kMetroCoral;
    const canvas = kMetroCanvas;
    const canvasDeep = kMetroCanvasDeep;
    const surface = kMetroSurface;
    const ink = kMetroInk;
    const muted = kMetroMuted;
    const line = kMetroLine;

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: accent,
      surface: surface,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final bodyTextTheme = GoogleFonts.outfitTextTheme(base.textTheme);
    final textTheme = bodyTextTheme.copyWith(
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.02,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.08,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.1,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 15,
        height: 1.42,
        color: ink,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        height: 1.38,
        color: muted,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        height: 1.28,
        color: muted,
        fontWeight: FontWeight.w700,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: 0.1,
      ),
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1.1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvasDeep,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: ink),
        helperStyle: textTheme.bodySmall,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF8A8F97),
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: inputBorder(line),
        enabledBorder: inputBorder(line),
        focusedBorder: inputBorder(seed, width: 1.4),
        errorBorder: inputBorder(const Color(0xFFB33A3A), width: 1.2),
        focusedErrorBorder: inputBorder(const Color(0xFFB33A3A), width: 1.3),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorColor: kMetroCoralSoft,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w800,
            color: selected ? ink : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? seed : muted,
            size: selected ? 24 : 22,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFC7CFDF),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          backgroundColor: surface,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
              return seed.withValues(alpha: 0.14);
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        side: const BorderSide(color: line),
        backgroundColor: surface,
        selectedColor: kMetroCoralSoft,
        labelStyle: textTheme.bodySmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: seed,
        linearTrackColor: Color(0xFFE2E5E8),
      ),
    );
  }
}
