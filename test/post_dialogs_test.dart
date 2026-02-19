import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carbonfeet/main.dart';

void main() {
  testWidgets('add flight dialog shows inline flight number validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddFlightDialog(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.text('Flight number is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'K1001');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(
      find.text('Use format like KL1001 (2 letters + 3-4 digits).'),
      findsOneWidget,
    );
  });
}
