part of 'package:carbonfeet/main.dart';

enum AuthActionStatus {
  authenticated,
  emailAlreadyExists,
  invalidCredentials,
  unavailable,
}

class AuthActionResult {
  const AuthActionResult({required this.status});

  final AuthActionStatus status;

  bool get isAuthenticated => status == AuthActionStatus.authenticated;
}

enum MutationStatus { updated, noActiveUser, unavailable }

class MutationResult {
  const MutationResult({required this.status});

  final MutationStatus status;

  bool get isSuccess => status == MutationStatus.updated;
}

enum AddFlightStatus {
  added,
  noActiveUser,
  unknownFlight,
  duplicateForDate,
  unavailable,
}

class AddFlightResult {
  const AddFlightResult({required this.status, this.entry});

  final AddFlightStatus status;
  final FlightEntry? entry;

  bool get isSuccess => status == AddFlightStatus.added;
}

abstract interface class AppRepository {
  Future<void> hydrate();

  String? get activeEmail;
  UserData? get activeUser;

  Future<AuthActionResult> register(String email, String password);
  Future<AuthActionResult> login(String email, String password);

  void logout();
  void updateActiveUser(UserData next);

  Future<AddFlightResult> addFlight(FlightDraft draft);
  Future<MutationResult> updateCarProfile(CarProfile profile);
  Future<MutationResult> updateDietProfile(DietProfile profile);
  Future<MutationResult> updateEnergyProfile(EnergyProfile profile);
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
    _applyPersistedState(restored);

