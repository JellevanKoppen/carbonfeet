part of 'package:carbonfeet/main.dart';

class AddFlightDialog extends StatefulWidget {
  const AddFlightDialog({super.key});

  @override
  State<AddFlightDialog> createState() => _AddFlightDialogState();
}

class _AddFlightDialogState extends State<AddFlightDialog> {
  final TextEditingController _flightNumberController = TextEditingController();
  DateTime _flightDate = DateTime.now();
  OccupancyLevel _occupancy = OccupancyLevel.halfFull;
  String? _error;

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
              onChanged: (_) {
                if (_error == null) {
                  return;
                }
                setState(() {
                  _error = null;
                });
              },
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
        _error = null;
      });
    }
  }

  void _submit() {
    final normalizedNumber = _flightNumberController.text.trim().toUpperCase();
    final numberError = InputValidation.validateFlightNumber(normalizedNumber);
    if (numberError != null) {
      setState(() {
        _error = numberError;
      });
      return;
    }

    final dateError = InputValidation.validateFlightDate(_flightDate);
    if (dateError != null) {
      setState(() {
        _error = dateError;
      });
      return;
    }

    Navigator.of(context).pop(
      FlightDraft(
        flightNumber: normalizedNumber,
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
    final error = InputValidation.validateCarDistance(value, _distanceMode);
    if (error != null) {
      setState(() {
        _error = error;
      });
      return;
    }
    final safeValue = value!;

    Navigator.of(context).pop(
      CarProfile(
        vehicleKey: _vehicleKey,
        distanceMode: _distanceMode,
        distanceValue: safeValue,
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
                  _error = null;
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
              onChanged: (_) {
                if (_error == null) {
                  return;
                }
                setState(() {
                  _error = null;
                });
              },
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
              onChanged: (_) {
                if (_error == null) {
                  return;
                }
                setState(() {
                  _error = null;
                });
              },
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

    final error = InputValidation.validateEnergyUsage(electricity, gas);
    if (error != null) {
      setState(() {
        _error = error;
      });
      return;
    }
    final safeElectricity = electricity!;
    final safeGas = gas!;

    Navigator.of(context).pop(
      EnergyProfile(
        electricityKwh: safeElectricity,
        gasM3: safeGas,
        isEstimated: !_known,
      ),
    );
  }
}
