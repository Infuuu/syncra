import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../components/layout/ambient_background.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';

class AppLayout extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const AppLayout({super.key, required this.child, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final c = SyncraColors.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: isDesktop
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        _Sidebar(currentRoute: currentRoute),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                )
              : child,
        ),
      ),
      // Bottom Navigation Bar for mobile
      bottomNavigationBar: isDesktop
          ? null
          : _MobileBottomNav(currentRoute: currentRoute),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final String currentRoute;

  const _MobileBottomNav({required this.currentRoute});

  int get _currentIndex {
    if (currentRoute == '/') return 0;
    if (currentRoute.startsWith('/notes')) return 1;
    if (currentRoute.startsWith('/boards')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border.withValues(alpha: 0.3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MobileNavItem(
                icon: Icons.dashboard_rounded,
                label: 'Home',
                isSelected: _currentIndex == 0,
                onTap: () => context.go('/'),
              ),
              _MobileNavItem(
                icon: Icons.note_alt_rounded,
                label: 'Notes',
                isSelected: _currentIndex == 1,
                onTap: () => context.go('/notes'),
              ),
              _MobileNavItem(
                icon: Icons.view_kanban_rounded,
                label: 'Boards',
                isSelected: _currentIndex == 2,
                onTap: () => context.go('/boards'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? c.primary : c.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? c.primary : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final String currentRoute;

  const _Sidebar({required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SyncraColors.of(context);

    return Container(
      width: 250,
      color: c.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF818CF8), Color(0xFFF472B6)],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Syncra',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isSelected: currentRoute == '/',
            onTap: () => context.go('/'),
          ),
          _NavItem(
            icon: Icons.note_alt_rounded,
            label: 'Notes',
            isSelected: currentRoute.startsWith('/notes'),
            onTap: () => context.go('/notes'),
          ),
          _NavItem(
            icon: Icons.view_kanban_rounded,
            label: 'Boards',
            isSelected: currentRoute == '/boards' || (currentRoute.startsWith('/boards/') && currentRoute != '/'),
            onTap: () => context.go('/boards'),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.primaryFixed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primarySoft.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.workspace_premium_rounded, color: c.primary),
                  ),
                  const SizedBox(height: 12),
                  Text('Upgrade to Pro', style: AppTypography.h3.copyWith(fontSize: 14, color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Unlock all features now', style: AppTypography.bodySmall.copyWith(fontSize: 11, color: c.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: c.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Settings',
            isSelected: false,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SyncraColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? c.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? c.primary : c.textMuted,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? c.primary : c.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
