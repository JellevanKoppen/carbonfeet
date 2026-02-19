import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carbonfeet/main.dart';

const String _storageKey = 'carbonfeet_state_v1';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('unknown flight post is rejected with user feedback', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-unknown@example.com',
    ).copyWith(onboardingComplete: true);
    await _pumpAppWithUser(tester, user);

    await _openFlightDialog(tester);
    await tester.enterText(find.byType(TextField).first, 'AA9999');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(
      find.text('Flight not found. MVP only accepts known flight numbers.'),
      findsOneWidget,
    );
    expect(find.text('No flights logged yet. Add a flight to see details.'), findsOneWidget);
  });

  testWidgets('duplicate flight post is blocked for same date', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-duplicate@example.com',
    ).copyWith(onboardingComplete: true);
    await _pumpAppWithUser(tester, user);

    await _openFlightDialog(tester);
    await tester.enterText(find.byType(TextField).first, 'KL1001');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('KL1001 added'), findsOneWidget);
    expect(find.textContaining('KL1001  AMS → LHR'), findsOneWidget);

    await _openFlightDialog(tester);
    await tester.enterText(find.byType(TextField).first, 'KL1001');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('KL1001  AMS → LHR'), findsOneWidget);
  });

  testWidgets('simulator renders scenarios and delta labels', (
    WidgetTester tester,
  ) async {
    final flight = EmissionCalculator.buildFlightEntry(
      FlightDraft(
        flightNumber: 'BA0295',
        date: DateTime(2026, 1, 20),
        occupancy: OccupancyLevel.halfFull,
      ),
    )!;
    final user = UserData.empty(
      email: 'simulator@example.com',
    ).copyWith(onboardingComplete: true, flights: [flight]);
    final summary = EmissionCalculator.summarize(
      user,
      now: DateTime(2026, 8, 1),
    );
    final scenarios = EmissionCalculator.simulateScenarios(user);

    await _pumpAppWithUser(tester, user);
    await tester.tap(find.byTooltip('What if simulator'));
    await tester.pumpAndSettle();

    expect(find.text('What if simulator'), findsWidgets);
    expect(find.textContaining('Current projection:'), findsOneWidget);
    expect(find.text('Remove one flight'), findsOneWidget);
    expect(find.text('Drive 10% less'), findsOneWidget);
    expect(find.text('One less meat day/week'), findsOneWidget);

    for (final scenario in scenarios) {
      final delta = scenario.projectedKg - summary.projectedEndYearKg;
      final label = _formatDelta(delta);
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('car post updates projection and car category totals', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-car@example.com',
    ).copyWith(onboardingComplete: true);
    const updatedCar = CarProfile(
      vehicleKey: 'toyota_corolla',
      distanceMode: DistanceMode.perYear,
      distanceValue: 8000,
    );
    final expectedSummary = EmissionCalculator.summarize(
      user.copyWith(carProfile: updatedCar),
    );

    await _pumpAppWithUser(tester, user);

    await _openPostDialog(tester, 'Car usage');
    await tester.enterText(find.byType(TextField).first, '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      _metricValueForLabel(tester, 'End-of-year projection'),
      equals(_asKgCo2e(expectedSummary.projectedEndYearKg)),
    );
    expect(
      _categoryValueForLabel(tester, 'Car'),
      equals(
        _asKg(expectedSummary.categoryTotals[EmissionCategory.car] ?? 0),
      ),
    );
  });

  testWidgets('diet post updates projection and diet category totals', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-diet@example.com',
    ).copyWith(onboardingComplete: true);
    const updatedDiet = DietProfile(
      meatDaysPerWeek: 4,
      dairyLevel: DairyLevel.high,
    );
    final expectedSummary = EmissionCalculator.summarize(
      user.copyWith(dietProfile: updatedDiet),
    );

    await _pumpAppWithUser(tester, user);

    await _openPostDialog(tester, 'Diet profile');
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      _metricValueForLabel(tester, 'End-of-year projection'),
      equals(_asKgCo2e(expectedSummary.projectedEndYearKg)),
    );
    expect(
      _categoryValueForLabel(tester, 'Diet'),
      equals(
        _asKg(expectedSummary.categoryTotals[EmissionCategory.diet] ?? 0),
      ),
    );
  });

  testWidgets('home energy post updates projection and energy category totals', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-energy@example.com',
    ).copyWith(onboardingComplete: true);
    const updatedEnergy = EnergyProfile(
      electricityKwh: 3200,
      gasM3: 400,
      isEstimated: true,
    );
    final expectedSummary = EmissionCalculator.summarize(
      user.copyWith(energyProfile: updatedEnergy),
    );

    await _pumpAppWithUser(tester, user);

    await _openPostDialog(tester, 'Home energy');
    await tester.enterText(find.byType(TextField).at(0), '3200');
    await tester.enterText(find.byType(TextField).at(1), '400');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      _metricValueForLabel(tester, 'End-of-year projection'),
      equals(_asKgCo2e(expectedSummary.projectedEndYearKg)),
    );
    expect(
      _categoryValueForLabel(tester, 'Energy'),
      equals(
        _asKg(expectedSummary.categoryTotals[EmissionCategory.energy] ?? 0),
      ),
    );
  });
}

Future<void> _pumpAppWithUser(WidgetTester tester, UserData user) async {
  const password = 'secure123';
  final state = PersistedAppState(
    credentials: {user.email: password},
    users: {user.email: user},
    activeEmail: user.email,
  );
  SharedPreferences.setMockInitialValues({
    _storageKey: jsonEncode(state.toJson()),
  });

  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

Future<void> _openFlightDialog(WidgetTester tester) async {
  await _openPostDialog(tester, 'Flight');
}

Future<void> _openPostDialog(WidgetTester tester, String typeLabel) async {
  await tester.tap(find.text('Add CO2 post'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(typeLabel).last);
  await tester.pumpAndSettle();
}

String _formatDelta(double delta) {
  final rounded = delta.abs().toStringAsFixed(0);
  if (delta < 0) {
    return '-$rounded kg';
  }
  if (delta > 0) {
    return '+$rounded kg';
  }
  return '0 kg';
}

String _metricValueForLabel(WidgetTester tester, String label) {
  final columnAncestors = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .evaluate()
      .toList();

  for (final ancestor in columnAncestors) {
    final textFinder = find.descendant(
      of: find.byElementPredicate((element) => element == ancestor),
      matching: find.byType(Text),
    );
    final textValues = textFinder
        .evaluate()
        .map((element) => element.widget as Text)
        .map((textWidget) => textWidget.data)
        .whereType<String>()
        .toList();

    if (textValues.length == 2 &&
        textValues.first == label &&
        textValues.last.endsWith('kg CO2e')) {
      return textValues.last;
    }
  }

  fail('Could not find metric value for label "$label".');
}

String _categoryValueForLabel(WidgetTester tester, String label) {
  final rowFinder = find.ancestor(
    of: find.text(label),
    matching: find.byType(Row),
  );
  expect(rowFinder, findsWidgets);

  final valueFinder = find.descendant(
    of: rowFinder.first,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && widget.data!.endsWith(' kg'),
    ),
  );
  expect(valueFinder, findsOneWidget);
  return tester.widget<Text>(valueFinder).data!;
}

String _asKgCo2e(double value) => '${value.toStringAsFixed(0)} kg CO2e';

String _asKg(double value) => '${value.toStringAsFixed(0)} kg';
