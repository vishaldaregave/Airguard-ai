import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:airguard_ai/features/environmental_intelligence/domain/models/geo_models.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/widgets/geo_canvas_map.dart';

void main() {
  group('GeoCanvasMap Spatial Projection & Responsiveness Audit', () {
    const centerLat = 28.6139;
    const centerLon = 77.2090;

    final mockObservations = [
      GeoObservationModel(
        stationId: 'STA-PHYS-01',
        stationName: 'Connaught Place Monitor',
        provider: 'CPCB',
        stationType: StationType.physicalMonitor,
        latitude: 28.6300,
        longitude: 77.2200,
        timestamp: DateTime.now(),
        dataSourceType: 'LIVE',
        aqi: 240,
        aqiCategory: 'Poor',
        prominentPollutant: 'PM2.5',
        pm25: 110.0,
        pm10: 190.0,
      ),
      GeoObservationModel(
        stationId: 'STA-GRID-02',
        stationName: 'Regional Atmospheric Grid (28.58N, 77.15E)',
        provider: 'Open-Meteo',
        stationType: StationType.atmosphericModelGrid,
        latitude: 28.5800,
        longitude: 77.1500,
        timestamp: DateTime.now(),
        dataSourceType: 'ESTIMATED',
        aqi: 180,
        aqiCategory: 'Moderate',
        prominentPollutant: 'PM2.5',
        pm25: 75.0,
      ),
    ];

    final mockHotspots = [
      HotspotClusterModel(
        clusterId: 'HOTSPOT-DELHI-EAST',
        centerLat: 28.6500,
        centerLon: 77.3000,
        radiusKm: 6.5,
        severity: HotspotSeverity.severeHotspot,
        contributingStationsCount: 3,
        physicalStationsCount: 3,
        isConfirmedHotspot: true,
        peakAqi: 412,
        meanAqi: 395.0,
        peakPm25: 280.0,
        dominantPollutant: 'PM2.5',
        dataSourceType: 'LIVE',
        contributingStations: const ['S1', 'S2', 'S3'],
        explanation: 'Confirmed multi-station severe cluster.',
        disclaimer: 'Cluster bounds reflect network chain connectivity.',
        detectedAt: DateTime.now(),
      ),
    ];

    testWidgets('Renders properly on standard mobile viewport (412x915)', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeoCanvasMap(
              centerLat: centerLat,
              centerLon: centerLon,
              radiusKm: 50.0,
              observations: mockObservations,
              hotspots: mockHotspots,
              selectedPollutant: 'AQI',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders properly on compact mobile viewport (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeoCanvasMap(
              centerLat: centerLat,
              centerLon: centerLon,
              radiusKm: 50.0,
              observations: mockObservations,
              hotspots: mockHotspots,
              selectedPollutant: 'PM2.5',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders properly on large tablet viewport (800x1280)', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeoCanvasMap(
              centerLat: centerLat,
              centerLon: centerLon,
              radiusKm: 50.0,
              observations: mockObservations,
              hotspots: mockHotspots,
              selectedPollutant: 'AQI',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Handles tap on physical monitoring station marker by coordinates', (tester) async {
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? tappedStation;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 600,
              child: GeoCanvasMap(
                centerLat: centerLat,
                centerLon: centerLon,
                radiusKm: 50.0,
                observations: mockObservations,
                hotspots: const [],
                selectedPollutant: 'AQI',
                onStationSelected: (stationId) {
                  tappedStation = stationId;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Station STA-PHYS-01 is at lat: 28.6300, lon: 77.2200
      // Calculate screen position:
      // scale = (min(600, 600) * 0.42) / 50.0 = 252 / 50.0 = 5.04 px/km
      // kmPerLat = 110.574, kmPerLon = 111.320 * cos(28.6139 * pi / 180) = 97.728
      // dLatKm = (28.6300 - 28.6139) * 110.574 = 0.0161 * 110.574 = 1.780 km
      // dLonKm = (77.2200 - 77.2090) * 97.728 = 0.0110 * 97.728 = 1.075 km
      // x = 300 + (1.075 * 5.04) = 305.4
      // y = 300 - (1.780 * 5.04) = 291.0
      await tester.tapAt(const Offset(305.4, 291.0));
      await tester.pump();

      expect(tappedStation, 'STA-PHYS-01');
    });

    testWidgets('Converts canvas tap to geographic coordinates correctly', (tester) async {
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      double? tappedLat;
      double? tappedLon;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 600,
              child: GeoCanvasMap(
                centerLat: centerLat,
                centerLon: centerLon,
                radiusKm: 50.0,
                observations: const [],
                hotspots: const [],
                selectedPollutant: 'AQI',
                onMapTap: (lat, lon) {
                  tappedLat = lat;
                  tappedLon = lon;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap exact center of canvas (300, 300) -> should equal query centerLat, centerLon
      await tester.tapAt(const Offset(300, 300));
      await tester.pump();

      expect(tappedLat, isNotNull);
      expect(tappedLon, isNotNull);
      expect((tappedLat! - centerLat).abs() < 0.001, isTrue);
      expect((tappedLon! - centerLon).abs() < 0.001, isTrue);
    });
  });
}
