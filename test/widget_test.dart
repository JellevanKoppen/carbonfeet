import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carbonfeet/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('new user can register and reach onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('CarbonFeet'), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'newuser@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secure123');

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Build your baseline projection'), findsOneWidget);
  });
}
