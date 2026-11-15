import 'package:flutter_test/flutter_test.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/observation_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/risk_assessment_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/station_model.dart';

void main() {
  group('Domain Models Serialization', () {
    test('EnvironmentalObservation parses correctly from json', () {
      final json = {
        'station_id': 'TEST-001',
        'station_name': 'Test Station',
        'location': {
          'latitude': 28.6,
          'longitude': 77.2,
          'city': 'Delhi',
          'country': 'India',
        },
        'timestamp': '2026-11-15T10:00:00Z',
        'provider': 'Test Provider',
        'data_source_type': 'DEMO_FIXTURE',
        'pm2_5': 120.0,
        'pm10': 200.0,
      };

      final obs = EnvironmentalObservation.fromJson(json);
      expect(obs.stationId, 'TEST-001');
      expect(obs.pm25, 120.0);
      expect(obs.pm10, 200.0);
      expect(obs.dataSourceType, 'DEMO_FIXTURE');
    });

    test('MonitoringStationSummary parses correctly from json', () {
      final json = {
        'station_id': 'OPENAQ-1234',
        'station_name': 'Anand Vihar CAAQMS',
        'provider': 'OpenAQ Global Network',
        'location': {
          'latitude': 28.6508,
          'longitude': 77.3152,
          'city': 'Delhi',
          'country': 'India',
        },
        'distance_km': 3.42,
        'available_pollutants': ['PM2.5', 'PM10', 'NO2', 'CO'],
        'data_source_type': 'LIVE',
        'is_active': true,
        'last_reported_at': '2026-11-15T11:00:00Z',
      };

      final st = MonitoringStationSummary.fromJson(json);
      expect(st.stationId, 'OPENAQ-1234');
      expect(st.stationName, 'Anand Vihar CAAQMS');
      expect(st.distanceKm, 3.42);
      expect(st.availablePollutants.length, 4);
      expect(st.dataSourceType, 'LIVE');
    });

    test('ProviderStatusItem parses correctly from json', () {
      final json = {
        'name': 'openaq',
        'display_name': 'OpenAQ v3',
        'status': 'ONLINE',
        'requires_api_key': true,
        'is_authenticated': true,
        'primary_data_type': 'LIVE',
        'supported_pollutants': ['PM2.5', 'PM10'],
        'attribution': 'OpenAQ Community',
        'last_check_timestamp': '2026-11-15T11:30:00Z',
        'latency_ms': 142.5,
      };

      final p = ProviderStatusItem.fromJson(json);
      expect(p.name, 'openaq');
      expect(p.status, 'ONLINE');
      expect(p.latencyMs, 142.5);
    });

    test('AssessmentResponse parses aqi, risk assessment, and station properly', () {
      final json = {
        'aqi_result': {
          'standard': 'CPCB_INDIA',
          'status': 'VALID',
          'status_message': 'Valid calculation',
          'overall_aqi': 245,
          'category': 'Poor',
          'color_code': '#FF9900',
          'prominent_pollutant': 'PM2.5',
          'sub_indices': {},
          'monitored_pollutant_count': 3,
          'has_particulate_matter': true,
          'is_stale': false,
          'data_source_type': 'LIVE',
          'provider': 'CPCB',
          'observation_timestamp': '2026-11-15T10:00:00Z',
          'calculation_timestamp': '2026-11-15T10:05:00Z',
          'location': {
            'latitude': 28.6,
            'longitude': 77.2,
            'country': 'India',
          },
        },
        'risk_assessment': {
          'risk_score': 68,
          'risk_level': 'HIGH',
          'risk_summary': 'Elevated exposure risk.',
          'primary_driver': 'PM2.5',
          'breakdown': [],
          'activity_recommendations': [],
          'disclaimer': 'Informational risk calculation only.',
        },
        'distance_from_query_km': 4.2,
        'data_freshness_minutes': 25.0,
      };

      final assessment = AssessmentResponse.fromJson(json);
      expect(assessment.aqiResult.overallAqi, 245);
      expect(assessment.aqiResult.category, 'Poor');
      expect(assessment.riskAssessment.riskScore, 68);
      expect(assessment.riskAssessment.riskLevel, 'HIGH');
      expect(assessment.distanceFromQueryKm, 4.2);
      expect(assessment.dataFreshnessMinutes, 25.0);
    });
  });
}
