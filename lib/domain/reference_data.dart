part of 'package:carbonfeet/main.dart';

const defaultCountryReference = CountryReference(
  countryAverageKg: 8000,
  personalTargetKg: 5500,
  electricityKgPerKwh: 0.3,
  defaultElectricityKwh: 3500,
  defaultGasM3: 450,
);

const countryReferences = <String, CountryReference>{
  'United States': CountryReference(
    countryAverageKg: 14000,
    personalTargetKg: 8000,
    electricityKgPerKwh: 0.39,
    defaultElectricityKwh: 4600,
    defaultGasM3: 680,
  ),
  'Netherlands': CountryReference(
    countryAverageKg: 10500,
    personalTargetKg: 6500,
    electricityKgPerKwh: 0.34,
    defaultElectricityKwh: 3200,
    defaultGasM3: 1200,
  ),
  'Germany': CountryReference(
    countryAverageKg: 9000,
    personalTargetKg: 6000,
    electricityKgPerKwh: 0.37,
    defaultElectricityKwh: 3100,
    defaultGasM3: 950,
  ),
  'United Kingdom': CountryReference(
    countryAverageKg: 6500,
    personalTargetKg: 5000,
    electricityKgPerKwh: 0.23,
    defaultElectricityKwh: 2800,
    defaultGasM3: 930,
  ),
  'France': CountryReference(
    countryAverageKg: 6000,
    personalTargetKg: 4500,
    electricityKgPerKwh: 0.08,
    defaultElectricityKwh: 2900,
    defaultGasM3: 700,
  ),
  'India': CountryReference(
    countryAverageKg: 2200,
    personalTargetKg: 1800,
    electricityKgPerKwh: 0.65,
    defaultElectricityKwh: 1900,
    defaultGasM3: 210,
  ),
  'Brazil': CountryReference(
    countryAverageKg: 2500,
    personalTargetKg: 1800,
    electricityKgPerKwh: 0.09,
    defaultElectricityKwh: 2200,
    defaultGasM3: 120,
  ),
};

const vehicleCatalog = <VehicleProfile>[
  VehicleProfile(key: 'toyota_corolla', label: 'Toyota Corolla', kgPerKm: 0.17),
  VehicleProfile(
    key: 'volkswagen_golf',
    label: 'Volkswagen Golf',
    kgPerKm: 0.16,
  ),
  VehicleProfile(key: 'ford_focus', label: 'Ford Focus', kgPerKm: 0.18),
  VehicleProfile(key: 'tesla_model_3', label: 'Tesla Model 3', kgPerKm: 0.06),
  VehicleProfile(
    key: 'kia_niro_hybrid',
    label: 'Kia Niro Hybrid',
    kgPerKm: 0.11,
  ),
  VehicleProfile(key: 'ford_f150', label: 'Ford F-150', kgPerKm: 0.26),
  VehicleProfile(key: 'bmw_320i', label: 'BMW 320i', kgPerKm: 0.20),
  VehicleProfile(key: 'honda_civic', label: 'Honda Civic', kgPerKm: 0.16),
];

const flightCatalog = <String, FlightTemplate>{
  'KL1001': FlightTemplate(
    flightNumber: 'KL1001',
    origin: 'AMS',
    destination: 'LHR',
    distanceKm: 370,
    segments: 1,
    aircraftType: 'Boeing 737-800',
    aircraftMultiplier: 0.97,
  ),
  'KL0641': FlightTemplate(
    flightNumber: 'KL0641',
    origin: 'AMS',
    destination: 'JFK',
    distanceKm: 5860,
    segments: 1,
    aircraftType: 'Airbus A330',
    aircraftMultiplier: 1.04,
  ),
  'DL0405': FlightTemplate(
    flightNumber: 'DL0405',
    origin: 'JFK',
    destination: 'LAX',
    distanceKm: 3983,
    segments: 1,
    aircraftType: 'Boeing 767',
    aircraftMultiplier: 1.01,
  ),
  'BA0295': FlightTemplate(
    flightNumber: 'BA0295',
    origin: 'LHR',
    destination: 'ORD',
    distanceKm: 6353,
    segments: 1,
    aircraftType: 'Boeing 777',
    aircraftMultiplier: 1.07,
  ),
  'LH2010': FlightTemplate(
    flightNumber: 'LH2010',
    origin: 'FRA',
    destination: 'BER',
    distanceKm: 424,
    segments: 1,
    aircraftType: 'Airbus A320',
    aircraftMultiplier: 0.96,
  ),
  'UA0123': FlightTemplate(
    flightNumber: 'UA0123',
    origin: 'SFO',
    destination: 'NRT',
    distanceKm: 8235,
    segments: 1,
    aircraftType: 'Boeing 787',
    aircraftMultiplier: 0.95,
  ),
  'AF1777': FlightTemplate(
    flightNumber: 'AF1777',
    origin: 'CDG',
    destination: 'LIS',
    distanceKm: 1453,
    segments: 1,
    aircraftType: 'Airbus A320neo',
    aircraftMultiplier: 0.93,
  ),
  'EK0203': FlightTemplate(
    flightNumber: 'EK0203',
    origin: 'DXB',
    destination: 'JFK',
    distanceKm: 11020,
    segments: 1,
    aircraftType: 'Airbus A380',
    aircraftMultiplier: 1.12,
  ),
};

final vehicleByKey = {
  for (final vehicle in vehicleCatalog) vehicle.key: vehicle,
};
