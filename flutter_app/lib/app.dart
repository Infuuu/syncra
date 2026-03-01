import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'core/routing/app_router.dart';
import 'ui_kit/theme/app_theme.dart';

class SyncraApp extends ConsumerWidget {
  const SyncraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Syncra',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Force Dark Mode globally
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      routerConfig: router,
    );
  }
}
