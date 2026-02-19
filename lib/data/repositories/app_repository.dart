part of 'package:carbonfeet/main.dart';

abstract interface class AppRepository {
  Future<void> hydrate();

  String? get activeEmail;
  UserData? get activeUser;

  bool register(String email, String password);
  bool login(String email, String password);

  void logout();
  void updateActiveUser(UserData next);
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
