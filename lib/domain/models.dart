part of 'package:carbonfeet/main.dart';

class UserData {
  const UserData({
    required this.email,
    required this.country,
    required this.lifeStage,
    required this.dietProfile,
    required this.carProfile,
    required this.energyProfile,
    required this.flights,
    required this.activityLog,
    required this.onboardingComplete,
    required this.initialProjectionKg,
  });

  factory UserData.empty({required String email}) {
    return UserData(
      email: email,
      country: 'United States',
      lifeStage: LifeStage.youngProfessional,
      dietProfile: const DietProfile(
        meatDaysPerWeek: 4,
        dairyLevel: DairyLevel.medium,
      ),
      carProfile: const CarProfile(
        vehicleKey: 'toyota_corolla',
        distanceMode: DistanceMode.perYear,
        distanceValue: 12000,
      ),
      energyProfile: const EnergyProfile(
        electricityKwh: 4300,
        gasM3: 650,
        isEstimated: true,
      ),
      flights: const [],
      activityLog: const [],
      onboardingComplete: false,
      initialProjectionKg: 0,
    );
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    final flights = (json['flights'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => FlightEntry.fromJson(_asStringDynamicMap(item)))
        .toList();
    final activityLog = (json['activityLog'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => ActivityEvent.fromJson(_asStringDynamicMap(item)))
        .toList();

    return UserData(
      email: _readString(json['email'], fallback: ''),
      country: _readString(json['country'], fallback: 'United States'),
      lifeStage: _enumFromName(
        LifeStage.values,
        json['lifeStage'],
        LifeStage.youngProfessional,
      ),
      dietProfile: DietProfile.fromJson(
        _asStringDynamicMap(json['dietProfile']),
      ),
      carProfile: CarProfile.fromJson(_asStringDynamicMap(json['carProfile'])),
      energyProfile: EnergyProfile.fromJson(
        _asStringDynamicMap(json['energyProfile']),
      ),
      flights: flights,
      activityLog: activityLog,
      onboardingComplete: _readBool(json['onboardingComplete']),
      initialProjectionKg: _readDouble(json['initialProjectionKg']),
    );
  }

  final String email;
  final String country;
  final LifeStage lifeStage;
  final DietProfile dietProfile;
  final CarProfile carProfile;
  final EnergyProfile energyProfile;
  final List<FlightEntry> flights;
  final List<ActivityEvent> activityLog;
  final bool onboardingComplete;
  final double initialProjectionKg;

  UserData copyWith({
    String? email,
    String? country,
    LifeStage? lifeStage,
    DietProfile? dietProfile,
    CarProfile? carProfile,
    EnergyProfile? energyProfile,
    List<FlightEntry>? flights,
    List<ActivityEvent>? activityLog,
    bool? onboardingComplete,
    double? initialProjectionKg,
  }) {
    return UserData(
      email: email ?? this.email,
      country: country ?? this.country,
      lifeStage: lifeStage ?? this.lifeStage,
      dietProfile: dietProfile ?? this.dietProfile,
      carProfile: carProfile ?? this.carProfile,
      energyProfile: energyProfile ?? this.energyProfile,
      flights: flights ?? this.flights,
      activityLog: activityLog ?? this.activityLog,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      initialProjectionKg: initialProjectionKg ?? this.initialProjectionKg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'country': country,
      'lifeStage': lifeStage.name,
      'dietProfile': dietProfile.toJson(),
      'carProfile': carProfile.toJson(),
      'energyProfile': energyProfile.toJson(),
      'flights': flights.map((entry) => entry.toJson()).toList(),
      'activityLog': activityLog.map((entry) => entry.toJson()).toList(),
      'onboardingComplete': onboardingComplete,
      'initialProjectionKg': initialProjectionKg,
    };
  }
}

class DietProfile {
  const DietProfile({required this.meatDaysPerWeek, required this.dairyLevel});

  factory DietProfile.fromJson(Map<String, dynamic> json) {
    return DietProfile(
      meatDaysPerWeek: _readInt(json['meatDaysPerWeek'], fallback: 4),
      dairyLevel: _enumFromName(
        DairyLevel.values,
        json['dairyLevel'],
        DairyLevel.medium,
      ),
    );
  }

  final int meatDaysPerWeek;
  final DairyLevel dairyLevel;

  DietProfile copyWith({int? meatDaysPerWeek, DairyLevel? dairyLevel}) {
    return DietProfile(
      meatDaysPerWeek: meatDaysPerWeek ?? this.meatDaysPerWeek,
      dairyLevel: dairyLevel ?? this.dairyLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {'meatDaysPerWeek': meatDaysPerWeek, 'dairyLevel': dairyLevel.name};
  }
}

class CarProfile {
  const CarProfile({
    required this.vehicleKey,
    required this.distanceMode,
    required this.distanceValue,
  });

  factory CarProfile.fromJson(Map<String, dynamic> json) {
    return CarProfile(
      vehicleKey: _readString(
        json['vehicleKey'],
        fallback: vehicleCatalog.first.key,
      ),
      distanceMode: _enumFromName(
        DistanceMode.values,
        json['distanceMode'],
        DistanceMode.perYear,
      ),
      distanceValue: _readDouble(json['distanceValue'], fallback: 12000),
    );
  }

  final String vehicleKey;
  final DistanceMode distanceMode;
  final double distanceValue;

  CarProfile copyWith({
    String? vehicleKey,
    DistanceMode? distanceMode,
    double? distanceValue,
  }) {
    return CarProfile(
      vehicleKey: vehicleKey ?? this.vehicleKey,
      distanceMode: distanceMode ?? this.distanceMode,
      distanceValue: distanceValue ?? this.distanceValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleKey': vehicleKey,
      'distanceMode': distanceMode.name,
      'distanceValue': distanceValue,
    };
  }
}

class EnergyProfile {
  const EnergyProfile({
    required this.electricityKwh,
    required this.gasM3,
    required this.isEstimated,
  });

  factory EnergyProfile.fromJson(Map<String, dynamic> json) {
    return EnergyProfile(
      electricityKwh: _readDouble(json['electricityKwh'], fallback: 4300),
      gasM3: _readDouble(json['gasM3'], fallback: 650),
      isEstimated: _readBool(json['isEstimated'], fallback: true),
    );
  }

  final double electricityKwh;
  final double gasM3;
  final bool isEstimated;

  Map<String, dynamic> toJson() {
    return {
      'electricityKwh': electricityKwh,
      'gasM3': gasM3,
      'isEstimated': isEstimated,
    };
  }
}

class FlightEntry {
  const FlightEntry({
    required this.flightNumber,
    required this.date,
    required this.occupancy,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.segments,
    required this.aircraftType,
    required this.emissionsKg,
  });

  factory FlightEntry.fromJson(Map<String, dynamic> json) {
    return FlightEntry(
      flightNumber: _readString(json['flightNumber']),
      date: _readDateTime(json['date']),
      occupancy: _enumFromName(
        OccupancyLevel.values,
        json['occupancy'],
        OccupancyLevel.halfFull,
      ),
      origin: _readString(json['origin']),
      destination: _readString(json['destination']),
      distanceKm: _readDouble(json['distanceKm']),
      segments: _readInt(json['segments'], fallback: 1),
      aircraftType: _readString(json['aircraftType']),
      emissionsKg: _readDouble(json['emissionsKg']),
    );
  }

  final String flightNumber;
  final DateTime date;
  final OccupancyLevel occupancy;
  final String origin;
  final String destination;
  final double distanceKm;
  final int segments;
  final String aircraftType;
  final double emissionsKg;

  Map<String, dynamic> toJson() {
    return {
      'flightNumber': flightNumber,
      'date': date.toIso8601String(),
      'occupancy': occupancy.name,
      'origin': origin,
      'destination': destination,
      'distanceKm': distanceKm,
      'segments': segments,
      'aircraftType': aircraftType,
      'emissionsKg': emissionsKg,
    };
  }
}

class FlightDraft {
  const FlightDraft({
    required this.flightNumber,
    required this.date,
    required this.occupancy,
  });

  final String flightNumber;
  final DateTime date;
  final OccupancyLevel occupancy;
}

class FlightTemplate {
  const FlightTemplate({
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.segments,
    required this.aircraftType,
    required this.aircraftMultiplier,
  });

  final String flightNumber;
  final String origin;
  final String destination;
  final double distanceKm;
  final int segments;
  final String aircraftType;
  final double aircraftMultiplier;
}

class CountryReference {
  const CountryReference({
    required this.countryAverageKg,
    required this.personalTargetKg,
    required this.electricityKgPerKwh,
    required this.defaultElectricityKwh,
    required this.defaultGasM3,
  });

  final double countryAverageKg;
  final double personalTargetKg;
  final double electricityKgPerKwh;
  final double defaultElectricityKwh;
  final double defaultGasM3;
}

class VehicleProfile {
  const VehicleProfile({
    required this.key,
    required this.label,
    required this.kgPerKm,
  });

  final String key;
  final String label;
  final double kgPerKm;
}

class ActivityEvent {
  const ActivityEvent({required this.timestamp, required this.type});

  factory ActivityEvent.atNow(String type) {
    return ActivityEvent(timestamp: DateTime.now(), type: type);
  }

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      timestamp: _readDateTime(json['timestamp']),
      type: _readString(json['type']),
    );
  }

  final DateTime timestamp;
  final String type;

  Map<String, dynamic> toJson() {
    return {'timestamp': timestamp.toIso8601String(), 'type': type};
  }
}

class CategoryDisplayData {
  const CategoryDisplayData(this.label, this.valueKg, this.color);

  final String label;
  final double valueKg;
  final Color color;
}

enum AuthMode { login, register }

enum DistanceMode { perDay, perYear }

enum OccupancyLevel { nearlyEmpty, halfFull, nearlyFull }

enum PostType { flight, car, diet, energy }

enum EmissionCategory { flights, car, diet, energy }

enum DairyLevel { low, medium, high }

enum LifeStage { student, youngProfessional, family, retired }
