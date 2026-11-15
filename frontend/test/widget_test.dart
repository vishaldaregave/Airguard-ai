import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airguard_ai/main.dart';
import 'package:airguard_ai/core/network/api_client.dart';
import 'package:airguard_ai/features/environmental_intelligence/data/repositories/environmental_repository.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/observation_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/aqi_result_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/risk_assessment_model.dart';

class MockEnvironmentalRepository extends EnvironmentalRepository {
  MockEnvironmentalRepository() : super(ApiClient());

  @override
  Future<List<EnvironmentalObservation>> getDemoFixtures() async {
    return [
      EnvironmentalObservation(
        stationId: 'TEST-001',
        stationName: 'Test Monitoring Station [DEMO FIXTURE]',
        location: LocationCoordinate(latitude: 28.6, longitude: 77.2, city: 'Delhi'),
        timestamp: DateTime(2026, 11, 15, 12, 0),
        provider: 'Test Feed',
        dataSourceType: 'DEMO_FIXTURE',
        pm25: 120.0,
        pm10: 220.0,
        no2: 50.0,
        temperatureCelsius: 22.0,
        relativeHumidityPct: 60.0,
        windSpeedKmh: 10.0,
      ),
    ];
  }

  @override
  Future<AssessmentResponse> calculateAssessment(EnvironmentalObservation observation) async {
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
        dataSourceType: 'DEMO_FIXTURE',
        provider: 'Test Feed',
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
    );
  }
}

void main() {
  testWidgets('AirGuardApp smoke and rendering test with mock repository', (WidgetTester tester) async {
    final mockRepo = MockEnvironmentalRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentalRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const AirGuardApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app title and environmental intelligence branding
    expect(find.text('AIRGUARD AI'), findsOneWidget);
    expect(find.text('ENVIRONMENTAL INTELLIGENCE'), findsOneWidget);

    // Verify station name and AQI display
    expect(find.textContaining('Test Monitoring Station'), findsOneWidget);
    expect(find.text('CPCB AQI'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
  });
}
