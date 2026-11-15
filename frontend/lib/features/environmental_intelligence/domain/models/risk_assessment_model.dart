import 'aqi_result_model.dart';
import 'observation_model.dart';
import 'station_model.dart';

class RiskFactorContribution {
  final String factorName;
  final double contributionScore;
  final String explanation;

  RiskFactorContribution({
    required this.factorName,
    required this.contributionScore,
    required this.explanation,
  });

  factory RiskFactorContribution.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return RiskFactorContribution(
      factorName: json['factor_name'] as String,
      contributionScore: (json['contribution_score'] as num).toDouble(),
      explanation: json['explanation'] as String,
    );
  }
}

class ActivityRecommendation {
  final String activityType;
  final String feasibility; // SAFE, PROCEED_WITH_CAUTION, REDUCE_DURATION, AVOID
  final String guidance;

  ActivityRecommendation({
    required this.activityType,
    required this.feasibility,
    required this.guidance,
  });

  factory ActivityRecommendation.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return ActivityRecommendation(
      activityType: json['activity_type'] as String,
      feasibility: json['feasibility'] as String,
      guidance: json['guidance'] as String,
    );
  }
}

class EnvironmentalRiskScore {
  final int riskScore;
  final String riskLevel; // LOW, MODERATE, ELEVATED, HIGH, VERY_HIGH, HAZARDOUS
  final String riskSummary;
  final String primaryDriver;
  final List<RiskFactorContribution> breakdown;
  final List<ActivityRecommendation> activityRecommendations;
  final String disclaimer;

  EnvironmentalRiskScore({
    required this.riskScore,
    required this.riskLevel,
    required this.riskSummary,
    required this.primaryDriver,
    required this.breakdown,
    required this.activityRecommendations,
    required this.disclaimer,
  });

  factory EnvironmentalRiskScore.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    final breakdownList = (json['breakdown'] as List<dynamic>? ?? [])
        .map((e) => RiskFactorContribution.fromJson(e as Map<dynamic, dynamic>))
        .toList();

    final recsList = (json['activity_recommendations'] as List<dynamic>? ?? [])
        .map((e) => ActivityRecommendation.fromJson(e as Map<dynamic, dynamic>))
        .toList();

    return EnvironmentalRiskScore(
      riskScore: json['risk_score'] as int,
      riskLevel: json['risk_level'] as String,
      riskSummary: json['risk_summary'] as String,
      primaryDriver: json['primary_driver'] as String,
      breakdown: breakdownList,
      activityRecommendations: recsList,
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}

class AssessmentResponse {
  final AQICalculationResult aqiResult;
  final EnvironmentalRiskScore riskAssessment;
  final EnvironmentalObservation? observation;
  final MonitoringStationSummary? station;
  final double? distanceFromQueryKm;
  final double? dataFreshnessMinutes;
  final bool isStale;

  AssessmentResponse({
    required this.aqiResult,
    required this.riskAssessment,
    this.observation,
    this.station,
    this.distanceFromQueryKm,
    this.dataFreshnessMinutes,
    this.isStale = false,
  });

  factory AssessmentResponse.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);

    // Support both direct calculation output and /air/current pipeline response
    final aqiJson = json['aqi_result'] as Map<dynamic, dynamic>;
    final riskJson = json['risk_assessment'] as Map<dynamic, dynamic>;

    EnvironmentalObservation? obs;
    if (json['observation'] != null) {
      obs = EnvironmentalObservation.fromJson(json['observation'] as Map<dynamic, dynamic>);
    }

    MonitoringStationSummary? st;
    if (json['station'] != null) {
      st = MonitoringStationSummary.fromJson(json['station'] as Map<dynamic, dynamic>);
    }

    return AssessmentResponse(
      aqiResult: AQICalculationResult.fromJson(aqiJson),
      riskAssessment: EnvironmentalRiskScore.fromJson(riskJson),
      observation: obs,
      station: st,
      distanceFromQueryKm: (json['distance_from_query_km'] as num?)?.toDouble(),
      dataFreshnessMinutes: (json['data_freshness_minutes'] as num?)?.toDouble(),
      isStale: json['is_stale'] as bool? ?? false,
    );
  }
}
