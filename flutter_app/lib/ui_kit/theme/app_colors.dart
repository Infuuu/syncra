import 'package:flutter/material.dart';

// ── Shared Palette ───────────────────────────────────────────────────────────
class AppPalette {
  static const List<List<Color>> boardGradients = [
    [Color(0xFF818CF8), Color(0xFF6366F1)], // Indigo
    [Color(0xFFF472B6), Color(0xFFDB2777)], // Pink
    [Color(0xFF34D399), Color(0xFF059669)], // Emerald
    [Color(0xFFFBBF24), Color(0xFFD97706)], // Amber
    [Color(0xFF60A5FA), Color(0xFF2563EB)], // Blue
    [Color(0xFFA78BFA), Color(0xFF7C3AED)], // Violet
    [Color(0xFFF87171), Color(0xFFDC2626)], // Red
    [Color(0xFF2DD4BF), Color(0xFF0D9488)], // Teal
    [Color(0xFFFB923C), Color(0xFFEA580C)], // Orange
    [Color(0xFF38BDF8), Color(0xFF0284C7)], // Sky
    [Color(0xFFC084FC), Color(0xFF9333EA)], // Purple
    [Color(0xFF4ADE80), Color(0xFF16A34A)], // Green
  ];

  static List<Color> gradientForSeed(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum * 31 + c);
    return boardGradients[hash.abs() % boardGradients.length];
  }

  static const List<Color> columnAccents = [
    Color(0xFF818CF8), Color(0xFFFBBF24), Color(0xFF34D399), Color(0xFFF472B6),
    Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFFF87171), Color(0xFF2DD4BF),
  ];

  static Color columnAccentForIndex(int index) {
    return columnAccents[index % columnAccents.length];
  }
}

// ── Light Theme Colors ───────────────────────────────────────────────────────
class AppColors {
  // We use a white base for the new "MeetCraft" style
  static const Color background = Color(0xFFF4F7FE); // Outer background fallback
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFF8FAFC);
  static const Color surfaceHigh = Color(0xFFF1F5F9);
  static const Color surfaceHighest = Color(0xFFE2E8F0);
  static const Color surfaceTint = Color(0xFF6366F1);

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF6366F1);
  static const Color primarySoft = Color(0xFF818CF8);
  static const Color primaryFixed = Color(0xFFEEF2FF);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color secondaryFixed = Color(0xFFF3E8FF);
  static const Color tertiary = Color(0xFFEC4899);
  static const Color tertiarySoft = Color(0xFFF472B6);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEE2E2);

  static const Color glass = Color(0xCCFFFFFF);
  static const Color glassStrong = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x0F000000);
  static const Color overlay = Color(0x1A0F172A);
}

// ── Dark Theme Colors ────────────────────────────────────────────────────────
class AppColorsDark {
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceLow = Color(0xFF162032);
  static const Color surfaceHigh = Color(0xFF334155);
  static const Color surfaceHighest = Color(0xFF475569);
  static const Color surfaceTint = Color(0xFF818CF8);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFF0F172A);

  static const Color primary = Color(0xFF818CF8);
  static const Color primarySoft = Color(0xFFA5B4FC);
  static const Color primaryFixed = Color(0xFF1E1B4B);
  static const Color secondary = Color(0xFFA78BFA);
  static const Color secondaryFixed = Color(0xFF2E1065);
  static const Color tertiary = Color(0xFFF472B6);
  static const Color tertiarySoft = Color(0xFFF9A8D4);

  static const Color border = Color(0xFF334155);
  static const Color borderStrong = Color(0xFF475569);

  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color errorSoft = Color(0xFF7F1D1D);

  static const Color glass = Color(0xB31E293B);
  static const Color glassStrong = Color(0xD91E293B);
  static const Color shadow = Color(0x33000000);
  static const Color overlay = Color(0x4D000000);
}

class SyncraColors {
  final bool isDark;
  const SyncraColors._({required this.isDark});
  static const light = SyncraColors._(isDark: false);
  static const dark = SyncraColors._(isDark: true);
  static SyncraColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
  Color get background => isDark ? AppColorsDark.background : AppColors.background;
  Color get surface => isDark ? AppColorsDark.surface : AppColors.surface;
  Color get surfaceLow => isDark ? AppColorsDark.surfaceLow : AppColors.surfaceLow;
  Color get surfaceHigh => isDark ? AppColorsDark.surfaceHigh : AppColors.surfaceHigh;
  Color get surfaceHighest => isDark ? AppColorsDark.surfaceHighest : AppColors.surfaceHighest;
  Color get surfaceTint => isDark ? AppColorsDark.surfaceTint : AppColors.surfaceTint;
  Color get textPrimary => isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get textSecondary => isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get textMuted => isDark ? AppColorsDark.textMuted : AppColors.textMuted;
  Color get textInverse => isDark ? AppColorsDark.textInverse : AppColors.textInverse;
  Color get primary => isDark ? AppColorsDark.primary : AppColors.primary;
  Color get primarySoft => isDark ? AppColorsDark.primarySoft : AppColors.primarySoft;
  Color get primaryFixed => isDark ? AppColorsDark.primaryFixed : AppColors.primaryFixed;
  Color get secondary => isDark ? AppColorsDark.secondary : AppColors.secondary;
  Color get secondaryFixed => isDark ? AppColorsDark.secondaryFixed : AppColors.secondaryFixed;
  Color get tertiary => isDark ? AppColorsDark.tertiary : AppColors.tertiary;
  Color get tertiarySoft => isDark ? AppColorsDark.tertiarySoft : AppColors.tertiarySoft;
  Color get border => isDark ? AppColorsDark.border : AppColors.border;
  Color get borderStrong => isDark ? AppColorsDark.borderStrong : AppColors.borderStrong;
  Color get success => isDark ? AppColorsDark.success : AppColors.success;
  Color get warning => isDark ? AppColorsDark.warning : AppColors.warning;
  Color get error => isDark ? AppColorsDark.error : AppColors.error;
  Color get errorSoft => isDark ? AppColorsDark.errorSoft : AppColors.errorSoft;
  Color get glass => isDark ? AppColorsDark.glass : AppColors.glass;
  Color get glassStrong => isDark ? AppColorsDark.glassStrong : AppColors.glassStrong;
  Color get shadow => isDark ? AppColorsDark.shadow : AppColors.shadow;
  Color get overlay => isDark ? AppColorsDark.overlay : AppColors.overlay;
}
