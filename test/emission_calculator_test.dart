import 'package:flutter_test/flutter_test.dart';

import 'package:carbonfeet/main.dart';

class _InMemoryAppStateStore extends AppStateStore {
  _InMemoryAppStateStore() : state = const PersistedAppState.empty();

  PersistedAppState state;

  @override
  Future<PersistedAppState> load() async => state;

  @override
  Future<void> save(PersistedAppState next) async {
    state = next;
  }
}

class _FlakyRemoteStateClient implements RemoteStateClient {
  _FlakyRemoteStateClient({
    PersistedAppState? initialState,
    this.remainingLoadFailures = 0,
    this.remainingSaveFailures = 0,
  }) : _state = initialState ?? const PersistedAppState.empty();

  PersistedAppState _state;
  int remainingLoadFailures;
  int remainingSaveFailures;
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  Future<PersistedAppState> load() async {
    loadCalls += 1;
    if (remainingLoadFailures > 0) {
      remainingLoadFailures -= 1;
      throw const RemoteStateUnavailable();
    }
    return PersistedAppState.fromJson(_state.toJson());
  }

  @override
  Future<void> save(PersistedAppState state) async {
    saveCalls += 1;
    if (remainingSaveFailures > 0) {
      remainingSaveFailures -= 1;
      throw const RemoteStateUnavailable();
    }
    _state = PersistedAppState.fromJson(state.toJson());
  }
}

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

    test(
      'summarize uses leap-year day progress and excludes flights from other years',
      () {
        final leapYearFlight = EmissionCalculator.buildFlightEntry(
          FlightDraft(
            flightNumber: 'KL1001',
            date: DateTime.utc(2024, 2, 20),
            occupancy: OccupancyLevel.halfFull,
          ),
        )!;
        final otherYearFlight = EmissionCalculator.buildFlightEntry(
          FlightDraft(
            flightNumber: 'DL0405',
            date: DateTime.utc(2025, 2, 20),
            occupancy: OccupancyLevel.halfFull,
          ),
        )!;

        final user = UserData.empty(email: 'leap@example.com').copyWith(
          onboardingComplete: true,
          flights: [leapYearFlight, otherYearFlight],
        );

        final summary = EmissionCalculator.summarize(
          user,
          now: DateTime.utc(2024, 2, 29),
        );

        final expectedBaselineYtd = summary.baselineYearlyKg * (60 / 366);
        final expectedYtd = expectedBaselineYtd + leapYearFlight.emissionsKg;

        expect(
          summary.flightsYearlyKg,
          closeTo(leapYearFlight.emissionsKg, 0.001),
        );
        expect(
          summary.projectedEndYearKg,
          closeTo(summary.baselineYearlyKg + leapYearFlight.emissionsKg, 0.001),
        );
        expect(summary.yearToDateKg, closeTo(expectedYtd, 0.001));
      },
    );

    test(
      'projection includes future flights in year while ytd excludes them',
      () {
        final previousYearFlight = EmissionCalculator.buildFlightEntry(
          FlightDraft(
            flightNumber: 'KL0641',
            date: DateTime.utc(2025, 12, 31),
            occupancy: OccupancyLevel.halfFull,
          ),
        )!;
        final futureInYearFlight = EmissionCalculator.buildFlightEntry(
          FlightDraft(
            flightNumber: 'KL0641',
            date: DateTime.utc(2026, 1, 2),
            occupancy: OccupancyLevel.halfFull,
          ),
        )!;

        final user = UserData.empty(email: 'boundary@example.com').copyWith(
          onboardingComplete: true,
          flights: [previousYearFlight, futureInYearFlight],
        );

        final summary = EmissionCalculator.summarize(
          user,
          now: DateTime.utc(2026, 1, 1),
        );

        final expectedYtd = summary.baselineYearlyKg * (1 / 365);
        expect(
          summary.flightsYearlyKg,
          closeTo(futureInYearFlight.emissionsKg, 0.001),
        );
        expect(summary.yearToDateKg, closeTo(expectedYtd, 0.001));
        expect(
          summary.projectedEndYearKg,
          closeTo(
            summary.baselineYearlyKg + futureInYearFlight.emissionsKg,
            0.001,
          ),
        );
      },
    );
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

    test('migrates legacy payloads without schemaVersion', () {
      final legacyUser = UserData.empty(
        email: 'legacy@example.com',
      ).copyWith(onboardingComplete: true);
      final legacyPayload = <String, dynamic>{
        'credentials': {'legacy@example.com': 'secure123'},
        'users': {'legacy@example.com': legacyUser.toJson()},
        'activeEmail': 'legacy@example.com',
      };

      final hydrated = PersistedAppState.fromJson(legacyPayload);

      expect(
        hydrated.schemaVersion,
        equals(PersistedAppState.currentSchemaVersion),
      );
      expect(hydrated.credentials['legacy@example.com'], equals('secure123'));
      expect(hydrated.activeEmail, equals('legacy@example.com'));
      expect(hydrated.users['legacy@example.com']!.onboardingComplete, isTrue);
    });
  });

  group('LocalAppRepository', () {
    test('addFlight returns unknown for flights outside catalog', () async {
      final repository = LocalAppRepository(
        stateStore: _InMemoryAppStateStore(),
      );
      await repository.hydrate();
      final auth = await repository.register('repo@example.com', 'secure123');
      expect(auth.status, equals(AuthActionStatus.authenticated));

      final result = await repository.addFlight(
        FlightDraft(
          flightNumber: 'AA9999',
          date: DateTime(2026, 6, 1),
          occupancy: OccupancyLevel.halfFull,
        ),
      );

      expect(result.status, equals(AddFlightStatus.unknownFlight));
      expect(repository.activeUser!.flights, isEmpty);
    });

    test('addFlight prevents duplicate same-day entries', () async {
      final repository = LocalAppRepository(
        stateStore: _InMemoryAppStateStore(),
      );
      await repository.hydrate();
      final auth = await repository.register('repo@example.com', 'secure123');
      expect(auth.status, equals(AuthActionStatus.authenticated));

      final first = await repository.addFlight(
        FlightDraft(
          flightNumber: 'KL1001',
          date: DateTime(2026, 6, 1),
          occupancy: OccupancyLevel.halfFull,
        ),
      );
      final second = await repository.addFlight(
        FlightDraft(
          flightNumber: 'KL1001',
          date: DateTime(2026, 6, 1),
          occupancy: OccupancyLevel.nearlyEmpty,
        ),
      );

      expect(first.status, equals(AddFlightStatus.added));
      expect(first.entry, isNotNull);
      expect(second.status, equals(AddFlightStatus.duplicateForDate));

      final user = repository.activeUser!;
      expect(user.flights.length, equals(1));
      expect(
        user.activityLog.where((event) => event.type == 'flight').length,
        1,
      );
    });

    test(
      'profile updates mutate active user and append activity events',
      () async {
        final repository = LocalAppRepository(
          stateStore: _InMemoryAppStateStore(),
        );
        await repository.hydrate();
        final auth = await repository.register('repo@example.com', 'secure123');
        expect(auth.status, equals(AuthActionStatus.authenticated));

        final carUpdated = await repository.updateCarProfile(
          const CarProfile(
            vehicleKey: 'tesla_model_3',
            distanceMode: DistanceMode.perYear,
            distanceValue: 9000,
          ),
        );
        final dietUpdated = await repository.updateDietProfile(
          const DietProfile(meatDaysPerWeek: 1, dairyLevel: DairyLevel.low),
        );
        final energyUpdated = await repository.updateEnergyProfile(
          const EnergyProfile(
            electricityKwh: 2800,
            gasM3: 300,
            isEstimated: false,
          ),
        );

        expect(carUpdated.status, equals(MutationStatus.updated));
        expect(dietUpdated.status, equals(MutationStatus.updated));
        expect(energyUpdated.status, equals(MutationStatus.updated));

        final user = repository.activeUser!;
        expect(user.carProfile.vehicleKey, equals('tesla_model_3'));
        expect(user.dietProfile.meatDaysPerWeek, equals(1));
        expect(user.energyProfile.gasM3, equals(300));
        expect(
          user.activityLog.map((event) => event.type),
          containsAll(['car_update', 'diet_update', 'energy_update']),
        );
      },
    );

    test('profile updates immediately change projected emissions', () async {
      final repository = LocalAppRepository(
        stateStore: _InMemoryAppStateStore(),
      );
      await repository.hydrate();
      final auth = await repository.register('repo@example.com', 'secure123');
      expect(auth.status, equals(AuthActionStatus.authenticated));

      final initialProjection = EmissionCalculator.summarize(
        repository.activeUser!,
        now: DateTime.utc(2026, 6, 1),
      ).projectedEndYearKg;

      expect(
        await repository.updateCarProfile(
          const CarProfile(
            vehicleKey: 'tesla_model_3',
            distanceMode: DistanceMode.perYear,
            distanceValue: 7000,
          ),
        ),
        isA<MutationResult>().having(
          (result) => result.status,
          'status',
          MutationStatus.updated,
        ),
      );
      final afterCarProjection = EmissionCalculator.summarize(
        repository.activeUser!,
        now: DateTime.utc(2026, 6, 1),
      ).projectedEndYearKg;

      expect(
        await repository.updateDietProfile(
          const DietProfile(meatDaysPerWeek: 1, dairyLevel: DairyLevel.low),
        ),
        isA<MutationResult>().having(
          (result) => result.status,
          'status',
          MutationStatus.updated,
        ),
      );
      final afterDietProjection = EmissionCalculator.summarize(
        repository.activeUser!,
        now: DateTime.utc(2026, 6, 1),
      ).projectedEndYearKg;

      expect(
        await repository.updateEnergyProfile(
          const EnergyProfile(
            electricityKwh: 2500,
            gasM3: 250,
            isEstimated: false,
          ),
        ),
        isA<MutationResult>().having(
          (result) => result.status,
          'status',
          MutationStatus.updated,
        ),
      );
      final afterEnergyProjection = EmissionCalculator.summarize(
        repository.activeUser!,
        now: DateTime.utc(2026, 6, 1),
      ).projectedEndYearKg;

      expect(afterCarProjection, lessThan(initialProjection));
      expect(afterDietProjection, lessThan(afterCarProjection));
      expect(afterEnergyProjection, lessThan(afterDietProjection));
    });
  });

  group('RemoteAppRepository', () {
    test('persists auth and flight updates through remote client', () async {
      final remoteClient = SimulatedRemoteStateClient(
        networkDelay: Duration.zero,
      );
      final repository = RemoteAppRepository(
        remoteClient: remoteClient,
        stateStore: _InMemoryAppStateStore(),
        retryPolicy: const RemoteRetryPolicy(
          retryDelays: [Duration.zero, Duration.zero],
        ),
      );

      await repository.hydrate();
      final auth = await repository.register('remote@example.com', 'secure123');
      expect(auth.status, equals(AuthActionStatus.authenticated));

      final addFlight = await repository.addFlight(
        FlightDraft(
          flightNumber: 'KL1001',
          date: DateTime(2026, 6, 1),
          occupancy: OccupancyLevel.halfFull,
        ),
      );
      expect(addFlight.status, equals(AddFlightStatus.added));
      expect(repository.activeUser?.flights.length, equals(1));
    });

    test('returns unavailable and rolls back on remote outage', () async {
      final remoteClient = SimulatedRemoteStateClient(
        networkDelay: Duration.zero,
        failureRate: 1,
      );
      final repository = RemoteAppRepository(
        remoteClient: remoteClient,
        stateStore: _InMemoryAppStateStore(),
      );

      await repository.hydrate();

      final auth = await repository.register(
        'remote-fail@example.com',
        'secure123',
      );
      expect(auth.status, equals(AuthActionStatus.unavailable));
      expect(repository.activeEmail, isNull);
      expect(repository.activeUser, isNull);
    });

    test(
      'retries transient save failures and succeeds before exhausting policy',
      () async {
        final remoteClient = _FlakyRemoteStateClient(remainingSaveFailures: 2);
        final repository = RemoteAppRepository(
          remoteClient: remoteClient,
          stateStore: _InMemoryAppStateStore(),
          retryPolicy: const RemoteRetryPolicy(
            retryDelays: [Duration.zero, Duration.zero],
          ),
        );

        await repository.hydrate();
        final auth = await repository.register(
          'remote-retry@example.com',
          'secure123',
        );

        expect(auth.status, equals(AuthActionStatus.authenticated));
        expect(remoteClient.saveCalls, equals(3));
        expect(repository.activeEmail, equals('remote-retry@example.com'));
      },
    );

    test(
      'returns unavailable when transient failure retries are exhausted',
      () async {
        final remoteClient = _FlakyRemoteStateClient(remainingSaveFailures: 3);
        final repository = RemoteAppRepository(
          remoteClient: remoteClient,
          stateStore: _InMemoryAppStateStore(),
          retryPolicy: const RemoteRetryPolicy(
            retryDelays: [Duration.zero, Duration.zero],
          ),
        );

        await repository.hydrate();
        final auth = await repository.register(
          'remote-retry-fail@example.com',
          'secure123',
        );

        expect(auth.status, equals(AuthActionStatus.unavailable));
        expect(remoteClient.saveCalls, equals(3));
        expect(repository.activeEmail, isNull);
        expect(repository.activeUser, isNull);
      },
    );

    test('retries transient load failures during hydrate', () async {
      final user = UserData.empty(
        email: 'remote-load@example.com',
      ).copyWith(onboardingComplete: true);
      final remoteClient = _FlakyRemoteStateClient(
        initialState: PersistedAppState(
          credentials: const {'remote-load@example.com': 'secure123'},
          users: {'remote-load@example.com': user},
          activeEmail: 'remote-load@example.com',
        ),
        remainingLoadFailures: 1,
      );
      final repository = RemoteAppRepository(
        remoteClient: remoteClient,
        stateStore: _InMemoryAppStateStore(),
        retryPolicy: const RemoteRetryPolicy(retryDelays: [Duration.zero]),
      );

      await repository.hydrate();

      expect(remoteClient.loadCalls, equals(2));
      expect(repository.activeEmail, equals('remote-load@example.com'));
      expect(repository.activeUser?.onboardingComplete, isTrue);
    });
  });

  group('InputValidation', () {
    test('validates registration password complexity', () {
      expect(
        InputValidation.validatePassword('abcdefg'),
        equals('Password must be at least 8 characters.'),
      );
      expect(
        InputValidation.validatePassword('abcdefgh'),
        equals('Password must include at least one number.'),
      );
      expect(
        InputValidation.validatePassword('12345678'),
        equals('Password must include at least one letter.'),
      );
      expect(InputValidation.validatePassword('secure123'), isNull);
    });

    test('validates car distance ranges by distance mode', () {
      expect(
        InputValidation.validateCarDistance(0, DistanceMode.perDay),
        equals('Distance must be greater than 0.'),
      );
      expect(
        InputValidation.validateCarDistance(650, DistanceMode.perDay),
        equals('Distance for km/day must be between 1 and 500.'),
      );
      expect(
        InputValidation.validateCarDistance(80, DistanceMode.perYear),
        equals('Distance for km/year must be between 100 and 200000.'),
      );
      expect(
        InputValidation.validateCarDistance(14000, DistanceMode.perYear),
        isNull,
      );
    });

    test('validates energy input ranges', () {
      expect(
        InputValidation.validateEnergyUsage(null, 10),
        equals('Energy values must be valid numbers.'),
      );
      expect(
        InputValidation.validateEnergyUsage(-1, 10),
        equals('Energy values must be non-negative.'),
      );
      expect(
        InputValidation.validateEnergyUsage(51000, 10),
        equals('Electricity usage seems too high (max 50000 kWh/year).'),
      );
      expect(
        InputValidation.validateEnergyUsage(4000, 12000),
        equals('Gas usage seems too high (max 10000 m3/year).'),
      );
      expect(InputValidation.validateEnergyUsage(4000, 700), isNull);
    });

    test('validates flight number format and date range', () {
      expect(
        InputValidation.validateFlightNumber(''),
        equals('Flight number is required.'),
      );
      expect(
        InputValidation.validateFlightNumber('K1001'),
        equals('Use format like KL1001 (2 letters + 3-4 digits).'),
      );
      expect(InputValidation.validateFlightNumber('KL1001'), isNull);

      final reference = DateTime(2026, 8, 1);
      expect(
        InputValidation.validateFlightDate(
          DateTime(2026, 8, 2),
          now: reference,
        ),
        equals('Flight date cannot be in the future.'),
      );
      expect(
        InputValidation.validateFlightDate(
          DateTime(2024, 12, 31),
          now: reference,
        ),
        equals('Flight date is too far in the past for MVP logging.'),
      );
      expect(
        InputValidation.validateFlightDate(
          DateTime(2026, 1, 15),
          now: reference,
        ),
        isNull,
      );
    });
  });
}
