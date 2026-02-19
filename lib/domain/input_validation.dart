part of 'package:carbonfeet/main.dart';

extension DairyLevelLabel on DairyLevel {
  String get label => switch (this) {
    DairyLevel.low => 'Low',
    DairyLevel.medium => 'Medium',
    DairyLevel.high => 'High',
  };
}

extension OccupancyLevelLabel on OccupancyLevel {
  String get label => switch (this) {
    OccupancyLevel.nearlyEmpty => 'Nearly empty',
    OccupancyLevel.halfFull => 'Half full',
    OccupancyLevel.nearlyFull => 'Nearly full',
  };
}

extension LifeStageLabel on LifeStage {
  String get label => switch (this) {
    LifeStage.student => 'Student',
    LifeStage.youngProfessional => 'Young professional',
    LifeStage.family => 'Family',
    LifeStage.retired => 'Retired',
  };
}

class InputValidation {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _containsLetter = RegExp(r'[A-Za-z]');
  static final RegExp _containsDigit = RegExp(r'\d');
  static final RegExp _flightNumberPattern = RegExp(r'^[A-Z]{2}\d{3,4}$');

  static String? validateEmail(String email) {
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!_containsLetter.hasMatch(password)) {
      return 'Password must include at least one letter.';
    }
    if (!_containsDigit.hasMatch(password)) {
      return 'Password must include at least one number.';
    }
    return null;
  }

  static String? validateCarDistance(double? value, DistanceMode mode) {
    if (value == null) {
      return 'Enter a valid distance.';
    }
    if (value <= 0) {
      return 'Distance must be greater than 0.';
    }

    if (mode == DistanceMode.perDay) {
      if (value < 1 || value > 500) {
        return 'Distance for km/day must be between 1 and 500.';
      }
    } else {
      if (value < 100 || value > 200000) {
        return 'Distance for km/year must be between 100 and 200000.';
      }
    }

    return null;
  }

  static String? validateEnergyUsage(double? electricity, double? gas) {
    if (electricity == null || gas == null) {
      return 'Energy values must be valid numbers.';
    }
    if (electricity < 0 || gas < 0) {
      return 'Energy values must be non-negative.';
    }
    if (electricity > 50000) {
      return 'Electricity usage seems too high (max 50000 kWh/year).';
    }
    if (gas > 10000) {
      return 'Gas usage seems too high (max 10000 m3/year).';
    }
    return null;
  }

  static String? validateFlightNumber(String flightNumber) {
    if (flightNumber.isEmpty) {
      return 'Flight number is required.';
    }
    if (!_flightNumberPattern.hasMatch(flightNumber)) {
      return 'Use format like KL1001 (2 letters + 3-4 digits).';
    }
    return null;
  }

  static String? validateFlightDate(DateTime flightDate, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final selected = DateTime(
      flightDate.year,
      flightDate.month,
      flightDate.day,
    );
    final earliestAllowed = DateTime(today.year - 1, 1, 1);

    if (selected.isAfter(today)) {
      return 'Flight date cannot be in the future.';
    }
    if (selected.isBefore(earliestAllowed)) {
      return 'Flight date is too far in the past for MVP logging.';
    }
    return null;
  }
}
