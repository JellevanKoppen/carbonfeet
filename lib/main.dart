import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'data/persistence.dart';
part 'data/repositories/app_repository.dart';
part 'domain/emission_calculator.dart';
part 'domain/input_validation.dart';
part 'domain/models.dart';
part 'domain/reference_data.dart';
part 'features/auth/auth_screen.dart';
part 'features/charts/charts.dart';
part 'features/dashboard/dashboard_screen.dart';
part 'features/onboarding/onboarding_screen.dart';
part 'features/posts/post_dialogs.dart';
part 'shared/formatting.dart';

const bool _useRemoteRepository = bool.fromEnvironment(
  'CARBONFEET_USE_REMOTE_STATE',
  defaultValue: false,
);
const String _remoteStateBaseUrl = String.fromEnvironment(
  'CARBONFEET_REMOTE_BASE_URL',
  defaultValue: '',
);
const String _remoteStatePath = String.fromEnvironment(
  'CARBONFEET_REMOTE_STATE_PATH',
  defaultValue: 'state',
);
const String _remoteStateToken = String.fromEnvironment(
  'CARBONFEET_REMOTE_STATE_TOKEN',
  defaultValue: '',
);

AppRepository createDefaultRepository() {
  if (!_useRemoteRepository) {
    return LocalAppRepository();
  }

  final baseUrl = _remoteStateBaseUrl.trim();
  if (baseUrl.isEmpty) {
    return LocalAppRepository();
  }

  try {
    final remoteClient = HttpRemoteStateClient(
      baseUrl: baseUrl,
      statePath: _remoteStatePath,
      authToken: _remoteStateToken,
    );
    return RemoteAppRepository(remoteClient: remoteClient);
  } on FormatException {
    return LocalAppRepository();
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({this.repository, super.key});

  final AppRepository? repository;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2D6A4F);
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      useMaterial3: true,
      fontFamily: 'Palatino',
    );

    return MaterialApp(
      title: 'CarbonFeet',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF2F7F3),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          color: Colors.white,
        ),
      ),
      home: CarbonFeetShell(repository: repository),
    );
  }
}

class CarbonFeetShell extends StatefulWidget {
  const CarbonFeetShell({this.repository, super.key});

  final AppRepository? repository;

  @override
  State<CarbonFeetShell> createState() => _CarbonFeetShellState();
}

class _CarbonFeetShellState extends State<CarbonFeetShell> {
  late final AppRepository _repository;

