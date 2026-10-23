import 'package:flutter/material.dart';
import 'app_text_styles.dart';

class AppTheme {
  // Primary Palette
  static const Color backgroundDark = Color(0xEC0F172A); // Slate 900 translucent
  static const Color backgroundPureDark = Color(0xFF090D16); // Very deep slate
  static const Color cardBackground = Color(0x991E293B); // Slate 800 glass opacity
  static const Color cardBackgroundHover = Color(0xCC334155); // Slate 700 hover glass
  static const Color borderSubtle = Color(0x3364748B); // Slate 500 border
  static const Color borderGlow = Color(0x666366F1); // Indigo border glow

  // Accent Colors
  static const Color primaryAccent = Color(0xFF6366F1); // Indigo
  static const Color primaryAccentDark = Color(0xFF4F46E5);
  static const Color secondaryAccent = Color(0xFF10B981); // Emerald
  static const Color warningAccent = Color(0xFFF59E0B); // Amber
  static const Color panicAccent = Color(0xFFEF4444); // Red
  static const Color cyanAccent = Color(0xFF06B6D4); // Cyan

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8); // 6:1 on cards (was 3.2:1)

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        // Selected chips / segmented buttons use these; keep them indigo, not green.
        secondaryContainer: Color(0x336366F1),
        onSecondaryContainer: textPrimary,
        surface: cardBackground,
        error: panicAccent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: primaryAccent.withValues(alpha: 0.22),
        checkmarkColor: textPrimary,
        side: const BorderSide(color: borderSubtle),
        labelStyle: const TextStyle(fontSize: 11, color: textSecondary),
        secondaryLabelStyle: const TextStyle(fontSize: 11, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          side: const WidgetStatePropertyAll(BorderSide(color: borderSubtle)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primaryAccent.withValues(alpha: 0.22) : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? textPrimary : textSecondary,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: backgroundPureDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderSubtle),
        ),
        textStyle: const TextStyle(fontSize: 11, color: textPrimary),
      ),
      textTheme: const TextTheme(
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelSmall: AppTextStyles.caption,
      ),
    );
  }
}
