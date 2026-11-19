import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:airguard_ai/core/network/api_client.dart';
import 'package:airguard_ai/features/environmental_intelligence/data/repositories/environmental_repository.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/geo_models.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/screens/geo_map_screen.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/widgets/geo_tile_map.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/widgets/geo_station_detail_sheet.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/widgets/geo_interpolation_sheet.dart';

class MockGeoRepository extends EnvironmentalRepository {
  MockGeoRepository() : super(ApiClient());

  @override
  Future<List<GeoStationModel>> getGeoStations(
    double lat,
    double lon, {
    double? radiusKm,
    bool includeDemo = true,
  }) async {
    return [
      GeoStationModel(
        stationId: 'CPCB-001',
        stationName: 'Anand Vihar',
        provider: 'CPCB',
        stationType: StationType.physicalMonitor,
        latitude: lat + 0.02,
        longitude: lon + 0.02,
        distanceKm: 3.5,
        availablePollutants: const ['PM2.5', 'PM10', 'NO2'],
        dataSourceType: 'LIVE',
      ),
    ];
  }

  @override
  Future<List<GeoObservationModel>> getGeoObservations(
    double lat,
    double lon, {
    double? radiusKm,
    bool includeDemo = true,
  }) async {
    return [
      GeoObservationModel(
        stationId: 'CPCB-001',
        stationName: 'Anand Vihar',
        provider: 'CPCB',
        stationType: StationType.physicalMonitor,
        latitude: lat + 0.02,
        longitude: lon + 0.02,
        timestamp: DateTime.now(),
        dataSourceType: 'LIVE',
        aqi: 310,
        aqiCategory: 'Very Poor',
        prominentPollutant: 'PM2.5',
        pm25: 140.0,
        pm10: 250.0,
        no2: 45.0,
        distanceKm: 3.5,
      ),
    ];
  }

  @override
  Future<List<HotspotClusterModel>> getGeoHotspots(
    double lat,
    double lon, {
    double? radiusKm,
    bool allowDemo = false,
  }) async {
    return [];
  }

