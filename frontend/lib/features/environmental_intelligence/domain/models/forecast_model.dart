class PollutantPrediction {
  final String pollutant;
  final String unit;
  final double predictedValue;
  final double ci95Lower;
  final double ci95Upper;
  final double ci90Lower;
  final double ci90Upper;

  PollutantPrediction({
    required this.pollutant,
    required this.unit,
    required this.predictedValue,
    required this.ci95Lower,
    required this.ci95Upper,
    required this.ci90Lower,
    required this.ci90Upper,
  });

  factory PollutantPrediction.fromJson(Map<dynamic, dynamic> json) {
    return PollutantPrediction(
      pollutant: json['pollutant'] as String? ?? '',
      unit: json['unit'] as String? ?? 'µg/m³',
      predictedValue: (json['predicted_value'] as num?)?.toDouble() ?? 0.0,
      ci95Lower: (json['ci95_lower'] as num?)?.toDouble() ?? 0.0,
      ci95Upper: (json['ci95_upper'] as num?)?.toDouble() ?? 0.0,
      ci90Lower: (json['ci90_lower'] as num?)?.toDouble() ?? 0.0,
      ci90Upper: (json['ci90_upper'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'pollutant': pollutant,
    'unit': unit,
    'predicted_value': predictedValue,
    'ci95_lower': ci95Lower,
    'ci95_upper': ci95Upper,
    'ci90_lower': ci90Lower,
    'ci90_upper': ci90Upper,
  };
}

class HorizonForecastStep {
  final int horizonHours;
  final DateTime targetTimestamp;
  final int? predictedAqi;
  final String? predictedAqiCategory;
  final String? predictedAqiColor;
  final String? predictedAqiProminentPollutant;
  final bool isCpcbAqiValid;
  final Map<String, PollutantPrediction> pollutantPredictions;
  final double? temperatureCelsius;
  final double? relativeHumidityPct;
  final double? windSpeedKmh;

  HorizonForecastStep({
    required this.horizonHours,
    required this.targetTimestamp,
    this.predictedAqi,
    this.predictedAqiCategory,
    this.predictedAqiColor,
    this.predictedAqiProminentPollutant,
    required this.isCpcbAqiValid,
    required this.pollutantPredictions,
    this.temperatureCelsius,
    this.relativeHumidityPct,
    this.windSpeedKmh,
  });

  factory HorizonForecastStep.fromJson(Map<dynamic, dynamic> json) {
    final predictionsMap = <String, PollutantPrediction>{};
    if (json['pollutant_predictions'] is Map) {
      final rawMap = json['pollutant_predictions'] as Map;
      rawMap.forEach((k, v) {
        if (v is Map) {
          predictionsMap[k.toString()] = PollutantPrediction.fromJson(v);
        }
      });
    }

    return HorizonForecastStep(
      horizonHours: (json['horizon_hours'] as num?)?.toInt() ?? 1,
      targetTimestamp: json['target_timestamp'] != null
          ? DateTime.parse(json['target_timestamp'] as String)
          : DateTime.now(),
      predictedAqi: (json['predicted_aqi'] as num?)?.toInt(),
      predictedAqiCategory: json['predicted_aqi_category'] as String?,
      predictedAqiColor: json['predicted_aqi_color'] as String?,
      predictedAqiProminentPollutant: json['predicted_aqi_prominent_pollutant'] as String?,
      isCpcbAqiValid: json['is_cpcb_aqi_valid'] as bool? ?? false,
      pollutantPredictions: predictionsMap,
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble(),
      relativeHumidityPct: (json['relative_humidity_pct'] as num?)?.toDouble(),
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble(),
    );
  }
}

class ForecastModelMetadata {
  final String modelType;
  final int trainingSampleCount;
  final String? evaluationPeriodStart;
  final String? evaluationPeriodEnd;
  final double? maePm25;
  final double? rmsePm25;
  final double? persistenceMaePm25;
  final DateTime? retrainedAt;

  ForecastModelMetadata({
    required this.modelType,
    required this.trainingSampleCount,
    this.evaluationPeriodStart,
    this.evaluationPeriodEnd,
    this.maePm25,
    this.rmsePm25,
    this.persistenceMaePm25,
    this.retrainedAt,
  });

  factory ForecastModelMetadata.fromJson(Map<dynamic, dynamic> json) {
    return ForecastModelMetadata(
      modelType: json['model_type'] as String? ?? 'AUTOREGRESSIVE_RIDGE',
      trainingSampleCount: (json['training_sample_count'] as num?)?.toInt() ?? 0,
      evaluationPeriodStart: json['evaluation_period_start'] as String?,
      evaluationPeriodEnd: json['evaluation_period_end'] as String?,
      maePm25: (json['mae_pm25'] as num?)?.toDouble(),
      rmsePm25: (json['rmse_pm25'] as num?)?.toDouble(),
      persistenceMaePm25: (json['persistence_mae_pm25'] as num?)?.toDouble(),
      retrainedAt: json['retrained_at'] != null
          ? DateTime.parse(json['retrained_at'] as String)
          : null,
    );
  }
}

class ForecastCurrentResponse {
  final String status;
  final String stationId;
  final String stationName;
  final String dataSourceType;
  final DateTime baseTimestamp;
  final List<HorizonForecastStep> forecasts;
  final ForecastModelMetadata modelMetadata;
  final String disclaimer;

  ForecastCurrentResponse({
    required this.status,
    required this.stationId,
    required this.stationName,
    required this.dataSourceType,
    required this.baseTimestamp,
    required this.forecasts,
    required this.modelMetadata,
    required this.disclaimer,
  });

  factory ForecastCurrentResponse.fromJson(Map<dynamic, dynamic> json) {
    final list = (json['forecasts'] as List<dynamic>? ?? [])
        .map((e) => HorizonForecastStep.fromJson(e as Map<dynamic, dynamic>))
        .toList();

    return ForecastCurrentResponse(
      status: json['status'] as String? ?? 'ACTIVE',
      stationId: json['station_id'] as String? ?? '',
      stationName: json['station_name'] as String? ?? '',
      dataSourceType: json['data_source_type'] as String? ?? 'PHYSICAL_STATION',
      baseTimestamp: json['base_timestamp'] != null
          ? DateTime.parse(json['base_timestamp'] as String)
          : DateTime.now(),
      forecasts: list,
      modelMetadata: ForecastModelMetadata.fromJson(
        json['model_metadata'] as Map<dynamic, dynamic>? ?? {},
      ),
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
