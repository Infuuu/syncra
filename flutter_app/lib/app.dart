import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui_kit/theme/app_theme.dart';

class SyncraApp extends ConsumerWidget {
  const SyncraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Syncra',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Force Dark Mode globally
      darkTheme: AppTheme.darkTheme,
      home: const Scaffold(
        body: Center(
          child: Text('Syncra App Initialization Complete'),
        ),
      ),
    );
  }
}
