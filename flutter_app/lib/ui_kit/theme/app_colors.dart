import 'package:flutter/material.dart';

/// Predefined color palette used throughout the app.
/// Strict Black/White matching the Notion-style clean aesthetic.
class AppColors {
  // Backgrounds
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceOpaque = Color(0xFF191919); // Slightly elevated surfaces
  static const Color surfaceElevated = Color(0xFF262626); // Modals/Dialogs

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // High contrast text
  static const Color textSecondary = Color(0xFFA0A0A0); // Dimmer, less emphasis
  static const Color textTertiary = Color(0xFF737373); // Disabled/Placeholder

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFF333333); // 1px borders for clean layout separations

  // Interactable
  static const Color buttonPrimaryBg = Color(0xFFFFFFFF);
  static const Color buttonPrimaryText = Color(0xFF000000);
  
  static const Color buttonSecondaryBg = Color(0xFF262626);
  static const Color buttonSecondaryText = Color(0xFFFFFFFF); // White

  // Status/Error
  static const Color errorRed = Color(0xFFEB5757); // Notion's red hex
  static const Color errorBg = Color(0xFF3A1E1E); // Subtle red background

  // Overlay
  static const Color overlay = Color(0x99000000); // 60% opacity black
}
