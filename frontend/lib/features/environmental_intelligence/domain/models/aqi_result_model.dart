import 'observation_model.dart';

class SubIndexResult {
  final String pollutant;
  final double concentration;
  final String unit;
  final int subIndex;
  final String category;
  final double breakpointLow;
  final double breakpointHigh;
  final int indexLow;
  final int indexHigh;

  SubIndexResult({
    required this.pollutant,
    required this.concentration,
    required this.unit,
    required this.subIndex,
    required this.category,
    required this.breakpointLow,
    required this.breakpointHigh,
    required this.indexLow,
    required this.indexHigh,
  });

  factory SubIndexResult.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return SubIndexResult(
      pollutant: json['pollutant'] as String,
      concentration: (json['concentration'] as num).toDouble(),
      unit: json['unit'] as String,
      subIndex: json['sub_index'] as int,
      category: json['category'] as String,
      breakpointLow: (json['breakpoint_low'] as num).toDouble(),
      breakpointHigh: (json['breakpoint_high'] as num).toDouble(),
      indexLow: json['index_low'] as int,
      indexHigh: json['index_high'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pollutant': pollutant,
      'concentration': concentration,
      'unit': unit,
      'sub_index': subIndex,
      'category': category,
      'breakpoint_low': breakpointLow,
      'breakpoint_high': breakpointHigh,
      'index_low': indexLow,
      'index_high': indexHigh,
    };
  }
}

class HealthAdvisory {
  final String category;
  final String generalStatement;
  final String sensitiveGroupAdvice;
  final String outdoorActivityAdvice;
  final String? recommendedMask;
  final String? airPurifierAdvice;

  HealthAdvisory({
    required this.category,
    required this.generalStatement,
    required this.sensitiveGroupAdvice,
    required this.outdoorActivityAdvice,
    this.recommendedMask,
    this.airPurifierAdvice,
  });

  factory HealthAdvisory.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return HealthAdvisory(
      category: json['category'] as String,
      generalStatement: json['general_statement'] as String,
      sensitiveGroupAdvice: json['sensitive_group_advice'] as String,
      outdoorActivityAdvice: json['outdoor_activity_advice'] as String,
      recommendedMask: json['recommended_mask'] as String?,
      airPurifierAdvice: json['air_purifier_advice'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'general_statement': generalStatement,
      'sensitive_group_advice': sensitiveGroupAdvice,
      'outdoor_activity_advice': outdoorActivityAdvice,
      'recommended_mask': recommendedMask,
      'air_purifier_advice': airPurifierAdvice,
    };
  }
}

class AQICalculationResult {
  final String standard;
  final String status;
  final String statusMessage;
  final int? overallAqi;
  final String? category;
  final String? colorCode;
  final String? prominentPollutant;
  final Map<String, SubIndexResult> subIndices;
  final int monitoredPollutantCount;
  final bool hasParticulateMatter;
  final HealthAdvisory? healthAdvisory;
  final bool isStale;
  final String dataSourceType;
  final String provider;
  final DateTime observationTimestamp;
  final DateTime calculationTimestamp;
  final LocationCoordinate location;

  AQICalculationResult({
    required this.standard,
    required this.status,
    required this.statusMessage,
    this.overallAqi,
    this.category,
    this.colorCode,
    this.prominentPollutant,
    required this.subIndices,
    required this.monitoredPollutantCount,
    required this.hasParticulateMatter,
    this.healthAdvisory,
    required this.isStale,
    required this.dataSourceType,
    required this.provider,
    required this.observationTimestamp,
    required this.calculationTimestamp,
    required this.location,
  });

  factory AQICalculationResult.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    final subIndicesMap = <String, SubIndexResult>{};
    if (json['sub_indices'] != null) {
      (json['sub_indices'] as Map<dynamic, dynamic>).forEach((key, val) {
        subIndicesMap[key.toString()] = SubIndexResult.fromJson(val as Map<dynamic, dynamic>);
      });
    }

    return AQICalculationResult(
      standard: json['standard'] as String? ?? 'CPCB_INDIA',
      status: json['status'] as String,
      statusMessage: json['status_message'] as String,
      overallAqi: json['overall_aqi'] as int?,
      category: json['category'] as String?,
      colorCode: json['color_code'] as String?,
      prominentPollutant: json['prominent_pollutant'] as String?,
      subIndices: subIndicesMap,
      monitoredPollutantCount: json['monitored_pollutant_count'] as int,
      hasParticulateMatter: json['has_particulate_matter'] as bool,
      healthAdvisory: json['health_advisory'] != null
          ? HealthAdvisory.fromJson(json['health_advisory'] as Map<dynamic, dynamic>)
          : null,
      isStale: json['is_stale'] as bool? ?? false,
      dataSourceType: json['data_source_type'] as String,
      provider: json['provider'] as String,
      observationTimestamp: DateTime.parse(json['observation_timestamp'] as String),
      calculationTimestamp: DateTime.parse(json['calculation_timestamp'] as String),
      location: LocationCoordinate.fromJson(json['location'] as Map<dynamic, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'standard': standard,
      'status': status,
      'status_message': statusMessage,
      'overall_aqi': overallAqi,
      'category': category,
      'color_code': colorCode,
      'prominent_pollutant': prominentPollutant,
      'sub_indices': subIndices.map((k, v) => MapEntry(k, v.toJson())),
      'monitored_pollutant_count': monitoredPollutantCount,
      'has_particulate_matter': hasParticulateMatter,
      'health_advisory': healthAdvisory?.toJson(),
      'is_stale': isStale,
      'data_source_type': dataSourceType,
      'provider': provider,
      'observation_timestamp': observationTimestamp.toIso8601String(),
      'calculation_timestamp': calculationTimestamp.toIso8601String(),
      'location': location.toJson(),
    };
  }
}
