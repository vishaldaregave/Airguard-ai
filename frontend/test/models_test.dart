import 'package:flutter_test/flutter_test.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/observation_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/risk_assessment_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/station_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/forecast_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/ai_explanation_model.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/history_availability_model.dart';

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

    test('ForecastCurrentResponse parses multi-horizon steps and metadata', () {
      final json = {
        'status': 'ACTIVE',
        'station_id': 'TEST-001',
        'station_name': 'Test Station',
        'data_source_type': 'PHYSICAL_STATION',
        'base_timestamp': '2026-11-15T12:00:00Z',
        'forecasts': [
          {
            'horizon_hours': 1,
            'target_timestamp': '2026-11-15T13:00:00Z',
            'predicted_aqi': 225,
            'predicted_aqi_category': 'Poor',
            'predicted_aqi_color': '#FF9900',
            'predicted_aqi_prominent_pollutant': 'PM2.5',
            'is_cpcb_aqi_valid': true,
            'pollutant_predictions': {
              'PM2.5': {
                'pollutant': 'PM2.5',
                'unit': 'µg/m³',
                'predicted_value': 115.0,
                'ci95_lower': 95.0,
                'ci95_upper': 135.0,
                'ci90_lower': 98.0,
                'ci90_upper': 132.0,
              },
            },
          },
          {
            'horizon_hours': 3,
            'target_timestamp': '2026-11-15T15:00:00Z',
            'predicted_aqi': 240,
            'predicted_aqi_category': 'Poor',
            'is_cpcb_aqi_valid': true,
            'pollutant_predictions': {},
          },
        ],
        'model_metadata': {
          'model_type': 'AUTOREGRESSIVE_RIDGE',
          'training_sample_count': 72,
          'mae_pm25': 12.4,
          'rmse_pm25': 16.8,
          'persistence_mae_pm25': 18.2,
        },
        'disclaimer': 'Statistical forecast only.',
      };

      final resp = ForecastCurrentResponse.fromJson(json);
      expect(resp.status, 'ACTIVE');
      expect(resp.stationId, 'TEST-001');
      expect(resp.forecasts.length, 2);
      expect(resp.forecasts[0].horizonHours, 1);
      expect(resp.forecasts[0].predictedAqi, 225);
      expect(resp.forecasts[0].pollutantPredictions['PM2.5']?.predictedValue, 115.0);
      expect(resp.forecasts[0].pollutantPredictions['PM2.5']?.ci95Upper, 135.0);
      expect(resp.modelMetadata.modelType, 'AUTOREGRESSIVE_RIDGE');
      expect(resp.modelMetadata.trainingSampleCount, 72);
      expect(resp.modelMetadata.maePm25, 12.4);
    });

    test('AIExplanationResponse parses the 6 core environmental inquiries', () {
      final json = {
        'status': 'SUCCESS',
        'provider_used': 'gemini-1.5-flash',
        'station_name': 'Lodhi Road CAAQMS',
        'observation_timestamp': '2026-11-15T12:00:00Z',
        'overall_aqi': 260,
        'aqi_category': 'Poor',
        'prominent_pollutant': 'PM2.5',
        'atmospheric_dynamics': 'Boundary layer compression under light nocturnal winds.',
        'primary_driver_analysis': 'PM2.5 concentration of 135 µg/m³ is driving sub-index 280.',
        'elevation_causes': 'Trapped combustion emissions from urban traffic corridors.',
        'activity_implications': 'Limit strenuous outdoor activities for sensitive groups.',
        'practical_precautions': 'Use N95 particulate filtration when outdoors.',
        'historical_comparison': 'AQI is 15% higher than the 24-hour historical baseline.',
        'disclaimer': 'Informational only. Not medical diagnosis.',
      };

      final exp = AIExplanationResponse.fromJson(json);
      expect(exp.status, 'SUCCESS');
      expect(exp.providerUsed, 'gemini-1.5-flash');
      expect(exp.overallAqi, 260);
      expect(exp.aqiCategory, 'Poor');
      expect(exp.prominentPollutant, 'PM2.5');
      expect(exp.atmosphericDynamics, contains('Boundary layer'));
      expect(exp.primaryDriverAnalysis, contains('PM2.5'));
      expect(exp.elevationCauses, contains('combustion'));
      expect(exp.activityImplications, contains('Limit strenuous'));
      expect(exp.practicalPrecautions, contains('N95'));
      expect(exp.historicalComparison, contains('15% higher'));
      expect(exp.disclaimer, contains('Not medical diagnosis'));
    });

    test('HistoryAvailabilityResponse parses provenance audit summary', () {
      final json = {
        'status': 'ACTIVE',
        'total_records': 144,
        'oldest_record': '2026-11-12T00:00:00Z',
        'newest_record': '2026-11-15T00:00:00Z',
        'physical_station_records': 72,
        'model_derived_records': 48,
        'synthetic_demo_records': 24,
        'unique_stations_count': 3,
        'provenance_summary': {
          'PHYSICAL_STATION': {
            'count': 72,
            'description': 'Direct ground-truth measurements',
          },
        },
      };

      final hist = HistoryAvailabilityResponse.fromJson(json);
      expect(hist.totalRecords, 144);
      expect(hist.physicalStationRecords, 72);
      expect(hist.modelDerivedRecords, 48);
      expect(hist.syntheticDemoRecords, 24);
      expect(hist.uniqueStationsCount, 3);
      expect(hist.provenanceSummary['PHYSICAL_STATION']?.count, 72);
    });
  });
}
