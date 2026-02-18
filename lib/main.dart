import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<String, String> _credentials = <String, String>{};
  final Map<String, UserData> _users = <String, UserData>{};

  String? _activeEmail;
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

    final email = _activeEmail;
    if (email == null) {
      return AuthScreen(onSubmit: _handleAuth);
    }

    final activeUser = _users[email];
    if (activeUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _activeEmail = null;
        });
        _persistState();
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
        setState(() {
          _activeEmail = null;
        });
        _persistState();
      },
    );
  }

  Future<void> _restoreState() async {
    final restored = await AppStateStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _credentials
        ..clear()
        ..addAll(restored.credentials);
      _users
        ..clear()
        ..addAll(restored.users);
      _activeEmail = restored.activeEmail;
      _isHydrating = false;
    });
  }

  String? _handleAuth(String email, String password, AuthMode mode) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (mode == AuthMode.register) {
      if (_credentials.containsKey(normalizedEmail)) {
        return 'An account for this email already exists.';
      }

      final draft = UserData.empty(email: normalizedEmail);
      setState(() {
        _credentials[normalizedEmail] = password;
        _users[normalizedEmail] = draft;
        _activeEmail = normalizedEmail;
      });
      _persistState();
      return null;
    }

    final storedPassword = _credentials[normalizedEmail];
    if (storedPassword == null || storedPassword != password) {
      return 'Incorrect email or password.';
    }

    setState(() {
      _activeEmail = normalizedEmail;
    });
    _persistState();

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
        await _openFlightDialog(user);
      case PostType.car:
        await _openCarDialog(user);
      case PostType.diet:
        await _openDietDialog(user);
      case PostType.energy:
        await _openEnergyDialog(user);
    }
  }

  Future<void> _openFlightDialog(UserData user) async {
    final draft = await showDialog<FlightDraft>(
      context: context,
      builder: (context) => const AddFlightDialog(),
    );

    if (!mounted || draft == null) {
      return;
    }

    final entry = EmissionCalculator.buildFlightEntry(draft);
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Flight not found. MVP only accepts known flight numbers.',
          ),
        ),
      );
      return;
    }

    _updateActiveUser(
      user.copyWith(
        flights: [...user.flights, entry],
        activityLog: [...user.activityLog, ActivityEvent.atNow('flight')],
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${entry.flightNumber} added (${_formatNumber(entry.emissionsKg)} kg CO2e).',
        ),
      ),
    );
  }

  Future<void> _openCarDialog(UserData user) async {
    final updated = await showDialog<CarProfile>(
      context: context,
      builder: (context) => EditCarDialog(initial: user.carProfile),
    );

    if (updated == null) {
      return;
    }

    _updateActiveUser(
      user.copyWith(
        carProfile: updated,
        activityLog: [...user.activityLog, ActivityEvent.atNow('car_update')],
      ),
    );
  }

  Future<void> _openDietDialog(UserData user) async {
    final updated = await showDialog<DietProfile>(
      context: context,
      builder: (context) => EditDietDialog(initial: user.dietProfile),
    );

    if (updated == null) {
      return;
    }

    _updateActiveUser(
      user.copyWith(
        dietProfile: updated,
        activityLog: [...user.activityLog, ActivityEvent.atNow('diet_update')],
      ),
    );
  }

  Future<void> _openEnergyDialog(UserData user) async {
    final updated = await showDialog<EnergyProfile>(
      context: context,
      builder: (context) =>
          EditEnergyDialog(initial: user.energyProfile, country: user.country),
    );

    if (updated == null) {
      return;
    }

    _updateActiveUser(
      user.copyWith(
        energyProfile: updated,
        activityLog: [
          ...user.activityLog,
          ActivityEvent.atNow('energy_update'),
        ],
      ),
    );
  }

  void _updateActiveUser(UserData next) {
    final email = _activeEmail;
    if (email == null) {
      return;
    }

    setState(() {
      _users[email] = next;
    });
    _persistState();
  }

  void _persistState() {
    unawaited(
      AppStateStore.save(
        PersistedAppState(
          credentials: Map<String, String>.from(_credentials),
          users: Map<String, UserData>.from(_users),
          activeEmail: _activeEmail,
        ),
      ),
    );
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

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.onSubmit, super.key});

  final String? Function(String email, String password, AuthMode mode) onSubmit;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.register;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE4F2E8), Color(0xFFF8F4EA)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'CarbonFeet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track your footprint. Improve with clarity.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<AuthMode>(
                      selected: <AuthMode>{_mode},
                      segments: const [
                        ButtonSegment(
                          value: AuthMode.register,
                          label: Text('Create account'),
                        ),
                        ButtonSegment(
                          value: AuthMode.login,
                          label: Text('Log in'),
                        ),
                      ],
                      onSelectionChanged: (selection) {
                        setState(() {
                          _mode = selection.first;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(
                        _mode == AuthMode.register
                            ? 'Create account'
                            : 'Log in',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final error = widget.onSubmit(
      _emailController.text,
      _passwordController.text,
      _mode,
    );

    setState(() {
      _error = error;
    });
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.draftUser,
    required this.onComplete,
    super.key,
  });

  final UserData draftUser;
  final ValueChanged<UserData> onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late String _country;
  late LifeStage _lifeStage;
  late int _meatDays;
  late DairyLevel _dairyLevel;
  late String _vehicleKey;
  late DistanceMode _distanceMode;
  late TextEditingController _distanceController;
  late bool _energyKnown;
  late TextEditingController _electricityController;
  late TextEditingController _gasController;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.draftUser;
    _country = user.country;
    _lifeStage = user.lifeStage;
    _meatDays = user.dietProfile.meatDaysPerWeek;
    _dairyLevel = user.dietProfile.dairyLevel;
    _vehicleKey = user.carProfile.vehicleKey;
    _distanceMode = user.carProfile.distanceMode;
    _distanceController = TextEditingController(
      text: user.carProfile.distanceValue.toStringAsFixed(0),
    );
    _energyKnown = !user.energyProfile.isEstimated;
    _electricityController = TextEditingController(
      text: user.energyProfile.electricityKwh.toStringAsFixed(0),
    );
    _gasController = TextEditingController(
      text: user.energyProfile.gasM3.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _electricityController.dispose();
    _gasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build your baseline projection',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Answer a few questions so CarbonFeet can estimate your yearly footprint.',
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Country and life stage',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _country,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                          ),
                          items: countryReferences.keys
                              .map(
                                (country) => DropdownMenuItem(
                                  value: country,
                                  child: Text(country),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _country = value;
                              if (!_energyKnown) {
                                final estimate =
                                    EmissionCalculator.estimateEnergyForCountry(
                                      value,
                                    );
                                _electricityController.text = estimate.$1
                                    .toStringAsFixed(0);
                                _gasController.text = estimate.$2
                                    .toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LifeStage>(
                          initialValue: _lifeStage,
                          decoration: const InputDecoration(
                            labelText: 'Life stage',
                            border: OutlineInputBorder(),
                          ),
                          items: LifeStage.values
                              .map(
                                (stage) => DropdownMenuItem(
                                  value: stage,
                                  child: Text(stage.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _lifeStage = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Diet profile',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Meat days per week: $_meatDays'),
                        Slider(
                          min: 0,
                          max: 7,
                          divisions: 7,
                          value: _meatDays.toDouble(),
                          label: '$_meatDays',
                          onChanged: (value) {
                            setState(() {
                              _meatDays = value.round();
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<DairyLevel>(
                          initialValue: _dairyLevel,
                          decoration: const InputDecoration(
                            labelText: 'Dairy consumption',
                            border: OutlineInputBorder(),
                          ),
                          items: DairyLevel.values
                              .map(
                                (dairy) => DropdownMenuItem(
                                  value: dairy,
                                  child: Text(dairy.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _dairyLevel = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Car usage',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _vehicleKey,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle',
                            border: OutlineInputBorder(),
                          ),
                          items: vehicleCatalog
                              .map(
                                (vehicle) => DropdownMenuItem(
                                  value: vehicle.key,
                                  child: Text(vehicle.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _vehicleKey = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<DistanceMode>(
                          selected: {_distanceMode},
                          segments: const [
                            ButtonSegment(
                              value: DistanceMode.perDay,
                              label: Text('km/day'),
                            ),
                            ButtonSegment(
                              value: DistanceMode.perYear,
                              label: Text('km/year'),
                            ),
                          ],
                          onSelectionChanged: (selection) {
                            setState(() {
                              _distanceMode = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _distanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _distanceMode == DistanceMode.perDay
                                ? 'Distance (km/day)'
                                : 'Distance (km/year)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Home energy',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('I know my yearly energy usage'),
                          contentPadding: EdgeInsets.zero,
                          value: _energyKnown,
                          onChanged: (value) {
                            setState(() {
                              _energyKnown = value;
                              if (!value) {
                                final estimate =
                                    EmissionCalculator.estimateEnergyForCountry(
                                      _country,
                                    );
                                _electricityController.text = estimate.$1
                                    .toStringAsFixed(0);
                                _gasController.text = estimate.$2
                                    .toStringAsFixed(0);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _electricityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _energyKnown
                                ? 'Electricity (kWh/year)'
                                : 'Electricity estimate (kWh/year)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _gasController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _energyKnown
                                ? 'Gas (m3/year)'
                                : 'Gas estimate (m3/year)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _finish,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Create my baseline projection'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _finish() {
    final distance = double.tryParse(_distanceController.text);
    final electricity = double.tryParse(_electricityController.text);
    final gas = double.tryParse(_gasController.text);

    if (distance == null || distance <= 0) {
      setState(() {
        _error = 'Distance must be greater than 0.';
      });
      return;
    }

    if (electricity == null || electricity < 0 || gas == null || gas < 0) {
      setState(() {
        _error = 'Energy values must be valid numbers.';
      });
      return;
    }

    final updated = widget.draftUser.copyWith(
      country: _country,
      lifeStage: _lifeStage,
      dietProfile: DietProfile(
        meatDaysPerWeek: _meatDays,
        dairyLevel: _dairyLevel,
      ),
      carProfile: CarProfile(
        vehicleKey: _vehicleKey,
        distanceMode: _distanceMode,
        distanceValue: distance,
      ),
      energyProfile: EnergyProfile(
        electricityKwh: electricity,
        gasM3: gas,
        isEstimated: !_energyKnown,
      ),
      onboardingComplete: true,
      activityLog: [
        ...widget.draftUser.activityLog,
        ActivityEvent.atNow('onboarding'),
      ],
    );

    final summary = EmissionCalculator.summarize(updated);
    widget.onComplete(
      updated.copyWith(initialProjectionKg: summary.projectedEndYearKg),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.user,
    required this.summary,
    required this.onOpenPostMenu,
    required this.onOpenSimulator,
    required this.onLogout,
    super.key,
  });

  final UserData user;
  final EmissionSummary summary;
  final VoidCallback onOpenPostMenu;
  final VoidCallback onOpenSimulator;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbonFeet'),
        actions: [
          IconButton(
            onPressed: onOpenSimulator,
            tooltip: 'What if simulator',
            icon: const Icon(Icons.auto_graph),
          ),
          IconButton(
            onPressed: onLogout,
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onOpenPostMenu,
        icon: const Icon(Icons.add),
        label: const Text('Add CO2 post'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF7F0), Color(0xFFF7F7F2)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user.email.split('@').first}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'CO2 emitted this year',
                              value:
                                  '${_formatNumber(summary.yearToDateKg)} kg CO2e',
                            ),
                          ),
                          Expanded(
                            child: _MetricTile(
                              label: 'End-of-year projection',
                              value:
                                  '${_formatNumber(summary.projectedEndYearKg)} kg CO2e',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Green vs red zone',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary.comparisonLabel,
                            style: TextStyle(
                              color: summary.isBelowCountryAverage
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ReferenceBar(
                            label:
                                'Country average (${_formatNumber(summary.countryAverageKg)} kg)',
                            ratio:
                                summary.projectedEndYearKg /
                                summary.countryAverageKg,
                          ),
                          const SizedBox(height: 8),
                          _ReferenceBar(
                            label:
                                'Personal target (${_formatNumber(summary.personalTargetKg)} kg)',
                            ratio:
                                summary.projectedEndYearKg /
                                summary.personalTargetKg,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final singleColumn = constraints.maxWidth < 760;
                      if (singleColumn) {
                        return Column(
                          children: [
                            _buildCategoryCard(),
                            const SizedBox(height: 12),
                            _buildTrendCard(),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCategoryCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTrendCard()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Achievements',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: summary.badges.isEmpty
                                ? [
                                    const Chip(
                                      label: Text(
                                        'Add more posts to unlock badges',
                                      ),
                                    ),
                                  ]
                                : summary.badges
                                      .map((badge) => Chip(label: Text(badge)))
                                      .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_graph),
                      title: const Text('What if simulator'),
                      subtitle: const Text(
                        'Explore how one less flight, lower driving, or less meat changes your projection.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onOpenSimulator,
                    ),
                  ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    final labels = <CategoryDisplayData>[
      CategoryDisplayData(
        'Flights',
        summary.categoryTotals[EmissionCategory.flights] ?? 0,
        const Color(0xFF4361EE),
      ),
      CategoryDisplayData(
        'Car',
        summary.categoryTotals[EmissionCategory.car] ?? 0,
        const Color(0xFFEF476F),
      ),
      CategoryDisplayData(
        'Diet',
        summary.categoryTotals[EmissionCategory.diet] ?? 0,
        const Color(0xFFF4A261),
      ),
      CategoryDisplayData(
        'Energy',
        summary.categoryTotals[EmissionCategory.energy] ?? 0,
        const Color(0xFF2A9D8F),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category breakdown',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: CategoryPieChart(data: labels),
              ),
            ),
            const SizedBox(height: 12),
            for (final item in labels)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.label)),
                    Text('${_formatNumber(item.valueKg)} kg'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Year trend (YTD)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: TrendChart(points: summary.monthlyTrendKg),
            ),
            const SizedBox(height: 8),
            Text(
              'Baseline/year: ${_formatNumber(summary.baselineYearlyKg)} kg  |  Flights logged: ${_formatNumber(summary.flightsYearlyKg)} kg',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReferenceBar extends StatelessWidget {
  const _ReferenceBar({required this.label, required this.ratio});

  final String label;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0, 2).toDouble();
    final color = clamped <= 1 ? Colors.green.shade700 : Colors.red.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: clamped / 2,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
      ],
    );
  }
}

class AddFlightDialog extends StatefulWidget {
  const AddFlightDialog({super.key});

  @override
  State<AddFlightDialog> createState() => _AddFlightDialogState();
}

class _AddFlightDialogState extends State<AddFlightDialog> {
  final TextEditingController _flightNumberController = TextEditingController();
  DateTime _flightDate = DateTime.now();
  OccupancyLevel _occupancy = OccupancyLevel.halfFull;

  @override
  void dispose() {
    _flightNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add flight'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _flightNumberController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Flight number',
                border: OutlineInputBorder(),
                hintText: 'Example: KL1001',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<OccupancyLevel>(
              initialValue: _occupancy,
              decoration: const InputDecoration(
                labelText: 'Occupancy estimate',
                border: OutlineInputBorder(),
              ),
              items: OccupancyLevel.values
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(level.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _occupancy = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Date: ${_formatDate(_flightDate)}')),
                TextButton(onPressed: _pickDate, child: const Text('Select')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _flightDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );

    if (selected != null) {
      setState(() {
        _flightDate = selected;
      });
    }
  }

  void _submit() {
    Navigator.of(context).pop(
      FlightDraft(
        flightNumber: _flightNumberController.text.trim().toUpperCase(),
        date: _flightDate,
        occupancy: _occupancy,
      ),
    );
  }
}

class EditCarDialog extends StatefulWidget {
  const EditCarDialog({required this.initial, super.key});

  final CarProfile initial;

  @override
  State<EditCarDialog> createState() => _EditCarDialogState();
}

class _EditCarDialogState extends State<EditCarDialog> {
  late String _vehicleKey;
  late DistanceMode _distanceMode;
  late TextEditingController _distanceController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vehicleKey = widget.initial.vehicleKey;
    _distanceMode = widget.initial.distanceMode;
    _distanceController = TextEditingController(
      text: widget.initial.distanceValue.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update car usage'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _vehicleKey,
              decoration: const InputDecoration(
                labelText: 'Vehicle',
                border: OutlineInputBorder(),
              ),
              items: vehicleCatalog
                  .map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle.key,
                      child: Text(vehicle.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _vehicleKey = value;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            SegmentedButton<DistanceMode>(
              selected: {_distanceMode},
              segments: const [
                ButtonSegment(
                  value: DistanceMode.perDay,
                  label: Text('km/day'),
                ),
                ButtonSegment(
                  value: DistanceMode.perYear,
                  label: Text('km/year'),
                ),
              ],
              onSelectionChanged: (selection) {
                setState(() {
                  _distanceMode = selection.first;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _distanceMode == DistanceMode.perDay
                    ? 'Distance (km/day)'
                    : 'Distance (km/year)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final value = double.tryParse(_distanceController.text);
    if (value == null || value <= 0) {
      setState(() {
        _error = 'Distance must be greater than 0.';
      });
      return;
    }

    Navigator.of(context).pop(
      CarProfile(
        vehicleKey: _vehicleKey,
        distanceMode: _distanceMode,
        distanceValue: value,
      ),
    );
  }
}

class EditDietDialog extends StatefulWidget {
  const EditDietDialog({required this.initial, super.key});

  final DietProfile initial;

  @override
  State<EditDietDialog> createState() => _EditDietDialogState();
}

class _EditDietDialogState extends State<EditDietDialog> {
  late int _meatDays;
  late DairyLevel _dairy;

  @override
  void initState() {
    super.initState();
    _meatDays = widget.initial.meatDaysPerWeek;
    _dairy = widget.initial.dairyLevel;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update diet profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meat days per week: $_meatDays'),
            Slider(
              min: 0,
              max: 7,
              divisions: 7,
              value: _meatDays.toDouble(),
              label: '$_meatDays',
              onChanged: (value) {
                setState(() {
                  _meatDays = value.round();
                });
              },
            ),
            DropdownButtonFormField<DairyLevel>(
              initialValue: _dairy,
              decoration: const InputDecoration(
                labelText: 'Dairy level',
                border: OutlineInputBorder(),
              ),
              items: DairyLevel.values
                  .map(
                    (level) => DropdownMenuItem(
                      value: level,
                      child: Text(level.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _dairy = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(DietProfile(meatDaysPerWeek: _meatDays, dairyLevel: _dairy));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class EditEnergyDialog extends StatefulWidget {
  const EditEnergyDialog({
    required this.initial,
    required this.country,
    super.key,
  });

  final EnergyProfile initial;
  final String country;

  @override
  State<EditEnergyDialog> createState() => _EditEnergyDialogState();
}

class _EditEnergyDialogState extends State<EditEnergyDialog> {
  late bool _known;
  late TextEditingController _electricityController;
  late TextEditingController _gasController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _known = !widget.initial.isEstimated;
    _electricityController = TextEditingController(
      text: widget.initial.electricityKwh.toStringAsFixed(0),
    );
    _gasController = TextEditingController(
      text: widget.initial.gasM3.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _electricityController.dispose();
    _gasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update home energy'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I know my exact yearly usage'),
              value: _known,
              onChanged: (value) {
                setState(() {
                  _known = value;
                  if (!value) {
                    final estimate =
                        EmissionCalculator.estimateEnergyForCountry(
                          widget.country,
                        );
                    _electricityController.text = estimate.$1.toStringAsFixed(
                      0,
                    );
                    _gasController.text = estimate.$2.toStringAsFixed(0);
                  }
                });
              },
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _electricityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _known
                    ? 'Electricity (kWh/year)'
                    : 'Electricity estimate (kWh/year)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gasController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _known ? 'Gas (m3/year)' : 'Gas estimate (m3/year)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    final electricity = double.tryParse(_electricityController.text);
    final gas = double.tryParse(_gasController.text);

    if (electricity == null || electricity < 0 || gas == null || gas < 0) {
      setState(() {
        _error = 'Energy values must be valid non-negative numbers.';
      });
      return;
    }

    Navigator.of(context).pop(
      EnergyProfile(
        electricityKwh: electricity,
        gasM3: gas,
        isEstimated: !_known,
      ),
    );
  }
}

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({required this.data, super.key});

  final List<CategoryDisplayData> data;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PiePainter(data));
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.data);

  final List<CategoryDisplayData> data;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<double>(0, (sum, item) => sum + item.valueKg);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()..style = PaintingStyle.fill;

    var startAngle = -math.pi / 2;
    for (final item in data) {
      final sweep = total <= 0 ? 0.0 : (item.valueKg / total) * math.pi * 2;
      basePaint.color = item.color;
      canvas.drawArc(rect, startAngle, sweep, true, basePaint);
      startAngle += sweep;
    }

    final centerCutPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.54, centerCutPaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart({required this.points, super.key});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(points: points),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (var i = 0; i < 5; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) {
      return;
    }

    final maxValue = points.reduce(math.max);
    final minValue = points.reduce(math.min);
    final range = math.max(maxValue - minValue, 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final normalized = (points[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF2A9D8F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF1D3557);
    for (var i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final normalized = (points[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class EmissionCalculator {
  static EmissionSummary summarize(UserData user, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final countryRef =
        countryReferences[user.country] ?? defaultCountryReference;

    final carKg = _carYearlyKg(user.carProfile);
    final dietKg = _dietYearlyKg(user.dietProfile);
    final energyKg = _energyYearlyKg(user.energyProfile, countryRef);

    final baselineKg = carKg + dietKg + energyKg;

    final currentYearFlights = user.flights
        .where((entry) => entry.date.year == timestamp.year)
        .toList();

    final flightsYearKg = currentYearFlights.fold<double>(
      0,
      (sum, entry) => sum + entry.emissionsKg,
    );

    final currentYearFlightsYtd = currentYearFlights.where(
      (entry) => !entry.date.isAfter(timestamp),
    );

    final flightsYtdKg = currentYearFlightsYtd.fold<double>(
      0,
      (sum, entry) => sum + entry.emissionsKg,
    );

    final yearStart = DateTime(timestamp.year, 1, 1);
    final nextYearStart = DateTime(timestamp.year + 1, 1, 1);
    final daysInYear = nextYearStart.difference(yearStart).inDays;
    final dayOfYear = timestamp.difference(yearStart).inDays + 1;
    final progressRatio = dayOfYear / daysInYear;

    final ytdKg = baselineKg * progressRatio + flightsYtdKg;
    final projectedKg = baselineKg + flightsYearKg;

    final trend = <double>[];
    for (var month = 1; month <= 12; month++) {
      final monthEnd = month == 12
          ? DateTime(timestamp.year, 12, 31)
          : DateTime(
              timestamp.year,
              month + 1,
              1,
            ).subtract(const Duration(days: 1));
      final elapsed = monthEnd.difference(yearStart).inDays + 1;
      final baselineToMonth = baselineKg * (elapsed / daysInYear);
      final flightsToMonth = currentYearFlights
          .where((entry) => !entry.date.isAfter(monthEnd))
          .fold<double>(0, (sum, entry) => sum + entry.emissionsKg);

      trend.add(baselineToMonth + flightsToMonth);
    }

    final categoryTotals = <EmissionCategory, double>{
      EmissionCategory.flights: flightsYearKg,
      EmissionCategory.car: carKg,
      EmissionCategory.diet: dietKg,
      EmissionCategory.energy: energyKg,
    };

    final badges = <String>[];
    final hasImproved =
        user.initialProjectionKg > 0 &&
        projectedKg <= user.initialProjectionKg * 0.95;
    if (hasImproved) {
      badges.add('Improvement badge');
    }

    final uniqueWeekKeys = user.activityLog
        .where((event) => event.timestamp.year == timestamp.year)
        .map((event) => _weekKey(event.timestamp))
        .toSet();

    if (uniqueWeekKeys.length >= 3) {
      badges.add('Consistency badge');
    }

    final belowAverage = projectedKg <= countryRef.countryAverageKg;
    if (belowAverage) {
      badges.add('Low footprint badge');
    }

    final comparisonLabel = belowAverage
        ? 'Below country average by ${_formatNumber(countryRef.countryAverageKg - projectedKg)} kg'
        : 'Above country average by ${_formatNumber(projectedKg - countryRef.countryAverageKg)} kg';

    return EmissionSummary(
      yearToDateKg: ytdKg,
      projectedEndYearKg: projectedKg,
      baselineYearlyKg: baselineKg,
      flightsYearlyKg: flightsYearKg,
      countryAverageKg: countryRef.countryAverageKg,
      personalTargetKg: countryRef.personalTargetKg,
      comparisonLabel: comparisonLabel,
      isBelowCountryAverage: belowAverage,
      categoryTotals: categoryTotals,
      monthlyTrendKg: trend,
      badges: badges,
    );
  }

  static List<SimulationOutcome> simulateScenarios(UserData user) {
    final scenarios = <SimulationOutcome>[];

    if (user.flights.isNotEmpty) {
      final sortedFlights = [...user.flights]
        ..sort((a, b) => b.emissionsKg.compareTo(a.emissionsKg));
      final reduced = user.copyWith(flights: sortedFlights.skip(1).toList());
      scenarios.add(
        SimulationOutcome(
          title: 'Remove one flight',
          description:
              'Simulates skipping your largest logged flight this year.',
          projectedKg: summarize(reduced).projectedEndYearKg,
        ),
      );
    }

    final lessDriving = user.copyWith(
      carProfile: user.carProfile.copyWith(
        distanceValue: user.carProfile.distanceValue * 0.9,
      ),
    );
    scenarios.add(
      SimulationOutcome(
        title: 'Drive 10% less',
        description: 'Simulates reducing yearly car distance by 10%.',
        projectedKg: summarize(lessDriving).projectedEndYearKg,
      ),
    );

    final lessMeat = user.copyWith(
      dietProfile: user.dietProfile.copyWith(
        meatDaysPerWeek: math.max(0, user.dietProfile.meatDaysPerWeek - 1),
      ),
    );
    scenarios.add(
      SimulationOutcome(
        title: 'One less meat day/week',
        description: 'Simulates replacing one meat day every week.',
        projectedKg: summarize(lessMeat).projectedEndYearKg,
      ),
    );

    return scenarios;
  }

  static (double electricityKwh, double gasM3) estimateEnergyForCountry(
    String country,
  ) {
    final ref = countryReferences[country] ?? defaultCountryReference;
    return (ref.defaultElectricityKwh, ref.defaultGasM3);
  }

  static FlightEntry? buildFlightEntry(FlightDraft draft) {
    if (draft.flightNumber.isEmpty) {
      return null;
    }

    final template = flightCatalog[draft.flightNumber];
    if (template == null) {
      return null;
    }

    final occupancyMultiplier = switch (draft.occupancy) {
      OccupancyLevel.nearlyEmpty => 1.25,
      OccupancyLevel.halfFull => 1,
      OccupancyLevel.nearlyFull => 0.82,
    };

    final basePerKm = 0.115;
    final segmentMultiplier = 1 + ((template.segments - 1) * 0.15);

    final emissions =
        template.distanceKm *
        basePerKm *
        segmentMultiplier *
        template.aircraftMultiplier *
        occupancyMultiplier;

    return FlightEntry(
      flightNumber: draft.flightNumber,
      date: draft.date,
      occupancy: draft.occupancy,
      origin: template.origin,
      destination: template.destination,
      distanceKm: template.distanceKm,
      segments: template.segments,
      aircraftType: template.aircraftType,
      emissionsKg: emissions,
    );
  }

  static double _carYearlyKg(CarProfile car) {
    final vehicle = vehicleByKey[car.vehicleKey] ?? vehicleCatalog.first;
    final yearlyKm = car.distanceMode == DistanceMode.perDay
        ? car.distanceValue * 365
        : car.distanceValue;
    return yearlyKm * vehicle.kgPerKm;
  }

  static double _dietYearlyKg(DietProfile diet) {
    final meatBase = switch (diet.meatDaysPerWeek) {
      0 => 600,
      1 => 850,
      2 => 1100,
      3 => 1350,
      4 => 1600,
      5 => 1850,
      6 => 2100,
      _ => 2350,
    };

    final dairyOffset = switch (diet.dairyLevel) {
      DairyLevel.low => -150,
      DairyLevel.medium => 0,
      DairyLevel.high => 180,
    };

    return math.max(350, meatBase + dairyOffset).toDouble();
  }

  static double _energyYearlyKg(
    EnergyProfile energy,
    CountryReference countryRef,
  ) {
    final electricityKg =
        energy.electricityKwh * countryRef.electricityKgPerKwh;
    final gasKg = energy.gasM3 * 2.0;
    return electricityKg + gasKg;
  }

  static String _weekKey(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final week = ((date.difference(firstDay).inDays) / 7).floor() + 1;
    return '${date.year}-$week';
  }
}

class EmissionSummary {
  const EmissionSummary({
    required this.yearToDateKg,
    required this.projectedEndYearKg,
    required this.baselineYearlyKg,
    required this.flightsYearlyKg,
    required this.countryAverageKg,
    required this.personalTargetKg,
    required this.comparisonLabel,
    required this.isBelowCountryAverage,
    required this.categoryTotals,
    required this.monthlyTrendKg,
    required this.badges,
  });

  final double yearToDateKg;
  final double projectedEndYearKg;
  final double baselineYearlyKg;
  final double flightsYearlyKg;
  final double countryAverageKg;
  final double personalTargetKg;
  final String comparisonLabel;
  final bool isBelowCountryAverage;
  final Map<EmissionCategory, double> categoryTotals;
  final List<double> monthlyTrendKg;
  final List<String> badges;
}

class SimulationOutcome {
  const SimulationOutcome({
    required this.title,
    required this.description,
    required this.projectedKg,
  });

  final String title;
  final String description;
  final double projectedKg;
}

class PersistedAppState {
  const PersistedAppState({
    required this.credentials,
    required this.users,
    required this.activeEmail,
  });

  const PersistedAppState.empty()
    : credentials = const {},
      users = const {},
      activeEmail = null;

  final Map<String, String> credentials;
  final Map<String, UserData> users;
  final String? activeEmail;

  factory PersistedAppState.fromJson(Map<String, dynamic> json) {
    final credentials = <String, String>{};
    for (final entry in _asStringDynamicMap(json['credentials']).entries) {
      if (entry.value is String) {
        credentials[entry.key] = entry.value as String;
      }
    }

    final users = <String, UserData>{};
    for (final entry in _asStringDynamicMap(json['users']).entries) {
      final rawUser = _asStringDynamicMap(entry.value);
      if (rawUser.isEmpty) {
        continue;
      }
      final parsed = UserData.fromJson(rawUser);
      users[entry.key] = parsed.email.isEmpty
          ? parsed.copyWith(email: entry.key)
          : parsed;
    }

    final activeEmailRaw = json['activeEmail'];
    return PersistedAppState(
      credentials: credentials,
      users: users,
      activeEmail: activeEmailRaw is String && activeEmailRaw.isNotEmpty
          ? activeEmailRaw
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'credentials': credentials,
      'users': {
        for (final entry in users.entries) entry.key: entry.value.toJson(),
      },
      'activeEmail': activeEmail,
    };
  }
}

class AppStateStore {
  static const String _storageKey = 'carbonfeet_state_v1';

  static Future<PersistedAppState> load() async {
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

  static Future<void> save(PersistedAppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}

class UserData {
  const UserData({
    required this.email,
    required this.country,
    required this.lifeStage,
    required this.dietProfile,
    required this.carProfile,
    required this.energyProfile,
    required this.flights,
    required this.activityLog,
    required this.onboardingComplete,
    required this.initialProjectionKg,
  });

  factory UserData.empty({required String email}) {
    return UserData(
      email: email,
      country: 'United States',
      lifeStage: LifeStage.youngProfessional,
      dietProfile: const DietProfile(
        meatDaysPerWeek: 4,
        dairyLevel: DairyLevel.medium,
      ),
      carProfile: const CarProfile(
        vehicleKey: 'toyota_corolla',
        distanceMode: DistanceMode.perYear,
        distanceValue: 12000,
      ),
      energyProfile: const EnergyProfile(
        electricityKwh: 4300,
        gasM3: 650,
        isEstimated: true,
      ),
      flights: const [],
      activityLog: const [],
      onboardingComplete: false,
      initialProjectionKg: 0,
    );
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    final flights = (json['flights'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => FlightEntry.fromJson(_asStringDynamicMap(item)))
        .toList();
    final activityLog = (json['activityLog'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => ActivityEvent.fromJson(_asStringDynamicMap(item)))
        .toList();

    return UserData(
      email: _readString(json['email'], fallback: ''),
      country: _readString(json['country'], fallback: 'United States'),
      lifeStage: _enumFromName(
        LifeStage.values,
        json['lifeStage'],
        LifeStage.youngProfessional,
      ),
      dietProfile: DietProfile.fromJson(
        _asStringDynamicMap(json['dietProfile']),
      ),
      carProfile: CarProfile.fromJson(_asStringDynamicMap(json['carProfile'])),
      energyProfile: EnergyProfile.fromJson(
        _asStringDynamicMap(json['energyProfile']),
      ),
      flights: flights,
      activityLog: activityLog,
      onboardingComplete: _readBool(json['onboardingComplete']),
      initialProjectionKg: _readDouble(json['initialProjectionKg']),
    );
  }

  final String email;
  final String country;
  final LifeStage lifeStage;
  final DietProfile dietProfile;
  final CarProfile carProfile;
  final EnergyProfile energyProfile;
  final List<FlightEntry> flights;
  final List<ActivityEvent> activityLog;
  final bool onboardingComplete;
  final double initialProjectionKg;

  UserData copyWith({
    String? email,
    String? country,
    LifeStage? lifeStage,
    DietProfile? dietProfile,
    CarProfile? carProfile,
    EnergyProfile? energyProfile,
    List<FlightEntry>? flights,
    List<ActivityEvent>? activityLog,
    bool? onboardingComplete,
    double? initialProjectionKg,
  }) {
    return UserData(
      email: email ?? this.email,
      country: country ?? this.country,
      lifeStage: lifeStage ?? this.lifeStage,
      dietProfile: dietProfile ?? this.dietProfile,
      carProfile: carProfile ?? this.carProfile,
      energyProfile: energyProfile ?? this.energyProfile,
      flights: flights ?? this.flights,
      activityLog: activityLog ?? this.activityLog,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      initialProjectionKg: initialProjectionKg ?? this.initialProjectionKg,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'country': country,
      'lifeStage': lifeStage.name,
      'dietProfile': dietProfile.toJson(),
      'carProfile': carProfile.toJson(),
      'energyProfile': energyProfile.toJson(),
      'flights': flights.map((entry) => entry.toJson()).toList(),
      'activityLog': activityLog.map((entry) => entry.toJson()).toList(),
      'onboardingComplete': onboardingComplete,
      'initialProjectionKg': initialProjectionKg,
    };
  }
}

class DietProfile {
  const DietProfile({required this.meatDaysPerWeek, required this.dairyLevel});

  factory DietProfile.fromJson(Map<String, dynamic> json) {
    return DietProfile(
      meatDaysPerWeek: _readInt(json['meatDaysPerWeek'], fallback: 4),
      dairyLevel: _enumFromName(
        DairyLevel.values,
        json['dairyLevel'],
        DairyLevel.medium,
      ),
    );
  }

  final int meatDaysPerWeek;
  final DairyLevel dairyLevel;

  DietProfile copyWith({int? meatDaysPerWeek, DairyLevel? dairyLevel}) {
    return DietProfile(
      meatDaysPerWeek: meatDaysPerWeek ?? this.meatDaysPerWeek,
      dairyLevel: dairyLevel ?? this.dairyLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {'meatDaysPerWeek': meatDaysPerWeek, 'dairyLevel': dairyLevel.name};
  }
}

class CarProfile {
  const CarProfile({
    required this.vehicleKey,
    required this.distanceMode,
    required this.distanceValue,
  });

  factory CarProfile.fromJson(Map<String, dynamic> json) {
    return CarProfile(
      vehicleKey: _readString(
        json['vehicleKey'],
        fallback: vehicleCatalog.first.key,
      ),
      distanceMode: _enumFromName(
        DistanceMode.values,
        json['distanceMode'],
        DistanceMode.perYear,
      ),
      distanceValue: _readDouble(json['distanceValue'], fallback: 12000),
    );
  }

  final String vehicleKey;
  final DistanceMode distanceMode;
  final double distanceValue;

  CarProfile copyWith({
    String? vehicleKey,
    DistanceMode? distanceMode,
    double? distanceValue,
  }) {
    return CarProfile(
      vehicleKey: vehicleKey ?? this.vehicleKey,
      distanceMode: distanceMode ?? this.distanceMode,
      distanceValue: distanceValue ?? this.distanceValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicleKey': vehicleKey,
      'distanceMode': distanceMode.name,
      'distanceValue': distanceValue,
    };
  }
}

class EnergyProfile {
  const EnergyProfile({
    required this.electricityKwh,
    required this.gasM3,
    required this.isEstimated,
  });

  factory EnergyProfile.fromJson(Map<String, dynamic> json) {
    return EnergyProfile(
      electricityKwh: _readDouble(json['electricityKwh'], fallback: 4300),
      gasM3: _readDouble(json['gasM3'], fallback: 650),
      isEstimated: _readBool(json['isEstimated'], fallback: true),
    );
  }

  final double electricityKwh;
  final double gasM3;
  final bool isEstimated;

  Map<String, dynamic> toJson() {
    return {
      'electricityKwh': electricityKwh,
      'gasM3': gasM3,
      'isEstimated': isEstimated,
    };
  }
}

class FlightEntry {
  const FlightEntry({
    required this.flightNumber,
    required this.date,
    required this.occupancy,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.segments,
    required this.aircraftType,
    required this.emissionsKg,
  });

  factory FlightEntry.fromJson(Map<String, dynamic> json) {
    return FlightEntry(
      flightNumber: _readString(json['flightNumber']),
      date: _readDateTime(json['date']),
      occupancy: _enumFromName(
        OccupancyLevel.values,
        json['occupancy'],
        OccupancyLevel.halfFull,
      ),
      origin: _readString(json['origin']),
      destination: _readString(json['destination']),
      distanceKm: _readDouble(json['distanceKm']),
      segments: _readInt(json['segments'], fallback: 1),
      aircraftType: _readString(json['aircraftType']),
      emissionsKg: _readDouble(json['emissionsKg']),
    );
  }

  final String flightNumber;
  final DateTime date;
  final OccupancyLevel occupancy;
  final String origin;
  final String destination;
  final double distanceKm;
  final int segments;
  final String aircraftType;
  final double emissionsKg;

  Map<String, dynamic> toJson() {
    return {
      'flightNumber': flightNumber,
      'date': date.toIso8601String(),
      'occupancy': occupancy.name,
      'origin': origin,
      'destination': destination,
      'distanceKm': distanceKm,
      'segments': segments,
      'aircraftType': aircraftType,
      'emissionsKg': emissionsKg,
    };
  }
}

class FlightDraft {
  const FlightDraft({
    required this.flightNumber,
    required this.date,
    required this.occupancy,
  });

  final String flightNumber;
  final DateTime date;
  final OccupancyLevel occupancy;
}

class FlightTemplate {
  const FlightTemplate({
    required this.flightNumber,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.segments,
    required this.aircraftType,
    required this.aircraftMultiplier,
  });

  final String flightNumber;
  final String origin;
  final String destination;
  final double distanceKm;
  final int segments;
  final String aircraftType;
  final double aircraftMultiplier;
}

class CountryReference {
  const CountryReference({
    required this.countryAverageKg,
    required this.personalTargetKg,
    required this.electricityKgPerKwh,
    required this.defaultElectricityKwh,
    required this.defaultGasM3,
  });

  final double countryAverageKg;
  final double personalTargetKg;
  final double electricityKgPerKwh;
  final double defaultElectricityKwh;
  final double defaultGasM3;
}

class VehicleProfile {
  const VehicleProfile({
    required this.key,
    required this.label,
    required this.kgPerKm,
  });

  final String key;
  final String label;
  final double kgPerKm;
}

class ActivityEvent {
  const ActivityEvent({required this.timestamp, required this.type});

  factory ActivityEvent.atNow(String type) {
    return ActivityEvent(timestamp: DateTime.now(), type: type);
  }

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      timestamp: _readDateTime(json['timestamp']),
      type: _readString(json['type']),
    );
  }

  final DateTime timestamp;
  final String type;

  Map<String, dynamic> toJson() {
    return {'timestamp': timestamp.toIso8601String(), 'type': type};
  }
}

class CategoryDisplayData {
  const CategoryDisplayData(this.label, this.valueKg, this.color);

  final String label;
  final double valueKg;
  final Color color;
}

enum AuthMode { login, register }

enum DistanceMode { perDay, perYear }

enum OccupancyLevel { nearlyEmpty, halfFull, nearlyFull }

enum PostType { flight, car, diet, energy }

enum EmissionCategory { flights, car, diet, energy }

enum DairyLevel { low, medium, high }

enum LifeStage { student, youngProfessional, family, retired }

extension DairyLevelLabel on DairyLevel {
  String get label => switch (this) {
    DairyLevel.low => 'Low',
    DairyLevel.medium => 'Medium',
    DairyLevel.high => 'High',
  };
}

extension OccupancyLevelLabel on OccupancyLevel {
  String get label => switch (this) {
    OccupancyLevel.nearlyEmpty => 'Nearly empty',
    OccupancyLevel.halfFull => 'Half full',
    OccupancyLevel.nearlyFull => 'Nearly full',
  };
}

extension LifeStageLabel on LifeStage {
  String get label => switch (this) {
    LifeStage.student => 'Student',
    LifeStage.youngProfessional => 'Young professional',
    LifeStage.family => 'Family',
    LifeStage.retired => 'Retired',
  };
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

const defaultCountryReference = CountryReference(
  countryAverageKg: 8000,
  personalTargetKg: 5500,
  electricityKgPerKwh: 0.3,
  defaultElectricityKwh: 3500,
  defaultGasM3: 450,
);

const countryReferences = <String, CountryReference>{
  'United States': CountryReference(
    countryAverageKg: 14000,
    personalTargetKg: 8000,
    electricityKgPerKwh: 0.39,
    defaultElectricityKwh: 4600,
    defaultGasM3: 680,
  ),
  'Netherlands': CountryReference(
    countryAverageKg: 10500,
    personalTargetKg: 6500,
    electricityKgPerKwh: 0.34,
    defaultElectricityKwh: 3200,
    defaultGasM3: 1200,
  ),
  'Germany': CountryReference(
    countryAverageKg: 9000,
    personalTargetKg: 6000,
    electricityKgPerKwh: 0.37,
    defaultElectricityKwh: 3100,
    defaultGasM3: 950,
  ),
  'United Kingdom': CountryReference(
    countryAverageKg: 6500,
    personalTargetKg: 5000,
    electricityKgPerKwh: 0.23,
    defaultElectricityKwh: 2800,
    defaultGasM3: 930,
  ),
  'France': CountryReference(
    countryAverageKg: 6000,
    personalTargetKg: 4500,
    electricityKgPerKwh: 0.08,
    defaultElectricityKwh: 2900,
    defaultGasM3: 700,
  ),
  'India': CountryReference(
    countryAverageKg: 2200,
    personalTargetKg: 1800,
    electricityKgPerKwh: 0.65,
    defaultElectricityKwh: 1900,
    defaultGasM3: 210,
  ),
  'Brazil': CountryReference(
    countryAverageKg: 2500,
    personalTargetKg: 1800,
    electricityKgPerKwh: 0.09,
    defaultElectricityKwh: 2200,
    defaultGasM3: 120,
  ),
};

const vehicleCatalog = <VehicleProfile>[
  VehicleProfile(key: 'toyota_corolla', label: 'Toyota Corolla', kgPerKm: 0.17),
  VehicleProfile(
    key: 'volkswagen_golf',
    label: 'Volkswagen Golf',
    kgPerKm: 0.16,
  ),
  VehicleProfile(key: 'ford_focus', label: 'Ford Focus', kgPerKm: 0.18),
  VehicleProfile(key: 'tesla_model_3', label: 'Tesla Model 3', kgPerKm: 0.06),
  VehicleProfile(
    key: 'kia_niro_hybrid',
    label: 'Kia Niro Hybrid',
    kgPerKm: 0.11,
  ),
  VehicleProfile(key: 'ford_f150', label: 'Ford F-150', kgPerKm: 0.26),
  VehicleProfile(key: 'bmw_320i', label: 'BMW 320i', kgPerKm: 0.20),
  VehicleProfile(key: 'honda_civic', label: 'Honda Civic', kgPerKm: 0.16),
];

const flightCatalog = <String, FlightTemplate>{
  'KL1001': FlightTemplate(
    flightNumber: 'KL1001',
    origin: 'AMS',
    destination: 'LHR',
    distanceKm: 370,
    segments: 1,
    aircraftType: 'Boeing 737-800',
    aircraftMultiplier: 0.97,
  ),
  'KL0641': FlightTemplate(
    flightNumber: 'KL0641',
    origin: 'AMS',
    destination: 'JFK',
    distanceKm: 5860,
    segments: 1,
    aircraftType: 'Airbus A330',
    aircraftMultiplier: 1.04,
  ),
  'DL0405': FlightTemplate(
    flightNumber: 'DL0405',
    origin: 'JFK',
    destination: 'LAX',
    distanceKm: 3983,
    segments: 1,
    aircraftType: 'Boeing 767',
    aircraftMultiplier: 1.01,
  ),
  'BA0295': FlightTemplate(
    flightNumber: 'BA0295',
    origin: 'LHR',
    destination: 'ORD',
    distanceKm: 6353,
    segments: 1,
    aircraftType: 'Boeing 777',
    aircraftMultiplier: 1.07,
  ),
  'LH2010': FlightTemplate(
    flightNumber: 'LH2010',
    origin: 'FRA',
    destination: 'BER',
    distanceKm: 424,
    segments: 1,
    aircraftType: 'Airbus A320',
    aircraftMultiplier: 0.96,
  ),
  'UA0123': FlightTemplate(
    flightNumber: 'UA0123',
    origin: 'SFO',
    destination: 'NRT',
    distanceKm: 8235,
    segments: 1,
    aircraftType: 'Boeing 787',
    aircraftMultiplier: 0.95,
  ),
  'AF1777': FlightTemplate(
    flightNumber: 'AF1777',
    origin: 'CDG',
    destination: 'LIS',
    distanceKm: 1453,
    segments: 1,
    aircraftType: 'Airbus A320neo',
    aircraftMultiplier: 0.93,
  ),
  'EK0203': FlightTemplate(
    flightNumber: 'EK0203',
    origin: 'DXB',
    destination: 'JFK',
    distanceKm: 11020,
    segments: 1,
    aircraftType: 'Airbus A380',
    aircraftMultiplier: 1.12,
  ),
};

final vehicleByKey = {
  for (final vehicle in vehicleCatalog) vehicle.key: vehicle,
};

String _formatNumber(double number) {
  return number.toStringAsFixed(0);
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _deltaLabel(double delta) {
  final rounded = delta.abs().toStringAsFixed(0);
  if (delta < 0) {
    return '-$rounded kg';
  }
  if (delta > 0) {
    return '+$rounded kg';
  }
  return '0 kg';
}
