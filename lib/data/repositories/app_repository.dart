part of 'package:carbonfeet/main.dart';

enum AuthActionStatus {
  authenticated,
  emailAlreadyExists,
  invalidCredentials,
  sessionExpired,
  unavailable,
}

class AuthActionResult {
  const AuthActionResult({required this.status});

  final AuthActionStatus status;

  bool get isAuthenticated => status == AuthActionStatus.authenticated;
}

enum MutationStatus { updated, noActiveUser, sessionExpired, unavailable }

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
  sessionExpired,
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

class RemoteSession {
  const RemoteSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  factory RemoteSession.fromJson(Map<String, dynamic> json) {
    final accessToken = _readString(json['accessToken']).trim();
    if (accessToken.isEmpty) {
      throw const FormatException('Missing access token.');
    }

    final refreshToken = _readString(json['refreshToken']).trim();
    final expiresAtRaw = _readString(json['expiresAt']).trim();

    return RemoteSession(
      accessToken: accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      expiresAt: expiresAtRaw.isEmpty ? null : DateTime.tryParse(expiresAtRaw),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool isExpired({DateTime? now}) {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) {
      return false;
    }
    final reference = (now ?? DateTime.now()).toUtc();
    return !expiresAt.toUtc().isAfter(reference);
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
    };
  }
}

abstract interface class RemoteSessionStore {
  Future<RemoteSession?> load();
  Future<void> save(RemoteSession? session);
}

class NoopRemoteSessionStore implements RemoteSessionStore {
  const NoopRemoteSessionStore();

  @override
  Future<RemoteSession?> load() async => null;

  @override
  Future<void> save(RemoteSession? session) async {}
}

class SharedPreferencesRemoteSessionStore implements RemoteSessionStore {
  const SharedPreferencesRemoteSessionStore();

  static const String _storageKey = 'carbonfeet_remote_session_v1';

