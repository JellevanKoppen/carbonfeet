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

    final beforeProjection = _metricValueForLabel(tester, 'End-of-year projection');

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
