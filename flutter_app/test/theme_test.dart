import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncra_frontend/app.dart';
import 'package:syncra_frontend/ui_kit/theme/app_colors.dart';

void main() {
  testWidgets('App initializes router and renders Dark Theme login', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SyncraApp(),
      ),
    );

    // Let the router digest the initial route ('/login')
    await tester.pumpAndSettle();

    // Verify it lands on the Login screen layout
    expect(find.text('Welcome back'), findsOneWidget);

    // Verify background is pure black (from AppTheme)
    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.backgroundBlack);
  });
}
