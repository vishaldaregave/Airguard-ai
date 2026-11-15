class ApiConstants {
  // Configurable base URL (defaults to localhost for development/emulator)
  // For Android emulator: 10.0.2.2:8000, for local desktop / web / device: localhost:8000
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  static const String fallbackLocalUrl = 'http://127.0.0.1:8000';

  // Milestone 1 endpoints
  static const String aqiCalculate = '/api/v1/aqi/calculate';
  static const String demoFixtures = '/api/v1/aqi/demo-fixtures';
  static const String health = '/api/v1/health';

  // Milestone 2 Live Pipeline endpoints
  static const String locationsNearby = '/api/v1/locations/nearby';
  static const String stationsNearby = '/api/v1/stations/nearby';
  static const String stationDetails = '/api/v1/stations';
  static const String airCurrent = '/api/v1/air/current';
  static const String airHistory = '/api/v1/air/history';
  static const String providersStatus = '/api/v1/air/providers/status';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
