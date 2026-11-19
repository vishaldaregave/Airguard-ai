import 'package:flutter/foundation.dart';

class ApiConstants {
  // Host loopback as seen from inside the Android emulator.
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  static const String fallbackLocalUrl = 'http://127.0.0.1:8000';

  /// Backend origin that can actually reach a host-run API server.
  ///
  /// The Android emulator maps the host machine to `10.0.2.2`, so `127.0.0.1`
  /// would resolve to the emulator itself. Browsers and desktop builds run on
  /// the host and use loopback directly.
  static String get resolvedBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return defaultBaseUrl;
    }
    return fallbackLocalUrl;
  }

  // Milestone 1 endpoints
  static const String aqiCalculate = '/api/v1/aqi/calculate';
  static const String demoFixtures = '/api/v1/aqi/demo-fixtures';
  static const String health = '/api/v1/health';

  // Milestone 2 Live Pipeline endpoints
  static const String locationsNearby = '/api/v1/locations/nearby';
  static const String locationDetectIp = '/api/v1/locations/detect-ip';
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
  static const String geoHeatmap = '/api/v1/geo/heatmap';
  static const String geoCoverage = '/api/v1/geo/coverage';

  // Milestone 5.2 Exposure Simulator endpoints
  static const String exposureActivityProfiles = '/api/v1/exposure/activity-profiles';
  static const String exposureSimulate = '/api/v1/exposure/simulate';
  static const String exposureCompare = '/api/v1/exposure/compare';
  static const String exposureExplain = '/api/v1/exposure/explain';

  // Milestone 5.4 Historical Environmental Intelligence endpoints
  static const String historySummary = '/api/v1/history/summary';
  static const String historyTrends = '/api/v1/history/trends';
  static const String historyPollutants = '/api/v1/history/pollutants';
  static const String historyExtremes = '/api/v1/history/extremes';
  static const String historyCalendar = '/api/v1/history/calendar';
  static const String historyCompare = '/api/v1/history/compare';
  static const String historyCoverage = '/api/v1/history/coverage';
  static const String historyReport = '/api/v1/history/report';
  static const String historyExplain = '/api/v1/history/explain';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
