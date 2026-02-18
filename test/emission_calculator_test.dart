import 'package:flutter_test/flutter_test.dart';

import 'package:carbonfeet/main.dart';

void main() {
  group('EmissionCalculator', () {
    test('summarize computes baseline, ytd, and projection with flights', () {
      final flight = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'KL1001',
          date: DateTime.utc(2026, 5, 1),
          occupancy: OccupancyLevel.halfFull,
        ),
      )!;

      final user = UserData(
        email: 'tester@example.com',
        country: 'United States',
        lifeStage: LifeStage.youngProfessional,
        dietProfile: const DietProfile(
          meatDaysPerWeek: 2,
          dairyLevel: DairyLevel.medium,
        ),
        carProfile: const CarProfile(
          vehicleKey: 'toyota_corolla',
          distanceMode: DistanceMode.perYear,
          distanceValue: 10000,
        ),
        energyProfile: const EnergyProfile(
          electricityKwh: 1000,
          gasM3: 100,
          isEstimated: false,
        ),
        flights: [flight],
        activityLog: const [],
        onboardingComplete: true,
        initialProjectionKg: 0,
      );

      final summary = EmissionCalculator.summarize(
        user,
        now: DateTime.utc(2026, 6, 30),
      );

      expect(summary.baselineYearlyKg, closeTo(3390, 0.001));
      expect(summary.flightsYearlyKg, closeTo(41.2735, 0.001));
      expect(summary.projectedEndYearKg, closeTo(3431.2735, 0.001));
      expect(summary.yearToDateKg, closeTo(1722.3420, 0.01));
    });

    test('unknown flight numbers are rejected in MVP', () {
      final result = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'UNKNOWN123',
          date: DateTime(2026, 2, 1),
          occupancy: OccupancyLevel.halfFull,
        ),
      );

      expect(result, isNull);
    });

    test('occupancy multipliers produce lower emissions when fuller', () {
      final empty = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'KL0641',
          date: DateTime(2026, 1, 15),
          occupancy: OccupancyLevel.nearlyEmpty,
        ),
      )!;
      final half = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'KL0641',
          date: DateTime(2026, 1, 15),
          occupancy: OccupancyLevel.halfFull,
        ),
      )!;
      final full = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'KL0641',
          date: DateTime(2026, 1, 15),
          occupancy: OccupancyLevel.nearlyFull,
        ),
      )!;

      expect(empty.emissionsKg, greaterThan(half.emissionsKg));
      expect(half.emissionsKg, greaterThan(full.emissionsKg));
    });

    test('simulator scenarios reduce projection for mitigation actions', () {
      final flight = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'BA0295',
          date: DateTime(2026, 3, 4),
          occupancy: OccupancyLevel.halfFull,
        ),
      )!;

      final user = UserData.empty(
        email: 'sim@example.com',
      ).copyWith(onboardingComplete: true, flights: [flight]);

      final currentProjection = EmissionCalculator.summarize(
        user,
        now: DateTime(2026, 8, 1),
      ).projectedEndYearKg;

      final scenarios = EmissionCalculator.simulateScenarios(user);
      final byTitle = {
        for (final scenario in scenarios) scenario.title: scenario.projectedKg,
      };

      expect(byTitle.containsKey('Remove one flight'), isTrue);
      expect(byTitle['Remove one flight']!, lessThan(currentProjection));
      expect(byTitle['Drive 10% less']!, lessThan(currentProjection));
      expect(byTitle['One less meat day/week']!, lessThan(currentProjection));
    });
  });

  group('PersistedAppState', () {
    test('round-trips persisted user state safely', () {
      final entry = EmissionCalculator.buildFlightEntry(
        FlightDraft(
          flightNumber: 'DL0405',
          date: DateTime(2026, 7, 9),
          occupancy: OccupancyLevel.nearlyFull,
        ),
      )!;

      final user = UserData.empty(email: 'persist@example.com').copyWith(
        onboardingComplete: true,
        flights: [entry],
        activityLog: [
          ActivityEvent(timestamp: DateTime(2026, 7, 9, 12, 0), type: 'flight'),
        ],
      );

      final state = PersistedAppState(
        credentials: const {'persist@example.com': 'secure123'},
        users: {'persist@example.com': user},
        activeEmail: 'persist@example.com',
      );

      final hydrated = PersistedAppState.fromJson(state.toJson());

      expect(hydrated.activeEmail, equals('persist@example.com'));
      expect(hydrated.credentials['persist@example.com'], equals('secure123'));
      expect(hydrated.users.containsKey('persist@example.com'), isTrue);
      expect(
        hydrated.users['persist@example.com']!.flights.single.flightNumber,
        equals('DL0405'),
      );
      expect(
        hydrated.users['persist@example.com']!.activityLog.single.type,
        equals('flight'),
      );
    });
  });
}
