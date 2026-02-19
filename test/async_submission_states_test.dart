import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carbonfeet/main.dart';

class _InMemoryStateStore extends AppStateStore {
  _InMemoryStateStore();

  PersistedAppState state = const PersistedAppState.empty();

  @override
  Future<PersistedAppState> load() async => state;

  @override
  Future<void> save(PersistedAppState next) async {
    state = next;
  }
}

class _FailingSaveStateStore extends AppStateStore {
  _FailingSaveStateStore({required this.state, required this.saveDelay});

  PersistedAppState state;
  final Duration saveDelay;

  @override
  Future<PersistedAppState> load() async => state;

  @override
  Future<void> save(PersistedAppState next) async {
    await Future<void>.delayed(saveDelay);
    throw Exception('save failed');
  }
}

class _FlakySaveStateStore extends AppStateStore {
  _FlakySaveStateStore({
    required this.state,
    required this.saveDelay,
    required this.remainingFailures,
  });

  PersistedAppState state;
  final Duration saveDelay;
  int remainingFailures;

  @override
  Future<PersistedAppState> load() async => state;

  @override
  Future<void> save(PersistedAppState next) async {
    await Future<void>.delayed(saveDelay);
    if (remainingFailures > 0) {
      remainingFailures -= 1;
      throw Exception('transient save failed');
    }
    state = next;
  }
}

class _DelayedAuthRepository extends LocalAppRepository {
  _DelayedAuthRepository({required this.delay, required super.stateStore});

  final Duration delay;

  @override
  Future<AuthActionResult> register(String email, String password) async {
    await Future<void>.delayed(delay);
    return super.register(email, password);
  }

  @override
  Future<AuthActionResult> login(String email, String password) async {
    await Future<void>.delayed(delay);
    return super.login(email, password);
  }
}

class _UnauthorizedSaveRemoteClient implements RemoteStateClient {
  _UnauthorizedSaveRemoteClient({required this.state});

  PersistedAppState state;

  @override
  Future<PersistedAppState> load() async => state;

  @override
  Future<void> save(PersistedAppState next) async {
    throw const RemoteStateUnauthorized();
  }
}

void main() {
  testWidgets('auth shows submitting feedback during async account creation', (
    WidgetTester tester,
  ) async {
    final repository = _DelayedAuthRepository(
      delay: const Duration(milliseconds: 250),
      stateStore: _InMemoryStateStore(),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'newuser@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secure123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Submitting...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create account'),
          )
          .onPressed,
      isNull,
    );

    await tester.pumpAndSettle();
    expect(find.text('Build your baseline projection'), findsOneWidget);
  });

  testWidgets('post submission failure shows error and keeps dashboard data', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-failure@example.com',
    ).copyWith(onboardingComplete: true);
    final state = PersistedAppState(
      credentials: const {'post-failure@example.com': 'secure123'},
      users: {'post-failure@example.com': user},
      activeEmail: 'post-failure@example.com',
    );
    final repository = LocalAppRepository(
      stateStore: _FailingSaveStateStore(
        state: state,
        saveDelay: const Duration(milliseconds: 220),
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    final beforeProjection = _metricValueForLabel(
      tester,
      'End-of-year projection',
    );

    await _openPostDialog(tester, 'Car usage');
    await tester.enterText(find.byType(TextField).first, '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 40));

    final submittingIndicator = find.byWidgetPredicate(
      (widget) => widget is LinearProgressIndicator && widget.value == null,
    );
    expect(submittingIndicator, findsOneWidget);

    await tester.pumpAndSettle();

    expect(
      find.text('Could not update car profile right now. Please try again.'),
      findsOneWidget,
    );
    expect(
      _metricValueForLabel(tester, 'End-of-year projection'),
      equals(beforeProjection),
    );
  });

  testWidgets('post submission retry action succeeds after transient failure', (
    WidgetTester tester,
  ) async {
    final user = UserData.empty(
      email: 'post-retry@example.com',
    ).copyWith(onboardingComplete: true);
    const updatedCar = CarProfile(
      vehicleKey: 'toyota_corolla',
      distanceMode: DistanceMode.perYear,
      distanceValue: 8000,
    );
    final expectedProjection = _asKgCo2e(
      EmissionCalculator.summarize(
        user.copyWith(carProfile: updatedCar),
      ).projectedEndYearKg,
    );
    final state = PersistedAppState(
      credentials: const {'post-retry@example.com': 'secure123'},
      users: {'post-retry@example.com': user},
      activeEmail: 'post-retry@example.com',
    );
    final repository = LocalAppRepository(
      stateStore: _FlakySaveStateStore(
        state: state,
        saveDelay: const Duration(milliseconds: 160),
        remainingFailures: 1,
      ),
    );

    await tester.pumpWidget(MyApp(repository: repository));
    await tester.pumpAndSettle();

    final beforeProjection = _metricValueForLabel(
      tester,
      'End-of-year projection',
    );

    await _openPostDialog(tester, 'Car usage');
    await tester.enterText(find.byType(TextField).first, '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update car profile right now. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(
      _metricValueForLabel(tester, 'End-of-year projection'),
      equals(beforeProjection),
    );

    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 30));

    final submittingIndicator = find.byWidgetPredicate(
      (widget) => widget is LinearProgressIndicator && widget.value == null,
    );
    expect(submittingIndicator, findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      _metricValueForLabel(tester, 'End-of-year projection'),
      equals(expectedProjection),
    );
  });

  testWidgets(
    'session expiration during post submission forces re-auth prompt',
    (WidgetTester tester) async {
      final user = UserData.empty(
        email: 'post-session-expired@example.com',
      ).copyWith(onboardingComplete: true);
      final state = PersistedAppState(
        credentials: const {'post-session-expired@example.com': 'secure123'},
        users: {'post-session-expired@example.com': user},
        activeEmail: 'post-session-expired@example.com',
      );
      final stateStore = _InMemoryStateStore()..state = state;
      final repository = RemoteAppRepository(
        remoteClient: _UnauthorizedSaveRemoteClient(state: state),
        stateStore: stateStore,
        retryPolicy: const RemoteRetryPolicy(
          retryDelays: [Duration.zero, Duration.zero],
        ),
      );

      await tester.pumpWidget(MyApp(repository: repository));
      await tester.pumpAndSettle();

      await _openPostDialog(tester, 'Car usage');
      await tester.enterText(find.byType(TextField).first, '8000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Session expired. Please log in again to continue.'),
        findsOneWidget,
      );
      expect(
        find.text('Track your footprint. Improve with clarity.'),
        findsOneWidget,
      );
    },
  );
}

Future<void> _openPostDialog(WidgetTester tester, String typeLabel) async {
  await tester.tap(find.text('Add CO2 post'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(typeLabel).last);
  await tester.pumpAndSettle();
}

String _metricValueForLabel(WidgetTester tester, String label) {
  final columnAncestors = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .evaluate()
      .toList();

  for (final ancestor in columnAncestors) {
    final textFinder = find.descendant(
      of: find.byElementPredicate((element) => element == ancestor),
      matching: find.byType(Text),
    );
    final textValues = textFinder
        .evaluate()
        .map((element) => element.widget as Text)
        .map((textWidget) => textWidget.data)
        .whereType<String>()
        .toList();

    if (textValues.length == 2 &&
        textValues.first == label &&
        textValues.last.endsWith('kg CO2e')) {
      return textValues.last;
    }
  }

  fail('Could not find metric value for label "$label".');
}

String _asKgCo2e(double value) => '${value.toStringAsFixed(0)} kg CO2e';
