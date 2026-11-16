import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum StationType {
  physicalMonitor,
  atmosphericModelGrid,
  syntheticFixture;

  static StationType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PHYSICAL_MONITOR':
        return StationType.physicalMonitor;
      case 'ATMOSPHERIC_MODEL_GRID':
        return StationType.atmosphericModelGrid;
      case 'SYNTHETIC_FIXTURE':
      default:
        return StationType.syntheticFixture;
    }
  }

  String get displayName {
    switch (this) {
      case StationType.physicalMonitor:
        return 'Physical Station';
      case StationType.atmosphericModelGrid:
        return 'Atmospheric Model Grid';
      case StationType.syntheticFixture:
        return 'Synthetic Demo Fixture';
    }
  }

  IconData get icon {
    switch (this) {
      case StationType.physicalMonitor:
        return Icons.sensors_outlined;
      case StationType.atmosphericModelGrid:
        return Icons.grid_view_outlined;
      case StationType.syntheticFixture:
        return Icons.science_outlined;
    }
  }
}

enum HotspotSeverity {
  severeHotspot,
  veryPoorHotspot,
  elevatedCluster,
  isolatedElevatedReading;

  static HotspotSeverity fromString(String val) {
    switch (val.toUpperCase()) {
      case 'SEVERE_HOTSPOT':
        return HotspotSeverity.severeHotspot;
      case 'VERY_POOR_HOTSPOT':
        return HotspotSeverity.veryPoorHotspot;
      case 'ELEVATED_CLUSTER':
        return HotspotSeverity.elevatedCluster;
      case 'ISOLATED_ELEVATED_READING':
      default:
        return HotspotSeverity.isolatedElevatedReading;
    }
  }

  String get displayName {
    switch (this) {
      case HotspotSeverity.severeHotspot:
        return 'Severe Hotspot';
      case HotspotSeverity.veryPoorHotspot:
        return 'Very Poor Hotspot';
      case HotspotSeverity.elevatedCluster:
        return 'Elevated Cluster';
      case HotspotSeverity.isolatedElevatedReading:
        return 'Isolated Elevated Reading';
    }
  }

  Color get color {
    switch (this) {
      case HotspotSeverity.severeHotspot:
        return AppColors.aqiSevere;
      case HotspotSeverity.veryPoorHotspot:
        return AppColors.aqiVeryPoor;
      case HotspotSeverity.elevatedCluster:
        return AppColors.aqiPoor;
      case HotspotSeverity.isolatedElevatedReading:
        return AppColors.aqiModerate;
    }
  }
}

class GeoStationModel {
  final String stationId;
  final String stationName;
  final String provider;
  final StationType stationType;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final List<String> availablePollutants;
  final String dataSourceType;
  final DateTime? latestObservationTime;
  final bool isOperational;

  bool get isActive => isOperational;

  const GeoStationModel({
    required this.stationId,
    required this.stationName,
    required this.provider,
    required this.stationType,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    this.availablePollutants = const [],
    required this.dataSourceType,
    this.latestObservationTime,
    this.isOperational = true,
  });

  factory GeoStationModel.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return GeoStationModel(
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? 'Monitoring Station',
      provider: json['provider'] as String? ?? 'CPCB',
      stationType: StationType.fromString(json['station_type'] as String? ?? ''),
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      availablePollutants: (json['available_pollutants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dataSourceType: json['data_source_type'] as String? ?? 'LIVE',
      latestObservationTime: DateTime.tryParse(json['latest_observation_time']?.toString() ?? ''),
      isOperational: json['is_operational'] as bool? ?? true,
    );
  }
}

class GeoObservationModel {
  final String stationId;
  final String stationName;
  final String provider;
  final StationType stationType;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String dataSourceType;
  final int? aqi;
  final String? aqiCategory;
  final String? prominentPollutant;
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? so2;
  final double? co;
  final double? o3;
  final double? nh3;
  final double? pb;
  final double? temperatureCelsius;
  final double? relativeHumidityPct;
  final double? windSpeedKmh;
  final double? dataFreshnessMinutes;
  final bool isStale;
  final double? distanceKm;

