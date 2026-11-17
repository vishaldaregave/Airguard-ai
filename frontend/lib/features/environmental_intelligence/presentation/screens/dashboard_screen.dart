import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/observation_model.dart';
import '../controllers/environmental_controller.dart';
import '../controllers/alert_controller.dart';
import '../widgets/data_integrity_badge.dart';
import '../widgets/futuristic_aqi_gauge.dart';
import '../widgets/pollutant_grid_card.dart';
import '../widgets/exposure_risk_meter.dart';
import '../widgets/health_advisory_card.dart';
import '../widgets/provider_status_sheet.dart';
import '../widgets/forecast_chart_card.dart';
import '../widgets/ai_explanation_card.dart';
import 'station_selector_sheet.dart';
import 'alert_inbox_screen.dart';
import 'geo_map_screen.dart';
import 'exposure_simulator_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentalControllerProvider);
    final controller = ref.read(environmentalControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.emeraldAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.air,
                color: AppColors.emeraldAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AIRGUARD AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'ENVIRONMENTAL INTELLIGENCE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Personal Exposure Simulator (Milestone 5.2)
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExposureSimulatorScreen()),
              );
            },
            icon: const Icon(Icons.timer_outlined, color: AppColors.emeraldAccent),
            tooltip: 'Personal Exposure Simulator',
          ),
          // Geographic Intelligence & Spatial Map (Milestone 5.1)
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GeoMapScreen()),
              );
            },
            icon: const Icon(Icons.map_outlined, color: AppColors.cyanAccent),
            tooltip: 'Geographic Intelligence & Spatial Map',
          ),
          // Environmental Alerts Inbox Button with Unread Badge
          Consumer(
            builder: (context, ref, _) {
              final alertState = ref.watch(alertControllerProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AlertInboxScreen()),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.cyanAccent),
                    tooltip: 'Environmental Alerts',
                  ),
                  if (alertState.unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.aqiPoor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${alertState.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ProviderStatusSheet(providers: state.providerStatuses),
              );
            },
            icon: const Icon(Icons.hub_outlined, color: AppColors.textSecondary),
            tooltip: 'Data Providers Telemetry',
          ),
          IconButton(
            onPressed: () => controller.locateMe(),
            icon: const Icon(Icons.my_location, color: AppColors.emeraldAccent),
            tooltip: 'Detect GPS Location',
          ),
          IconButton(
            onPressed: () => controller.refreshCurrent(),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Refresh Intelligence',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.emeraldAccent,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () => controller.refreshCurrent(),
          child: _buildBody(context, ref, state, controller),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    EnvironmentalState state,
    EnvironmentalController controller,
  ) {
    if (state.isLoading && state.currentAssessment == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldAccent),
            ),
            SizedBox(height: 16),
            Text(
              'Retrieving Environmental Telemetry...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.currentAssessment == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.aqiPoor),
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => controller.initialize(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final assessment = state.currentAssessment;
    final currentObs = state.currentObservation ?? assessment?.observation;

    if (assessment == null) {
      return const SizedBox.shrink();
    }

    final station = state.selectedStation ?? assessment.station;
    final stationName = station?.stationName ?? currentObs?.stationName ?? 'Regional Monitoring Point';
    final stationCity = station?.location.city ?? currentObs?.location.city ?? 'Local Area';
    final distKm = assessment.distanceFromQueryKm ?? station?.distanceKm;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Station Selector Banner
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => StationSelectorSheet(
                  stations: state.nearbyStations,
                  current: state.selectedStation,
                  onSelected: (selected) => controller.selectStation(selected),
                  onLocateMe: () => controller.locateMe(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: AppColors.emeraldAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stationName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              stationCity,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            if (distKm != null) ...[
                              const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                              Text(
                                '${distKm.toStringAsFixed(1)} km away',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.cyanAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Data Integrity Badge
          DataIntegrityBadge(
            aqiResult: assessment.aqiResult,
            station: station,
            distanceFromUserKm: distKm,
            freshnessMinutes: assessment.dataFreshnessMinutes,
          ),
          const SizedBox(height: 14),

          // Primary AQI Gauge or Insufficient Pollutants Message
          if (assessment.aqiResult.overallAqi != null) ...[
            FuturisticAqiGauge(aqiResult: assessment.aqiResult),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, size: 36, color: AppColors.aqiModerate),
                  const SizedBox(height: 10),
                  const Text(
                    'INCOMPLETE POLLUTANT SUITE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assessment.aqiResult.statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Meteorology Strip (if observed)
          if (currentObs != null) ...[
            _buildMeteorologyStrip(currentObs),
            const SizedBox(height: 14),
          ],

          // AI Atmospheric Explainer Card (Milestone 3)
          AIExplanationCard(
            explanation: state.aiExplanation,
            isLoading: state.isAILoading,
            onRefresh: () => controller.refreshCurrent(),
          ),
          const SizedBox(height: 14),

          // Multi-Horizon Air Quality Forecast Card (Milestone 3)
          ForecastChartCard(
            forecast: state.forecast,
            currentAqi: assessment.aqiResult,
            selectedHorizon: state.selectedHorizonHours,
            isLoading: state.isForecastLoading,
            onHorizonSelected: (h) => controller.selectForecastHorizon(h),
          ),
          const SizedBox(height: 14),

          // Explainable Exposure Risk Meter
          ExposureRiskMeter(riskAssessment: assessment.riskAssessment),
          const SizedBox(height: 14),

          // Personal Exposure Simulator Banner (Milestone 5.2)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExposureSimulatorScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceCard,
                    AppColors.cyanAccent.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.timer_outlined, color: AppColors.cyanAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PERSONAL EXPOSURE SIMULATOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.cyanAccent,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Estimate cumulative inhaled mass based on activity (Resting, Walking, Running) and duration.',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.cyanAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // CPCB Health Advisory
          if (assessment.aqiResult.healthAdvisory != null) ...[
            HealthAdvisoryCard(advisory: assessment.aqiResult.healthAdvisory!),
            const SizedBox(height: 14),
          ],

          // Pollutant Breakdown Grid
          PollutantGridCard(subIndices: assessment.aqiResult.subIndices),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMeteorologyStrip(EnvironmentalObservation obs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetItem(
            icon: Icons.thermostat,
            label: 'Temperature',
            value: obs.temperatureCelsius != null ? '${obs.temperatureCelsius!.toStringAsFixed(1)} °C' : '--',
          ),
          Container(width: 1, height: 28, color: AppColors.border),
          _buildMetItem(
            icon: Icons.water_drop_outlined,
            label: 'Humidity',
            value: obs.relativeHumidityPct != null ? '${obs.relativeHumidityPct!.toStringAsFixed(0)}%' : '--',
          ),
          Container(width: 1, height: 28, color: AppColors.border),
          _buildMetItem(
            icon: Icons.air,
            label: 'Wind Speed',
            value: obs.windSpeedKmh != null ? '${obs.windSpeedKmh!.toStringAsFixed(1)} km/h' : '--',
          ),
        ],
      ),
    );
  }

  Widget _buildMetItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.cyanAccent),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ],
    );
  }
}