  bool _isHydrating = true;
  bool _isAuthSubmitting = false;
  bool _isPostSubmissionInProgress = false;
  String? _authNotice;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? createDefaultRepository();
    _restoreState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isHydrating) {
      return const _LoadingStateScreen();
    }

    final activeEmail = _repository.activeEmail;
    if (activeEmail == null) {
      return AuthScreen(
        onSubmit: _handleAuth,
        isSubmitting: _isAuthSubmitting,
        noticeMessage: _authNotice,
      );
    }

    final activeUser = _repository.activeUser;
    if (activeUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _repository.logout();
        setState(() {});
      });
      return AuthScreen(
        onSubmit: _handleAuth,
        isSubmitting: _isAuthSubmitting,
        noticeMessage: _authNotice,
      );
    }

    if (!activeUser.onboardingComplete) {
      return OnboardingScreen(
        draftUser: activeUser,
        onComplete: (completedUser) {
          _updateActiveUser(completedUser);
        },
      );
    }

    final summary = EmissionCalculator.summarize(activeUser);

    return DashboardScreen(
      user: activeUser,
      summary: summary,
      isPostSubmissionInProgress: _isPostSubmissionInProgress,
      onOpenPostMenu: () => _openPostMenu(activeUser),
      onOpenSimulator: () => _openSimulator(activeUser),
      onLogout: () {
        _repository.logout();
        setState(() {});
      },
    );
  }

  Future<void> _restoreState() async {
    await _repository.hydrate();
    if (!mounted) {
      return;
    }

    setState(() {
      _isHydrating = false;
    });
  }

  Future<String?> _handleAuth(
    String email,
    String password,
    AuthMode mode,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    final emailError = InputValidation.validateEmail(normalizedEmail);
    if (emailError != null) {
      return emailError;
    }

    setState(() {
      _isAuthSubmitting = true;
    });

    if (mode == AuthMode.login) {
      if (password.isEmpty) {
        setState(() {
          _isAuthSubmitting = false;
        });
        return 'Enter your password.';
      }

      final result = await _repository.login(normalizedEmail, password);
      if (!mounted) {
        return null;
      }

      setState(() {
        _isAuthSubmitting = false;
      });

      switch (result.status) {
        case AuthActionStatus.authenticated:
          setState(() {
            _authNotice = null;
          });
          return null;
        case AuthActionStatus.invalidCredentials:
          return 'Incorrect email or password.';
        case AuthActionStatus.sessionExpired:
          return 'Session expired. Please sign in again.';
        case AuthActionStatus.unavailable:
          return 'Login is temporarily unavailable. Please try again.';
        case AuthActionStatus.emailAlreadyExists:
          return 'Incorrect email or password.';
      }
    }

    final passwordError = InputValidation.validatePassword(password);
    if (passwordError != null) {
      setState(() {
        _isAuthSubmitting = false;
      });
      return passwordError;
    }

    final result = await _repository.register(normalizedEmail, password);
    if (!mounted) {
      return null;
    }

    setState(() {
      _isAuthSubmitting = false;
    });

    switch (result.status) {
      case AuthActionStatus.authenticated:
        setState(() {
          _authNotice = null;
        });
        return null;
      case AuthActionStatus.emailAlreadyExists:
        return 'An account for this email already exists.';
      case AuthActionStatus.sessionExpired:
        return 'Session expired. Please sign in again.';
      case AuthActionStatus.unavailable:
        return 'Account creation is temporarily unavailable. Please try again.';
      case AuthActionStatus.invalidCredentials:
        return 'An account for this email already exists.';
    }
  }

  Future<void> _openPostMenu(UserData user) async {
    final selected = await showModalBottomSheet<PostType>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Add or update CO2 post',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: const Text('Flight'),
                onTap: () => Navigator.of(context).pop(PostType.flight),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('Car usage'),
                onTap: () => Navigator.of(context).pop(PostType.car),
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('Diet profile'),
                onTap: () => Navigator.of(context).pop(PostType.diet),
              ),
              ListTile(
                leading: const Icon(Icons.bolt),
                title: const Text('Home energy'),
                onTap: () => Navigator.of(context).pop(PostType.energy),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case PostType.flight:
        await _openFlightDialog();
      case PostType.car:
        await _openCarDialog(user);
      case PostType.diet:
        await _openDietDialog(user);
      case PostType.energy:
        await _openEnergyDialog(user);
    }
  }

  Future<void> _openFlightDialog() async {
    final draft = await showDialog<FlightDraft>(
      context: context,
      builder: (context) => const AddFlightDialog(),
    );

    if (!mounted || draft == null) {
      return;
    }

    await _submitFlightDraft(draft);
  }

  Future<void> _submitFlightDraft(FlightDraft draft) async {
    final result = await _runPostMutation(() => _repository.addFlight(draft));
    if (!mounted || result == null) {
      return;
    }

    switch (result.status) {
      case AddFlightStatus.unknownFlight:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Flight not found. MVP only accepts known flight numbers.',
            ),
          ),
        );
      case AddFlightStatus.duplicateForDate:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This flight is already logged for that date.'),
          ),
        );
      case AddFlightStatus.noActiveUser:
        _repository.logout();
        setState(() {});
      case AddFlightStatus.sessionExpired:
        _expireSessionAndPromptReauth();
      case AddFlightStatus.added:
        final entry = result.entry;
        if (entry == null) {
          return;
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${entry.flightNumber} added (${_formatNumber(entry.emissionsKg)} kg CO2e).',
            ),
          ),
        );
      case AddFlightStatus.unavailable:
        _showPostRetrySnackBar(
          message: 'Could not save flight right now. Please try again.',
          onRetry: () => _submitFlightDraft(draft),
        );
    }
  }

  Future<void> _openCarDialog(UserData user) async {
    final updated = await showDialog<CarProfile>(
      context: context,
      builder: (context) => EditCarDialog(initial: user.carProfile),
    );

    if (!mounted || updated == null) {
      return;
    }

    await _submitCarProfile(updated);
  }

  Future<void> _submitCarProfile(CarProfile profile) async {
    await _submitProfileMutation(
      mutation: () => _repository.updateCarProfile(profile),
      unavailableMessage:
          'Could not update car profile right now. Please try again.',
      onRetry: () => _submitCarProfile(profile),
    );
  }

  Future<void> _submitDietProfile(DietProfile profile) async {
    await _submitProfileMutation(
      mutation: () => _repository.updateDietProfile(profile),
      unavailableMessage:
          'Could not update diet profile right now. Please try again.',
      onRetry: () => _submitDietProfile(profile),
    );
  }

  Future<void> _submitEnergyProfile(EnergyProfile profile) async {
    await _submitProfileMutation(
      mutation: () => _repository.updateEnergyProfile(profile),
      unavailableMessage:
          'Could not update home energy right now. Please try again.',
      onRetry: () => _submitEnergyProfile(profile),
    );
  }

  Future<void> _submitProfileMutation({
    required Future<MutationResult> Function() mutation,
    required String unavailableMessage,
    required Future<void> Function() onRetry,
  }) async {
    final result = await _runPostMutation(mutation);
    if (!mounted || result == null) {
      return;
    }

    if (result.status == MutationStatus.noActiveUser) {
      _repository.logout();
      setState(() {});
      return;
    }
    if (result.status == MutationStatus.sessionExpired) {
      _expireSessionAndPromptReauth();
      return;
    }
    if (result.status == MutationStatus.unavailable) {
      _showPostRetrySnackBar(message: unavailableMessage, onRetry: onRetry);
      return;
    }

    setState(() {});
  }

  Future<void> _openDietDialog(UserData user) async {
    final updated = await showDialog<DietProfile>(
      context: context,
      builder: (context) => EditDietDialog(initial: user.dietProfile),
    );

    if (!mounted || updated == null) {
      return;
    }

    await _submitDietProfile(updated);
  }

  Future<void> _openEnergyDialog(UserData user) async {
    final updated = await showDialog<EnergyProfile>(
      context: context,
      builder: (context) =>
          EditEnergyDialog(initial: user.energyProfile, country: user.country),
    );

    if (!mounted || updated == null) {
      return;
    }

    await _submitEnergyProfile(updated);
  }

  void _showPostRetrySnackBar({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            unawaited(onRetry());
          },
        ),
      ),
    );
  }

  void _updateActiveUser(UserData next) {
    _repository.updateActiveUser(next);
    setState(() {});
  }

  void _expireSessionAndPromptReauth() {
    _repository.logout();
    setState(() {
      _authNotice = 'Session expired. Please log in again to continue.';
    });
  }

  Future<T?> _runPostMutation<T>(Future<T> Function() operation) async {
    if (_isPostSubmissionInProgress) {
      return null;
    }

    setState(() {
      _isPostSubmissionInProgress = true;
    });

    try {
      return await operation();
    } finally {
      if (mounted) {
        setState(() {
          _isPostSubmissionInProgress = false;
        });
      }
    }
  }

  Future<void> _openSimulator(UserData user) async {
    final currentSummary = EmissionCalculator.summarize(user);
    final scenarios = EmissionCalculator.simulateScenarios(user);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What if simulator',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current projection: ${_formatNumber(currentSummary.projectedEndYearKg)} kg CO2e',
                ),
                const SizedBox(height: 16),
                for (final scenario in scenarios)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scenario.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(scenario.description),
                                const SizedBox(height: 6),
                                Text(
                                  'New projection: ${_formatNumber(scenario.projectedKg)} kg',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _deltaLabel(
                              scenario.projectedKg -
                                  currentSummary.projectedEndYearKg,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  scenario.projectedKg <=
                                      currentSummary.projectedEndYearKg
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingStateScreen extends StatelessWidget {
  const _LoadingStateScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading your footprint data...'),
          ],
        ),
      ),
    );
  }
}
