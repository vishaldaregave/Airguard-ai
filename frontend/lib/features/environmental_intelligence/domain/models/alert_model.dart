import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

enum AlertSeverity {
  info,
  warning,
  danger,
  critical;

  static AlertSeverity fromString(String val) {
    switch (val.toUpperCase()) {
      case 'WARNING':
        return AlertSeverity.warning;
      case 'DANGER':
        return AlertSeverity.danger;
      case 'CRITICAL':
        return AlertSeverity.critical;
      case 'INFO':
      default:
        return AlertSeverity.info;
    }
  }

  String get displayName {
    switch (this) {
      case AlertSeverity.info:
        return 'INFO';
      case AlertSeverity.warning:
        return 'WARNING';
      case AlertSeverity.danger:
        return 'DANGER';
      case AlertSeverity.critical:
        return 'CRITICAL';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.info:
        return AppColors.cyanAccent;
      case AlertSeverity.warning:
        return AppColors.aqiModerate;
      case AlertSeverity.danger:
        return AppColors.aqiPoor;
      case AlertSeverity.critical:
        return AppColors.aqiSevere;
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.info:
        return Icons.info_outline;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.danger:
        return Icons.report_problem_rounded;
      case AlertSeverity.critical:
        return Icons.dangerous_rounded;
    }
  }
}

enum AlertType {
  aqiThreshold,
  pm25Threshold,
  pm10Threshold,
  suddenDeterioration,
  forecastWarning,
  dataFreshness,
  recovery;

  static AlertType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'AQI_THRESHOLD':
        return AlertType.aqiThreshold;
      case 'PM25_THRESHOLD':
        return AlertType.pm25Threshold;
      case 'PM10_THRESHOLD':
        return AlertType.pm10Threshold;
      case 'SUDDEN_DETERIORATION':
        return AlertType.suddenDeterioration;
      case 'FORECAST_WARNING':
        return AlertType.forecastWarning;
      case 'DATA_FRESHNESS':
        return AlertType.dataFreshness;
      case 'RECOVERY':
        return AlertType.recovery;
      default:
        return AlertType.aqiThreshold;
    }
  }

  String get displayName {
    switch (this) {
      case AlertType.aqiThreshold:
        return 'AQI Threshold';
      case AlertType.pm25Threshold:
        return 'PM2.5 Exceeded';
      case AlertType.pm10Threshold:
        return 'PM10 Exceeded';
      case AlertType.suddenDeterioration:
        return 'Sudden Spike';
      case AlertType.forecastWarning:
        return 'Forecast Warning';
      case AlertType.dataFreshness:
        return 'Telemetry Stale';
      case AlertType.recovery:
        return 'Air Quality Recovered';
    }
  }
}

class AlertItem {
  final String alertId;
  final String userId;
  final AlertType alertType;
  final AlertSeverity severity;
  final String stationCode;
  final String stationName;
  final String? pollutant;
  final double? observedValue;
  final double? thresholdValue;
  final String unit;
  final String sourceProvenance;
  final DateTime observationTimestamp;
  final String triggerReason;
  final String recommendedPrecaution;
  final bool isForecast;
  final int? forecastHorizonHours;
  final bool isRead;
  final bool isResolved;
  final String deliveryStatus;
  final DateTime createdAt;

