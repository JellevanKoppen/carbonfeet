part of 'package:carbonfeet/main.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.user,
    required this.summary,
    required this.onOpenPostMenu,
    required this.onOpenSimulator,
    required this.onLogout,
    this.isSummaryLoading = false,
    this.isPostSubmissionInProgress = false,
    this.summaryErrorMessage,
    super.key,
  });

  final UserData user;
  final EmissionSummary summary;
  final VoidCallback onOpenPostMenu;
  final VoidCallback onOpenSimulator;
  final VoidCallback onLogout;
  final bool isSummaryLoading;
  final bool isPostSubmissionInProgress;
  final String? summaryErrorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbonFeet'),
        bottom: isPostSubmissionInProgress
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
        actions: [
          IconButton(
            onPressed: isSummaryLoading || isPostSubmissionInProgress
                ? null
                : onOpenSimulator,
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
        onPressed: isSummaryLoading || isPostSubmissionInProgress
            ? null
            : onOpenPostMenu,
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
                  _buildHeadlineCard(),
                  const SizedBox(height: 12),
                  _buildComparisonCard(),
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
                  _buildAchievementsCard(),
                  const SizedBox(height: 12),
                  _buildRecentFlightsCard(context),
                  const SizedBox(height: 12),
                  _buildSimulatorCard(),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasSummaryError =>
      summaryErrorMessage != null && summaryErrorMessage!.trim().isNotEmpty;

  bool _isNonNegativeFinite(double value) => value.isFinite && value >= 0;

  bool _isPositiveFinite(double value) => value.isFinite && value > 0;

  Widget _buildHeadlineCard() {
    if (isSummaryLoading) {
      return _buildSectionCard(
        title: 'Summary',
        child: const _SectionStateView.loading(
          message: 'Calculating your latest footprint totals...',
        ),
      );
    }
    if (_hasSummaryError) {
      return _buildSectionCard(
        title: 'Summary',
        child: _SectionStateView.error(
          message: summaryErrorMessage!,
        ),
      );
    }

    final validYearToDate = _isNonNegativeFinite(summary.yearToDateKg);
    final validProjection = _isNonNegativeFinite(summary.projectedEndYearKg);
    if (!validYearToDate || !validProjection) {
      return _buildSectionCard(
        title: 'Summary',
        child: const _SectionStateView.error(
          message: 'Summary metrics are unavailable right now.',
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'CO2 emitted this year',
                value: '${_formatNumber(summary.yearToDateKg)} kg CO2e',
              ),
            ),
            Expanded(
              child: _MetricTile(
                label: 'End-of-year projection',
                value: '${_formatNumber(summary.projectedEndYearKg)} kg CO2e',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard() {
    if (isSummaryLoading) {
      return _buildSectionCard(
        title: 'Green vs red zone',
        child: const _SectionStateView.loading(
          message: 'Calculating your benchmark comparison...',
        ),
      );
    }
    if (_hasSummaryError) {
      return _buildSectionCard(
        title: 'Green vs red zone',
        child: _SectionStateView.error(
          message: summaryErrorMessage!,
        ),
      );
    }

    final hasValidData =
        _isNonNegativeFinite(summary.projectedEndYearKg) &&
        _isPositiveFinite(summary.countryAverageKg) &&
        _isPositiveFinite(summary.personalTargetKg) &&
        summary.comparisonLabel.trim().isNotEmpty;
    if (!hasValidData) {
      return _buildSectionCard(
        title: 'Green vs red zone',
        child: const _SectionStateView.error(
          message: 'Comparison data is unavailable right now.',
        ),
      );
    }

    return Card(
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
              ratio: summary.projectedEndYearKg / summary.countryAverageKg,
            ),
            const SizedBox(height: 8),
            _ReferenceBar(
              label:
                  'Personal target (${_formatNumber(summary.personalTargetKg)} kg)',
              ratio: summary.projectedEndYearKg / summary.personalTargetKg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    if (isSummaryLoading) {
      return _buildSectionCard(
        title: 'Category breakdown',
        child: const _SectionStateView.loading(
          message: 'Calculating category totals...',
        ),
      );
    }
    if (_hasSummaryError) {
      return _buildSectionCard(
        title: 'Category breakdown',
        child: _SectionStateView.error(
          message: summaryErrorMessage!,
        ),
      );
    }

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
    final hasInvalidData = labels.any((item) => !_isNonNegativeFinite(item.valueKg));
    if (hasInvalidData) {
      return _buildSectionCard(
        title: 'Category breakdown',
        child: const _SectionStateView.error(
          message: 'Category data is unavailable right now.',
        ),
      );
    }
    final totalKg = labels.fold<double>(0, (sum, item) => sum + item.valueKg);
    if (totalKg <= 0) {
      return _buildSectionCard(
        title: 'Category breakdown',
        child: const _SectionStateView.empty(
          message: 'No category data yet. Add your first CO2 post to populate this view.',
        ),
      );
    }

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
    if (isSummaryLoading) {
      return _buildSectionCard(
        title: 'Year trend (YTD)',
        child: const _SectionStateView.loading(
          message: 'Building your trend chart...',
        ),
      );
    }
    if (_hasSummaryError) {
      return _buildSectionCard(
        title: 'Year trend (YTD)',
        child: _SectionStateView.error(
          message: summaryErrorMessage!,
        ),
      );
    }

    final points = summary.monthlyTrendKg;
    if (points.isEmpty) {
      return _buildSectionCard(
        title: 'Year trend (YTD)',
        child: const _SectionStateView.empty(
          message: 'No trend data yet. Your timeline will appear after baseline data is available.',
        ),
      );
    }
    final hasInvalidPoints = points.any((value) => !_isNonNegativeFinite(value));
    final hasInvalidBreakdown =
        !_isNonNegativeFinite(summary.baselineYearlyKg) ||
        !_isNonNegativeFinite(summary.flightsYearlyKg);
    if (hasInvalidPoints || hasInvalidBreakdown || points.length < 2) {
      return _buildSectionCard(
        title: 'Year trend (YTD)',
        child: const _SectionStateView.error(
          message: 'Trend data is unavailable right now.',
        ),
      );
    }
    if (points.every((value) => value == 0)) {
      return _buildSectionCard(
        title: 'Year trend (YTD)',
        child: const _SectionStateView.empty(
          message: 'No emissions activity yet. Trend points will appear as you log data.',
        ),
      );
    }

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
              child: TrendChart(points: points),
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
    if (isSummaryLoading) {
      return _buildSectionCard(
        title: 'Recent flights',
        child: const _SectionStateView.loading(
          message: 'Loading your recent flights...',
        ),
      );
    }

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

  Widget _buildAchievementsCard() {
    if (isSummaryLoading) {
      return _buildSectionCard(
        title: 'Achievements',
        child: const _SectionStateView.loading(
          message: 'Checking badge progress...',
        ),
      );
    }
    if (_hasSummaryError) {
      return _buildSectionCard(
        title: 'Achievements',
        child: _SectionStateView.error(
          message: summaryErrorMessage!,
        ),
      );
    }

    return Card(
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
    );
  }

  Widget _buildSimulatorCard() {
    final disabled = isSummaryLoading || isPostSubmissionInProgress;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.auto_graph),
        title: const Text('What if simulator'),
        subtitle: Text(
          isSummaryLoading
              ? 'Simulator is temporarily unavailable while dashboard data refreshes.'
              : isPostSubmissionInProgress
              ? 'Simulator is temporarily unavailable while your latest update is saved.'
              : 'Explore how one less flight, lower driving, or less meat changes your projection.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: disabled ? null : onOpenSimulator,
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
    final safeRatio = ratio.isFinite ? ratio : 0.0;
    final clamped = safeRatio.clamp(0, 2).toDouble();
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

class _SectionStateView extends StatelessWidget {
  const _SectionStateView.loading({required this.message})
    : _kind = _SectionStateKind.loading;

  const _SectionStateView.empty({required this.message})
    : _kind = _SectionStateKind.empty;

  const _SectionStateView.error({required this.message})
    : _kind = _SectionStateKind.error;

  final String message;
  final _SectionStateKind _kind;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (_kind) {
          _SectionStateKind.loading => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          _SectionStateKind.empty => Icon(
            Icons.info_outline,
            color: Colors.blueGrey.shade600,
          ),
          _SectionStateKind.error => Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
          ),
        },
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}

enum _SectionStateKind { loading, empty, error }
