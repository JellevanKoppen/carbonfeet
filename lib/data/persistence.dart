part of 'package:carbonfeet/main.dart';

class PersistedAppState {
  const PersistedAppState({
    required this.credentials,
    required this.users,
    required this.activeEmail,
    this.schemaVersion = currentSchemaVersion,
  });

  const PersistedAppState.empty()
    : credentials = const {},
      users = const {},
      activeEmail = null,
      schemaVersion = currentSchemaVersion;

  static const int currentSchemaVersion = 1;

  final Map<String, String> credentials;
  final Map<String, UserData> users;
  final String? activeEmail;
  final int schemaVersion;

  factory PersistedAppState.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _readInt(json['schemaVersion']);
    final normalizedJson = switch (schemaVersion) {
      0 => _migrateLegacySchema(json),
      _ => json,
    };

    final credentials = <String, String>{};
    for (final entry in _asStringDynamicMap(
      normalizedJson['credentials'],
    ).entries) {
      if (entry.value is String) {
        credentials[entry.key] = entry.value as String;
      }
    }

    final users = <String, UserData>{};
    for (final entry in _asStringDynamicMap(normalizedJson['users']).entries) {
      final rawUser = _asStringDynamicMap(entry.value);
      if (rawUser.isEmpty) {
        continue;
      }
      final parsed = UserData.fromJson(rawUser);
      users[entry.key] = parsed.email.isEmpty
          ? parsed.copyWith(email: entry.key)
          : parsed;
    }

    final activeEmailRaw = normalizedJson['activeEmail'];
    return PersistedAppState(
      credentials: credentials,
      users: users,
      activeEmail: activeEmailRaw is String && activeEmailRaw.isNotEmpty
          ? activeEmailRaw
          : null,
      schemaVersion: currentSchemaVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'credentials': credentials,
      'users': {
        for (final entry in users.entries) entry.key: entry.value.toJson(),
      },
      'activeEmail': activeEmail,
    };
  }

  static Map<String, dynamic> _migrateLegacySchema(
    Map<String, dynamic> legacy,
  ) {
    return {
      'credentials': _asStringDynamicMap(legacy['credentials']),
      'users': _asStringDynamicMap(legacy['users']),
      'activeEmail': legacy['activeEmail'],
      'schemaVersion': currentSchemaVersion,
    };
  }
}

class AppStateStore {
  const AppStateStore();

  static const String _storageKey = 'carbonfeet_state_v1';

  Future<PersistedAppState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return const PersistedAppState.empty();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const PersistedAppState.empty();
      }
      return PersistedAppState.fromJson(_asStringDynamicMap(decoded));
    } catch (_) {
      return const PersistedAppState.empty();
    }
  }

  Future<void> save(PersistedAppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}

Map<String, dynamic> _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  return fallback;
}

double _readDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool _readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

DateTime _readDateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

T _enumFromName<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is String) {
    for (final entry in values) {
      if (entry.name == value) {
        return entry;
      }
    }
  }
  return fallback;
}
