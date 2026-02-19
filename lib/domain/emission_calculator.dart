part of 'package:carbonfeet/main.dart';

class EmissionCalculator {
  static EmissionSummary summarize(UserData user, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final countryRef =
        countryReferences[user.country] ?? defaultCountryReference;

    final carKg = _carYearlyKg(user.carProfile);
    final dietKg = _dietYearlyKg(user.dietProfile);
    final energyKg = _energyYearlyKg(user.energyProfile, countryRef);

    final baselineKg = carKg + dietKg + energyKg;

    final currentYearFlights = user.flights
        .where((entry) => entry.date.year == timestamp.year)
        .toList();

    final flightsYearKg = currentYearFlights.fold<double>(
      0,
      (sum, entry) => sum + entry.emissionsKg,
    );

    final currentYearFlightsYtd = currentYearFlights.where(
      (entry) => !entry.date.isAfter(timestamp),
    );

    final flightsYtdKg = currentYearFlightsYtd.fold<double>(
      0,
      (sum, entry) => sum + entry.emissionsKg,
    );

    final yearStart = DateTime(timestamp.year, 1, 1);
    final nextYearStart = DateTime(timestamp.year + 1, 1, 1);
    final daysInYear = nextYearStart.difference(yearStart).inDays;
    final dayOfYear = timestamp.difference(yearStart).inDays + 1;
    final progressRatio = dayOfYear / daysInYear;

    final ytdKg = baselineKg * progressRatio + flightsYtdKg;
    final projectedKg = baselineKg + flightsYearKg;

    final trend = <double>[];
    for (var month = 1; month <= 12; month++) {
      final monthEnd = month == 12
          ? DateTime(timestamp.year, 12, 31)
          : DateTime(
              timestamp.year,
              month + 1,
              1,
            ).subtract(const Duration(days: 1));
      final elapsed = monthEnd.difference(yearStart).inDays + 1;
      final baselineToMonth = baselineKg * (elapsed / daysInYear);
      final flightsToMonth = currentYearFlights
          .where((entry) => !entry.date.isAfter(monthEnd))
          .fold<double>(0, (sum, entry) => sum + entry.emissionsKg);

      trend.add(baselineToMonth + flightsToMonth);
    }

    final categoryTotals = <EmissionCategory, double>{
      EmissionCategory.flights: flightsYearKg,
      EmissionCategory.car: carKg,
      EmissionCategory.diet: dietKg,
      EmissionCategory.energy: energyKg,
    };

    final badges = <String>[];
    final hasImproved =
        user.initialProjectionKg > 0 &&
        projectedKg <= user.initialProjectionKg * 0.95;
    if (hasImproved) {
      badges.add('Improvement badge');
    }

    final uniqueWeekKeys = user.activityLog
        .where((event) => event.timestamp.year == timestamp.year)
        .map((event) => _weekKey(event.timestamp))
        .toSet();

    if (uniqueWeekKeys.length >= 3) {
      badges.add('Consistency badge');
    }

    final belowAverage = projectedKg <= countryRef.countryAverageKg;
    if (belowAverage) {
      badges.add('Low footprint badge');
    }

    final comparisonLabel = belowAverage
        ? 'Below country average by ${_formatNumber(countryRef.countryAverageKg - projectedKg)} kg'
        : 'Above country average by ${_formatNumber(projectedKg - countryRef.countryAverageKg)} kg';

    return EmissionSummary(
      yearToDateKg: ytdKg,
      projectedEndYearKg: projectedKg,
      baselineYearlyKg: baselineKg,
      flightsYearlyKg: flightsYearKg,
      countryAverageKg: countryRef.countryAverageKg,
      personalTargetKg: countryRef.personalTargetKg,
      comparisonLabel: comparisonLabel,
      isBelowCountryAverage: belowAverage,
      categoryTotals: categoryTotals,
      monthlyTrendKg: trend,
      badges: badges,
    );
  }

