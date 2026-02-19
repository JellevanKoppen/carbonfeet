part of 'package:carbonfeet/main.dart';

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
                  _buildRecentFlightsCard(context),
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

  Widget _buildRecentFlightsCard(BuildContext context) {
    final flights = [...user.flights]
      ..sort((left, right) => right.date.compareTo(left.date));
    final recent = flights.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent flights',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            if (recent.isEmpty)
              const Text('No flights logged yet. Add a flight to see details.')
            else
              for (final flight in recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flight),
                  title: Text(
                    '${flight.flightNumber}  ${flight.origin} → ${flight.destination}',
                  ),
                  subtitle: Text(
                    '${_formatDate(flight.date)}  •  ${flight.occupancy.label}',
                  ),
                  trailing: Text('${_formatNumber(flight.emissionsKg)} kg'),
                  onTap: () => _openFlightDetailSheet(context, flight),
                ),
          ],
        ),
      ),
    );
  }

  void _openFlightDetailSheet(BuildContext context, FlightEntry flight) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flight details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text('Flight: ${flight.flightNumber}'),
                Text('Route: ${flight.origin} → ${flight.destination}'),
                Text('Date: ${_formatDate(flight.date)}'),
                Text('Occupancy: ${flight.occupancy.label}'),
                Text('Aircraft: ${flight.aircraftType}'),
                Text('Distance: ${_formatNumber(flight.distanceKm)} km'),
                Text('Segments: ${flight.segments}'),
                const SizedBox(height: 8),
                Text(
                  'Estimated emissions: ${_formatNumber(flight.emissionsKg)} kg CO2e',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      },
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
