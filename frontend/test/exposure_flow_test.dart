import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:airguard_ai/core/network/api_client.dart';
import 'package:airguard_ai/features/environmental_intelligence/data/repositories/environmental_repository.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/exposure_models.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/screens/exposure_simulator_screen.dart';

class MockExposureRepository extends EnvironmentalRepository {
  MockExposureRepository() : super(ApiClient());

  @override
  Future<List<ActivityProfileModel>> getActivityProfiles() async {
    return const [
      ActivityProfileModel(
        activityType: ActivityTypeEnum.resting,
        displayName: 'Resting / Sedentary',
        inhalationRateM3H: 0.50,
        metEquivalent: 1.0,
        description: 'Quiet rest',
        reference: 'EPA EFH',
      ),
      ActivityProfileModel(
        activityType: ActivityTypeEnum.walking,
        displayName: 'Walking (Moderate Pace)',
        inhalationRateM3H: 1.20,
        metEquivalent: 3.0,
        description: 'Standard walking',
        reference: 'EPA EFH',
      ),
      ActivityProfileModel(
        activityType: ActivityTypeEnum.running,
        displayName: 'Running / Jogging',
        inhalationRateM3H: 2.80,
        metEquivalent: 8.0,
        description: 'Vigorous running',
        reference: 'EPA EFH',
      ),
    ];
  }

