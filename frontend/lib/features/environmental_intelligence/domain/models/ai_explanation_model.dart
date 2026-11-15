class AIExplanationResponse {
  final String status;
  final String providerUsed;
  final String stationName;
  final DateTime observationTimestamp;
  final int? overallAqi;
  final String aqiCategory;
  final String prominentPollutant;
  final String atmosphericDynamics;
  final String primaryDriverAnalysis;
  final String elevationCauses;
  final String activityImplications;
  final String practicalPrecautions;
  final String historicalComparison;
  final String disclaimer;

  AIExplanationResponse({
    required this.status,
    required this.providerUsed,
    required this.stationName,
    required this.observationTimestamp,
    this.overallAqi,
    required this.aqiCategory,
    required this.prominentPollutant,
    required this.atmosphericDynamics,
    required this.primaryDriverAnalysis,
    required this.elevationCauses,
    required this.activityImplications,
    required this.practicalPrecautions,
    required this.historicalComparison,
    required this.disclaimer,
  });

  factory AIExplanationResponse.fromJson(Map<dynamic, dynamic> json) {
    return AIExplanationResponse(
      status: json['status'] as String? ?? 'SUCCESS',
      providerUsed: json['provider_used'] as String? ?? 'deterministic_expert_system',
      stationName: json['station_name'] as String? ?? '',
      observationTimestamp: json['observation_timestamp'] != null
          ? DateTime.parse(json['observation_timestamp'] as String)
          : DateTime.now(),
      overallAqi: (json['overall_aqi'] as num?)?.toInt(),
      aqiCategory: json['aqi_category'] as String? ?? 'Moderate',
      prominentPollutant: json['prominent_pollutant'] as String? ?? 'PM2.5',
      atmosphericDynamics: json['atmospheric_dynamics'] as String? ?? '',
      primaryDriverAnalysis: json['primary_driver_analysis'] as String? ?? '',
      elevationCauses: json['elevation_causes'] as String? ?? '',
      activityImplications: json['activity_implications'] as String? ?? '',
      practicalPrecautions: json['practical_precautions'] as String? ?? '',
      historicalComparison: json['historical_comparison'] as String? ?? '',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
