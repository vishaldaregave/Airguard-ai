import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airguard_ai/main.dart';
import 'package:airguard_ai/core/network/api_client.dart';
import 'package:airguard_ai/core/services/location_service.dart';
import 'package:airguard_ai/features/environmental_intelligence/data/repositories/environmental_repository.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/observation_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/aqi_result_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/risk_assessment_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/station_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/forecast_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/ai_explanation_model.dart';

class MockLocationService extends LocationService {
  @override
  Future<UserLocationResult> determinePosition() async {
    return UserLocationResult(
      latitude: 28.6139,
      longitude: 77.2090,
      isGpsLive: true,
      statusMessage: 'Mock GPS position acquired.',
    );
  }
}

class MockEnvironmentalRepository extends EnvironmentalRepository {
  MockEnvironmentalRepository() : super(ApiClient());

  @override
  Future<List<MonitoringStationSummary>> getNearbyStations(
    double lat,
    double lon, {
    double radiusKm = 25.0,
    bool includeDemo = true,
  }) async {
    return [
      MonitoringStationSummary(
        stationId: 'TEST-001',
        stationName: 'Test Monitoring Station [LIVE]',
        provider: 'OpenAQ Network',
        location: LocationCoordinate(latitude: 28.6, longitude: 77.2, city: 'Delhi'),
        distanceKm: 2.8,
        availablePollutants: ['PM2.5', 'PM10', 'NO2'],
        dataSourceType: 'LIVE',
        isActive: true,
      ),
    ];
  }

  @override
  Future<AssessmentResponse> getCurrentAirQuality({
    String? stationId,
    double? lat,
    double? lon,
  }) async {
    return AssessmentResponse(
      aqiResult: AQICalculationResult(
        standard: 'CPCB_INDIA',
        status: 'VALID',
        statusMessage: 'Valid test calculation',
        overallAqi: 240,
        category: 'Poor',
        colorCode: '#FF9900',
        prominentPollutant: 'PM2.5',
        subIndices: {},
        monitoredPollutantCount: 3,
        hasParticulateMatter: true,
        healthAdvisory: HealthAdvisory(
          category: 'Poor',
          generalStatement: 'Breathing discomfort to most people on prolonged exposure.',
          sensitiveGroupAdvice: 'People with lung disease should avoid prolonged exposure.',
          outdoorActivityAdvice: 'Limit strenuous outdoor exercise.',
        ),
        isStale: false,
        dataSourceType: 'LIVE',
        provider: 'OpenAQ Network',
        observationTimestamp: DateTime(2026, 11, 15, 12, 0),
        calculationTimestamp: DateTime(2026, 11, 15, 12, 5),
        location: LocationCoordinate(latitude: 28.6, longitude: 77.2, city: 'Delhi'),
      ),
      riskAssessment: EnvironmentalRiskScore(
        riskScore: 68,
        riskLevel: 'HIGH',
        riskSummary: 'High exposure risk.',
        primaryDriver: 'PM2.5',
        breakdown: [],
        activityRecommendations: [],
        disclaimer: 'Informational risk calculation only.',
      ),
      observation: EnvironmentalObservation(
        stationId: 'TEST-001',
        stationName: 'Test Monitoring Station [LIVE]',
        location: LocationCoordinate(latitude: 28.6, longitude: 77.2, city: 'Delhi'),
        timestamp: DateTime(2026, 11, 15, 12, 0),
        provider: 'OpenAQ Network',
        dataSourceType: 'LIVE',
        pm25: 120.0,
        pm10: 220.0,
        no2: 50.0,
        temperatureCelsius: 22.0,
        relativeHumidityPct: 60.0,
        windSpeedKmh: 10.0,
      ),
      station: MonitoringStationSummary(
        stationId: 'TEST-001',
        stationName: 'Test Monitoring Station [LIVE]',
        provider: 'OpenAQ Network',
        location: LocationCoordinate(latitude: 28.6, longitude: 77.2, city: 'Delhi'),
        distanceKm: 2.8,
        availablePollutants: ['PM2.5', 'PM10', 'NO2'],
        dataSourceType: 'LIVE',
        isActive: true,
      ),
      distanceFromQueryKm: 2.8,
      dataFreshnessMinutes: 15.0,
    );
  }

