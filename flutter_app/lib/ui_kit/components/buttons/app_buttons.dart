import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';

/// Primary action button (White background, Black text)
class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final Widget? icon;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimaryBg,
          foregroundColor: AppColors.buttonPrimaryText,
          disabledBackgroundColor: AppColors.surfaceOpaque,
          disabledForegroundColor: AppColors.textTertiary,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderSm,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonPrimaryText),
        ),
      );
    }
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: const IconThemeData(size: 16),
            child: icon!,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.labelLarge.copyWith(color: AppColors.buttonPrimaryText)),
        ],
      );
    }
    
    return Text(label, style: AppTypography.labelLarge.copyWith(color: AppColors.buttonPrimaryText));
  }
}

/// Secondary button (Dark gray background, White text)
class SecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final Widget? icon;

  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: AppColors.buttonSecondaryBg,
          foregroundColor: AppColors.buttonSecondaryText,
          disabledBackgroundColor: AppColors.surfaceOpaque,
          disabledForegroundColor: AppColors.textTertiary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderSm,
            side: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.buttonSecondaryText),
        ),
      );
    }
    
    final contentStyle = AppTypography.labelLarge.copyWith(color: AppColors.buttonSecondaryText);
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: const IconThemeData(size: 16),
            child: icon!,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: contentStyle),
        ],
      );
    }
    
    return Text(label, style: contentStyle);
  }
}

/// Ghost / Text button (Transparent background, white text)
class GhostButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? icon;

  const GhostButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderSm,
          ),
        ),
        onPressed: onPressed,
        child: _buildContent(),
      ),
    );
  }
  
  Widget _buildContent() {
    final style = AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500);
    
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: const IconThemeData(size: 16, color: AppColors.textSecondary),
            child: icon!,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: style),
        ],
      );
    }
    
    return Text(label, style: style);
  }
}
