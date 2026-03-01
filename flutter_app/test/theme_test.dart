import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncra_frontend/app.dart';
import 'package:syncra_frontend/ui_kit/theme/app_colors.dart';

void main() {
  testWidgets('App initializes correctly with dark theme', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SyncraApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app text renders
    expect(find.text('Syncra App Initialization Complete'), findsOneWidget);

    // Verify background is pure black (from AppTheme)
    final BuildContext context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.backgroundBlack);
  });
}
