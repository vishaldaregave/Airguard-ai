import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum ActivityTypeEnum {
  resting,
  commuting,
  walking,
  cycling,
  running;

  static ActivityTypeEnum fromString(String val) {
    switch (val.toLowerCase()) {
      case 'resting':
        return ActivityTypeEnum.resting;
      case 'commuting':
        return ActivityTypeEnum.commuting;
      case 'cycling':
        return ActivityTypeEnum.cycling;
      case 'running':
        return ActivityTypeEnum.running;
      case 'walking':
      default:
        return ActivityTypeEnum.walking;
    }
  }

  String get keyName => name;

  IconData get icon {
    switch (this) {
      case ActivityTypeEnum.resting:
        return Icons.hotel_outlined;
      case ActivityTypeEnum.commuting:
        return Icons.directions_bus_outlined;
      case ActivityTypeEnum.walking:
        return Icons.directions_walk_outlined;
      case ActivityTypeEnum.cycling:
        return Icons.directions_bike_outlined;
      case ActivityTypeEnum.running:
        return Icons.directions_run_outlined;
    }
  }
}

class ActivityProfileModel {
  final ActivityTypeEnum activityType;
  final String displayName;
  final double inhalationRateM3H;
  final double metEquivalent;
  final String description;
  final String reference;

  const ActivityProfileModel({
    required this.activityType,
    required this.displayName,
    required this.inhalationRateM3H,
    required this.metEquivalent,
    required this.description,
    required this.reference,
  });

