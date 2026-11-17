import 'package:flutter/foundation.dart';

/// Represents a single historical telemetry point
@immutable
class HistoricalDataPointModel {
  final DateTime timestamp;
  final int? calculatedAqi;
  final String? aqiCategory;
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? so2;
  final double? co;
  final double? o3;
  final String qualityFlag;

  const HistoricalDataPointModel({
    required this.timestamp,
    this.calculatedAqi,
    this.aqiCategory,
    this.pm25,
    this.pm10,
    this.no2,
    this.so2,
    this.co,
    this.o3,
    this.qualityFlag = 'VALID',
  });

  factory HistoricalDataPointModel.fromJson(Map<String, dynamic> json) {
    return HistoricalDataPointModel(
      timestamp: DateTime.parse(json['timestamp'] as String),
      calculatedAqi: json['calculated_aqi'] as int?,
      aqiCategory: json['aqi_category'] as String?,
      pm25: (json['pm2_5'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
      so2: (json['so2'] as num?)?.toDouble(),
      co: (json['co'] as num?)?.toDouble(),
      o3: (json['o3'] as num?)?.toDouble(),
      qualityFlag: json['quality_flag'] as String? ?? 'VALID',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'calculated_aqi': calculatedAqi,
      'aqi_category': aqiCategory,
      'pm2_5': pm25,
      'pm10': pm10,
      'no2': no2,
      'so2': so2,
      'co': co,
      'o3': o3,
      'quality_flag': qualityFlag,
    };
  }
}

/// Identifies a temporal missing observation interval
@immutable
class DataGapModel {
  final DateTime gapStart;
  final DateTime gapEnd;
  final double durationHours;
  final double expectedIntervalHours;

  const DataGapModel({
    required this.gapStart,
    required this.gapEnd,
    required this.durationHours,
    required this.expectedIntervalHours,
  });

  factory DataGapModel.fromJson(Map<String, dynamic> json) {
    return DataGapModel(
      gapStart: DateTime.parse(json['gap_start'] as String),
      gapEnd: DateTime.parse(json['gap_end'] as String),
      durationHours: (json['duration_hours'] as num).toDouble(),
      expectedIntervalHours: (json['expected_interval_hours'] as num? ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gap_start': gapStart.toIso8601String(),
      'gap_end': gapEnd.toIso8601String(),
      'duration_hours': durationHours,
      'expected_interval_hours': expectedIntervalHours,
    };
  }
}

/// Comprehensive statistical profile for an individual pollutant
@immutable
class PollutantTrendModel {
  final String pollutant;
  final String unit;
  final double? mean;
  final double? median;
  final double? minValue;
  final double? maxValue;
  final double? stdDev;
  final double? slopePerDay;
  final String trend;
  final double? rSquared;
  final double? pValue;
  final bool isStatisticallySignificant;
  final double completenessPct;
  final int statutoryStandardExceededCount;

  const PollutantTrendModel({
    required this.pollutant,
    required this.unit,
    this.mean,
    this.median,
    this.minValue,
    this.maxValue,
    this.stdDev,
    this.slopePerDay,
    this.trend = 'STABLE',
    this.rSquared,
    this.pValue,
    this.isStatisticallySignificant = false,
    this.completenessPct = 0.0,
    this.statutoryStandardExceededCount = 0,
  });

  factory PollutantTrendModel.fromJson(Map<String, dynamic> json) {
    return PollutantTrendModel(
      pollutant: json['pollutant'] as String,
      unit: json['unit'] as String? ?? 'µg/m³',
      mean: (json['mean'] as num?)?.toDouble(),
      median: (json['median'] as num?)?.toDouble(),
      minValue: (json['min_value'] as num?)?.toDouble(),
      maxValue: (json['max_value'] as num?)?.toDouble(),
      stdDev: (json['std_dev'] as num?)?.toDouble(),
      slopePerDay: (json['slope_per_day'] as num?)?.toDouble(),
      trend: json['trend'] as String? ?? 'STABLE',
      rSquared: (json['r_squared'] as num?)?.toDouble(),
      pValue: (json['p_value'] as num?)?.toDouble(),
      isStatisticallySignificant: json['is_statistically_significant'] as bool? ?? false,
      completenessPct: (json['completeness_pct'] as num? ?? 0.0).toDouble(),
      statutoryStandardExceededCount: json['statutory_standard_exceeded_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pollutant': pollutant,
      'unit': unit,
      'mean': mean,
      'median': median,
      'min_value': minValue,
      'max_value': maxValue,
      'std_dev': stdDev,
      'slope_per_day': slopePerDay,
      'trend': trend,
      'r_squared': rSquared,
      'p_value': pValue,
      'is_statistically_significant': isStatisticallySignificant,
      'completeness_pct': completenessPct,
      'statutory_standard_exceeded_count': statutoryStandardExceededCount,
    };
  }
}

/// Identifies episodic peaks or clean intervals
@immutable
class PeakEpisodeModel {
  final String peakType;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final double meanAqi;
  final double maxAqi;
  final String prominentPollutant;
  final String physicalDescription;

  const PeakEpisodeModel({
    required this.peakType,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.meanAqi,
    required this.maxAqi,
    required this.prominentPollutant,
    required this.physicalDescription,
  });

  factory PeakEpisodeModel.fromJson(Map<String, dynamic> json) {
    return PeakEpisodeModel(
      peakType: json['peak_type'] as String? ?? 'PEAK_ELEVATION',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      durationHours: (json['duration_hours'] as num).toDouble(),
      meanAqi: (json['mean_aqi'] as num).toDouble(),
      maxAqi: (json['max_aqi'] as num).toDouble(),
      prominentPollutant: json['prominent_pollutant'] as String? ?? 'PM2.5',
      physicalDescription: json['physical_description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'peak_type': peakType,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_hours': durationHours,
      'mean_aqi': meanAqi,
      'max_aqi': maxAqi,
      'prominent_pollutant': prominentPollutant,
      'physical_description': physicalDescription,
    };
  }
}

/// Executive historical summary response
@immutable
class HistoricalSummaryModel {
  final String stationId;
  final String stationName;
  final String provider;
  final String dataSourceType;
  final bool isPhysicalStation;
  final String period;
  final DateTime startTime;
  final DateTime endTime;
  final int totalRecords;
  final int expectedSamples;
  final double dataCoveragePct;
  final int missingIntervalsCount;
  final double? aqiMean;
  final double? aqiMedian;
  final int? aqiMin;
  final int? aqiMax;
  final double? aqiStd;
  final String overallTrend;
  final Map<String, int> aqiCategoryDistribution;
  final Map<String, PollutantTrendModel> pollutantSummaries;
  final String disclaimer;

  const HistoricalSummaryModel({
    required this.stationId,
    required this.stationName,
    required this.provider,
    required this.dataSourceType,
    required this.isPhysicalStation,
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.totalRecords,
    required this.expectedSamples,
    required this.dataCoveragePct,
    required this.missingIntervalsCount,
    this.aqiMean,
    this.aqiMedian,
    this.aqiMin,
    this.aqiMax,
    this.aqiStd,
    this.overallTrend = 'STABLE',
    this.aqiCategoryDistribution = const {},
    this.pollutantSummaries = const {},
    required this.disclaimer,
  });

  factory HistoricalSummaryModel.fromJson(Map<String, dynamic> json) {
    final catDistRaw = json['aqi_category_distribution'] as Map<String, dynamic>? ?? {};
    final catDist = catDistRaw.map((k, v) => MapEntry(k, v as int));

    final pollSumRaw = json['pollutant_summaries'] as Map<String, dynamic>? ?? {};
    final pollSum = pollSumRaw.map(
      (k, v) => MapEntry(k, PollutantTrendModel.fromJson(v as Map<String, dynamic>)),
    );

    return HistoricalSummaryModel(
      stationId: json['station_id'] as String,
      stationName: json['station_name'] as String,
      provider: json['provider'] as String,
      dataSourceType: json['data_source_type'] as String,
      isPhysicalStation: json['is_physical_station'] as bool? ?? true,
      period: json['period'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      totalRecords: json['total_records'] as int,
      expectedSamples: json['expected_samples'] as int,
      dataCoveragePct: (json['data_coverage_pct'] as num).toDouble(),
      missingIntervalsCount: json['missing_intervals_count'] as int? ?? 0,
      aqiMean: (json['aqi_mean'] as num?)?.toDouble(),
      aqiMedian: (json['aqi_median'] as num?)?.toDouble(),
      aqiMin: json['aqi_min'] as int?,
      aqiMax: json['aqi_max'] as int?,
      aqiStd: (json['aqi_std'] as num?)?.toDouble(),
      overallTrend: json['overall_trend'] as String? ?? 'STABLE',
      aqiCategoryDistribution: catDist,
      pollutantSummaries: pollSum,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// Detailed historical trends with diurnal profile
@immutable
class HistoricalTrendsModel {
  final String stationId;
  final String period;
  final int datapointsCount;
  final String overallTrend;
  final double? slopeAqiPerDay;
  final double? rSquared;
  final bool isStatisticallySignificant;
  final Map<int, double?> diurnalProfile;
  final Map<String, PollutantTrendModel> pollutantTrends;
  final List<DataGapModel> detectedGaps;
  final List<HistoricalDataPointModel> timeseries;
  final String disclaimer;

  const HistoricalTrendsModel({
    required this.stationId,
    required this.period,
    required this.datapointsCount,
    this.overallTrend = 'STABLE',
    this.slopeAqiPerDay,
    this.rSquared,
    this.isStatisticallySignificant = false,
    this.diurnalProfile = const {},
    this.pollutantTrends = const {},
    this.detectedGaps = const [],
    this.timeseries = const [],
    required this.disclaimer,
  });

  factory HistoricalTrendsModel.fromJson(Map<String, dynamic> json) {
    final diurnalRaw = json['diurnal_profile'] as Map<String, dynamic>? ?? {};
    final diurnal = diurnalRaw.map(
      (k, v) => MapEntry(int.parse(k), (v as num?)?.toDouble()),
    );

    final pollTrendsRaw = json['pollutant_trends'] as Map<String, dynamic>? ?? {};
    final pollTrends = pollTrendsRaw.map(
      (k, v) => MapEntry(k, PollutantTrendModel.fromJson(v as Map<String, dynamic>)),
    );

    final gapsRaw = json['detected_gaps'] as List<dynamic>? ?? [];
    final gaps = gapsRaw.map((g) => DataGapModel.fromJson(g as Map<String, dynamic>)).toList();

    final tsRaw = json['timeseries'] as List<dynamic>? ?? [];
    final ts = tsRaw.map((t) => HistoricalDataPointModel.fromJson(t as Map<String, dynamic>)).toList();

    return HistoricalTrendsModel(
      stationId: json['station_id'] as String,
      period: json['period'] as String,
      datapointsCount: json['datapoints_count'] as int? ?? 0,
      overallTrend: json['overall_trend'] as String? ?? 'STABLE',
      slopeAqiPerDay: (json['slope_aqi_per_day'] as num?)?.toDouble(),
      rSquared: (json['r_squared'] as num?)?.toDouble(),
      isStatisticallySignificant: json['is_statistically_significant'] as bool? ?? false,
      diurnalProfile: diurnal,
      pollutantTrends: pollTrends,
      detectedGaps: gaps,
      timeseries: ts,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// A single day on the historical pollution calendar
@immutable
class CalendarDayModel {
  final String date;
  final String dayOfWeek;
  final int sampleCount;
  final double dataCoveragePct;
  final bool isSufficient;
  final int? representativeAqi;
  final String? aqiCategory;
  final String? dominantPollutant;
  final bool isUnavailable;
  final double? meanPm25;
  final double? meanPm10;
  final String regulatoryDisclosure;

  const CalendarDayModel({
    required this.date,
    required this.dayOfWeek,
    required this.sampleCount,
    required this.dataCoveragePct,
    required this.isSufficient,
    this.representativeAqi,
    this.aqiCategory,
    this.dominantPollutant,
    this.isUnavailable = false,
    this.meanPm25,
    this.meanPm10,
    required this.regulatoryDisclosure,
  });

  factory CalendarDayModel.fromJson(Map<String, dynamic> json) {
    return CalendarDayModel(
      date: json['date'] as String,
      dayOfWeek: json['day_of_week'] as String,
      sampleCount: json['sample_count'] as int,
      dataCoveragePct: (json['data_coverage_pct'] as num).toDouble(),
      isSufficient: json['is_sufficient'] as bool? ?? false,
      representativeAqi: json['representative_aqi'] as int?,
      aqiCategory: json['aqi_category'] as String?,
      dominantPollutant: json['dominant_pollutant'] as String?,
      isUnavailable: json['is_unavailable'] as bool? ?? false,
      meanPm25: (json['mean_pm2_5'] as num?)?.toDouble(),
      meanPm10: (json['mean_pm10'] as num?)?.toDouble(),
      regulatoryDisclosure: json['regulatory_disclosure'] as String? ?? '',
    );
  }
}

/// Calendar dataset of daily historical evaluations
@immutable
class HistoricalCalendarModel {
  final String stationId;
  final String period;
  final int totalDays;
  final int sufficientDays;
  final int insufficientDays;
  final int unavailableDays;
  final List<CalendarDayModel> days;
  final String disclaimer;

  const HistoricalCalendarModel({
    required this.stationId,
    required this.period,
    required this.totalDays,
    required this.sufficientDays,
    required this.insufficientDays,
    required this.unavailableDays,
    required this.days,
    required this.disclaimer,
  });

  factory HistoricalCalendarModel.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['days'] as List<dynamic>? ?? [];
    return HistoricalCalendarModel(
      stationId: json['station_id'] as String,
      period: json['period'] as String,
      totalDays: json['total_days'] as int,
      sufficientDays: json['sufficient_days'] as int,
      insufficientDays: json['insufficient_days'] as int,
      unavailableDays: json['unavailable_days'] as int,
      days: daysRaw.map((d) => CalendarDayModel.fromJson(d as Map<String, dynamic>)).toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// Extreme episodes response (peaks and cleanest periods)
@immutable
class HistoricalExtremesModel {
  final String stationId;
  final String period;
  final int? maximumAqi;
  final DateTime? maximumAqiTimestamp;
  final int? minimumAqi;
  final DateTime? minimumAqiTimestamp;
  final List<PeakEpisodeModel> peakEpisodes;
  final List<PeakEpisodeModel> cleanestPeriods;
  final String disclaimer;

  const HistoricalExtremesModel({
    required this.stationId,
    required this.period,
    this.maximumAqi,
    this.maximumAqiTimestamp,
    this.minimumAqi,
    this.minimumAqiTimestamp,
    required this.peakEpisodes,
    required this.cleanestPeriods,
    required this.disclaimer,
  });

  factory HistoricalExtremesModel.fromJson(Map<String, dynamic> json) {
    final peaksRaw = json['peak_episodes'] as List<dynamic>? ?? [];
    final cleanestRaw = json['cleanest_periods'] as List<dynamic>? ?? [];

    return HistoricalExtremesModel(
      stationId: json['station_id'] as String,
      period: json['period'] as String,
      maximumAqi: json['maximum_aqi'] as int?,
      maximumAqiTimestamp: json['maximum_aqi_timestamp'] != null
          ? DateTime.parse(json['maximum_aqi_timestamp'] as String)
          : null,
      minimumAqi: json['minimum_aqi'] as int?,
      minimumAqiTimestamp: json['minimum_aqi_timestamp'] != null
          ? DateTime.parse(json['minimum_aqi_timestamp'] as String)
          : null,
      peakEpisodes: peaksRaw.map((p) => PeakEpisodeModel.fromJson(p as Map<String, dynamic>)).toList(),
      cleanestPeriods: cleanestRaw.map((c) => PeakEpisodeModel.fromJson(c as Map<String, dynamic>)).toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// Location comparison response
@immutable
class HistoricalCompareModel {
  final String stationA;
  final String stationB;
  final String period;
  final bool isCompatible;
  final List<String> compatibilityNotes;
  final double? aqiMeanA;
  final double? aqiMeanB;
  final double? aqiDifference;
  final int? peakAqiA;
  final int? peakAqiB;
  final double coveragePctA;
  final double coveragePctB;
  final Map<String, double> pollutantDifferences;
  final String disclaimer;

  const HistoricalCompareModel({
    required this.stationA,
    required this.stationB,
    required this.period,
    required this.isCompatible,
    required this.compatibilityNotes,
    this.aqiMeanA,
    this.aqiMeanB,
    this.aqiDifference,
    this.peakAqiA,
    this.peakAqiB,
    required this.coveragePctA,
    required this.coveragePctB,
    required this.pollutantDifferences,
    required this.disclaimer,
  });

  factory HistoricalCompareModel.fromJson(Map<String, dynamic> json) {
    final diffsRaw = json['pollutant_differences'] as Map<String, dynamic>? ?? {};
    final diffs = diffsRaw.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final notesRaw = json['compatibility_notes'] as List<dynamic>? ?? [];
    final notes = notesRaw.map((n) => n.toString()).toList();

    return HistoricalCompareModel(
      stationA: json['station_a'] as String,
      stationB: json['station_b'] as String,
      period: json['period'] as String,
      isCompatible: json['is_compatible'] as bool? ?? false,
      compatibilityNotes: notes,
      aqiMeanA: (json['aqi_mean_a'] as num?)?.toDouble(),
      aqiMeanB: (json['aqi_mean_b'] as num?)?.toDouble(),
      aqiDifference: (json['aqi_difference'] as num?)?.toDouble(),
      peakAqiA: json['peak_aqi_a'] as int?,
      peakAqiB: json['peak_aqi_b'] as int?,
      coveragePctA: (json['coverage_pct_a'] as num).toDouble(),
      coveragePctB: (json['coverage_pct_b'] as num).toDouble(),
      pollutantDifferences: diffs,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// Audit response for historical completeness and gaps
@immutable
class HistoricalCoverageModel {
  final String stationId;
  final String period;
  final DateTime startTime;
  final DateTime endTime;
  final int expectedSamples;
  final int actualSamples;
  final double coveragePct;
  final int gapsCount;
  final double longestGapHours;
  final double temporalRegularityScore;
  final List<DataGapModel> gaps;
  final String disclaimer;

  const HistoricalCoverageModel({
    required this.stationId,
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.expectedSamples,
    required this.actualSamples,
    required this.coveragePct,
    required this.gapsCount,
    required this.longestGapHours,
    required this.temporalRegularityScore,
    required this.gaps,
    required this.disclaimer,
  });

  factory HistoricalCoverageModel.fromJson(Map<String, dynamic> json) {
    final gapsRaw = json['gaps'] as List<dynamic>? ?? [];
    return HistoricalCoverageModel(
      stationId: json['station_id'] as String,
      period: json['period'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      expectedSamples: json['expected_samples'] as int,
      actualSamples: json['actual_samples'] as int,
      coveragePct: (json['coverage_pct'] as num).toDouble(),
      gapsCount: json['gaps_count'] as int,
      longestGapHours: (json['longest_gap_hours'] as num).toDouble(),
      temporalRegularityScore: (json['temporal_regularity_score'] as num).toDouble(),
      gaps: gapsRaw.map((g) => DataGapModel.fromJson(g as Map<String, dynamic>)).toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// Downloadable publication-ready report
@immutable
class HistoricalReportModel {
  final String title;
  final String stationId;
  final String stationName;
  final String period;
  final DateTime generatedAt;
  final String executiveSummary;
  final String markdownContent;
  final HistoricalCoverageModel coverageAudit;
  final Map<String, dynamic> trendAnalysis;
  final String disclaimer;

  const HistoricalReportModel({
    required this.title,
    required this.stationId,
    required this.stationName,
    required this.period,
    required this.generatedAt,
    required this.executiveSummary,
    required this.markdownContent,
    required this.coverageAudit,
    required this.trendAnalysis,
    required this.disclaimer,
  });

  factory HistoricalReportModel.fromJson(Map<String, dynamic> json) {
    return HistoricalReportModel(
      title: json['title'] as String,
      stationId: json['station_id'] as String,
      stationName: json['station_name'] as String,
      period: json['period'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      executiveSummary: json['executive_summary'] as String,
      markdownContent: json['markdown_content'] as String,
      coverageAudit: HistoricalCoverageModel.fromJson(json['coverage_audit'] as Map<String, dynamic>),
      trendAnalysis: json['trend_analysis'] as Map<String, dynamic>? ?? {},
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

/// Evidence-based explainable narrative
@immutable
class HistoricalExplanationModel {
  final String narrative;
  final List<String> keyInsights;
  final List<String> diurnalObservations;
  final List<String> dataLimitations;
  final String disclaimer;
  final String provider;
  final DateTime timestamp;

  const HistoricalExplanationModel({
    required this.narrative,
    required this.keyInsights,
    required this.diurnalObservations,
    required this.dataLimitations,
    required this.disclaimer,
    required this.provider,
    required this.timestamp,
  });

  factory HistoricalExplanationModel.fromJson(Map<String, dynamic> json) {
    final insightsRaw = json['key_insights'] as List<dynamic>? ?? [];
    final diurnalRaw = json['diurnal_observations'] as List<dynamic>? ?? [];
    final limitRaw = json['data_limitations'] as List<dynamic>? ?? [];

    return HistoricalExplanationModel(
      narrative: json['narrative'] as String,
      keyInsights: insightsRaw.map((s) => s.toString()).toList(),
      diurnalObservations: diurnalRaw.map((s) => s.toString()).toList(),
      dataLimitations: limitRaw.map((s) => s.toString()).toList(),
      disclaimer: json['disclaimer'] as String? ?? '',
      provider: json['provider'] as String? ?? 'AirGuard Explainer',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