  String? get cpcbCategory => aqiCategory;
  String? get dominantPollutant => prominentPollutant;

  const GeoObservationModel({
    required this.stationId,
    required this.stationName,
    required this.provider,
    required this.stationType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.dataSourceType,
    this.aqi,
    this.aqiCategory,
    this.prominentPollutant,
    this.pm25,
    this.pm10,
    this.no2,
    this.so2,
    this.co,
    this.o3,
    this.nh3,
    this.pb,
    this.temperatureCelsius,
    this.relativeHumidityPct,
    this.windSpeedKmh,
    this.dataFreshnessMinutes,
    this.isStale = false,
    this.distanceKm,
  });

  factory GeoObservationModel.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    final pollutants = json['pollutant_concentrations'] as Map<String, dynamic>? ?? {};

    return GeoObservationModel(
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? 'Monitoring Location',
      provider: json['provider'] as String? ?? 'CPCB',
      stationType: StationType.fromString(json['station_type'] as String? ?? ''),
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      dataSourceType: json['data_source_type'] as String? ?? 'LIVE',
      aqi: json['aqi'] as int?,
      aqiCategory: json['aqi_category'] as String?,
      prominentPollutant: json['prominent_pollutant'] as String?,
      pm25: (pollutants['PM2.5'] as num?)?.toDouble(),
      pm10: (pollutants['PM10'] as num?)?.toDouble(),
      no2: (pollutants['NO2'] as num?)?.toDouble(),
      so2: (pollutants['SO2'] as num?)?.toDouble(),
      co: (pollutants['CO'] as num?)?.toDouble(),
      o3: (pollutants['O3'] as num?)?.toDouble(),
      nh3: (pollutants['NH3'] as num?)?.toDouble(),
      pb: (pollutants['Pb'] as num?)?.toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble(),
      relativeHumidityPct: (json['relative_humidity_pct'] as num?)?.toDouble(),
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble(),
      dataFreshnessMinutes: (json['data_freshness_minutes'] as num?)?.toDouble(),
      isStale: json['is_stale'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  Color get aqiColor => AppColors.getAqiColor(aqi);
}

class ContributingStationModel {
  final String stationId;
  final String stationName;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double weightNormalized;
  final String provider;
  final String dataSourceType;
  final int? stationAqi;

  double get weight => weightNormalized;

  const ContributingStationModel({
    required this.stationId,
    required this.stationName,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.weightNormalized,
    required this.provider,
    required this.dataSourceType,
    this.stationAqi,
  });

  factory ContributingStationModel.fromJson(Map<String, dynamic> json) {
    return ContributingStationModel(
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      weightNormalized: (json['weight_normalized'] as num?)?.toDouble() ?? 0.0,
      provider: json['provider'] as String? ?? '',
      dataSourceType: json['data_source_type'] as String? ?? 'LIVE',
      stationAqi: json['station_aqi'] as int?,
    );
  }
}

class InterpolatedPollutantModel {
  final String pollutant;
  final double estimatedValue;
  final String unit;
  final String averagingPeriod;
  final int contributingCount;
  final double? subIndex;

  const InterpolatedPollutantModel({
    required this.pollutant,
    required this.estimatedValue,
    required this.unit,
    required this.averagingPeriod,
    required this.contributingCount,
    this.subIndex,
  });

  factory InterpolatedPollutantModel.fromJson(Map<String, dynamic> json) {
    return InterpolatedPollutantModel(
      pollutant: json['pollutant'] as String? ?? '',
      estimatedValue: (json['estimated_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? '',
      averagingPeriod: json['averaging_period'] as String? ?? '',
      contributingCount: json['contributing_count'] as int? ?? 0,
      subIndex: (json['sub_index'] as num?)?.toDouble(),
    );
  }
}

class SpatialInterpolationModel {
  final double targetLat;
  final double targetLon;
  final String status;
  final String dataSourceType;
  final int? interpolatedAqi;
  final String? aqiCategory;
  final String? prominentPollutant;
  final Map<String, InterpolatedPollutantModel> pollutants;
  final int eligibleStationsCount;
  final double? nearestStationKm;
  final double? maxContributingDistanceKm;
  final double spatialUncertaintyScore;
  final String uncertaintyLevel;
  final List<ContributingStationModel> contributingStations;
  final String method;
  final double idwPower;
  final String message;
  final String disclaimer;
  final DateTime timestamp;

  String? get cpcbCategory => aqiCategory;
  String? get dominantPollutant => prominentPollutant;
  int get contributingStationCount => eligibleStationsCount;
  bool get isInterpolated => status == 'INTERPOLATED';

  const SpatialInterpolationModel({
    required this.targetLat,
    required this.targetLon,
    required this.status,
    required this.dataSourceType,
    this.interpolatedAqi,
    this.aqiCategory,
    this.prominentPollutant,
    this.pollutants = const {},
    required this.eligibleStationsCount,
    this.nearestStationKm,
    this.maxContributingDistanceKm,
    required this.spatialUncertaintyScore,
    required this.uncertaintyLevel,
    this.contributingStations = const [],
    required this.method,
    required this.idwPower,
    required this.message,
    required this.disclaimer,
    required this.timestamp,
  });

  factory SpatialInterpolationModel.fromJson(Map<String, dynamic> json) {
    final polMap = <String, InterpolatedPollutantModel>{};
    if (json['pollutants'] is Map) {
      (json['pollutants'] as Map<String, dynamic>).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          polMap[k] = InterpolatedPollutantModel.fromJson(v);
        }
      });
    }

    final stations = (json['contributing_stations'] as List<dynamic>?)
            ?.map((e) => ContributingStationModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final target = json['target_location'] as Map<String, dynamic>? ?? {};

    return SpatialInterpolationModel(
      targetLat: (target['latitude'] as num?)?.toDouble() ?? 0.0,
      targetLon: (target['longitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'INVALID_INPUT',
      dataSourceType: json['data_source_type'] as String? ?? 'ESTIMATED',
      interpolatedAqi: json['interpolated_aqi'] as int?,
      aqiCategory: json['aqi_category'] as String?,
      prominentPollutant: json['prominent_pollutant'] as String?,
      pollutants: polMap,
      eligibleStationsCount: json['eligible_stations_count'] as int? ?? 0,
      nearestStationKm: (json['nearest_station_km'] as num?)?.toDouble(),
      maxContributingDistanceKm: (json['max_contributing_distance_km'] as num?)?.toDouble(),
      spatialUncertaintyScore: (json['spatial_uncertainty_score'] as num?)?.toDouble() ?? 100.0,
      uncertaintyLevel: json['uncertainty_level'] as String? ?? 'HIGH',
      contributingStations: stations,
      method: json['method'] as String? ?? 'IDW',
      idwPower: (json['idw_power'] as num?)?.toDouble() ?? 2.0,
      message: json['message'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Color get aqiColor => AppColors.getAqiColor(interpolatedAqi);
}

class HotspotClusterModel {
  final String clusterId;
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final HotspotSeverity severity;
  final int contributingStationsCount;
  final bool isConfirmedHotspot;
  final int? peakAqi;
  final double? meanAqi;
  final double? peakPm25;
  final String? dominantPollutant;
  final String dataSourceType;
  final List<String> contributingStations;
  final String explanation;
  final String disclaimer;
  final DateTime detectedAt;

  const HotspotClusterModel({
    required this.clusterId,
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    required this.severity,
    required this.contributingStationsCount,
    required this.isConfirmedHotspot,
    this.peakAqi,
    this.meanAqi,
    this.peakPm25,
    this.dominantPollutant,
    required this.dataSourceType,
    this.contributingStations = const [],
    required this.explanation,
    required this.disclaimer,
    required this.detectedAt,
  });

  factory HotspotClusterModel.fromJson(Map<String, dynamic> json) {
    final loc = json['center_location'] as Map<String, dynamic>? ?? {};
    return HotspotClusterModel(
      clusterId: json['cluster_id'] as String? ?? '',
      centerLat: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      centerLon: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 2.0,
      severity: HotspotSeverity.fromString(json['severity'] as String? ?? ''),
      contributingStationsCount: json['contributing_stations_count'] as int? ?? 1,
      isConfirmedHotspot: json['is_confirmed_hotspot'] as bool? ?? false,
      peakAqi: json['peak_aqi'] as int?,
      meanAqi: (json['mean_aqi'] as num?)?.toDouble(),
      peakPm25: (json['peak_pm2_5'] as num?)?.toDouble(),
      dominantPollutant: json['dominant_pollutant'] as String?,
      dataSourceType: json['data_source_type'] as String? ?? 'LIVE',
      contributingStations: (json['contributing_stations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      explanation: json['explanation'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
      detectedAt: DateTime.tryParse(json['detected_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class GeoCoverageModel {
  final double centerLat;
  final double centerLon;
  final double searchRadiusKm;
  final int totalStations;
  final int physicalStationsCount;
  final int modelGridPointsCount;
  final int activeStationsCount;
  final Map<String, int> monitoredPollutantCounts;
  final double? nearestStationKm;
  final double? farthestStationKm;
  final double spatialDensityScore;
  final String coverageQuality;
  final String message;
  final DateTime timestamp;

  const GeoCoverageModel({
    required this.centerLat,
    required this.centerLon,
    required this.searchRadiusKm,
    required this.totalStations,
    required this.physicalStationsCount,
    required this.modelGridPointsCount,
    required this.activeStationsCount,
    this.monitoredPollutantCounts = const {},
    this.nearestStationKm,
    this.farthestStationKm,
    required this.spatialDensityScore,
    required this.coverageQuality,
    required this.message,
    required this.timestamp,
  });

  factory GeoCoverageModel.fromJson(Map<String, dynamic> json) {
    final loc = json['center_location'] as Map<String, dynamic>? ?? {};
    final polMap = <String, int>{};
    if (json['monitored_pollutant_counts'] is Map) {
      (json['monitored_pollutant_counts'] as Map<String, dynamic>).forEach((k, v) {
        if (v is num) polMap[k] = v.toInt();
      });
    }

    return GeoCoverageModel(
      centerLat: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      centerLon: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      searchRadiusKm: (json['search_radius_km'] as num?)?.toDouble() ?? 50.0,
      totalStations: json['total_stations'] as int? ?? 0,
      physicalStationsCount: json['physical_stations_count'] as int? ?? 0,
      modelGridPointsCount: json['model_grid_points_count'] as int? ?? 0,
      activeStationsCount: json['active_stations_count'] as int? ?? 0,
      monitoredPollutantCounts: polMap,
      nearestStationKm: (json['nearest_station_km'] as num?)?.toDouble(),
      farthestStationKm: (json['farthest_station_km'] as num?)?.toDouble(),
      spatialDensityScore: (json['spatial_density_score'] as num?)?.toDouble() ?? 0.0,
      coverageQuality: json['coverage_quality'] as String? ?? 'MODERATE',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Color get qualityColor {
    switch (coverageQuality.toUpperCase()) {
      case 'EXCELLENT':
        return AppColors.aqiGood;
      case 'GOOD':
        return AppColors.emeraldAccent;
      case 'MODERATE':
        return AppColors.aqiModerate;
      case 'SPARSE':
        return AppColors.aqiPoor;
      case 'INSUFFICIENT':
      default:
        return AppColors.aqiSevere;
    }
  }
}
