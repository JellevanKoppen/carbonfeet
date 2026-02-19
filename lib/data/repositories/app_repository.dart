part of 'package:carbonfeet/main.dart';

enum AddFlightStatus { added, noActiveUser, unknownFlight, duplicateForDate }

class AddFlightResult {
  const AddFlightResult({required this.status, this.entry});

  final AddFlightStatus status;
  final FlightEntry? entry;
}

abstract interface class AppRepository {
  Future<void> hydrate();

  String? get activeEmail;
  UserData? get activeUser;

  bool register(String email, String password);
  bool login(String email, String password);

  void logout();
  void updateActiveUser(UserData next);
  AddFlightResult addFlight(FlightDraft draft);
  bool updateCarProfile(CarProfile profile);
  bool updateDietProfile(DietProfile profile);
  bool updateEnergyProfile(EnergyProfile profile);
}

class LocalAppRepository implements AppRepository {
  LocalAppRepository({AppStateStore? stateStore})
    : _stateStore = stateStore ?? const AppStateStore();

  final AppStateStore _stateStore;
  final Map<String, String> _credentials = <String, String>{};
  final Map<String, UserData> _users = <String, UserData>{};

  String? _activeEmail;

  @override
  String? get activeEmail => _activeEmail;

  @override
  UserData? get activeUser {
    final email = _activeEmail;
    if (email == null) {
      return null;
    }
    return _users[email];
  }

  @override
  Future<void> hydrate() async {
    final restored = await _stateStore.load();
    _credentials
      ..clear()
      ..addAll(restored.credentials);
    _users
      ..clear()
      ..addAll(restored.users);
    _activeEmail = restored.activeEmail;

    var shouldPersist = false;
    for (final email in _credentials.keys) {
      if (_users.containsKey(email)) {
        continue;
      }
      _users[email] = UserData.empty(email: email);
      shouldPersist = true;
    }

    _users.removeWhere((email, _) {
      final shouldRemove = !_credentials.containsKey(email);
      if (shouldRemove) {
        shouldPersist = true;
      }
      return shouldRemove;
    });

    final activeEmail = _activeEmail;
    if (activeEmail != null && !_credentials.containsKey(activeEmail)) {
      _activeEmail = null;
      shouldPersist = true;
    }

    if (shouldPersist) {
      _persistState();
    }
  }

  @override
  bool register(String email, String password) {
    if (_credentials.containsKey(email)) {
      return false;
    }

    _credentials[email] = password;
    _users[email] = UserData.empty(email: email);
    _activeEmail = email;
    _persistState();
    return true;
  }

  @override
  bool login(String email, String password) {
    final storedPassword = _credentials[email];
    if (storedPassword == null || storedPassword != password) {
      return false;
    }

    _users.putIfAbsent(email, () => UserData.empty(email: email));
    _activeEmail = email;
    _persistState();
    return true;
  }

  @override
  void logout() {
    _activeEmail = null;
    _persistState();
  }

  @override
  void updateActiveUser(UserData next) {
    final email = _activeEmail;
    if (email == null) {
      return;
    }

    _users[email] = next.copyWith(email: email);
    _persistState();
  }

  @override
  AddFlightResult addFlight(FlightDraft draft) {
    final email = _activeEmail;
    if (email == null) {
      return const AddFlightResult(status: AddFlightStatus.noActiveUser);
    }

    final current = _users[email];
    if (current == null) {
      return const AddFlightResult(status: AddFlightStatus.noActiveUser);
    }

    final entry = EmissionCalculator.buildFlightEntry(draft);
    if (entry == null) {
      return const AddFlightResult(status: AddFlightStatus.unknownFlight);
    }

    final hasDuplicate = current.flights.any(
      (flight) =>
          flight.flightNumber == entry.flightNumber &&
          _isSameCalendarDate(flight.date, entry.date),
    );
    if (hasDuplicate) {
      return const AddFlightResult(status: AddFlightStatus.duplicateForDate);
    }

    _users[email] = current
        .copyWith(
          flights: [...current.flights, entry],
          activityLog: [...current.activityLog, ActivityEvent.atNow('flight')],
        )
        .copyWith(email: email);
    _persistState();

    return AddFlightResult(status: AddFlightStatus.added, entry: entry);
  }

  @override
  bool updateCarProfile(CarProfile profile) {
    return _mutateActiveUser(
      (current) => current.copyWith(
        carProfile: profile,
        activityLog: [
          ...current.activityLog,
          ActivityEvent.atNow('car_update'),
        ],
      ),
    );
  }

  @override
  bool updateDietProfile(DietProfile profile) {
    return _mutateActiveUser(
      (current) => current.copyWith(
        dietProfile: profile,
        activityLog: [
          ...current.activityLog,
          ActivityEvent.atNow('diet_update'),
        ],
      ),
    );
  }

  @override
  bool updateEnergyProfile(EnergyProfile profile) {
    return _mutateActiveUser(
      (current) => current.copyWith(
        energyProfile: profile,
        activityLog: [
          ...current.activityLog,
          ActivityEvent.atNow('energy_update'),
        ],
      ),
    );
  }

  bool _mutateActiveUser(UserData Function(UserData current) updater) {
    final email = _activeEmail;
    if (email == null) {
      return false;
    }

    final current = _users[email];
    if (current == null) {
      return false;
    }

    _users[email] = updater(current).copyWith(email: email);
    _persistState();
    return true;
  }

  void _persistState() {
    unawaited(
      _stateStore.save(
        PersistedAppState(
          credentials: Map<String, String>.from(_credentials),
          users: Map<String, UserData>.from(_users),
          activeEmail: _activeEmail,
        ),
      ),
    );
  }
}
