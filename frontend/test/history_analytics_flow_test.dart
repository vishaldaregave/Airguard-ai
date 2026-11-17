import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:airguard_ai/core/network/api_client.dart';
import 'package:airguard_ai/features/environmental_intelligence/data/repositories/environmental_repository.dart';
import 'package:airguard_ai/features/environmental_intelligence/domain/models/history_analytics_models.dart';
import 'package:airguard_ai/features/environmental_intelligence/presentation/screens/historical_intelligence_screen.dart';

class MockHistoryRepository extends EnvironmentalRepository {
  MockHistoryRepository() : super(ApiClient());

  @override
  Future<HistoricalSummaryModel> getHistorySummary(
    String stationId, {
    String period = '7d',
  }) async {
    final now = DateTime.now();
    return HistoricalSummaryModel(
      stationId: stationId,
      stationName: 'Anand Vihar, Delhi (CPCB)',
      provider: 'CPCB Physical Sensor',
      dataSourceType: 'LIVE',
      isPhysicalStation: true,
      period: period,
      startTime: now.subtract(const Duration(days: 7)),
      endTime: now,
      totalRecords: 72,
      expectedSamples: 168,
      dataCoveragePct: 42.9,
      missingIntervalsCount: 1,
      aqiMean: 246.5,
      aqiMedian: 242.0,
      aqiMin: 180,
      aqiMax: 325,
      aqiStd: 34.2,
      overallTrend: 'INCREASING',
      aqiCategoryDistribution: const {
        'Moderate': 12,
        'Poor': 44,
        'Very Poor': 16,
      },
      pollutantSummaries: const {
        'PM2.5': PollutantTrendModel(
          pollutant: 'PM2.5',
          unit: 'µg/m³',
          mean: 112.4,
          median: 108.0,
          minValue: 75.0,
          maxValue: 165.0,
          stdDev: 22.1,
          slopePerDay: 4.8,
          trend: 'INCREASING',
          rSquared: 0.68,
          isStatisticallySignificant: true,
          completenessPct: 100.0,
          statutoryStandardExceededCount: 65,
        ),
      },
      disclaimer: 'Empirical Historical Analytics: Observed historical values without unverified causal attribution.',
    );
  }

  @override
  Future<HistoricalTrendsModel> getHistoryTrends(
    String stationId, {
    String period = '7d',
  }) async {
    return HistoricalTrendsModel(
      stationId: stationId,
      period: period,
      datapointsCount: 24,
      overallTrend: 'INCREASING',
      slopeAqiPerDay: 4.8,
      rSquared: 0.65,
      isStatisticallySignificant: true,
      diurnalProfile: const {
        0: 220.0,
        8: 285.0,
        14: 190.0,
        21: 270.0,
      },
      pollutantTrends: const {},
      detectedGaps: const [],
      timeseries: [
        HistoricalDataPointModel(
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          calculatedAqi: 240,
          aqiCategory: 'Poor',
          pm25: 110.0,
          pm10: 195.0,
        ),
        HistoricalDataPointModel(
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          calculatedAqi: 255,
          aqiCategory: 'Poor',
          pm25: 118.0,
          pm10: 205.0,
        ),
      ],
      disclaimer: 'Scientific notice: Linear regression slope calculated via Ordinary Least Squares.',
    );
  }