  factory ActivityProfileModel.fromJson(Map<String, dynamic> json) {
    return ActivityProfileModel(
      activityType: ActivityTypeEnum.fromString(json['activity_type'] as String? ?? 'walking'),
      displayName: json['display_name'] as String? ?? 'Walking',
      inhalationRateM3H: (json['inhalation_rate_m3_h'] as num?)?.toDouble() ?? 1.20,
      metEquivalent: (json['met_equivalent'] as num?)?.toDouble() ?? 3.0,
      description: json['description'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'activity_type': activityType.keyName,
        'display_name': displayName,
        'inhalation_rate_m3_h': inhalationRateM3H,
        'met_equivalent': metEquivalent,
        'description': description,
        'reference': reference,
      };
}

class PollutantExposureMetricModel {
  final String pollutant;
  final double? ambientConcentration;
  final String concentrationUnit;
  final double? concentrationTimeExposure;
  final String exposureUnit;
  final double inhalationRateM3H;
  final double? estimatedInhaledMass;
  final String massUnit;
  final bool isAvailable;

  const PollutantExposureMetricModel({
    required this.pollutant,
    this.ambientConcentration,
    required this.concentrationUnit,
    this.concentrationTimeExposure,
    required this.exposureUnit,
    required this.inhalationRateM3H,
    this.estimatedInhaledMass,
    required this.massUnit,
    this.isAvailable = true,
  });

  factory PollutantExposureMetricModel.fromJson(Map<String, dynamic> json) {
    return PollutantExposureMetricModel(
      pollutant: json['pollutant'] as String? ?? '',
      ambientConcentration: (json['ambient_concentration'] as num?)?.toDouble(),
      concentrationUnit: json['concentration_unit'] as String? ?? 'µg/m³',
      concentrationTimeExposure: (json['concentration_time_exposure'] as num?)?.toDouble(),
      exposureUnit: json['exposure_unit'] as String? ?? 'µg·h/m³',
      inhalationRateM3H: (json['inhalation_rate_m3_h'] as num?)?.toDouble() ?? 1.20,
      estimatedInhaledMass: (json['estimated_inhaled_mass'] as num?)?.toDouble(),
      massUnit: json['mass_unit'] as String? ?? 'µg',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'pollutant': pollutant,
        'ambient_concentration': ambientConcentration,
        'concentration_unit': concentrationUnit,
        'concentration_time_exposure': concentrationTimeExposure,
        'exposure_unit': exposureUnit,
        'inhalation_rate_m3_h': inhalationRateM3H,
        'estimated_inhaled_mass': estimatedInhaledMass,
        'mass_unit': massUnit,
        'is_available': isAvailable,
      };
}

class ExposureSimulationModel {
  final String status;
  final ActivityProfileModel activity;
  final int durationMinutes;
  final double durationHours;
  final double totalInhaledVolumeM3;
  final String dataSourceType;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final Map<String, PollutantExposureMetricModel> pollutants;
  final int? cpcbAqi;
  final String? cpcbCategory;
  final String? prominentPollutant;
  final bool isForecast;
  final bool isInterpolated;
  final double? spatialUncertaintyScore;
  final String calculationMethodology;
  final String disclaimer;
  final DateTime timestamp;

  const ExposureSimulationModel({
    required this.status,
    required this.activity,
    required this.durationMinutes,
    required this.durationHours,
    required this.totalInhaledVolumeM3,
    required this.dataSourceType,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.pollutants,
    this.cpcbAqi,
    this.cpcbCategory,
    this.prominentPollutant,
    this.isForecast = false,
    this.isInterpolated = false,
    this.spatialUncertaintyScore,
    required this.calculationMethodology,
    required this.disclaimer,
    required this.timestamp,
  });

  factory ExposureSimulationModel.fromJson(Map<String, dynamic> json) {
    final polMap = <String, PollutantExposureMetricModel>{};
    if (json['pollutants'] is Map) {
      (json['pollutants'] as Map).forEach((k, v) {
        if (v is Map) {
          polMap[k.toString()] = PollutantExposureMetricModel.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    final actJson = json['activity'] is Map
        ? Map<String, dynamic>.from(json['activity'] as Map)
        : <String, dynamic>{};

    return ExposureSimulationModel(
      status: json['status'] as String? ?? 'COMPUTED',
      activity: ActivityProfileModel.fromJson(actJson),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      durationHours: (json['duration_hours'] as num?)?.toDouble() ?? 1.0,
      totalInhaledVolumeM3: (json['total_inhaled_volume_m3'] as num?)?.toDouble() ?? 1.2,
      dataSourceType: json['data_source_type'] as String? ?? 'LIVE',
      locationName: json['location_name'] as String? ?? 'Selected Location',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      pollutants: polMap,
      cpcbAqi: json['cpcb_aqi'] as int?,
      cpcbCategory: json['cpcb_category'] as String?,
      prominentPollutant: json['prominent_pollutant'] as String?,
      isForecast: json['is_forecast'] as bool? ?? false,
      isInterpolated: json['is_interpolated'] as bool? ?? false,
      spatialUncertaintyScore: (json['spatial_uncertainty_score'] as num?)?.toDouble(),
      calculationMethodology: json['calculation_methodology'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Color get aqiColor => AppColors.getAqiColor(cpcbAqi);
}

class PollutantComparisonDeltaModel {
  final String pollutant;
  final double? scenarioAExposure;
  final double? scenarioBExposure;
  final double? deltaExposure;
  final String exposureUnit;
  final double? scenarioAInhaledMass;
  final double? scenarioBInhaledMass;
  final double? deltaInhaledMass;
  final String massUnit;
  final double? percentChangeInhaledMass;
  final String summary;

  const PollutantComparisonDeltaModel({
    required this.pollutant,
    this.scenarioAExposure,
    this.scenarioBExposure,
    this.deltaExposure,
    required this.exposureUnit,
    this.scenarioAInhaledMass,
    this.scenarioBInhaledMass,
    this.deltaInhaledMass,
    required this.massUnit,
    this.percentChangeInhaledMass,
    required this.summary,
  });

  factory PollutantComparisonDeltaModel.fromJson(Map<String, dynamic> json) {
    return PollutantComparisonDeltaModel(
      pollutant: json['pollutant'] as String? ?? '',
      scenarioAExposure: (json['scenario_a_exposure'] as num?)?.toDouble(),
      scenarioBExposure: (json['scenario_b_exposure'] as num?)?.toDouble(),
      deltaExposure: (json['delta_exposure'] as num?)?.toDouble(),
      exposureUnit: json['exposure_unit'] as String? ?? 'µg·h/m³',
      scenarioAInhaledMass: (json['scenario_a_inhaled_mass'] as num?)?.toDouble(),
      scenarioBInhaledMass: (json['scenario_b_inhaled_mass'] as num?)?.toDouble(),
      deltaInhaledMass: (json['delta_inhaled_mass'] as num?)?.toDouble(),
      massUnit: json['mass_unit'] as String? ?? 'µg',
      percentChangeInhaledMass: (json['percent_change_inhaled_mass'] as num?)?.toDouble(),
      summary: json['summary'] as String? ?? '',
    );
  }
}

class ScenarioComparisonItemModel {
  final String scenarioId;
  final String label;
  final ExposureSimulationModel simulation;

  const ScenarioComparisonItemModel({
    required this.scenarioId,
    required this.label,
    required this.simulation,
  });

  factory ScenarioComparisonItemModel.fromJson(Map<String, dynamic> json) {
    final simJson = json['simulation'] is Map
        ? Map<String, dynamic>.from(json['simulation'] as Map)
        : <String, dynamic>{};

    return ScenarioComparisonItemModel(
      scenarioId: json['scenario_id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      simulation: ExposureSimulationModel.fromJson(simJson),
    );
  }
}

class ExposureComparisonModel {
  final ScenarioComparisonItemModel scenarioA;
  final ScenarioComparisonItemModel scenarioB;
  final Map<String, PollutantComparisonDeltaModel> deltas;
  final String physicalComparisonSummary;
  final String disclaimer;
  final DateTime timestamp;

  const ExposureComparisonModel({
    required this.scenarioA,
    required this.scenarioB,
    required this.deltas,
    required this.physicalComparisonSummary,
    required this.disclaimer,
    required this.timestamp,
  });

  factory ExposureComparisonModel.fromJson(Map<String, dynamic> json) {
    final deltasMap = <String, PollutantComparisonDeltaModel>{};
    if (json['deltas'] is Map) {
      (json['deltas'] as Map).forEach((k, v) {
        if (v is Map) {
          deltasMap[k.toString()] =
              PollutantComparisonDeltaModel.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    final scenAJson = json['scenario_a'] is Map
        ? Map<String, dynamic>.from(json['scenario_a'] as Map)
        : <String, dynamic>{};
    final scenBJson = json['scenario_b'] is Map
        ? Map<String, dynamic>.from(json['scenario_b'] as Map)
        : <String, dynamic>{};

    return ExposureComparisonModel(
      scenarioA: ScenarioComparisonItemModel.fromJson(scenAJson),
      scenarioB: ScenarioComparisonItemModel.fromJson(scenBJson),
      deltas: deltasMap,
      physicalComparisonSummary: json['physical_comparison_summary'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ExposureExplanationModel {
  final String narrative;
  final List<String> keyTakeaways;
  final List<String> protectiveSuggestions;
  final String methodologyNote;
  final String disclaimer;
  final String provider;
  final DateTime timestamp;

  const ExposureExplanationModel({
    required this.narrative,
    this.keyTakeaways = const [],
    this.protectiveSuggestions = const [],
    required this.methodologyNote,
    required this.disclaimer,
    required this.provider,
    required this.timestamp,
  });

  factory ExposureExplanationModel.fromJson(Map<String, dynamic> json) {
    final takeaways = (json['key_takeaways'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final suggestions = (json['protective_suggestions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return ExposureExplanationModel(
      narrative: json['narrative'] as String? ?? '',
      keyTakeaways: takeaways,
      protectiveSuggestions: suggestions,
      methodologyNote: json['methodology_note'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      provider: json['provider'] as String? ?? 'AirGuard Engine',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