  @override
  Future<ExposureSimulationModel> simulateExposure(Map<String, dynamic> request) async {
    final durMin = request['duration_minutes'] as int? ?? 60;
    final durH = durMin / 60.0;
    final actTypeStr = request['activity_type'] as String? ?? 'walking';
    final act = (await getActivityProfiles()).firstWhere(
      (p) => p.activityType.keyName == actTypeStr,
      orElse: () => (const ActivityProfileModel(
        activityType: ActivityTypeEnum.walking,
        displayName: 'Walking (Moderate Pace)',
        inhalationRateM3H: 1.20,
        metEquivalent: 3.0,
        description: 'Standard walking',
        reference: 'EPA EFH',
      )),
    );

    return ExposureSimulationModel(
      status: 'COMPUTED',
      activity: act,
      durationMinutes: durMin,
      durationHours: durH,
      totalInhaledVolumeM3: double.parse((act.inhalationRateM3H * durH).toStringAsFixed(2)),
      dataSourceType: 'LIVE',
      locationName: 'Delhi Central Monitoring Hub',
      latitude: 28.6139,
      longitude: 77.2090,
      pollutants: {
        'PM2.5': PollutantExposureMetricModel(
          pollutant: 'PM2.5',
          ambientConcentration: 120.0,
          concentrationUnit: 'µg/m³',
          concentrationTimeExposure: 120.0 * durH,
          exposureUnit: 'µg·h/m³',
          inhalationRateM3H: act.inhalationRateM3H,
          estimatedInhaledMass: 120.0 * act.inhalationRateM3H * durH,
          massUnit: 'µg',
        ),
        'PM10': PollutantExposureMetricModel(
          pollutant: 'PM10',
          ambientConcentration: 220.0,
          concentrationUnit: 'µg/m³',
          concentrationTimeExposure: 220.0 * durH,
          exposureUnit: 'µg·h/m³',
          inhalationRateM3H: act.inhalationRateM3H,
          estimatedInhaledMass: 220.0 * act.inhalationRateM3H * durH,
          massUnit: 'µg',
        ),
      },
      cpcbAqi: 295,
      cpcbCategory: 'Poor',
      prominentPollutant: 'PM2.5',
      calculationMethodology: 'Deterministic concentration-time and ventilation rate modeling.',
      disclaimer: 'Scientific Environmental Advisory: Pure physical exposure model. Not clinical diagnosis.',
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<ExposureComparisonModel> compareExposure(Map<String, dynamic> request) async {
    final simA = await simulateExposure(request['scenario_a'] as Map<String, dynamic>? ?? {});
    final simB = await simulateExposure(request['scenario_b'] as Map<String, dynamic>? ?? {});

    return ExposureComparisonModel(
      scenarioA: ScenarioComparisonItemModel(
        scenarioId: 'scenario_a',
        label: 'Scenario A',
        simulation: simA,
      ),
      scenarioB: ScenarioComparisonItemModel(
        scenarioId: 'scenario_b',
        label: 'Scenario B',
        simulation: simB,
      ),
      deltas: {
        'PM2.5': const PollutantComparisonDeltaModel(
          pollutant: 'PM2.5',
          scenarioAExposure: 120.0,
          scenarioBExposure: 120.0,
          deltaExposure: 0.0,
          exposureUnit: 'µg·h/m³',
          scenarioAInhaledMass: 144.0,
          scenarioBInhaledMass: 336.0,
          deltaInhaledMass: 192.0,
          massUnit: 'µg',
          percentChangeInhaledMass: 133.3,
          summary: 'Running increases inhaled PM2.5 mass by +192.0 µg (+133.3%) vs walking.',
        ),
      },
      physicalComparisonSummary: 'Physical Comparison: Scenario difference evaluated via adult ventilation rates.',
      disclaimer: 'Comparative advisory for awareness only. Does not establish medical safety.',
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<ExposureExplanationModel> explainExposure(
    ExposureSimulationModel simulation, {
    String? userQuery,
  }) async {
    return ExposureExplanationModel(
      narrative: 'During ${simulation.durationMinutes} minutes of ${simulation.activity.displayName.toLowerCase()}, you breathe an estimated ${simulation.totalInhaledVolumeM3} m³ of ambient air.',
      keyTakeaways: const [
        'Activity Multiplier: Running increases air intake 5.6x vs resting.',
        'Duration Linear Scaling: Halving duration directly reduces inhaled pollutant mass by 50%.',
      ],
      protectiveSuggestions: const [
        'Shift vigorous workouts indoors when ambient AQI exceeds 200.',
      ],
      methodologyNote: 'Ventilation rates derived from US EPA Exposure Factors Handbook (2011).',
      disclaimer: 'Scientific advisory only. Does not constitute clinical advice.',
      provider: 'AirGuard Explainer Engine',
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('Exposure Domain Models JSON Serialization Audit', () {
    test('ActivityProfileModel parses correctly from JSON', () {
      final json = {
        'activity_type': 'running',
        'display_name': 'Running / Jogging',
        'inhalation_rate_m3_h': 2.80,
        'met_equivalent': 8.0,
        'description': 'Vigorous aerobic running',
        'reference': 'US EPA Exposure Factors Handbook (2011)',
      };

      final profile = ActivityProfileModel.fromJson(json);
      expect(profile.activityType, ActivityTypeEnum.running);
      expect(profile.displayName, 'Running / Jogging');
      expect(profile.inhalationRateM3H, 2.80);
      expect(profile.metEquivalent, 8.0);
    });

    test('PollutantExposureMetricModel preserves null ambient concentrations', () {
      final json = {
        'pollutant': 'PM10',
        'ambient_concentration': null,
        'concentration_unit': 'µg/m³',
        'concentration_time_exposure': null,
        'exposure_unit': 'µg·h/m³',
        'inhalation_rate_m3_h': 1.20,
        'estimated_inhaled_mass': null,
        'mass_unit': 'µg',
        'is_available': false,
      };

      final metric = PollutantExposureMetricModel.fromJson(json);
      expect(metric.pollutant, 'PM10');
      expect(metric.ambientConcentration, isNull);
      expect(metric.estimatedInhaledMass, isNull);
      expect(metric.isAvailable, false);
    });

    test('ExposureSimulationModel parses correctly with all metrics', () {
      final json = {
        'status': 'COMPUTED',
        'activity': {
          'activity_type': 'walking',
          'display_name': 'Walking',
          'inhalation_rate_m3_h': 1.20,
          'met_equivalent': 3.0,
          'description': 'Walking',
          'reference': 'EPA',
        },
        'duration_minutes': 60,
        'duration_hours': 1.0,
        'total_inhaled_volume_m3': 1.20,
        'data_source_type': 'LIVE',
        'location_name': 'Connaught Place',
        'latitude': 28.63,
        'longitude': 77.22,
        'pollutants': {
          'PM2.5': {
            'pollutant': 'PM2.5',
            'ambient_concentration': 100.0,
            'concentration_unit': 'µg/m³',
            'concentration_time_exposure': 100.0,
            'exposure_unit': 'µg·h/m³',
            'inhalation_rate_m3_h': 1.20,
            'estimated_inhaled_mass': 120.0,
            'mass_unit': 'µg',
            'is_available': true,
          }
        },
        'cpcb_aqi': 260,
        'cpcb_category': 'Poor',
        'prominent_pollutant': 'PM2.5',
        'is_forecast': false,
        'is_interpolated': false,
        'calculation_methodology': 'Deterministic calculation.',
        'disclaimer': 'Scientific advisory only.',
        'timestamp': '2026-11-17T08:00:00Z',
      };

      final sim = ExposureSimulationModel.fromJson(json);
      expect(sim.status, 'COMPUTED');
      expect(sim.durationMinutes, 60);
      expect(sim.totalInhaledVolumeM3, 1.20);
      expect(sim.cpcbAqi, 260);
      expect(sim.pollutants.containsKey('PM2.5'), true);
      expect(sim.pollutants['PM2.5']!.estimatedInhaledMass, 120.0);
    });

    test('ExposureComparisonModel parses deltas correctly', () {
      final json = {
        'scenario_a': {
          'scenario_id': 'scenario_a',
          'label': 'Walk 60m',
          'simulation': {
            'status': 'COMPUTED',
            'activity': {
              'activity_type': 'walking',
              'display_name': 'Walking',
              'inhalation_rate_m3_h': 1.2,
              'met_equivalent': 3.0,
              'description': '',
              'reference': '',
            },
            'duration_minutes': 60,
            'duration_hours': 1.0,
            'total_inhaled_volume_m3': 1.2,
            'data_source_type': 'LIVE',
            'location_name': 'Loc',
            'pollutants': {},
            'calculation_methodology': '',
            'disclaimer': '',
            'timestamp': '2026-11-17T08:00:00Z',
          },
        },
        'scenario_b': {
          'scenario_id': 'scenario_b',
          'label': 'Run 60m',
          'simulation': {
            'status': 'COMPUTED',
            'activity': {
              'activity_type': 'running',
              'display_name': 'Running',
              'inhalation_rate_m3_h': 2.8,
              'met_equivalent': 8.0,
              'description': '',
              'reference': '',
            },
            'duration_minutes': 60,
            'duration_hours': 1.0,
            'total_inhaled_volume_m3': 2.8,
            'data_source_type': 'LIVE',
            'location_name': 'Loc',
            'pollutants': {},
            'calculation_methodology': '',
            'disclaimer': '',
            'timestamp': '2026-11-17T08:00:00Z',
          },
        },
        'deltas': {
          'PM2.5': {
            'pollutant': 'PM2.5',
            'scenario_a_exposure': 100.0,
            'scenario_b_exposure': 100.0,
            'delta_exposure': 0.0,
            'exposure_unit': 'µg·h/m³',
            'scenario_a_inhaled_mass': 120.0,
            'scenario_b_inhaled_mass': 280.0,
            'delta_inhaled_mass': 160.0,
            'mass_unit': 'µg',
            'percent_change_inhaled_mass': 133.3,
            'summary': 'Running increases inhaled mass.',
          }
        },
        'physical_comparison_summary': 'Physical Comparison Analysis.',
        'disclaimer': 'Non-medical advisory.',
        'timestamp': '2026-11-17T08:00:00Z',
      };

      final comp = ExposureComparisonModel.fromJson(json);
      expect(comp.deltas.containsKey('PM2.5'), true);
      expect(comp.deltas['PM2.5']!.deltaInhaledMass, 160.0);
      expect(comp.deltas['PM2.5']!.percentChangeInhaledMass, 133.3);
    });
  });

  group('Exposure Simulator Widgets & Interaction Audit', () {
    testWidgets('ExposureSimulatorScreen renders title, activity chips, duration controls, and action button',
        (WidgetTester tester) async {
      final mockRepo = MockExposureRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ExposureSimulatorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Title & Subtitle
      expect(find.text('EXPOSURE SIMULATOR'), findsOneWidget);
      expect(find.text('PERSONAL ENVIRONMENTAL EXPOSURE INTELLIGENCE'), findsOneWidget);

      // Section Titles
      expect(find.text('SELECT PHYSICAL ACTIVITY'), findsOneWidget);
      expect(find.text('EXPOSURE DURATION'), findsOneWidget);

      // Activity Chips
      expect(find.text('Resting'), findsOneWidget);
      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);

      // Duration preset chips
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);

      // Action Button
      expect(find.text('CALCULATE PHYSICAL EXPOSURE'), findsOneWidget);

      // Methodology & Disclaimer section
      expect(find.text('METHODOLOGY & SCIENTIFIC LIMITATIONS'), findsOneWidget);
    });

    testWidgets('Tapping comparison mode icon toggles Scenario B card',
        (WidgetTester tester) async {
      final mockRepo = MockExposureRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: ExposureSimulatorScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially single scenario title
      expect(find.text('EXPOSURE PARAMETERS'), findsOneWidget);
      expect(find.text('SCENARIO B (ALTERNATIVE WHAT-IF)'), findsNothing);

      // Tap comparison mode icon in app bar
      await tester.tap(find.byTooltip('Compare Two Scenarios'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now Scenario B card should appear
      expect(find.text('SCENARIO A (BASELINE)'), findsOneWidget);
      expect(find.text('SCENARIO B (ALTERNATIVE WHAT-IF)'), findsOneWidget);
      expect(find.text('RUN SCENARIO COMPARISON'), findsOneWidget);
    });
  });
}
