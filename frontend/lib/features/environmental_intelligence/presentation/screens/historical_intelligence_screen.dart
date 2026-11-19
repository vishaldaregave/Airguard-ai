import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/history_analytics_models.dart';
import '../controllers/environmental_controller.dart';
import '../controllers/history_controller.dart';

class HistoricalIntelligenceScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const HistoricalIntelligenceScreen({super.key, this.embedded = false});

  @override
  ConsumerState<HistoricalIntelligenceScreen> createState() =>
      _HistoricalIntelligenceScreenState();
}

class _HistoricalIntelligenceScreenState
    extends ConsumerState<HistoricalIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    final body = SafeArea(
      child: Column(
        children: [
          // Sticky top control panel: Station selector & Period selector
          _buildStationAndPeriodHeader(context, state, controller),

          // Main Tab View
          Expanded(
            child: state.isLoading && state.summary == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.cyanAccent),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading environmental archive...',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(context, state, controller),
                      _buildPollutantsTab(context, state),
                      _buildCalendarTab(context, state),
                      _buildExtremesAndGapsTab(context, state),
                      _buildComparisonTab(context, state, controller),
                    ],
                  ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Material(
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(child: _buildTabBar()),
                IconButton(
                  onPressed: () => _showReportDialog(context, ref),
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      size: 19, color: AppColors.cyanAccent),
                  tooltip: 'Export historical report',
                ),
                IconButton(
                  onPressed: () => controller.fetchHistoryData(),
                  icon: const Icon(Icons.refresh,
                      size: 19, color: AppColors.textSecondary),
                  tooltip: 'Refresh history',
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historical Intelligence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              state.selectedStationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.cyanAccent,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showReportDialog(context, ref),
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: AppColors.cyanAccent),
            tooltip: 'Export Historical Environmental Report',
          ),
          IconButton(
            onPressed: () => controller.fetchHistoryData(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Refresh Historical Telemetry',
          ),
          const SizedBox(width: 4),
        ],
        bottom: _buildTabBar(),
      ),
      body: body,
    );
  }

  TabBar _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: AppColors.cyanAccent,
      indicatorWeight: 3,
      labelColor: AppColors.cyanAccent,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      tabs: const [
        Tab(text: 'OVERVIEW & TRENDS'),
        Tab(text: 'POLLUTANTS'),
        Tab(text: 'CALENDAR'),
        Tab(text: 'EXTREMES & GAPS'),
        Tab(text: 'COMPARISON'),
      ],
    );
  }

  // =========================================================================
  // 1. TOP CONTROL PANEL (STATION + PERIOD SELECTOR)
  // =========================================================================
  Widget _buildStationAndPeriodHeader(
    BuildContext context,
    HistoryState state,
    HistoryController controller,
  ) {
    final periods = ['24h', '7d', '30d', '90d'];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              // Station Identity & Provenance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          state.isPhysicalStation ? Icons.sensors : Icons.grid_4x4,
                          size: 15,
                          color: state.isPhysicalStation
                              ? AppColors.liveBadge
                              : AppColors.estimatedBadge,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            state.selectedStationName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: (state.isPhysicalStation
                                    ? AppColors.liveBadge
                                    : AppColors.estimatedBadge)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (state.isPhysicalStation
                                      ? AppColors.liveBadge
                                      : AppColors.estimatedBadge)
                                  .withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            state.isPhysicalStation
                                ? 'PHYSICAL GROUND SENSOR'
                                : 'ATMOSPHERIC MODEL GRID',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: state.isPhysicalStation
                                  ? AppColors.liveBadge
                                  : AppColors.estimatedBadge,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${state.selectedStationId}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Recenter analytics on the user's current location
              IconButton(
                icon: const Icon(Icons.my_location,
                    color: AppColors.cyanAccent),
                tooltip: 'Use my current location',
                onPressed: () => ref
                    .read(environmentalControllerProvider.notifier)
                    .locateMe(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Period Chips
          Row(
            children: periods.map((p) {
              final isSelected = state.selectedPeriod == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => controller.setPeriod(p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.cyanAccent.withValues(alpha: 0.18)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.cyanAccent
                            : AppColors.border,
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Text(
                      p.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.cyanAccent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW & TRENDS
  // =========================================================================
  Widget _buildOverviewTab(
    BuildContext context,
    HistoryState state,
    HistoryController controller,
  ) {
    final summary = state.summary;
    final trends = state.trends;

    if (summary == null) {
      return const Center(child: Text('No historical observations found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Metric Row
          _buildKpiMetrics(summary),
          const SizedBox(height: 16),

          // 2. AQI Historical Trend Chart (FL Chart)
          _buildAqiTrendChartCard(trends),
          const SizedBox(height: 16),

          // 3. Diurnal Cycle Profile (Hourly Means)
          if (trends != null && trends.diurnalProfile.isNotEmpty) ...[
            _buildDiurnalCycleCard(trends.diurnalProfile),
            const SizedBox(height: 16),
          ],

          // 4. Evidence-Based Explanation Narrative
          _buildExplanationCard(state, controller),
          const SizedBox(height: 16),

          // 5. Scientific Disclaimer & Non-Causal Disclosure
          _buildDisclaimerCard(summary.disclaimer),
        ],
      ),
    );
  }

  Widget _buildKpiMetrics(HistoricalSummaryModel summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                label: 'MEAN CPCB AQI',
                value: summary.aqiMean != null
                    ? summary.aqiMean!.toStringAsFixed(1)
                    : 'N/A',
                sublabel: summary.aqiMedian != null
                    ? 'Median: ${summary.aqiMedian!.toStringAsFixed(0)}'
                    : 'Sparse Data',
                color: AppColors.getAqiColor(summary.aqiMean?.round()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                label: 'MIN / MAX AQI',
                value: summary.aqiMin != null && summary.aqiMax != null
                    ? '${summary.aqiMin} — ${summary.aqiMax}'
                    : 'N/A',
                sublabel: summary.aqiStd != null
                    ? 'Std: ±${summary.aqiStd!.toStringAsFixed(1)}'
                    : 'Std: N/A',
                color: AppColors.cyanAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                label: 'TREND TRAJECTORY',
                value: summary.overallTrend,
                sublabel: summary.overallTrend == 'INCREASING'
                    ? 'Worsening pollution'
                    : (summary.overallTrend == 'DECREASING'
                        ? 'Improving conditions'
                        : 'Stationary baseline'),
                color: summary.overallTrend == 'INCREASING'
                    ? AppColors.aqiPoor
                    : (summary.overallTrend == 'DECREASING'
                        ? AppColors.aqiGood
                        : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                label: 'DATA COVERAGE',
                value: '${summary.dataCoveragePct.toStringAsFixed(1)}%',
                sublabel:
                    '${summary.totalRecords} / ${summary.expectedSamples} samples (${summary.missingIntervalsCount} gaps)',
                color: summary.dataCoveragePct >= 75
                    ? AppColors.liveBadge
                    : (summary.dataCoveragePct >= 50
                        ? AppColors.aqiModerate
                        : AppColors.staleBadge),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sublabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAqiTrendChartCard(HistoricalTrendsModel? trends) {
    final timeseries = trends?.timeseries ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHRONOLOGICAL AQI TRAJECTORY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hourly telemetry plotted without synthetic interpolation',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trends?.slopeAqiPerDay != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Slope: ${trends!.slopeAqiPerDay! >= 0 ? "+" : ""}${trends.slopeAqiPerDay!.toStringAsFixed(1)} / day',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyanAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (timeseries.isEmpty)
            const SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No chronological observation points available for this interval.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: AppColors.border,
                      strokeWidth: 0.8,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 &&
                              idx < timeseries.length &&
                              idx % (timeseries.length > 24 ? 12 : 6) == 0) {
                            final t = timeseries[idx].timestamp;
                            return Text(
                              '${t.hour}:00',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 9),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: timeseries.asMap().entries.map((e) {
                        return FlSpot(
                          e.key.toDouble(),
                          (e.value.calculatedAqi ?? 100).toDouble(),
                        );
                      }).toList(),
                      isCurved: false, // Honest stepped/linear observations
                      color: AppColors.cyanAccent,
                      barWidth: 2.2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: timeseries.length <= 24,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 2.5,
                          color: AppColors.cyanAccent,
                          strokeWidth: 1,
                          strokeColor: AppColors.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.cyanAccent.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiurnalCycleCard(Map<int, double?> diurnalProfile) {
    final validPoints = diurnalProfile.entries
        .where((e) => e.value != null)
        .map((e) => FlSpot(e.key.toDouble(), e.value!))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wb_twilight, size: 16, color: AppColors.cobaltAccent),
              SizedBox(width: 8),
              Text(
                'DIURNAL CYCLE PROFILE (HOURLY MEAN AQI)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aggregated 24-hour diurnal cycle revealing boundary layer inversion dynamics',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 23,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 8.5),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      interval: 4,
                      getTitlesWidget: (v, m) => Text(
                        '${v.toInt()}h',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 9),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: validPoints,
                    isCurved: true,
                    color: AppColors.cobaltAccent,
                    barWidth: 2.4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.cobaltAccent.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(HistoryState state, HistoryController controller) {
    final expl = state.explanation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined,
                  size: 18, color: AppColors.cyanAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'EVIDENCE-BASED SCIENTIFIC NARRATIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ),
              if (state.isExplaining)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.cyanAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (expl != null) ...[
            Text(
              expl.narrative,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Key Takeaways
            ...expl.keyInsights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(
                              color: AppColors.cyanAccent, fontSize: 13)),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ] else
            const Text(
              'Analyzing historical patterns...',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard(String disclaimer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimer,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: CRITERIA POLLUTANTS
  // =========================================================================
  Widget _buildPollutantsTab(BuildContext context, HistoryState state) {
    final pollutants = state.summary?.pollutantSummaries ?? {};

    if (pollutants.isEmpty) {
      return const Center(
        child: Text(
          'No criteria pollutant breakdowns recorded for this period.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: pollutants.entries.map((entry) {
        final p = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        p.pollutant,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${p.unit})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (p.trend == 'INCREASING'
                              ? AppColors.aqiPoor
                              : (p.trend == 'DECREASING'
                                  ? AppColors.aqiGood
                                  : AppColors.textMuted))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (p.trend == 'INCREASING'
                                ? AppColors.aqiPoor
                                : (p.trend == 'DECREASING'
                                    ? AppColors.aqiGood
                                    : AppColors.textMuted))
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${p.trend} (${p.slopePerDay != null && p.slopePerDay! >= 0 ? "+" : ""}${p.slopePerDay?.toStringAsFixed(1) ?? "0.0"}/d)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: p.trend == 'INCREASING'
                            ? AppColors.aqiPoor
                            : (p.trend == 'DECREASING'
                                ? AppColors.aqiGood
                                : AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Pollutant Mean, Min, Max, Completeness
              Row(
                children: [
                  Expanded(
                    child: _buildSubStat(
                      label: 'MEAN CONCENTRATION',
                      value: p.mean != null ? '${p.mean!.toStringAsFixed(1)} ${p.unit}' : 'N/A',
                    ),
                  ),
                  Expanded(
                    child: _buildSubStat(
                      label: 'MIN / MAX RANGE',
                      value: p.minValue != null && p.maxValue != null
                          ? '${p.minValue!.toStringAsFixed(0)} - ${p.maxValue!.toStringAsFixed(0)}'
                          : 'N/A',
                    ),
                  ),
                  Expanded(
                    child: _buildSubStat(
                      label: 'COMPLETENESS',
                      value: '${p.completenessPct.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Regulatory Exceedance Indicator
              if (p.statutoryStandardExceededCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.aqiPoor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 13, color: AppColors.aqiPoor),
                      const SizedBox(width: 6),
                      Text(
                        'Exceeded 24h statutory standard in ${p.statutoryStandardExceededCount} hourly readings',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.aqiPoor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: DAILY POLLUTION CALENDAR
  // =========================================================================
  Widget _buildCalendarTab(BuildContext context, HistoryState state) {
    final calendar = state.calendar;

    if (calendar == null || calendar.days.isEmpty) {
      return const Center(child: Text('No calendar records loaded.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCalMetric('TOTAL DAYS', '${calendar.totalDays}'),
                _buildCalMetric('VALID (≥16h)', '${calendar.sufficientDays}',
                    color: AppColors.liveBadge),
                _buildCalMetric('INSUFFICIENT', '${calendar.insufficientDays}',
                    color: AppColors.aqiModerate),
                _buildCalMetric('UNAVAILABLE', '${calendar.unavailableDays}',
                    color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // CPCB 16-Hour Rule Disclosure
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cobaltAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.cobaltAccent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.cobaltAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CPCB NAAQS Requirement: Minimum 16 hourly samples required for valid statutory daily AQI.',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.cobaltAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendar.days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, // 7 days of the week
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (ctx, idx) {
              final day = calendar.days[idx];
              return _buildCalendarDayCell(context, day);
            },
          ),
          const SizedBox(height: 16),

          // Legend
          _buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildCalMetric(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCalendarDayCell(BuildContext context, CalendarDayModel day) {
    Color cellColor = AppColors.surfaceElevated;
    Color textColor = AppColors.textMuted;
    Border border = Border.all(color: AppColors.border, width: 0.6);

    if (day.isUnavailable) {
      cellColor = AppColors.surface.withValues(alpha: 0.3);
      textColor = AppColors.textMuted.withValues(alpha: 0.4);
    } else if (day.isSufficient && day.representativeAqi != null) {
      cellColor = AppColors.getAqiColor(day.representativeAqi).withValues(alpha: 0.22);
      textColor = AppColors.getAqiColor(day.representativeAqi);
      border = Border.all(color: textColor.withValues(alpha: 0.6), width: 1.0);
    } else {
      // Insufficient samples (<16 hours)
      cellColor = AppColors.aqiModerate.withValues(alpha: 0.12);
      textColor = AppColors.aqiModerate;
    }

    final dayNum = day.date.split('-').last;

    return InkWell(
      onTap: () => _showDayDetailSheet(context, day),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNum,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            if (day.isUnavailable)
              const Text('—', style: TextStyle(fontSize: 9, color: AppColors.textMuted))
            else if (!day.isSufficient)
              const Text(
                'PROV',
                style: TextStyle(fontSize: 7.5, color: AppColors.aqiModerate),
              )
            else if (day.representativeAqi != null)
              Text(
                '${day.representativeAqi}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              )
            else
              const Text(
                '—',
                style: TextStyle(fontSize: 7.5, color: AppColors.textMuted),
              ),
            Text(
              '${day.sampleCount}h',
              style: const TextStyle(fontSize: 7, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildLegendItem('Good (0-50)', AppColors.aqiGood),
          _buildLegendItem('Satisfactory (51-100)', AppColors.aqiSatisfactory),
          _buildLegendItem('Moderate (101-200)', AppColors.aqiModerate),
          _buildLegendItem('Poor (201-300)', AppColors.aqiPoor),
          _buildLegendItem('Very Poor (301-400)', AppColors.aqiVeryPoor),
          _buildLegendItem('Severe (401-500)', AppColors.aqiSevere),
          _buildLegendItem('Unavailable (<16h)', AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showDayDetailSheet(BuildContext context, CalendarDayModel day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${day.date} (${day.dayOfWeek})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (day.isSufficient
                            ? AppColors.liveBadge
                            : AppColors.staleBadge)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    day.isSufficient ? 'CPCB SUFFICIENT' : 'INSUFFICIENT SAMPLES',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: day.isSufficient
                          ? AppColors.liveBadge
                          : AppColors.staleBadge,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              'Representative AQI: ${day.representativeAqi ?? "N/A"} (${day.aqiCategory ?? "N/A"})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.getAqiColor(day.representativeAqi),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Samples Recorded: ${day.sampleCount} / 24 hours (${day.dataCoveragePct.toStringAsFixed(1)}% coverage)',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (day.meanPm25 != null) ...[
              const SizedBox(height: 4),
              Text(
                'Mean PM2.5: ${day.meanPm25!.toStringAsFixed(1)} µg/m³',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),

            Text(
              day.regulatoryDisclosure,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 4: EXTREMES & DATA GAPS
  // =========================================================================
  Widget _buildExtremesAndGapsTab(BuildContext context, HistoryState state) {
    final extremes = state.extremes;
    final coverage = state.coverage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Peaks and Cleanest Episodes Card
          if (extremes != null) ...[
            _buildExtremesSection(extremes),
            const SizedBox(height: 16),
          ],

          // Data Coverage & Missing Intervals Audit
          if (coverage != null) ...[
            _buildCoverageAuditSection(coverage),
          ],
        ],
      ),
    );
  }

  Widget _buildExtremesSection(HistoricalExtremesModel extremes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, size: 16, color: AppColors.aqiPoor),
              SizedBox(width: 8),
              Text(
                'POLLUTION EXTREMES & EPISODES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Maximum and Minimum points
          Row(
            children: [
              Expanded(
                child: _buildSubStat(
                  label: 'PERIOD MAXIMUM AQI',
                  value: extremes.maximumAqi != null
                      ? '${extremes.maximumAqi}'
                      : 'N/A',
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  label: 'PERIOD MINIMUM AQI',
                  value: extremes.minimumAqi != null
                      ? '${extremes.minimumAqi}'
                      : 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Peak Episodes List
          const Text(
            'Detected Peak Stagnation Episodes:',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (extremes.peakEpisodes.isEmpty)
            const Text(
              'No elevated pollution episodes detected during this period.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            )
          else
            ...extremes.peakEpisodes.map((ep) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.aqiPoor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    ep.physicalDescription,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textPrimary, height: 1.3),
                  ),
                )),

          const SizedBox(height: 10),
          // Cleanest Periods List
          const Text(
            'Detected Cleanest Dispersion Intervals:',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (extremes.cleanestPeriods.isEmpty)
            const Text(
              'No distinct clean episodes identified.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            )
          else
            ...extremes.cleanestPeriods.map((ep) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.aqiGood.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    ep.physicalDescription,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textPrimary, height: 1.3),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildCoverageAuditSection(HistoricalCoverageModel coverage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 16, color: AppColors.cyanAccent),
              SizedBox(width: 8),
              Text(
                'DATA COVERAGE & MISSING INTERVAL AUDIT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildSubStat(
                  label: 'TEMPORAL REGULARITY',
                  value: '${coverage.temporalRegularityScore.toStringAsFixed(1)} / 100',
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  label: 'DETECTED GAPS (>2h)',
                  value: '${coverage.gapsCount}',
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  label: 'LONGEST GAP',
                  value: '${coverage.longestGapHours.toStringAsFixed(0)} hours',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (coverage.gaps.isEmpty)
            const Text(
              'Telemetry stream is unbroken with zero detected temporal gaps.',
              style: TextStyle(fontSize: 11, color: AppColors.liveBadge),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unobserved Telemetry Gaps (Disclosed Without Zero-Filling):',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                ...coverage.gaps.take(4).map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${g.durationHours.toStringAsFixed(1)}h missing between ${g.gapStart.month}/${g.gapStart.day} and ${g.gapEnd.month}/${g.gapEnd.day}',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    )),
              ],
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 5: LOCATION COMPARISON
  // =========================================================================
  Widget _buildComparisonTab(
    BuildContext context,
    HistoryState state,
    HistoryController controller,
  ) {
    final comp = state.comparison;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Comparison Station Selector Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPARE WITH SECOND MONITORING LOCATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.comparisonStationId.isEmpty
                      ? 'Pick a reference city to compare against your current location.'
                      : 'Comparing with: ${state.comparisonStationId}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LocationService.popularCities.map((city) {
                    final id = HistoryController.stationIdFor(
                        city.latitude, city.longitude);
                    final isSelected = state.comparisonStationId == id;
                    return ChoiceChip(
                      label: Text(city.name),
                      selected: isSelected,
                      onSelected: (_) =>
                          controller.setComparisonStation(id),
                      selectedColor:
                          AppColors.cyanAccent.withValues(alpha: 0.22),
                      backgroundColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? AppColors.cyanAccent
                            : AppColors.textSecondary,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.cyanAccent
                            : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (comp == null)
            const Center(
              child: Text(
                'Select a second station to generate comparative environmental differences.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else ...[
            // Compatibility Warning / Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (comp.isCompatible
                        ? AppColors.cobaltAccent
                        : AppColors.aqiPoor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (comp.isCompatible
                          ? AppColors.cobaltAccent
                          : AppColors.aqiPoor)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comp.compatibilityNotes
                    .map((note) => Text(
                          note,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: comp.isCompatible
                                ? AppColors.textPrimary
                                : AppColors.aqiPoor,
                            height: 1.3,
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Comparison Metrics Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HISTORICAL DELTA BREAKDOWN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _buildSubStat(
                          label: 'STATION A MEAN AQI',
                          value: comp.aqiMeanA != null
                              ? comp.aqiMeanA!.toStringAsFixed(1)
                              : 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildSubStat(
                          label: 'STATION B MEAN AQI',
                          value: comp.aqiMeanB != null
                              ? comp.aqiMeanB!.toStringAsFixed(1)
                              : 'N/A',
                        ),
                      ),
                      Expanded(
                        child: _buildSubStat(
                          label: 'NET DIFFERENCE',
                          value: comp.aqiDifference != null
                              ? '${comp.aqiDifference! >= 0 ? "+" : ""}${comp.aqiDifference!.toStringAsFixed(1)}'
                              : 'N/A',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Pollutant Concentration Differences (Station A − Station B):',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),

                  ...comp.pollutantDifferences.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              '${e.value >= 0 ? "+" : ""}${e.value.toStringAsFixed(1)} µg/m³',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: e.value > 0
                                    ? AppColors.aqiPoor
                                    : AppColors.aqiGood,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // REPORT EXPORT DIALOG
  // =========================================================================
  void _showReportDialog(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(historyControllerProvider.notifier);
    final report = await controller.generateReport();

    if (!context.mounted || report == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.description_outlined,
                color: AppColors.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'HISTORICAL AUDIT REPORT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: report.markdownContent));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Markdown report copied to clipboard.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18, color: AppColors.cyanAccent),
              tooltip: 'Copy Markdown',
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Period: ${report.period} | Station: ${report.stationName}',
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
                const Divider(color: AppColors.border, height: 20),

                const Text(
                  'Executive Summary:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.executiveSummary,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),

                const Text(
                  'Report Document Content (Markdown):',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    report.markdownContent,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
