import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette
  static const Color backgroundDark = Color(0xDC0F172A); // Translucent Slate 900
  static const Color cardBackground = Color(0x801E293B); // Glass Slate 800
  static const Color borderSubtle = Color(0x3364748B); // Slate 500 border
  
  static const Color primaryAccent = Color(0xFF6366F1); // Indigo
  static const Color secondaryAccent = Color(0xFF10B981); // Emerald
  static const Color warningAccent = Color(0xFFF59E0B); // Amber
  static const Color panicAccent = Color(0xFFEF4444); // Red

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        surface: cardBackground,
        error: panicAccent,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: textSecondary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: textMuted,
        ),
      ),
    );
  }
}
