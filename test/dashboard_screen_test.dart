import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carbonfeet/main.dart';

void main() {
  testWidgets('dashboard shows recent flights and opens flight details', (
    WidgetTester tester,
  ) async {
    final firstFlight = EmissionCalculator.buildFlightEntry(
      FlightDraft(
        flightNumber: 'KL1001',
        date: DateTime(2026, 5, 1),
        occupancy: OccupancyLevel.halfFull,
      ),
    )!;
    final secondFlight = EmissionCalculator.buildFlightEntry(
      FlightDraft(
        flightNumber: 'DL0405',
        date: DateTime(2026, 4, 20),
        occupancy: OccupancyLevel.nearlyFull,
      ),
    )!;

    final user = UserData.empty(
      email: 'dashboard@example.com',
    ).copyWith(onboardingComplete: true, flights: [secondFlight, firstFlight]);
    final summary = EmissionCalculator.summarize(
      user,
      now: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          user: user,
          summary: summary,
          onOpenPostMenu: () {},
          onOpenSimulator: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Recent flights'), findsOneWidget);
    expect(find.textContaining('KL1001'), findsOneWidget);
    expect(find.textContaining('DL0405'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('KL1001'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(find.textContaining('KL1001'));
    await tester.pump();

    expect(find.text('Flight details'), findsOneWidget);
    expect(find.text('Flight: KL1001'), findsOneWidget);
    expect(find.text('Route: AMS → LHR'), findsOneWidget);
    expect(find.text('Segments: 1'), findsOneWidget);
  });

  testWidgets('dashboard shows loading guards while summary refreshes', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'loading@example.com',
    ).copyWith(onboardingComplete: true);
    final summary = EmissionCalculator.summarize(
      user,
      now: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          user: user,
          summary: summary,
          onOpenPostMenu: () {},
          onOpenSimulator: () {},
          onLogout: () {},
          isSummaryLoading: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Calculating your latest footprint totals...'),
      findsOneWidget,
    );
    expect(find.text('Loading your recent flights...'), findsOneWidget);
    expect(
      find.text(
        'Simulator is temporarily unavailable while dashboard data refreshes.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('dashboard shows guarded error states for malformed summary', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'malformed@example.com',
    ).copyWith(onboardingComplete: true);
    const malformed = EmissionSummary(
      yearToDateKg: double.nan,
      projectedEndYearKg: -10,
      baselineYearlyKg: -1,
      flightsYearlyKg: double.nan,
      countryAverageKg: 0,
      personalTargetKg: 0,
      comparisonLabel: '',
      isBelowCountryAverage: false,
      categoryTotals: {
        EmissionCategory.flights: -5,
      },
      monthlyTrendKg: [100],
      badges: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          user: user,
          summary: malformed,
          onOpenPostMenu: () {},
          onOpenSimulator: () {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Summary metrics are unavailable right now.'), findsOneWidget);
    expect(find.text('Comparison data is unavailable right now.'), findsOneWidget);
    expect(find.text('Category data is unavailable right now.'), findsOneWidget);
    expect(find.text('Trend data is unavailable right now.'), findsOneWidget);
  });
}
