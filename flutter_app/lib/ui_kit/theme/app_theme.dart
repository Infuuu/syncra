import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'typography.dart';

/// App Theme Generator
/// Enforces the sleek, Notion-style dark-mode interface globally.
class AppTheme {
  /// We enforce Dark Mode only as requested.
  static ThemeData get darkTheme {
    // We use Inter font which gives the closest matching sleek tech/Notion vibe
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundBlack,
      canvasColor: AppColors.backgroundBlack,
      dialogBackgroundColor: AppColors.surfaceElevated,

      // Customize standard typography overriding with Google Fonts 'Inter'
      textTheme: baseTextTheme.copyWith(
        displayLarge: AppTypography.h1.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        displayMedium: AppTypography.h2.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        displaySmall: AppTypography.h3.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          fontFamily: GoogleFonts.inter().fontFamily,
        ),
      ),

      // Card / Container theme
      cardTheme: const CardThemeData(
        color: AppColors.surfaceOpaque,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderSm,
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),

      // Dialog shape
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        backgroundColor: AppColors.surfaceElevated,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        space: 1,
        thickness: 1,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceOpaque,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: BorderSide(
            color: AppColors.textSecondary,
            width: 1,
          ), // Brighter when focused
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderSm,
          borderSide: BorderSide(color: AppColors.errorRed, width: 1),
        ),
      ),

      // TextSelection (cursor color)
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.textPrimary,
        selectionColor: AppColors.textSecondary,
        selectionHandleColor: AppColors.textPrimary,
      ),

      /// Color Scheme required for M3 features (like switches or chips)
      colorScheme: const ColorScheme.dark(
        primary: AppColors.buttonPrimaryBg,
        onPrimary: AppColors.buttonPrimaryText,
        secondary: AppColors.surfaceOpaque,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.backgroundBlack,
        onSurface: AppColors.textPrimary,
        error: AppColors.errorRed,
        onError: AppColors.textPrimary,
      ),
    );
  }
}
