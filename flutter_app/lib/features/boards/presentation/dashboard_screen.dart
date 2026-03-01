import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncra_frontend/ui_kit/components/buttons/app_buttons.dart';
import 'package:syncra_frontend/ui_kit/theme/typography.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: AppTypography.h3),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GhostButton(
              onPressed: () {
                context.go('/login');
              },
              label: 'Logout',
              icon: const Icon(Icons.logout, size: 16),
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome safely to Syncra',
              style: AppTypography.h2,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your boards will appear here.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              onPressed: () {},
              label: 'Create Board',
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