  const AlertItem({
    required this.alertId,
    required this.userId,
    required this.alertType,
    required this.severity,
    required this.stationCode,
    required this.stationName,
    this.pollutant,
    this.observedValue,
    this.thresholdValue,
    required this.unit,
    required this.sourceProvenance,
    required this.observationTimestamp,
    required this.triggerReason,
    required this.recommendedPrecaution,
    required this.isForecast,
    this.forecastHorizonHours,
    required this.isRead,
    required this.isResolved,
    required this.deliveryStatus,
    required this.createdAt,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      alertId: json['alert_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? 'default_user',
      alertType: AlertType.fromString(json['alert_type'] as String? ?? 'AQI_THRESHOLD'),
      severity: AlertSeverity.fromString(json['severity'] as String? ?? 'INFO'),
      stationCode: json['station_code'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      pollutant: json['pollutant'] as String?,
      observedValue: (json['observed_value'] as num?)?.toDouble(),
      thresholdValue: (json['threshold_value'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? 'µg/m³',
      sourceProvenance: json['source_provenance'] as String? ?? 'LIVE',
      observationTimestamp: json['observation_timestamp'] != null
          ? DateTime.parse(json['observation_timestamp'] as String)
          : DateTime.now(),
      triggerReason: json['trigger_reason'] as String? ?? '',
      recommendedPrecaution: json['recommended_precaution'] as String? ?? '',
      isForecast: json['is_forecast'] as bool? ?? false,
      forecastHorizonHours: json['forecast_horizon_hours'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      isResolved: json['is_resolved'] as bool? ?? false,
      deliveryStatus: json['delivery_status'] as String? ?? 'DELIVERED',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  AlertItem copyWith({bool? isRead, bool? isResolved}) {
    return AlertItem(
      alertId: alertId,
      userId: userId,
      alertType: alertType,
      severity: severity,
      stationCode: stationCode,
      stationName: stationName,
      pollutant: pollutant,
      observedValue: observedValue,
      thresholdValue: thresholdValue,
      unit: unit,
      sourceProvenance: sourceProvenance,
      observationTimestamp: observationTimestamp,
      triggerReason: triggerReason,
      recommendedPrecaution: recommendedPrecaution,
      isForecast: isForecast,
      forecastHorizonHours: forecastHorizonHours,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
      deliveryStatus: deliveryStatus,
      createdAt: createdAt,
    );
  }
}

class AlertListResponse {
  final List<AlertItem> alerts;
  final int total;
  final int unreadCount;

  const AlertListResponse({
    required this.alerts,
    required this.total,
    required this.unreadCount,
  });

  factory AlertListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['alerts'] as List<dynamic>? ?? [];
    return AlertListResponse(
      alerts: rawList.map((e) => AlertItem.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? rawList.length,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

class UserAlertPreference {
  final String userId;
  final bool notificationsEnabled;
  final int aqiThreshold;
  final double pm25Threshold;
  final double pm10Threshold;
  final bool suddenDeteriorationEnabled;
  final bool forecastAlertsEnabled;
  final bool recoveryAlertsEnabled;
  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;
  final String? preferredStationCode;
  final String? preferredStationName;
  final DateTime updatedAt;

  const UserAlertPreference({
    required this.userId,
    required this.notificationsEnabled,
    required this.aqiThreshold,
    required this.pm25Threshold,
    required this.pm10Threshold,
    required this.suddenDeteriorationEnabled,
    required this.forecastAlertsEnabled,
    required this.recoveryAlertsEnabled,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    this.preferredStationCode,
    this.preferredStationName,
    required this.updatedAt,
  });

  factory UserAlertPreference.fromJson(Map<String, dynamic> json) {
    return UserAlertPreference(
      userId: json['user_id'] as String? ?? 'default_user',
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      aqiThreshold: json['aqi_threshold'] as int? ?? 200,
      pm25Threshold: (json['pm25_threshold'] as num?)?.toDouble() ?? 60.0,
      pm10Threshold: (json['pm10_threshold'] as num?)?.toDouble() ?? 100.0,
      suddenDeteriorationEnabled: json['sudden_deterioration_enabled'] as bool? ?? true,
      forecastAlertsEnabled: json['forecast_alerts_enabled'] as bool? ?? true,
      recoveryAlertsEnabled: json['recovery_alerts_enabled'] as bool? ?? true,
      quietHoursEnabled: json['quiet_hours_enabled'] as bool? ?? false,
      quietHoursStart: json['quiet_hours_start'] as int? ?? 22,
      quietHoursEnd: json['quiet_hours_end'] as int? ?? 7,
      preferredStationCode: json['preferred_station_code'] as String?,
      preferredStationName: json['preferred_station_name'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications_enabled': notificationsEnabled,
      'aqi_threshold': aqiThreshold,
      'pm25_threshold': pm25Threshold,
      'pm10_threshold': pm10Threshold,
      'sudden_deterioration_enabled': suddenDeteriorationEnabled,
      'forecast_alerts_enabled': forecastAlertsEnabled,
      'recovery_alerts_enabled': recoveryAlertsEnabled,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'preferred_station_code': preferredStationCode,
      'preferred_station_name': preferredStationName,
    };
  }

  UserAlertPreference copyWith({
    bool? notificationsEnabled,
    int? aqiThreshold,
    double? pm25Threshold,
    double? pm10Threshold,
    bool? suddenDeteriorationEnabled,
    bool? forecastAlertsEnabled,
    bool? recoveryAlertsEnabled,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    String? preferredStationCode,
    String? preferredStationName,
  }) {
    return UserAlertPreference(
      userId: userId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      aqiThreshold: aqiThreshold ?? this.aqiThreshold,
      pm25Threshold: pm25Threshold ?? this.pm25Threshold,
      pm10Threshold: pm10Threshold ?? this.pm10Threshold,
      suddenDeteriorationEnabled: suddenDeteriorationEnabled ?? this.suddenDeteriorationEnabled,
      forecastAlertsEnabled: forecastAlertsEnabled ?? this.forecastAlertsEnabled,
      recoveryAlertsEnabled: recoveryAlertsEnabled ?? this.recoveryAlertsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      preferredStationCode: preferredStationCode ?? this.preferredStationCode,
      preferredStationName: preferredStationName ?? this.preferredStationName,
      updatedAt: DateTime.now(),
    );
  }
}
