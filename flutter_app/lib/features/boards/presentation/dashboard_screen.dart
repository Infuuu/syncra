import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncra_frontend/ui_kit/components/buttons/app_buttons.dart';
import 'package:syncra_frontend/ui_kit/theme/typography.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<String> _boards = [];

  void _createBoard() {
    setState(() {
      _boards.add('New Board ${_boards.length + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: AppTypography.h3),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                GhostButton(
                  onPressed: () {
                    context.go('/notes');
                  },
                  label: 'Go to Notes',
                  icon: const Icon(Icons.note, size: 16),
                ),
                const SizedBox(width: 8),
                GhostButton(
                  onPressed: () {
                    context.go('/login');
                  },
                  label: 'Logout',
                  icon: const Icon(Icons.logout, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
      body:
          _boards.isEmpty
              ? Center(
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
                      onPressed: _createBoard,
                      label: 'Create Board',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryButton(
                      onPressed: _createBoard,
                      label: 'Create Board',
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: _boards.length,
                        itemBuilder: (context, index) {
                          return Card(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              alignment: Alignment.center,
                              child: Text(
                                _boards[index],
                                style: AppTypography.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