  @override
  Future<ForecastCurrentResponse> getForecast({
    String? stationId,
    double? lat,
    double? lon,
  }) async {
    return ForecastCurrentResponse(
      status: 'ACTIVE',
      stationId: 'TEST-001',
      stationName: 'Test Monitoring Station [LIVE]',
      dataSourceType: 'PHYSICAL_STATION',
      baseTimestamp: DateTime(2026, 11, 15, 12, 0),
      forecasts: [
        HorizonForecastStep(
          horizonHours: 1,
          targetTimestamp: DateTime(2026, 11, 15, 13, 0),
          predictedAqi: 245,
          predictedAqiCategory: 'Poor',
          predictedAqiColor: '#FF9900',
          predictedAqiProminentPollutant: 'PM2.5',
          isCpcbAqiValid: true,
          pollutantPredictions: {
            'PM2.5': PollutantPrediction(
              pollutant: 'PM2.5',
              unit: 'µg/m³',
              predictedValue: 125.0,
              ci95Lower: 105.0,
              ci95Upper: 145.0,
              ci90Lower: 110.0,
              ci90Upper: 140.0,
            ),
          },
        ),
        HorizonForecastStep(
          horizonHours: 3,
          targetTimestamp: DateTime(2026, 11, 15, 15, 0),
          predictedAqi: 255,
          predictedAqiCategory: 'Poor',
          isCpcbAqiValid: true,
          pollutantPredictions: {},
        ),
      ],
      modelMetadata: ForecastModelMetadata(
        modelType: 'AUTOREGRESSIVE_RIDGE',
        trainingSampleCount: 72,
        maePm25: 11.2,
        rmsePm25: 15.6,
      ),
      disclaimer: 'Statistical forecast. Real conditions may deviate.',
    );
  }

  @override
  Future<AIExplanationResponse> getAIExplanation({
    required AssessmentResponse assessment,
    int? historical24hAvgAqi,
  }) async {
    return AIExplanationResponse(
      status: 'SUCCESS',
      providerUsed: 'deterministic_expert_system',
      stationName: 'Test Monitoring Station',
      observationTimestamp: DateTime(2026, 11, 15, 12, 0),
      overallAqi: 240,
      aqiCategory: 'Poor',
      prominentPollutant: 'PM2.5',
      atmosphericDynamics: 'Boundary layer thermal compression trapping ground particulates.',
      primaryDriverAnalysis: 'Fine Particulate Matter (PM2.5) dominates the observed loading.',
      elevationCauses: 'Low nocturnal wind dispersion under steady surface pressure.',
      activityImplications: 'Sensitive groups should limit prolonged outdoor exertion.',
      practicalPrecautions: 'Use certified N95 masks for outdoor commutes.',
      historicalComparison: 'Air quality is within normal bounds for this seasonal window.',
      disclaimer: 'Informational synthesis only. Does not constitute clinical advice.',
    );
  }

  @override
  Future<List<ProviderStatusItem>> getProvidersStatus() async {
    return [
      ProviderStatusItem(
        name: 'openaq',
        displayName: 'OpenAQ Global Network',
        status: 'ONLINE',
        requiresApiKey: true,
        isAuthenticated: true,
        primaryDataType: 'LIVE',
        supportedPollutants: ['PM2.5', 'PM10', 'NO2'],
        attribution: 'OpenAQ Data',
        lastCheckTimestamp: DateTime.now(),
        latencyMs: 120.0,
      ),
    ];
  }
}

void main() {
  testWidgets('AirGuardApp smoke, forecasting, and AI explainer rendering test', (WidgetTester tester) async {
    final mockRepo = MockEnvironmentalRepository();
    final mockLoc = MockLocationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentalRepositoryProvider.overrideWithValue(mockRepo),
          locationServiceProvider.overrideWithValue(mockLoc),
        ],
        child: const AirGuardApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app title and environmental intelligence branding
    expect(find.text('AIRGUARD AI'), findsOneWidget);
    expect(find.text('ENVIRONMENTAL INTELLIGENCE'), findsOneWidget);

    // Verify station name and AQI display
    expect(find.textContaining('Test Monitoring Station'), findsWidgets);
    expect(find.text('CPCB AQI'), findsOneWidget);
    expect(find.text('240'), findsWidgets);

    // Verify provenance and distance display
    expect(find.text('LIVE MONITORING STATION'), findsOneWidget);
    expect(find.textContaining('2.8 km away'), findsWidgets);

    // Verify AI Explainer card rendering
    expect(find.text('AI ATMOSPHERIC EXPLAINER'), findsOneWidget);
    expect(find.text('DETERMINISTIC EXPERT SYSTEM'), findsOneWidget);
    expect(find.textContaining('Boundary layer thermal compression'), findsOneWidget);
    expect(find.textContaining('Fine Particulate Matter (PM2.5)'), findsOneWidget);

    // Verify Forecast Chart card rendering
    expect(find.text('AIR QUALITY FORECAST'), findsOneWidget);
    expect(find.text('FORECAST'), findsOneWidget);
    expect(find.text('+1h'), findsOneWidget);
    expect(find.text('+3h'), findsOneWidget);
  });
}
