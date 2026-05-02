import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? c.background : null,
        gradient: c.isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD1EE), Color(0xFF9E84F5)], // Vibrant MeetCraft gradient
              ),
      ),
      child: child,
    );
  }
}