    final didNormalize = _normalizeInMemoryState();
    if (didNormalize) {
      await _persistStateSafely();
    }
  }

  @override
  Future<AuthActionResult> register(String email, String password) async {
    if (_credentials.containsKey(email)) {
      return const AuthActionResult(
        status: AuthActionStatus.emailAlreadyExists,
      );
    }

    final snapshot = _snapshot();
    _credentials[email] = password;
    _users[email] = UserData.empty(email: email);
    _activeEmail = email;

    final didPersist = await _persistStateSafely();
    if (!didPersist) {
      _restore(snapshot);
      return const AuthActionResult(status: AuthActionStatus.unavailable);
    }

    return const AuthActionResult(status: AuthActionStatus.authenticated);
  }

  @override
  Future<AuthActionResult> login(String email, String password) async {
    final storedPassword = _credentials[email];
    if (storedPassword == null || storedPassword != password) {
      return const AuthActionResult(
        status: AuthActionStatus.invalidCredentials,
      );
    }

    final snapshot = _snapshot();
    _users.putIfAbsent(email, () => UserData.empty(email: email));
    _activeEmail = email;

    final didPersist = await _persistStateSafely();
    if (!didPersist) {
      _restore(snapshot);
      return const AuthActionResult(status: AuthActionStatus.unavailable);
    }

    return const AuthActionResult(status: AuthActionStatus.authenticated);
  }

  @override
  void logout() {
    _activeEmail = null;
    unawaited(_persistStateSafely());
  }

  @override
  void updateActiveUser(UserData next) {
    final email = _activeEmail;
    if (email == null) {
      return;
    }

    _users[email] = next.copyWith(email: email);
    unawaited(_persistStateSafely());
  }

  @override
  Future<AddFlightResult> addFlight(FlightDraft draft) async {
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

    final snapshot = _snapshot();
    _users[email] = current
        .copyWith(
          flights: [...current.flights, entry],
          activityLog: [...current.activityLog, ActivityEvent.atNow('flight')],
        )
        .copyWith(email: email);

    final didPersist = await _persistStateSafely();
    if (!didPersist) {
      _restore(snapshot);
      return const AddFlightResult(status: AddFlightStatus.unavailable);
    }

    return AddFlightResult(status: AddFlightStatus.added, entry: entry);
  }

  @override
  Future<MutationResult> updateCarProfile(CarProfile profile) {
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
  Future<MutationResult> updateDietProfile(DietProfile profile) {
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
  Future<MutationResult> updateEnergyProfile(EnergyProfile profile) {
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

  Future<MutationResult> _mutateActiveUser(
    UserData Function(UserData current) updater,
  ) async {
    final email = _activeEmail;
    if (email == null) {
      return const MutationResult(status: MutationStatus.noActiveUser);
    }

    final current = _users[email];
    if (current == null) {
      return const MutationResult(status: MutationStatus.noActiveUser);
    }

    final snapshot = _snapshot();
    _users[email] = updater(current).copyWith(email: email);

    final didPersist = await _persistStateSafely();
    if (!didPersist) {
      _restore(snapshot);
      return const MutationResult(status: MutationStatus.unavailable);
    }

    return const MutationResult(status: MutationStatus.updated);
  }

  _RepositorySnapshot _snapshot() {
    return _RepositorySnapshot(
      credentials: Map<String, String>.from(_credentials),
      users: Map<String, UserData>.from(_users),
      activeEmail: _activeEmail,
    );
  }

  void _restore(_RepositorySnapshot snapshot) {
    _credentials
      ..clear()
      ..addAll(snapshot.credentials);
    _users
      ..clear()
      ..addAll(snapshot.users);
    _activeEmail = snapshot.activeEmail;
  }

  void _applyPersistedState(PersistedAppState state) {
    _credentials
      ..clear()
      ..addAll(state.credentials);
    _users
      ..clear()
      ..addAll(state.users);
    _activeEmail = state.activeEmail;
  }

  bool _normalizeInMemoryState() {
    var changed = false;

    for (final email in _credentials.keys) {
      if (_users.containsKey(email)) {
        continue;
      }
      _users[email] = UserData.empty(email: email);
      changed = true;
    }

    _users.removeWhere((email, _) {
      final shouldRemove = !_credentials.containsKey(email);
      if (shouldRemove) {
        changed = true;
      }
      return shouldRemove;
    });

    final activeEmail = _activeEmail;
    if (activeEmail != null && !_credentials.containsKey(activeEmail)) {
      _activeEmail = null;
      changed = true;
    }

    return changed;
  }

  PersistedAppState _buildPersistedState() {
    return PersistedAppState(
      credentials: Map<String, String>.from(_credentials),
      users: Map<String, UserData>.from(_users),
      activeEmail: _activeEmail,
    );
  }

  Future<bool> _persistStateSafely() async {
    try {
      await _stateStore.save(_buildPersistedState());
      return true;
    } catch (_) {
      return false;
    }
  }
}

abstract interface class RemoteStateClient {
  Future<PersistedAppState> load();
  Future<void> save(PersistedAppState state);
}

class RemoteStateUnavailable implements Exception {
  const RemoteStateUnavailable([
    this.message = 'Remote state service is unavailable.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class RemoteRetryPolicy {
  const RemoteRetryPolicy({
    this.retryDelays = const [
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(milliseconds: 1000),
    ],
  });

  final List<Duration> retryDelays;

  int get maxAttempts => retryDelays.length + 1;
}

class SimulatedRemoteStateClient implements RemoteStateClient {
  SimulatedRemoteStateClient({
    PersistedAppState? initialState,
    this.networkDelay = const Duration(milliseconds: 320),
    this.failureRate = 0,
    math.Random? random,
  }) : _state = initialState ?? const PersistedAppState.empty(),
       _random = random ?? math.Random();

  PersistedAppState _state;
  final Duration networkDelay;
  final double failureRate;
  final math.Random _random;

  @override
  Future<PersistedAppState> load() async {
    await _simulateNetwork();
    _throwIfUnavailable();
    return PersistedAppState.fromJson(_state.toJson());
  }

  @override
  Future<void> save(PersistedAppState state) async {
    await _simulateNetwork();
    _throwIfUnavailable();
    _state = PersistedAppState.fromJson(state.toJson());
  }

  Future<void> _simulateNetwork() async {
    if (networkDelay <= Duration.zero) {
      return;
    }
    await Future<void>.delayed(networkDelay);
  }

  void _throwIfUnavailable() {
    final shouldFail = failureRate > 0 && _random.nextDouble() < failureRate;
    if (shouldFail) {
      throw const RemoteStateUnavailable();
    }
  }
}

class RemoteAppRepository implements AppRepository {
  RemoteAppRepository({
    required RemoteStateClient remoteClient,
    AppStateStore? stateStore,
    RemoteRetryPolicy retryPolicy = const RemoteRetryPolicy(),
    Future<void> Function(Duration delay)? waitForDelay,
  }) : _remoteClient = remoteClient,
       _stateStore = stateStore ?? const AppStateStore(),
       _retryPolicy = retryPolicy,
       _waitForDelay = waitForDelay ?? _defaultWaitForDelay;

  final RemoteStateClient _remoteClient;
  final AppStateStore _stateStore;
  final RemoteRetryPolicy _retryPolicy;
  final Future<void> Function(Duration delay) _waitForDelay;
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
    final local = await _stateStore.load();
    _applyPersistedState(local);
    _normalizeInMemoryState();

    try {
      final remote = await _withRemoteRetries(() => _remoteClient.load());
      _applyPersistedState(remote);
      _normalizeInMemoryState();
      await _persistLocalSafely();
    } catch (_) {
      // Keep local cache when remote cannot be reached.
    }
  }

  @override
  Future<AuthActionResult> register(String email, String password) async {
    if (_credentials.containsKey(email)) {
      return const AuthActionResult(
        status: AuthActionStatus.emailAlreadyExists,
      );
    }

    final snapshot = _snapshot();
    _credentials[email] = password;
    _users[email] = UserData.empty(email: email);
    _activeEmail = email;

    final didCommit = await _commitStateSafely();
    if (!didCommit) {
      _restore(snapshot);
      return const AuthActionResult(status: AuthActionStatus.unavailable);
    }

    return const AuthActionResult(status: AuthActionStatus.authenticated);
  }

  @override
  Future<AuthActionResult> login(String email, String password) async {
    final storedPassword = _credentials[email];
    if (storedPassword == null || storedPassword != password) {
      return const AuthActionResult(
        status: AuthActionStatus.invalidCredentials,
      );
    }

    final snapshot = _snapshot();
    _users.putIfAbsent(email, () => UserData.empty(email: email));
    _activeEmail = email;

    final didCommit = await _commitStateSafely();
    if (!didCommit) {
      _restore(snapshot);
      return const AuthActionResult(status: AuthActionStatus.unavailable);
    }

    return const AuthActionResult(status: AuthActionStatus.authenticated);
  }

  @override
  void logout() {
    _activeEmail = null;
    unawaited(_commitStateSafely());
  }

  @override
  void updateActiveUser(UserData next) {
    final email = _activeEmail;
    if (email == null) {
      return;
    }

    _users[email] = next.copyWith(email: email);
    unawaited(_commitStateSafely());
  }

  @override
  Future<AddFlightResult> addFlight(FlightDraft draft) async {
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

    final snapshot = _snapshot();
    _users[email] = current
        .copyWith(
          flights: [...current.flights, entry],
          activityLog: [...current.activityLog, ActivityEvent.atNow('flight')],
        )
        .copyWith(email: email);

    final didCommit = await _commitStateSafely();
    if (!didCommit) {
      _restore(snapshot);
      return const AddFlightResult(status: AddFlightStatus.unavailable);
    }

    return AddFlightResult(status: AddFlightStatus.added, entry: entry);
  }

  @override
  Future<MutationResult> updateCarProfile(CarProfile profile) {
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
  Future<MutationResult> updateDietProfile(DietProfile profile) {
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
  Future<MutationResult> updateEnergyProfile(EnergyProfile profile) {
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

  Future<MutationResult> _mutateActiveUser(
    UserData Function(UserData current) updater,
  ) async {
    final email = _activeEmail;
    if (email == null) {
      return const MutationResult(status: MutationStatus.noActiveUser);
    }

    final current = _users[email];
    if (current == null) {
      return const MutationResult(status: MutationStatus.noActiveUser);
    }

    final snapshot = _snapshot();
    _users[email] = updater(current).copyWith(email: email);

    final didCommit = await _commitStateSafely();
    if (!didCommit) {
      _restore(snapshot);
      return const MutationResult(status: MutationStatus.unavailable);
    }

    return const MutationResult(status: MutationStatus.updated);
  }

  _RepositorySnapshot _snapshot() {
    return _RepositorySnapshot(
      credentials: Map<String, String>.from(_credentials),
      users: Map<String, UserData>.from(_users),
      activeEmail: _activeEmail,
    );
  }

  void _restore(_RepositorySnapshot snapshot) {
    _credentials
      ..clear()
      ..addAll(snapshot.credentials);
    _users
      ..clear()
      ..addAll(snapshot.users);
    _activeEmail = snapshot.activeEmail;
  }

  void _applyPersistedState(PersistedAppState state) {
    _credentials
      ..clear()
      ..addAll(state.credentials);
    _users
      ..clear()
      ..addAll(state.users);
    _activeEmail = state.activeEmail;
  }

  bool _normalizeInMemoryState() {
    var changed = false;

    for (final email in _credentials.keys) {
      if (_users.containsKey(email)) {
        continue;
      }
      _users[email] = UserData.empty(email: email);
      changed = true;
    }

    _users.removeWhere((email, _) {
      final shouldRemove = !_credentials.containsKey(email);
      if (shouldRemove) {
        changed = true;
      }
      return shouldRemove;
    });

    final activeEmail = _activeEmail;
    if (activeEmail != null && !_credentials.containsKey(activeEmail)) {
      _activeEmail = null;
      changed = true;
    }

    return changed;
  }

  PersistedAppState _buildPersistedState() {
    return PersistedAppState(
      credentials: Map<String, String>.from(_credentials),
      users: Map<String, UserData>.from(_users),
      activeEmail: _activeEmail,
    );
  }

  Future<bool> _persistLocalSafely() async {
    try {
      await _stateStore.save(_buildPersistedState());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _commitStateSafely() async {
    final next = _buildPersistedState();
    try {
      await _withRemoteRetries(() => _remoteClient.save(next));
      await _stateStore.save(next);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<T> _withRemoteRetries<T>(Future<T> Function() operation) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt < _retryPolicy.maxAttempts; attempt++) {
      try {
        return await operation();
      } on RemoteStateUnavailable catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        if (attempt >= _retryPolicy.retryDelays.length) {
          break;
        }
        await _waitForDelay(_retryPolicy.retryDelays[attempt]);
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(
        lastError,
        lastStackTrace ?? StackTrace.current,
      );
    }

    throw const RemoteStateUnavailable();
  }

  static Future<void> _defaultWaitForDelay(Duration delay) {
    if (delay <= Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(delay);
  }
}

class _RepositorySnapshot {
  const _RepositorySnapshot({
    required this.credentials,
    required this.users,
    required this.activeEmail,
  });

  final Map<String, String> credentials;
  final Map<String, UserData> users;
  final String? activeEmail;
}
