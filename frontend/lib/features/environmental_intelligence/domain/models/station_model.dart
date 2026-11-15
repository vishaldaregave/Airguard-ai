import 'observation_model.dart';

class MonitoringStationSummary {
  final String stationId;
  final String stationName;
  final String provider;
  final LocationCoordinate location;
  final double? distanceKm;
  final List<String> availablePollutants;
  final String dataSourceType;
  final bool isActive;
  final DateTime? lastReportedAt;

  MonitoringStationSummary({
    required this.stationId,
    required this.stationName,
    required this.provider,
    required this.location,
    this.distanceKm,
    this.availablePollutants = const [],
    required this.dataSourceType,
    this.isActive = true,
    this.lastReportedAt,
  });

  factory MonitoringStationSummary.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return MonitoringStationSummary(
      stationId: json['station_id'] as String,
      stationName: json['station_name'] as String,
      provider: json['provider'] as String,
      location: LocationCoordinate.fromJson(json['location'] as Map<dynamic, dynamic>),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      availablePollutants: (json['available_pollutants'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      dataSourceType: json['data_source_type'] as String? ?? 'LIVE',
      isActive: json['is_active'] as bool? ?? true,
      lastReportedAt: json['last_reported_at'] != null
          ? DateTime.parse(json['last_reported_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'station_id': stationId,
      'station_name': stationName,
      'provider': provider,
      'location': location.toJson(),
      if (distanceKm != null) 'distance_km': distanceKm,
      'available_pollutants': availablePollutants,
      'data_source_type': dataSourceType,
      'is_active': isActive,
      if (lastReportedAt != null) 'last_reported_at': lastReportedAt!.toIso8601String(),
    };
  }
}

class ProviderStatusItem {
  final String name;
  final String displayName;
  final String status;
  final bool requiresApiKey;
  final bool isAuthenticated;
  final String primaryDataType;
  final List<String> supportedPollutants;
  final String attribution;
  final DateTime lastCheckTimestamp;
  final double? latencyMs;
  final String? details;

  ProviderStatusItem({
    required this.name,
    required this.displayName,
    required this.status,
    required this.requiresApiKey,
    required this.isAuthenticated,
    required this.primaryDataType,
    required this.supportedPollutants,
    required this.attribution,
    required this.lastCheckTimestamp,
    this.latencyMs,
    this.details,
  });

  factory ProviderStatusItem.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return ProviderStatusItem(
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      status: json['status'] as String,
      requiresApiKey: json['requires_api_key'] as bool? ?? false,
      isAuthenticated: json['is_authenticated'] as bool? ?? false,
      primaryDataType: json['primary_data_type'] as String? ?? 'LIVE',
      supportedPollutants: (json['supported_pollutants'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      attribution: json['attribution'] as String? ?? '',
      lastCheckTimestamp: DateTime.parse(json['last_check_timestamp'] as String),
      latencyMs: (json['latency_ms'] as num?)?.toDouble(),
      details: json['details'] as String?,
    );
  }
}
