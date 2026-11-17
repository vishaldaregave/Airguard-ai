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

  // Milestone 3 Forecasting & AI Explanation endpoints
  static const String forecastCurrent = '/api/v1/forecast/current';
  static const String forecastAccuracy = '/api/v1/forecast/accuracy';
  static const String forecastModelStatus = '/api/v1/forecast/model/status';
  static const String aiExplain = '/api/v1/ai/explain';
  static const String historyAvailability = '/api/v1/history/availability';

  // Milestone 4 Alert & Notification endpoints
  static const String alerts = '/api/v1/alerts';
  static const String alertPreferences = '/api/v1/alerts/preferences';
  static const String alertDeviceRegister = '/api/v1/alerts/device/register';
  static const String alertDeviceUnregister = '/api/v1/alerts/device/unregister';

  // Milestone 5 Geographic Intelligence endpoints
  static const String geoStations = '/api/v1/geo/stations';
  static const String geoObservations = '/api/v1/geo/observations';
  static const String geoInterpolation = '/api/v1/geo/interpolation';
  static const String geoHotspots = '/api/v1/geo/hotspots';
  static const String geoCoverage = '/api/v1/geo/coverage';

  // Milestone 5.2 Exposure Simulator endpoints
  static const String exposureActivityProfiles = '/api/v1/exposure/activity-profiles';
  static const String exposureSimulate = '/api/v1/exposure/simulate';
  static const String exposureCompare = '/api/v1/exposure/compare';
  static const String exposureExplain = '/api/v1/exposure/explain';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
