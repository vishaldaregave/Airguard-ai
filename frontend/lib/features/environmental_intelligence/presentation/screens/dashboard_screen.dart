import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cloudy_background.dart';
import '../controllers/environmental_controller.dart';
import '../controllers/alert_controller.dart';
import '../widgets/data_integrity_badge.dart';
import '../widgets/futuristic_aqi_gauge.dart';
import '../widgets/pollutant_grid_card.dart';
import '../widgets/exposure_risk_meter.dart';
import '../widgets/health_advisory_card.dart';
import '../widgets/provider_status_sheet.dart';
import '../widgets/ai_explanation_card.dart';
import '../widgets/forecast_chart_card.dart';
import 'location_selector_sheet.dart';
import 'alert_inbox_screen.dart';
import 'geo_map_screen.dart';
import 'exposure_simulator_screen.dart';
import 'historical_intelligence_screen.dart';
import 'forecast_tab_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentNavIndex = 0;

  void _openLocationSheet(
    BuildContext context,
    EnvironmentalState state,
    EnvironmentalController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSelectorSheet(
        stations: state.nearbyStations,
        currentStation: state.selectedStation,
        currentLocation: state.userLocation,
        onStationSelected: (station) => controller.selectStation(station),
        onCitySelected: (lat, lon, city, stateName, country) {
          controller.changeLocation(
            lat,
            lon,
            cityName: city,
            stateName: stateName,
            countryName: country,
          );
        },
        onDetectLocation: () => controller.locateMe(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentalControllerProvider);
    final controller = ref.read(environmentalControllerProvider.notifier);
    final alertState = ref.watch(alertControllerProvider);

    return CloudyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.air,
                  color: AppColors.primaryBlue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AirGuard',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            // Personal Exposure Simulator Button
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExposureSimulatorScreen()),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Icon(Icons.timer_outlined, size: 18, color: AppColors.primaryBlue),
              ),
              tooltip: 'Personal Exposure Simulator',
            ),
            // Smart Alerts Inbox Button with Unread Badge
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AlertInboxScreen()),
                    );
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: const Icon(Icons.notifications_outlined, size: 18, color: AppColors.textPrimary),
                  ),
                  tooltip: 'Environmental Alerts',
                ),
                if (alertState.unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
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
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            // Telemetry Hub
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ProviderStatusSheet(providers: state.providerStatuses),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Icon(Icons.hub_outlined, size: 18, color: AppColors.textSecondary),
              ),
              tooltip: 'Data Providers Telemetry',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _currentNavIndex,
            children: [
              // Tab 0: Home / Main Dashboard
              RefreshIndicator(
                color: AppColors.primaryBlue,
                backgroundColor: AppColors.surface,
                onRefresh: () => controller.refreshCurrent(),
                child: _buildHomeTab(context, state, controller),
              ),

              // Tab 1: Map View (Geographic Intelligence)
              const GeoMapScreen(embedded: true),

              // Tab 2: Forecast (Hourly & 7-Day projections)
              const ForecastTabScreen(),

              // Tab 3: History (Historical Environmental Intelligence & Analytics)
              const HistoricalIntelligenceScreen(embedded: true),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 16,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentNavIndex,
            onTap: (index) => setState(() => _currentNavIndex = index),
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primaryBlue,
            unselectedItemColor: AppColors.textMuted,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map_rounded),
                label: 'Map View',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights_rounded),
                label: 'Forecast',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_outlined),
                activeIcon: Icon(Icons.history_rounded),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(
    BuildContext context,
    EnvironmentalState state,
    EnvironmentalController controller,
  ) {
    if (state.isLoading && state.currentAssessment == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
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
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final stationName = station?.stationName ??
        currentObs?.stationName ??
        'Regional Monitoring Point';
    final stationCity = station?.location.city ?? currentObs?.location.city ?? 'Local Area';
    final distKm = assessment.distanceFromQueryKm ?? station?.distanceKm;
    final riskAssessment = assessment.riskAssessment;

    // Location display text
    final loc = state.userLocation;
    final locationText = loc?.displayLocation ??
        (stationCity.isNotEmpty ? stationCity : 'Choose location');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Location + station selector (single merged card)
          InkWell(
            onTap: () => _openLocationSheet(context, state, controller),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      loc?.isGpsLive == true
                          ? Icons.my_location
                          : Icons.location_on,
                      size: 19,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                locationText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (loc?.isApproximate == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.amberAccent
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'approx',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.amberAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          distKm != null
                              ? '$stationName · ${distKm.toStringAsFixed(1)} km'
                              : stationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more,
                      size: 20, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Data Integrity Badge
          DataIntegrityBadge(
            aqiResult: assessment.aqiResult,
            station: station,
            distanceFromUserKm: distKm,
            freshnessMinutes: assessment.dataFreshnessMinutes,
          ),
          const SizedBox(height: 14),

          // Primary AQI Speedometer Arc Gauge (Dribbble shot inspiration)
          if (assessment.aqiResult.overallAqi != null) ...[
            FuturisticAqiGauge(aqiResult: assessment.aqiResult),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, size: 36, color: AppColors.aqiModerate),
                  const SizedBox(height: 10),
                  const Text(
                    'CPCB Calculation Rule Not Satisfied',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    assessment.aqiResult.statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Quick Metric Row (Side-by-side cards from Dribbble shot)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.show_chart, size: 14, color: AppColors.skyBlue),
                          SizedBox(width: 6),
                          Text(
                            'Air Quality Trend',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assessment.aqiResult.overallAqi != null && assessment.aqiResult.overallAqi! <= 100
                            ? 'Optimal'
                            : 'Elevated',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: AppColors.primaryBlue),
                          SizedBox(width: 6),
                          Text(
                            'Exposure Risk',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        riskAssessment.riskLevel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.getAqiColor(assessment.aqiResult.overallAqi),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pollutant Breakdown
          if (assessment.aqiResult.subIndices.isNotEmpty) ...[
            PollutantGridCard(subIndices: assessment.aqiResult.subIndices),
            const SizedBox(height: 14),
          ],

          // Forecast Chart Card
          ForecastChartCard(
            forecast: state.forecast,
            currentAqi: assessment.aqiResult,
            selectedHorizon: state.selectedHorizonHours,
            isLoading: state.isForecastLoading,
            onHorizonSelected: (h) => controller.selectForecastHorizon(h),
          ),
          const SizedBox(height: 14),

          // AI Atmospheric Explainer
          AIExplanationCard(
            explanation: state.aiExplanation,
            isLoading: state.isAILoading,
            onRefresh: () => controller.refreshCurrent(),
          ),
          const SizedBox(height: 14),

          // Health Advisory & Precautions
          if (assessment.aqiResult.healthAdvisory != null) ...[
            HealthAdvisoryCard(advisory: assessment.aqiResult.healthAdvisory!),
            const SizedBox(height: 14),
          ],

          // Exposure Risk Meter
          ExposureRiskMeter(riskAssessment: riskAssessment),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
