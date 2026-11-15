class LocationCoordinate {
  final double latitude;
  final double longitude;
  final String? city;
  final String? state;
  final String country;

  LocationCoordinate({
    required this.latitude,
    required this.longitude,
    this.city,
    this.state,
    this.country = 'India',
  });

  factory LocationCoordinate.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return LocationCoordinate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'India',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'state': state,
      'country': country,
    };
  }
}

class EnvironmentalObservation {
  final String? stationId;
  final String? stationName;
  final LocationCoordinate location;
  final DateTime timestamp;
  final String provider;
  final String dataSourceType; // LIVE, HISTORICAL, ESTIMATED, FORECAST, DEMO_FIXTURE

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

  EnvironmentalObservation({
    this.stationId,
    this.stationName,
    required this.location,
    required this.timestamp,
    required this.provider,
    required this.dataSourceType,
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
  });

  factory EnvironmentalObservation.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    return EnvironmentalObservation(
      stationId: json['station_id'] as String?,
      stationName: json['station_name'] as String?,
      location: LocationCoordinate.fromJson(json['location'] as Map<dynamic, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      provider: json['provider'] as String,
      dataSourceType: json['data_source_type'] as String,
      pm25: (json['pm2_5'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
      so2: (json['so2'] as num?)?.toDouble(),
      co: (json['co'] as num?)?.toDouble(),
      o3: (json['o3'] as num?)?.toDouble(),
      nh3: (json['nh3'] as num?)?.toDouble(),
      pb: (json['pb'] as num?)?.toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble(),
      relativeHumidityPct: (json['relative_humidity_pct'] as num?)?.toDouble(),
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (stationId != null) 'station_id': stationId,
      if (stationName != null) 'station_name': stationName,
      'location': location.toJson(),
      'timestamp': timestamp.toUtc().toIso8601String(),
      'provider': provider,
      'data_source_type': dataSourceType,
      if (pm25 != null) 'pm2_5': pm25,
      if (pm10 != null) 'pm10': pm10,
      if (no2 != null) 'no2': no2,
      if (so2 != null) 'so2': so2,
      if (co != null) 'co': co,
      if (o3 != null) 'o3': o3,
      if (nh3 != null) 'nh3': nh3,
      if (pb != null) 'pb': pb,
      if (temperatureCelsius != null) 'temperature_celsius': temperatureCelsius,
      if (relativeHumidityPct != null) 'relative_humidity_pct': relativeHumidityPct,
      if (windSpeedKmh != null) 'wind_speed_kmh': windSpeedKmh,
    };
  }
}