  @override
  Future<HistoricalCalendarModel> getHistoryCalendar(
    String stationId, {
    String period = '30d',
  }) async {
    return const HistoricalCalendarModel(
      stationId: 'DELHI-CPCB-001',
      period: '30d',
      totalDays: 3,
      sufficientDays: 2,
      insufficientDays: 1,
      unavailableDays: 0,
      days: [
        CalendarDayModel(
          date: '2026-11-15',
          dayOfWeek: 'Sun',
          sampleCount: 24,
          dataCoveragePct: 100.0,
          isSufficient: true,
          representativeAqi: 245,
          aqiCategory: 'Poor',
          dominantPollutant: 'PM2.5',
          meanPm25: 112.0,
          regulatoryDisclosure: 'Sufficient Data: Meets statutory minimum of 16 hourly samples/day.',
        ),
        CalendarDayModel(
          date: '2026-11-16',
          dayOfWeek: 'Mon',
          sampleCount: 24,
          dataCoveragePct: 100.0,
          isSufficient: true,
          representativeAqi: 260,
          aqiCategory: 'Poor',
          dominantPollutant: 'PM2.5',
          meanPm25: 119.0,
          regulatoryDisclosure: 'Sufficient Data: Meets statutory minimum of 16 hourly samples/day.',
        ),
        CalendarDayModel(
          date: '2026-11-17',
          dayOfWeek: 'Tue',
          sampleCount: 8,
          dataCoveragePct: 33.3,
          isSufficient: false,
          representativeAqi: 230,
          aqiCategory: 'Poor',
          dominantPollutant: 'PM2.5',
          meanPm25: 105.0,
          regulatoryDisclosure: 'Provisional AQI: Only 8/24 samples recorded (<16h CPCB threshold).',
        ),
      ],
      disclaimer: 'CPCB 16-Hour Rule: Valid daily AQI requires at least 16 hourly observations.',
    );
  }

  @override
  Future<HistoricalExtremesModel> getHistoryExtremes(
    String stationId, {
    String period = '7d',
  }) async {
    final now = DateTime.now();
    return HistoricalExtremesModel(
      stationId: stationId,
      period: period,
      maximumAqi: 325,
      minimumAqi: 180,
      peakEpisodes: [
        PeakEpisodeModel(
          peakType: 'PEAK_ELEVATION',
          startTime: now.subtract(const Duration(hours: 18)),
          endTime: now.subtract(const Duration(hours: 12)),
          durationHours: 6.0,
          meanAqi: 312.0,
          maxAqi: 325.0,
          prominentPollutant: 'PM2.5',
          physicalDescription: 'Elevated particulate episode (max AQI: 325, PM2.5) during nocturnal boundary layer inversion.',
        ),
      ],
      cleanestPeriods: [
        PeakEpisodeModel(
          peakType: 'CLEAN_PERIOD',
          startTime: now.subtract(const Duration(hours: 46)),
          endTime: now.subtract(const Duration(hours: 38)),
          durationHours: 8.0,
          meanAqi: 188.0,
          maxAqi: 198.0,
          prominentPollutant: 'PM2.5',
          physicalDescription: 'Cleanest interval (mean AQI: 188.0) during afternoon convective thermal ventilation.',
        ),
      ],
      disclaimer: 'Episodes classified deterministically via moving statistical thresholds.',
    );
  }

  @override
  Future<HistoricalCoverageModel> getHistoryCoverage(
    String stationId, {
    String period = '7d',
  }) async {
    final now = DateTime.now();
    return HistoricalCoverageModel(
      stationId: stationId,
      period: period,
      startTime: now.subtract(const Duration(days: 7)),
      endTime: now,
      expectedSamples: 168,
      actualSamples: 72,
      coveragePct: 42.9,
      gapsCount: 1,
      longestGapHours: 96.0,
      temporalRegularityScore: 68.5,
      gaps: [
        DataGapModel(
          gapStart: now.subtract(const Duration(days: 7)),
          gapEnd: now.subtract(const Duration(days: 3)),
          durationHours: 96.0,
          expectedIntervalHours: 1.0,
        ),
      ],
      disclaimer: 'Audit Notice: Gaps (>2 hours) disclose missing telemetry without synthetic imputation.',
    );
  }

  @override
  Future<HistoricalCompareModel> compareHistoryLocations(
    String stationA,
    String stationB, {
    String period = '7d',
  }) async {
    return const HistoricalCompareModel(
      stationA: 'DELHI-CPCB-001',
      stationB: 'METEO-GRID-28.61-77.21',
      period: '7d',
      isCompatible: true,
      compatibilityNotes: [
        'Provenance Asymmetry: Station A is physical ground telemetry, whereas Station B is atmospheric model grid approximation.',
      ],
      aqiMeanA: 246.5,
      aqiMeanB: 218.0,
      aqiDifference: 28.5,
      peakAqiA: 325,
      peakAqiB: 280,
      coveragePctA: 42.9,
      coveragePctB: 42.9,
      pollutantDifferences: {
        'PM2.5': 18.2,
        'PM10': 32.5,
      },
      disclaimer: 'Comparative Environmental Notice: Mean differences reflect localized microclimate and sensor proximity.',
    );
  }

