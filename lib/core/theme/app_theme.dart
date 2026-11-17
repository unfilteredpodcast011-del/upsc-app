import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_controller.dart';

class AppTheme {
  // Theme Accent Palettes
  static Color getPrimaryColor(AppThemePreset preset) {
    switch (preset) {
      case AppThemePreset.royalBlue:
        return const Color(0xFF1E3A8A); // Classic Blue
      case AppThemePreset.forestGreen:
        return const Color(0xFF0F766E); // Forest Green / Teal
      case AppThemePreset.skyBlue:
        return const Color(0xFF0284C7); // Vibrant Sky Blue
      case AppThemePreset.pink:
        return const Color(0xFFDB2777); // Vibrant Pink
      case AppThemePreset.violet:
        return const Color(0xFF7C3AED); // Royal Violet
      case AppThemePreset.crimsonRed:
        return const Color(0xFFDC2626); // Crimson Red
    }
  }

  static ThemeData getLightTheme(AppThemePreset preset) {
    final primary = getPrimaryColor(preset);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: const Color(0xFFD97706),
        surface: const Color(0xFFF8FAFC),
        onSurface: const Color(0xFF0F172A),
        error: const Color(0xFFDC2626),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF0F172A),
        displayColor: const Color(0xFF0F172A),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: GoogleFonts.notoSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static ThemeData getDarkTheme(AppThemePreset preset) {
    final primary = getPrimaryColor(preset);
    final accentPrimary = Color.lerp(primary, Colors.white, 0.35) ?? primary;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: accentPrimary,
        secondary: const Color(0xFFFBBF24),
        surface: const Color(0xFF1E293B),
        onSurface: Colors.white,
        surfaceContainerHighest: const Color(0xFF334155),
        error: const Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      // Crystal clear typography in Dark Mode so all text is 100% visible
      textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: const TextStyle(color: Color(0xFFF1F5F9)),
        bodyMedium: const TextStyle(color: Color(0xFFE2E8F0)),
        bodySmall: const TextStyle(color: Color(0xFFCBD5E1)),
        titleLarge: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(color: Color(0xFFE2E8F0)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: GoogleFonts.notoSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFFF1F5F9),
        iconColor: Color(0xFFCBD5E1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        labelStyle: const TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        prefixIconColor: const Color(0xFF94A3B8),
        suffixIconColor: const Color(0xFF94A3B8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Backwards compatibility
  static ThemeData lightTheme = getLightTheme(AppThemePreset.royalBlue);
  static ThemeData darkTheme = getDarkTheme(AppThemePreset.royalBlue);
}