  @override
  Future<GeoCoverageModel> getGeoCoverage(
    double lat,
    double lon, {
    double? radiusKm,
    bool includeDemo = true,
  }) async {
    return GeoCoverageModel(
      centerLat: lat,
      centerLon: lon,
      searchRadiusKm: 50.0,
      totalStations: 1,
      physicalStationsCount: 1,
      modelGridPointsCount: 0,
      activeStationsCount: 1,
      spatialDensityScore: 80.0,
      coverageQuality: 'GOOD',
      message: 'Coverage adequate',
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('Geographic Intelligence Domain Models', () {
    test('GeoStationModel parses correctly from JSON', () {
      final json = {
        'station_id': 'CPCB-DELHI-001',
        'station_name': 'Anand Vihar',
        'provider': 'CPCB',
        'station_type': 'PHYSICAL_MONITOR',
        'location': {
          'latitude': 28.6469,
          'longitude': 77.3160,
          'city': 'Delhi',
          'country': 'India',
        },
        'distance_km': 8.4,
        'available_pollutants': ['PM2.5', 'PM10', 'NO2'],
        'data_source_type': 'LIVE',
        'is_operational': true,
        'latest_observation_time': '2026-11-16T12:00:00Z',
      };

      final model = GeoStationModel.fromJson(json);
      expect(model.stationId, 'CPCB-DELHI-001');
      expect(model.stationName, 'Anand Vihar');
      expect(model.stationType, StationType.physicalMonitor);
      expect(model.latitude, 28.6469);
      expect(model.longitude, 77.3160);
      expect(model.distanceKm, 8.4);
      expect(model.dataSourceType, 'LIVE');
      expect(model.isActive, true);
    });

    test('GeoObservationModel parses correctly with CPCB AQI and concentrations', () {
      final json = {
        'station_id': 'CPCB-001',
        'station_name': 'R K Puram',
        'station_type': 'PHYSICAL_MONITOR',
        'provider': 'CPCB',
        'location': {'latitude': 28.56, 'longitude': 77.18},
        'timestamp': '2026-11-16T12:00:00Z',
        'data_source_type': 'LIVE',
        'aqi': 345,
        'aqi_category': 'Very Poor',
        'prominent_pollutant': 'PM2.5',
        'pollutant_concentrations': {
          'PM2.5': 165.0,
          'PM10': 280.0,
          'NO2': 55.0,
        },
        'data_freshness_minutes': 15.0,
        'is_stale': false,
        'distance_km': 5.2,
      };

      final obs = GeoObservationModel.fromJson(json);
      expect(obs.stationId, 'CPCB-001');
      expect(obs.aqi, 345);
      expect(obs.cpcbCategory, 'Very Poor');
      expect(obs.pm25, 165.0);
      expect(obs.isStale, false);
      expect(obs.aqiColor, isNotNull);
    });

    test('SpatialInterpolationModel parses correctly with uncertainty score', () {
      final json = {
        'target_location': {'latitude': 28.60, 'longitude': 77.20},
        'status': 'INTERPOLATED',
        'data_source_type': 'ESTIMATED',
        'method': 'INVERSE_DISTANCE_WEIGHTING',
        'idw_power': 2.0,
        'interpolated_aqi': 295,
        'aqi_category': 'Poor',
        'prominent_pollutant': 'PM2.5',
        'pollutants': {
          'pm2_5': {
            'pollutant': 'PM2.5',
            'estimated_value': 118.4,
            'unit': 'µg/m³',
            'averaging_period': '24hr',
            'sub_index': 295,
            'contributing_count': 1,
          }
        },
        'contributing_stations': [
          {
            'station_id': 'ST-1',
            'station_name': 'Station 1',
            'latitude': 28.61,
            'longitude': 77.21,
            'provider': 'CPCB',
            'station_type': 'PHYSICAL_MONITOR',
            'distance_km': 6.2,
            'weight_normalized': 0.65,
            'data_source_type': 'LIVE',
          }
        ],
        'eligible_stations_count': 3,
        'spatial_uncertainty_score': 28.5,
        'uncertainty_level': 'LOW',
        'message': 'Interpolation successful',
        'disclaimer': 'Estimated via Inverse Distance Weighting.',
        'timestamp': '2026-11-16T12:00:00Z',
      };

      final interp = SpatialInterpolationModel.fromJson(json);
      expect(interp.status, 'INTERPOLATED');
      expect(interp.isInterpolated, true);
      expect(interp.dataSourceType, 'ESTIMATED');
      expect(interp.interpolatedAqi, 295);
      expect(interp.spatialUncertaintyScore, 28.5);
      expect(interp.pollutants.containsKey('pm2_5'), true);
      expect(interp.contributingStations.length, 1);
    });

    test('HotspotClusterModel parses with confirmed multi-station classification', () {
      final json = {
        'cluster_id': 'HOTSPOT-001',
        'center_location': {'latitude': 28.64, 'longitude': 77.31},
        'radius_km': 5.2,
        'severity': 'SEVERE_HOTSPOT',
        'contributing_stations_count': 3,
        'is_confirmed_hotspot': true,
        'peak_aqi': 425,
        'mean_aqi': 410.0,
        'peak_pm2_5': 310.0,
        'dominant_pollutant': 'PM2.5',
        'data_source_type': 'LIVE',
        'contributing_stations': ['ST-1', 'ST-2', 'ST-3'],
        'explanation': 'Confirmed multi-station severe cluster.',
        'disclaimer': 'Not exact boundaries.',
        'detected_at': '2026-11-16T12:00:00Z',
      };

      final hotspot = HotspotClusterModel.fromJson(json);
      expect(hotspot.clusterId, 'HOTSPOT-001');
      expect(hotspot.severity, HotspotSeverity.severeHotspot);
      expect(hotspot.isConfirmedHotspot, true);
      expect(hotspot.contributingStationsCount, 3);
      expect(hotspot.peakAqi, 425);
    });

    test('GeoCoverageModel parses density score and coverage assessment', () {
      final json = {
        'center_location': {'latitude': 28.61, 'longitude': 77.20},
        'search_radius_km': 50.0,
        'total_stations': 5,
        'physical_stations_count': 4,
        'model_grid_points_count': 1,
        'active_stations_count': 5,
        'monitored_pollutant_counts': {'PM2.5': 5, 'PM10': 4},
        'nearest_station_km': 3.2,
        'farthest_station_km': 28.0,
        'spatial_density_score': 82.5,
        'coverage_quality': 'EXCELLENT',
        'message': 'Dense physical monitoring network.',
        'timestamp': '2026-11-16T12:00:00Z',
      };

      final coverage = GeoCoverageModel.fromJson(json);
      expect(coverage.totalStations, 5);
      expect(coverage.physicalStationsCount, 4);
      expect(coverage.coverageQuality, 'EXCELLENT');
      expect(coverage.spatialDensityScore, 82.5);
    });
  });

  group('Geographic Intelligence Widgets & Screens', () {
    test('Map zoom scales inversely with search radius', () {
      expect(geoZoomForRadius(50), lessThan(geoZoomForRadius(10)));
      expect(geoZoomForRadius(10), lessThan(geoZoomForRadius(2)));
      expect(geoZoomForRadius(500), greaterThanOrEqualTo(7.0));
      expect(geoZoomForRadius(0.1), lessThanOrEqualTo(14.0));
    });

    testWidgets('GeoMapScreen renders title, filter chips, and basemap',
        (WidgetTester tester) async {
      final mockRepo = MockGeoRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: GeoMapScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify title
      expect(find.text('Air Map'), findsOneWidget);

      // Verify pollutant chips
      expect(find.text('AQI'), findsOneWidget);
      expect(find.text('PM2.5'), findsOneWidget);
      expect(find.text('PM10'), findsOneWidget);
      expect(find.text('NO2'), findsOneWidget);

      // Verify Map layers icon
      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    });

    testWidgets('GeoStationDetailSheet displays station telemetry and provenance badge',
        (WidgetTester tester) async {
      final obs = GeoObservationModel(
        stationId: 'DELHI-TEST-01',
        stationName: 'Major Dhyan Chand Stadium',
        stationType: StationType.physicalMonitor,
        provider: 'CPCB CAAQMS',
        latitude: 28.61,
        longitude: 77.23,
        timestamp: DateTime.now(),
        dataSourceType: 'LIVE',
        aqi: 285,
        aqiCategory: 'Poor',
        prominentPollutant: 'PM2.5',
        pm25: 115.0,
        pm10: 210.0,
        distanceKm: 4.2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeoStationDetailSheet(
              observation: obs,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Major Dhyan Chand Stadium'), findsOneWidget);
      expect(find.text('285'), findsOneWidget);
      expect(find.text('Poor'), findsOneWidget);
      expect(find.text('MONITORED POLLUTANTS'), findsOneWidget);
      expect(find.textContaining('4.2 km away'), findsOneWidget);
    });

    testWidgets('GeoInterpolationSheet displays IDW estimate and uncertainty score',
        (WidgetTester tester) async {
      final interp = SpatialInterpolationModel(
        targetLat: 28.6050,
        targetLon: 77.2150,
        status: 'INTERPOLATED',
        dataSourceType: 'ESTIMATED',
        method: 'INVERSE_DISTANCE_WEIGHTING',
        idwPower: 2.0,
        interpolatedAqi: 260,
        aqiCategory: 'Poor',
        prominentPollutant: 'PM2.5',
        eligibleStationsCount: 3,
        spatialUncertaintyScore: 35.0,
        uncertaintyLevel: 'LOW',
        message: 'Interpolation computed',
        disclaimer: 'Estimated via Inverse Distance Weighting from nearby monitoring stations.',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeoInterpolationSheet(
              interpolation: interp,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('SPATIAL INTERPOLATION'), findsOneWidget);
      expect(find.text('260'), findsOneWidget);
      expect(find.text('UNCERTAINTY'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      expect(find.text('CONTRIBUTING STATIONS (3)'), findsOneWidget);
    });
  });
}