  @override
  Future<HistoricalReportModel> getHistoryReport(
    String stationId, {
    String period = '7d',
  }) async {
    final now = DateTime.now();
    final cov = await getHistoryCoverage(stationId, period: period);
    return HistoricalReportModel(
      title: 'AIRGUARD AI — Historical Environmental Intelligence Report',
      stationId: stationId,
      stationName: 'Anand Vihar, Delhi (CPCB)',
      period: period,
      generatedAt: now,
      executiveSummary: 'Historical environmental audit indicates Poor air quality (mean AQI: 246.5) with upward particulate slope.',
      markdownContent: '# Report Markdown Content\nAudit confirms mean AQI 246.5.',
      coverageAudit: cov,
      trendAnalysis: const {'trend': 'INCREASING', 'slope': 4.8},
      disclaimer: 'Evidence-based report. Does not constitute medical diagnosis.',
    );
  }

  @override
  Future<HistoricalExplanationModel> explainHistory(
    HistoricalSummaryModel summary,
    HistoricalTrendsModel? trends,
  ) async {
    return HistoricalExplanationModel(
      narrative: 'Over the 7d analysis period at Anand Vihar, Delhi (CPCB), air quality recorded an average CPCB AQI of 246.5.',
      keyInsights: const [
        'Boundary Layer Dynamics: Elevated morning particulates correspond to nocturnal temperature inversion.',
        'Particulate Dominance: Fine particulate matter (PM2.5) is the primary driver of CPCB AQI sub-indices.',
      ],
      diurnalObservations: const [
        'Daily peaks typically manifest at 08:00 and 21:00.',
      ],
      dataLimitations: const [
        'Sparse interval: Only verified observations are evaluated; missing intervals are never zero-filled.',
      ],
      disclaimer: 'Scientific empirical explanation. Informational only.',
      provider: 'AirGuard Deterministic Explainer',
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('Milestone 5.4: Historical Domain Models Serialization & Integrity', () {
    test('HistoricalDataPointModel correctly handles nulls without zero-filling', () {
      final json = {
        'timestamp': '2026-11-17T00:00:00Z',
        'calculated_aqi': null,
        'aqi_category': null,
        'pm2_5': null,
        'pm10': 150.0,
        'quality_flag': 'VALID',
      };

      final dp = HistoricalDataPointModel.fromJson(json);
      expect(dp.calculatedAqi, isNull);
      expect(dp.pm25, isNull);
      expect(dp.pm10, equals(150.0));
      expect(dp.qualityFlag, equals('VALID'));
    });

    test('CalendarDayModel properly reflects CPCB 16-Hour Rule thresholds', () {
      final day1 = CalendarDayModel.fromJson({
        'date': '2026-11-16',
        'day_of_week': 'Mon',
        'sample_count': 20,
        'data_coverage_pct': 83.3,
        'is_sufficient': true,
        'representative_aqi': 240,
        'regulatory_disclosure': 'Sufficient Data: Meets statutory minimum of 16 hourly samples/day.',
      });

      expect(day1.isSufficient, isTrue);
      expect(day1.sampleCount, equals(20));

      final day2 = CalendarDayModel.fromJson({
        'date': '2026-11-17',
        'day_of_week': 'Tue',
        'sample_count': 10,
        'data_coverage_pct': 41.7,
        'is_sufficient': false,
        'representative_aqi': 210,
        'regulatory_disclosure': 'Provisional AQI: Only 10/24 samples recorded (<16h CPCB threshold).',
      });

      expect(day2.isSufficient, isFalse);
      expect(day2.regulatoryDisclosure, contains('<16h CPCB threshold'));
    });

    test('HistoricalCompareModel handles physical vs model-grid distinction', () {
      final comp = HistoricalCompareModel.fromJson({
        'station_a': 'DELHI-CPCB-001',
        'station_b': 'METEO-GRID-28.61-77.21',
        'period': '7d',
        'is_compatible': true,
        'compatibility_notes': [
          'Provenance Asymmetry: Station A is physical ground telemetry, whereas Station B is atmospheric model grid approximation.'
        ],
        'aqi_mean_a': 250.0,
        'aqi_mean_b': 210.0,
        'aqi_difference': 40.0,
        'coverage_pct_a': 80.0,
        'coverage_pct_b': 100.0,
        'pollutant_differences': {'PM2.5': 24.5},
        'disclaimer': 'Notice',
      });

      expect(comp.isCompatible, isTrue);
      expect(comp.aqiDifference, equals(40.0));
      expect(comp.compatibilityNotes.first, contains('Provenance Asymmetry'));
    });
  });

  group('Milestone 5.4: Historical Intelligence Screen Widget Tests', () {
    testWidgets('Renders Historical Intelligence Screen with tabs and KPI metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(MockHistoryRepository()),
          ],
          child: const MaterialApp(
            home: HistoricalIntelligenceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check App Bar
      expect(find.text('HISTORICAL INTELLIGENCE'), findsOneWidget);
      expect(find.text('EVIDENCE-DRIVEN ENVIRONMENTAL ANALYTICS'), findsOneWidget);

      // Check Tabs
      expect(find.text('OVERVIEW & TRENDS'), findsOneWidget);
      expect(find.text('POLLUTANTS'), findsOneWidget);
      expect(find.text('CALENDAR'), findsOneWidget);
      expect(find.text('EXTREMES & GAPS'), findsOneWidget);
      expect(find.text('COMPARISON'), findsOneWidget);

      // Check KPI Metrics
      expect(find.text('MEAN CPCB AQI'), findsOneWidget);
      expect(find.text('246.5'), findsOneWidget);
      expect(find.text('TREND TRAJECTORY'), findsOneWidget);
      expect(find.text('INCREASING'), findsWidgets);
      expect(find.text('DATA COVERAGE'), findsOneWidget);
      expect(find.text('42.9%'), findsOneWidget);

      // Check Period Chips
      expect(find.text('24H'), findsOneWidget);
      expect(find.text('7D'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);
      expect(find.text('90D'), findsOneWidget);

      // Check Evidence-based narrative section
      expect(find.text('EVIDENCE-BASED SCIENTIFIC NARRATIVE'), findsOneWidget);
      expect(find.textContaining('Over the 7d analysis period at Anand Vihar'), findsOneWidget);
    });

    testWidgets('Tapping Calendar tab displays daily cells and CPCB 16-Hour rule', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(MockHistoryRepository()),
          ],
          child: const MaterialApp(
            home: HistoricalIntelligenceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap CALENDAR tab
      await tester.tap(find.text('CALENDAR'));
      await tester.pumpAndSettle();

      // Verify CPCB NAAQS disclosure
      expect(find.textContaining('CPCB NAAQS Requirement: Minimum 16 hourly samples'), findsOneWidget);
      expect(find.text('TOTAL DAYS'), findsOneWidget);
      expect(find.text('VALID (≥16h)'), findsOneWidget);

      // Verify daily cells
      expect(find.text('15'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('PROV'), findsOneWidget); // Provisional day
    });

    testWidgets('Clicking export report button opens report modal dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            environmentalRepositoryProvider.overrideWithValue(MockHistoryRepository()),
          ],
          child: const MaterialApp(
            home: HistoricalIntelligenceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap report icon in AppBar
      await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
      await tester.pumpAndSettle();

      // Verify modal dialog opened
      expect(find.text('HISTORICAL AUDIT REPORT'), findsOneWidget);
      expect(find.textContaining('Historical environmental audit indicates Poor air quality'), findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(find.text('HISTORICAL AUDIT REPORT'), findsNothing);
    });
  });
}
