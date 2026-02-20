import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:carbonfeet/main.dart';

class _RecordingTransport implements RemoteHttpTransport {
  _RecordingTransport({required this.handler});

  final Future<RemoteHttpResponse> Function({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  })
  handler;

  int callCount = 0;
  String? lastMethod;
  Uri? lastUrl;
  Map<String, String> lastHeaders = const {};
  String? lastBody;
  Duration? lastTimeout;

  @override
  Future<RemoteHttpResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    callCount += 1;
    lastMethod = method;
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;
    lastTimeout = timeout;
    return handler(
      method: method,
      url: url,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }
}

void main() {
  test('createDefaultRepository falls back to local repository by default', () {
    final repository = createDefaultRepository();

    expect(repository, isA<LocalAppRepository>());
  });

  test('http remote client loads persisted state from GET endpoint', () async {
    final expected = PersistedAppState(
      credentials: const {'remote@example.com': 'secure123'},
      users: {
        'remote@example.com': UserData.empty(
          email: 'remote@example.com',
        ).copyWith(onboardingComplete: true),
      },
      activeEmail: 'remote@example.com',
    );
    final transport = _RecordingTransport(
      handler:
          ({
            required method,
            required url,
            required headers,
            body,
            required timeout,
          }) async {
            return RemoteHttpResponse(
              statusCode: 200,
              body: jsonEncode(expected.toJson()),
            );
          },
    );
    final client = HttpRemoteStateClient(
      baseUrl: 'https://api.example.com/v1/',
      statePath: 'state',
      transport: transport,
      timeout: const Duration(seconds: 3),
    );

    final loaded = await client.load();

    expect(transport.callCount, equals(1));
    expect(transport.lastMethod, equals('GET'));
    expect(
      transport.lastUrl,
      equals(Uri.parse('https://api.example.com/v1/state')),
    );
    expect(transport.lastHeaders['Accept'], equals('application/json'));
    expect(transport.lastHeaders['Content-Type'], equals('application/json'));
    expect(transport.lastHeaders.containsKey('Authorization'), isFalse);
    expect(transport.lastTimeout, equals(const Duration(seconds: 3)));
    expect(loaded.activeEmail, equals('remote@example.com'));
    expect(loaded.users['remote@example.com']!.onboardingComplete, isTrue);
  });

  test('http remote client treats 404 load response as empty state', () async {
    final transport = _RecordingTransport(
      handler:
          ({
            required method,
            required url,
            required headers,
            body,
            required timeout,
          }) async {
            return const RemoteHttpResponse(statusCode: 404, body: '');
          },
    );
    final client = HttpRemoteStateClient(
      baseUrl: 'https://api.example.com/',
      transport: transport,
    );

    final loaded = await client.load();

    expect(loaded.activeEmail, isNull);
    expect(loaded.credentials, isEmpty);
    expect(loaded.users, isEmpty);
  });

  test(
    'http remote client maps transient load status to unavailable',
    () async {
      final transport = _RecordingTransport(
        handler:
            ({
              required method,
              required url,
              required headers,
              body,
              required timeout,
            }) async {
              return const RemoteHttpResponse(statusCode: 503, body: '');
            },
      );
      final client = HttpRemoteStateClient(
        baseUrl: 'https://api.example.com/',
        transport: transport,
      );

      expect(client.load(), throwsA(isA<RemoteStateUnavailable>()));
    },
  );

  test('http remote client maps unauthorized load status to unauthorized', () {
    final transport = _RecordingTransport(
      handler:
          ({
            required method,
            required url,
            required headers,
            body,
            required timeout,
          }) async {
            return const RemoteHttpResponse(statusCode: 401, body: '');
          },
    );
    final client = HttpRemoteStateClient(
      baseUrl: 'https://api.example.com/',
      transport: transport,
    );

    expect(client.load(), throwsA(isA<RemoteStateUnauthorized>()));
  });

  test(
    'http remote client save sends PUT with auth token and payload',
    () async {
      final transport = _RecordingTransport(
        handler:
            ({
              required method,
              required url,
              required headers,
              body,
              required timeout,
            }) async {
              return const RemoteHttpResponse(statusCode: 204, body: '');
            },
      );
      final client = HttpRemoteStateClient(
        baseUrl: 'https://api.example.com/',
        statePath: '/state',
        authToken: 'token-123',
        transport: transport,
      );
      const state = PersistedAppState(
        credentials: {'save@example.com': 'secure123'},
        users: {},
        activeEmail: 'save@example.com',
      );

      await client.save(state);

      expect(transport.lastMethod, equals('PUT'));
      expect(
        transport.lastUrl,
        equals(Uri.parse('https://api.example.com/state')),
      );
      expect(
        transport.lastHeaders['Authorization'],
        equals('Bearer token-123'),
      );

      final decoded = jsonDecode(transport.lastBody!) as Map<String, dynamic>;
      expect(decoded['activeEmail'], equals('save@example.com'));
    },
  );

  test(
    'http remote client load supports envelope and rotates session token',
    () async {
      final authHeaders = <String?>[];
      final transport = _RecordingTransport(
        handler:
            ({
              required method,
              required url,
              required headers,
              body,
              required timeout,
            }) async {
              authHeaders.add(headers['Authorization']);

              if (method == 'GET') {
                return RemoteHttpResponse(
                  statusCode: 200,
                  body: jsonEncode({
                    'state': const PersistedAppState(
                      credentials: {'envelope@example.com': 'secure123'},
                      users: {},
                      activeEmail: 'envelope@example.com',
                    ).toJson(),
                    'session': {
                      'accessToken': 'rotated-token-456',
                      'expiresAt': '2035-01-01T00:00:00Z',
                    },
                  }),
                );
              }

              return const RemoteHttpResponse(statusCode: 204, body: '');
            },
      );
      final client = HttpRemoteStateClient(
        baseUrl: 'https://api.example.com/',
        authToken: 'initial-token-123',
        transport: transport,
      );

      final loaded = await client.load();
      await client.save(const PersistedAppState.empty());

      expect(loaded.activeEmail, equals('envelope@example.com'));
      expect(
        authHeaders,
        equals(['Bearer initial-token-123', 'Bearer rotated-token-456']),
      );
      expect(client.session?.accessToken, equals('rotated-token-456'));
    },
  );

  test(
    'http remote client save supports envelope payload and api version header',
    () async {
      final transport = _RecordingTransport(
        handler:
            ({
              required method,
              required url,
              required headers,
              body,
              required timeout,
            }) async {
              return const RemoteHttpResponse(
                statusCode: 200,
                body: '',
                headers: {'x-carbonfeet-access-token': 'next-token-789'},
              );
            },
      );
      final client = HttpRemoteStateClient(
        baseUrl: 'https://api.example.com/',
        apiVersion: '2026-02',
        useStateEnvelope: true,
        transport: transport,
      );

      await client.save(
        const PersistedAppState(
          credentials: {'save-envelope@example.com': 'secure123'},
          users: {},
          activeEmail: 'save-envelope@example.com',
        ),
      );

      expect(
        transport.lastHeaders['x-carbonfeet-api-version'],
        equals('2026-02'),
      );
      final decoded = jsonDecode(transport.lastBody!) as Map<String, dynamic>;
      expect(decoded.containsKey('state'), isTrue);
      expect(
        (decoded['state'] as Map<String, dynamic>)['activeEmail'],
        equals('save-envelope@example.com'),
      );
      expect(client.session?.accessToken, equals('next-token-789'));
    },
  );

  test('http remote client save maps unauthorized to session error', () async {
    final transport = _RecordingTransport(
      handler:
          ({
            required method,
            required url,
            required headers,
            body,
            required timeout,
          }) async {
            return const RemoteHttpResponse(statusCode: 403, body: '');
          },
    );
    final client = HttpRemoteStateClient(
      baseUrl: 'https://api.example.com/',
      transport: transport,
    );

    expect(
      client.save(const PersistedAppState.empty()),
      throwsA(isA<RemoteStateUnauthorized>()),
    );
  });

  test('http remote client save maps non-auth 4xx to request failed', () async {
    final transport = _RecordingTransport(
      handler:
          ({
            required method,
            required url,
            required headers,
            body,
            required timeout,
          }) async {
            return const RemoteHttpResponse(statusCode: 422, body: '');
          },
    );
    final client = HttpRemoteStateClient(
      baseUrl: 'https://api.example.com/',
      transport: transport,
    );

    expect(
      client.save(const PersistedAppState.empty()),
      throwsA(
        isA<RemoteStateRequestFailed>().having(
          (error) => error.statusCode,
          'statusCode',
          422,
        ),
      ),
    );
  });
}
