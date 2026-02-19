import 'dart:async';
import 'dart:convert';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const CarbonFeetShell(),
    );
  }
}

class CarbonFeetShell extends StatefulWidget {
  const CarbonFeetShell({super.key});

  @override
  State<CarbonFeetShell> createState() => _CarbonFeetShellState();
}

class _CarbonFeetShellState extends State<CarbonFeetShell> {
  final AppRepository _repository = LocalAppRepository();

  bool _isHydrating = true;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isHydrating) {
      return const _LoadingStateScreen();
    }

    final activeEmail = _repository.activeEmail;
    if (activeEmail == null) {
      return AuthScreen(onSubmit: _handleAuth);
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
      return AuthScreen(onSubmit: _handleAuth);
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

  String? _handleAuth(String email, String password, AuthMode mode) {
    final normalizedEmail = email.trim().toLowerCase();
    final emailError = InputValidation.validateEmail(normalizedEmail);
    if (emailError != null) {
      return emailError;
    }

    if (mode == AuthMode.login) {
      if (password.isEmpty) {
        return 'Enter your password.';
      }
      final loggedIn = _repository.login(normalizedEmail, password);
      if (!loggedIn) {
        return 'Incorrect email or password.';
      }
      setState(() {});
      return null;
    }

    final passwordError = InputValidation.validatePassword(password);
    if (passwordError != null) {
      return passwordError;
    }

    final registered = _repository.register(normalizedEmail, password);
    if (!registered) {
      return 'An account for this email already exists.';
    }

    setState(() {});
    return null;
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

    final result = _repository.addFlight(draft);
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

    final didUpdate = _repository.updateCarProfile(updated);
    if (!didUpdate) {
      _repository.logout();
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

    final didUpdate = _repository.updateDietProfile(updated);
    if (!didUpdate) {
      _repository.logout();
    }
    setState(() {});
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

    final didUpdate = _repository.updateEnergyProfile(updated);
    if (!didUpdate) {
      _repository.logout();
    }
    setState(() {});
  }

  void _updateActiveUser(UserData next) {
    _repository.updateActiveUser(next);
    setState(() {});
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
