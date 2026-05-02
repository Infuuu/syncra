import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncra_frontend/app.dart';
import 'package:syncra_frontend/ui_kit/theme/app_colors.dart';

void main() {
  testWidgets('App initializes router and renders light theme login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: SyncraApp()));

    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.background);
  });
}
