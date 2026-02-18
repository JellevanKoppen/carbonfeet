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
    await tester.pumpAndSettle();

    expect(find.text('Recent flights'), findsOneWidget);
    expect(find.textContaining('KL1001'), findsOneWidget);
    expect(find.textContaining('DL0405'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('KL1001'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('KL1001'));
    await tester.pumpAndSettle();

    expect(find.text('Flight details'), findsOneWidget);
    expect(find.text('Flight: KL1001'), findsOneWidget);
    expect(find.text('Route: AMS → LHR'), findsOneWidget);
    expect(find.text('Segments: 1'), findsOneWidget);
  });
}