  @override
  Future<RemoteSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return RemoteSession.fromJson(_asStringDynamicMap(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(RemoteSession? session) async {
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(_storageKey);
      return;
    }
    await prefs.setString(_storageKey, jsonEncode(session.toJson()));
  }
}

abstract interface class RemoteSessionAwareClient {
  RemoteSession? get session;
  set session(RemoteSession? value);
}

class RemoteStateUnavailable implements Exception {
  const RemoteStateUnavailable([
    this.message = 'Remote state service is unavailable.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class RemoteStateUnauthorized implements Exception {
  const RemoteStateUnauthorized([
    this.message = 'Remote session is unauthorized.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class RemoteStateRequestFailed implements Exception {
  const RemoteStateRequestFailed({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() => '[$statusCode] $message';
}

class RemoteHttpResponse {
  const RemoteHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

abstract interface class RemoteHttpTransport {
  Future<RemoteHttpResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  });
}

class IoRemoteHttpTransport implements RemoteHttpTransport {
  const IoRemoteHttpTransport();

  @override
  Future<RemoteHttpResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, url).timeout(timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (body != null) {
        request.write(body);
      }

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decodeStream(response).timeout(timeout);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        if (values.isEmpty) {
          return;
        }
        responseHeaders[name.toLowerCase()] = values.join(',');
      });

      return RemoteHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } on TimeoutException {
      throw const RemoteStateUnavailable('Remote state request timed out.');
    } on SocketException {
      throw const RemoteStateUnavailable(
        'Could not connect to remote state service.',
      );
    } on HttpException {
      throw const RemoteStateUnavailable(
        'Remote state service is unavailable.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class HttpRemoteStateClient
    implements RemoteStateClient, RemoteSessionAwareClient {
  HttpRemoteStateClient({
    required String baseUrl,
    String statePath = 'state',
    String? authToken,
    String? apiVersion,
    this.useStateEnvelope = false,
    RemoteHttpTransport? transport,
    this.timeout = const Duration(seconds: 8),
  }) : _baseUri = Uri.parse(baseUrl),
       _statePath = _normalizeStatePath(statePath),
       _apiVersion = _normalizeApiVersion(apiVersion),
       session = _initialSession(authToken),
       _transport = transport ?? const IoRemoteHttpTransport();

  final Uri _baseUri;
  final String _statePath;
  final String? _apiVersion;
  @override
  RemoteSession? session;
  final bool useStateEnvelope;
  final RemoteHttpTransport _transport;
  final Duration timeout;

  static const String _accessTokenHeader = 'x-carbonfeet-access-token';
  static const String _sessionTokenHeader = 'x-carbonfeet-session-token';
  static const String _sessionExpiryHeader = 'x-carbonfeet-session-expires-at';
  static const String _apiVersionHeader = 'x-carbonfeet-api-version';

  static RemoteSession? _initialSession(String? authToken) {
    final normalized = _normalizeAuthToken(authToken);
    if (normalized == null) {
      return null;
    }
    return RemoteSession(accessToken: normalized);
  }

  @override
  Future<PersistedAppState> load() async {
    final response = await _transport.send(
      method: 'GET',
      url: _stateUri,
      headers: _headers,
      timeout: timeout,
    );

    if (response.statusCode == 404) {
      return const PersistedAppState.empty();
    }
    if (_isUnauthorizedStatusCode(response.statusCode)) {
      session = null;
      throw const RemoteStateUnauthorized();
    }
    if (_isTransientStatusCode(response.statusCode)) {
      throw const RemoteStateUnavailable();
    }
    if (!_isSuccessStatusCode(response.statusCode)) {
      throw RemoteStateRequestFailed(
        statusCode: response.statusCode,
        message: 'Failed to load remote state.',
      );
    }
    if (response.body.trim().isEmpty) {
      return const PersistedAppState.empty();
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Expected JSON object.');
      }
      final payload = _asStringDynamicMap(decoded);
      _syncSessionFromResponse(response, payload: payload);

      final statePayload = payload.containsKey('state')
          ? _asStringDynamicMap(payload['state'])
          : payload;
      return PersistedAppState.fromJson(statePayload);
    } catch (_) {
      throw const RemoteStateUnavailable('Remote state payload is invalid.');
    }
  }

  @override
  Future<void> save(PersistedAppState state) async {
    final response = await _transport.send(
      method: 'PUT',
      url: _stateUri,
      headers: _headers,
      body: jsonEncode(_buildSavePayload(state)),
      timeout: timeout,
    );

    if (_isUnauthorizedStatusCode(response.statusCode)) {
      session = null;
      throw const RemoteStateUnauthorized();
    }
    if (_isTransientStatusCode(response.statusCode)) {
      throw const RemoteStateUnavailable();
    }
    if (!_isSuccessStatusCode(response.statusCode)) {
      throw RemoteStateRequestFailed(
        statusCode: response.statusCode,
        message: 'Failed to save remote state.',
      );
    }

    if (response.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          _syncSessionFromResponse(
            response,
            payload: _asStringDynamicMap(decoded),
          );
          return;
        }
      } catch (_) {
        // Ignore body parse failures for save responses.
      }
    }
    _syncSessionFromResponse(response);
  }

  Uri get _stateUri => _baseUri.resolve(_statePath);

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final authToken = _currentAccessToken;
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    final apiVersion = _apiVersion;
    if (apiVersion != null) {
      headers[_apiVersionHeader] = apiVersion;
    }
    return headers;
  }

  String? get _currentAccessToken {
    final current = session;
    if (current == null) {
      return null;
    }
    if (current.isExpired()) {
      session = null;
      return null;
    }
    return current.accessToken;
  }

  bool _isSuccessStatusCode(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  bool _isUnauthorizedStatusCode(int statusCode) =>
      statusCode == 401 || statusCode == 403;

  bool _isTransientStatusCode(int statusCode) =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;

  Object _buildSavePayload(PersistedAppState state) {
    if (useStateEnvelope) {
      return {'state': state.toJson()};
    }
    return state.toJson();
  }

  void _syncSessionFromResponse(
    RemoteHttpResponse response, {
    Map<String, dynamic>? payload,
  }) {
    if (payload != null && payload.containsKey('session')) {
      session = _sessionFromPayload(payload);
      return;
    }

    final headers = _lowercaseHeaders(response.headers);
    final accessToken =
        headers[_accessTokenHeader] ?? headers[_sessionTokenHeader];
    final normalizedAccessToken = _normalizeAuthToken(accessToken);
    if (normalizedAccessToken == null) {
      return;
    }
    session = RemoteSession(
      accessToken: normalizedAccessToken,
      refreshToken: session?.refreshToken,
      expiresAt: _parseExpiresAt(headers[_sessionExpiryHeader]),
    );
  }

  RemoteSession? _sessionFromPayload(Map<String, dynamic>? payload) {
    if (payload == null || !payload.containsKey('session')) {
      return null;
    }
    final rawSession = payload['session'];
    if (rawSession == null) {
      return null;
    }
    final sessionMap = _asStringDynamicMap(rawSession);
    if (sessionMap.isEmpty) {
      return null;
    }
    final accessToken = _normalizeAuthToken(
      _readString(sessionMap['accessToken']),
    );
    if (accessToken == null) {
      return null;
    }
    final refreshToken = _normalizeAuthToken(
      _readString(sessionMap['refreshToken']),
    );
    final expiresAt = _parseExpiresAt(sessionMap['expiresAt']);
    return RemoteSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  Map<String, String> _lowercaseHeaders(Map<String, String> headers) {
    if (headers.isEmpty) {
      return const {};
    }
    return {
      for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
    };
  }

  DateTime? _parseExpiresAt(Object? rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue is String) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  static String _normalizeStatePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return 'state';
    }
    return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  }

  static String? _normalizeAuthToken(String? authToken) {
    final normalized = authToken?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String? _normalizeApiVersion(String? apiVersion) {
    final normalized = apiVersion?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
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

class SimulatedRemoteStateClient
    implements RemoteStateClient, RemoteSessionAwareClient {
  SimulatedRemoteStateClient({
    PersistedAppState? initialState,
    this.networkDelay = const Duration(milliseconds: 320),
    this.failureRate = 0,
    math.Random? random,
  }) : _state = initialState ?? const PersistedAppState.empty(),
       _random = random ?? math.Random();

  PersistedAppState _state;
  @override
  RemoteSession? session;
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
    RemoteSessionStore remoteSessionStore = const NoopRemoteSessionStore(),
    RemoteRetryPolicy retryPolicy = const RemoteRetryPolicy(),
    Future<void> Function(Duration delay)? waitForDelay,
  }) : _remoteClient = remoteClient,
       _stateStore = stateStore ?? const AppStateStore(),
       _remoteSessionStore = remoteSessionStore,
       _retryPolicy = retryPolicy,
       _waitForDelay = waitForDelay ?? _defaultWaitForDelay;

  final RemoteStateClient _remoteClient;
  final AppStateStore _stateStore;
  final RemoteSessionStore _remoteSessionStore;
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
    await _restoreRemoteSession();

    try {
      final remote = await _withRemoteRetries(() => _remoteClient.load());
      _applyPersistedState(remote);
      _normalizeInMemoryState();
      await _persistLocalSafely();
      await _persistRemoteSession();
    } on RemoteStateUnauthorized {
      await _expireActiveSession();
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

    final commitStatus = await _commitStateSafely();
    switch (commitStatus) {
      case _RemoteCommitStatus.synced:
        return const AuthActionResult(status: AuthActionStatus.authenticated);
      case _RemoteCommitStatus.unauthorized:
        _restore(snapshot);
        await _expireActiveSession();
        return const AuthActionResult(status: AuthActionStatus.sessionExpired);
      case _RemoteCommitStatus.unavailable:
        _restore(snapshot);
        return const AuthActionResult(status: AuthActionStatus.unavailable);
    }
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

    final commitStatus = await _commitStateSafely();
    switch (commitStatus) {
      case _RemoteCommitStatus.synced:
        return const AuthActionResult(status: AuthActionStatus.authenticated);
      case _RemoteCommitStatus.unauthorized:
        _restore(snapshot);
        await _expireActiveSession();
        return const AuthActionResult(status: AuthActionStatus.sessionExpired);
      case _RemoteCommitStatus.unavailable:
        _restore(snapshot);
        return const AuthActionResult(status: AuthActionStatus.unavailable);
    }
  }

  @override
  void logout() {
    _activeEmail = null;
    _sessionAwareClient?.session = null;
    unawaited(_commitStateSafely());
    unawaited(_clearRemoteSessionStore());
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

    final commitStatus = await _commitStateSafely();
    switch (commitStatus) {
      case _RemoteCommitStatus.synced:
        return AddFlightResult(status: AddFlightStatus.added, entry: entry);
      case _RemoteCommitStatus.unauthorized:
        _restore(snapshot);
        await _expireActiveSession();
        return const AddFlightResult(status: AddFlightStatus.sessionExpired);
      case _RemoteCommitStatus.unavailable:
        _restore(snapshot);
        return const AddFlightResult(status: AddFlightStatus.unavailable);
    }
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

    final commitStatus = await _commitStateSafely();
    switch (commitStatus) {
      case _RemoteCommitStatus.synced:
        return const MutationResult(status: MutationStatus.updated);
      case _RemoteCommitStatus.unauthorized:
        _restore(snapshot);
        await _expireActiveSession();
        return const MutationResult(status: MutationStatus.sessionExpired);
      case _RemoteCommitStatus.unavailable:
        _restore(snapshot);
        return const MutationResult(status: MutationStatus.unavailable);
    }
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

  Future<_RemoteCommitStatus> _commitStateSafely() async {
    final next = _buildPersistedState();
    try {
      await _withRemoteRetries(() => _remoteClient.save(next));
      await _stateStore.save(next);
      await _persistRemoteSession();
      return _RemoteCommitStatus.synced;
    } on RemoteStateUnauthorized {
      return _RemoteCommitStatus.unauthorized;
    } catch (_) {
      return _RemoteCommitStatus.unavailable;
    }
  }

  Future<void> _expireActiveSession() async {
    _activeEmail = null;
    _sessionAwareClient?.session = null;
    await _persistLocalSafely();
    await _clearRemoteSessionStore();
  }

  RemoteSessionAwareClient? get _sessionAwareClient {
    final client = _remoteClient;
    if (client is RemoteSessionAwareClient) {
      return client as RemoteSessionAwareClient;
    }
    return null;
  }

  Future<void> _restoreRemoteSession() async {
    final client = _sessionAwareClient;
    if (client == null) {
      return;
    }

    final restored = await _remoteSessionStore.load();
    if (restored == null || restored.isExpired()) {
      client.session = null;
      await _clearRemoteSessionStore();
      return;
    }
    client.session = restored;
  }

  Future<void> _persistRemoteSession() async {
    final client = _sessionAwareClient;
    if (client == null) {
      return;
    }

    final current = client.session;
    if (current == null || current.isExpired()) {
      client.session = null;
      await _clearRemoteSessionStore();
      return;
    }
    await _remoteSessionStore.save(current);
  }

  Future<void> _clearRemoteSessionStore() async {
    await _remoteSessionStore.save(null);
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

enum _RemoteCommitStatus { synced, unauthorized, unavailable }
