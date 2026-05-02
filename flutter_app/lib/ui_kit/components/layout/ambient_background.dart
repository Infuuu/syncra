import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.background),
          ),
        ),
        Positioned(
          top: -180,
          left: -140,
          child: _Glow(
            size: 520,
            color: AppColors.primarySoft.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: -220,
          right: -140,
          child: _Glow(
            size: 480,
            color: AppColors.secondaryFixed.withValues(alpha: 0.36),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