  static List<SimulationOutcome> simulateScenarios(UserData user) {
    final scenarios = <SimulationOutcome>[];

    if (user.flights.isNotEmpty) {
      final sortedFlights = [...user.flights]
        ..sort((a, b) => b.emissionsKg.compareTo(a.emissionsKg));
      final reduced = user.copyWith(flights: sortedFlights.skip(1).toList());
      scenarios.add(
        SimulationOutcome(
          title: 'Remove one flight',
          description:
              'Simulates skipping your largest logged flight this year.',
          projectedKg: summarize(reduced).projectedEndYearKg,
        ),
      );
    }

    final lessDriving = user.copyWith(
      carProfile: user.carProfile.copyWith(
        distanceValue: user.carProfile.distanceValue * 0.9,
      ),
    );
    scenarios.add(
      SimulationOutcome(
        title: 'Drive 10% less',
        description: 'Simulates reducing yearly car distance by 10%.',
        projectedKg: summarize(lessDriving).projectedEndYearKg,
      ),
    );

    final lessMeat = user.copyWith(
      dietProfile: user.dietProfile.copyWith(
        meatDaysPerWeek: math.max(0, user.dietProfile.meatDaysPerWeek - 1),
      ),
    );
    scenarios.add(
      SimulationOutcome(
        title: 'One less meat day/week',
        description: 'Simulates replacing one meat day every week.',
        projectedKg: summarize(lessMeat).projectedEndYearKg,
      ),
    );

    return scenarios;
  }

  static (double electricityKwh, double gasM3) estimateEnergyForCountry(
    String country,
  ) {
    final ref = countryReferences[country] ?? defaultCountryReference;
    return (ref.defaultElectricityKwh, ref.defaultGasM3);
  }

  static FlightEntry? buildFlightEntry(FlightDraft draft) {
    if (draft.flightNumber.isEmpty) {
      return null;
    }

    final template = flightCatalog[draft.flightNumber];
    if (template == null) {
      return null;
    }

    final occupancyMultiplier = switch (draft.occupancy) {
      OccupancyLevel.nearlyEmpty => 1.25,
      OccupancyLevel.halfFull => 1,
      OccupancyLevel.nearlyFull => 0.82,
    };

    final basePerKm = 0.115;
    final segmentMultiplier = 1 + ((template.segments - 1) * 0.15);

    final emissions =
        template.distanceKm *
        basePerKm *
        segmentMultiplier *
        template.aircraftMultiplier *
        occupancyMultiplier;

    return FlightEntry(
      flightNumber: draft.flightNumber,
      date: draft.date,
      occupancy: draft.occupancy,
      origin: template.origin,
      destination: template.destination,
      distanceKm: template.distanceKm,
      segments: template.segments,
      aircraftType: template.aircraftType,
      emissionsKg: emissions,
    );
  }

  static double _carYearlyKg(CarProfile car) {
    final vehicle = vehicleByKey[car.vehicleKey] ?? vehicleCatalog.first;
    final yearlyKm = car.distanceMode == DistanceMode.perDay
        ? car.distanceValue * 365
        : car.distanceValue;
    return yearlyKm * vehicle.kgPerKm;
  }

  static double _dietYearlyKg(DietProfile diet) {
    final meatBase = switch (diet.meatDaysPerWeek) {
      0 => 600,
      1 => 850,
      2 => 1100,
      3 => 1350,
      4 => 1600,
      5 => 1850,
      6 => 2100,
      _ => 2350,
    };

    final dairyOffset = switch (diet.dairyLevel) {
      DairyLevel.low => -150,
      DairyLevel.medium => 0,
      DairyLevel.high => 180,
    };

    return math.max(350, meatBase + dairyOffset).toDouble();
  }

  static double _energyYearlyKg(
    EnergyProfile energy,
    CountryReference countryRef,
  ) {
    final electricityKg =
        energy.electricityKwh * countryRef.electricityKgPerKwh;
    final gasKg = energy.gasM3 * 2.0;
    return electricityKg + gasKg;
  }

  static String _weekKey(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final week = ((date.difference(firstDay).inDays) / 7).floor() + 1;
    return '${date.year}-$week';
  }
}

class EmissionSummary {
  const EmissionSummary({
    required this.yearToDateKg,
    required this.projectedEndYearKg,
    required this.baselineYearlyKg,
    required this.flightsYearlyKg,
    required this.countryAverageKg,
    required this.personalTargetKg,
    required this.comparisonLabel,
    required this.isBelowCountryAverage,
    required this.categoryTotals,
    required this.monthlyTrendKg,
    required this.badges,
  });

  final double yearToDateKg;
  final double projectedEndYearKg;
  final double baselineYearlyKg;
  final double flightsYearlyKg;
  final double countryAverageKg;
  final double personalTargetKg;
  final String comparisonLabel;
  final bool isBelowCountryAverage;
  final Map<EmissionCategory, double> categoryTotals;
  final List<double> monthlyTrendKg;
  final List<String> badges;
}

class SimulationOutcome {
  const SimulationOutcome({
    required this.title,
    required this.description,
    required this.projectedKg,
  });

  final String title;
  final String description;
  final double projectedKg;
}
