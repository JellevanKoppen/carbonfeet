part of 'package:carbonfeet/main.dart';

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
                              _error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _distanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) {
                            if (_error == null) {
                              return;
                            }
                            setState(() {
                              _error = null;
                            });
                          },
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
                              _error = null;
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
                          onChanged: (_) {
                            if (_error == null) {
                              return;
                            }
                            setState(() {
                              _error = null;
                            });
                          },
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
                          onChanged: (_) {
                            if (_error == null) {
                              return;
                            }
                            setState(() {
                              _error = null;
                            });
                          },
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

    final distanceError = InputValidation.validateCarDistance(
      distance,
      _distanceMode,
    );
    if (distanceError != null) {
      setState(() {
        _error = distanceError;
      });
      return;
    }

    final energyError = InputValidation.validateEnergyUsage(electricity, gas);
    if (energyError != null) {
      setState(() {
        _error = energyError;
      });
      return;
    }
    final safeDistance = distance!;
    final safeElectricity = electricity!;
    final safeGas = gas!;

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
        distanceValue: safeDistance,
      ),
      energyProfile: EnergyProfile(
        electricityKwh: safeElectricity,
        gasM3: safeGas,
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
