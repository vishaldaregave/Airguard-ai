import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/api_constants.dart';

class CitySearchResult {
  final String name;
  final String? state;
  final String country;
  final double latitude;
  final double longitude;

  const CitySearchResult({
    required this.name,
    this.state,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get displayName {
    if (state != null && state!.isNotEmpty) {
      return '$name, $state';
    }
    return '$name, $country';
  }
}

class UserLocationResult {
  final double latitude;
  final double longitude;
  final bool isGpsLive;
  final String statusMessage;
  final String? cityName;
  final String? stateName;
  final String? countryName;
  final bool isUserSelected;

  UserLocationResult({
    required this.latitude,
    required this.longitude,
    required this.isGpsLive,
    required this.statusMessage,
    this.cityName,
    this.stateName,
    this.countryName,
    this.isUserSelected = false,
  });

  bool get isApproximate => !isGpsLive && !isUserSelected;

  String get displayLocation {
    if (cityName != null && cityName!.isNotEmpty) {
      if (stateName != null && stateName!.isNotEmpty) {
        return '$cityName, $stateName';
      }
      if (countryName != null && countryName!.isNotEmpty) {
        return '$cityName, $countryName';
      }
      return cityName!;
    }
    return coordinateLabel;
  }

  String get coordinateLabel {
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lonDir = longitude >= 0 ? 'E' : 'W';
    return '${latitude.abs().toStringAsFixed(2)}°$latDir, '
        '${longitude.abs().toStringAsFixed(2)}°$lonDir';
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  // Default fallback regional coordinate: Pune, India (or New Delhi)
  static const double defaultLatitude = 18.5204;
  static const double defaultLongitude = 73.8567;

  // Major popular cities for instant one-tap selection
  static const List<CitySearchResult> popularCities = [
    CitySearchResult(name: 'Pune', state: 'Maharashtra', country: 'India', latitude: 18.5204, longitude: 73.8567),
    CitySearchResult(name: 'Mumbai', state: 'Maharashtra', country: 'India', latitude: 19.0760, longitude: 72.8777),
    CitySearchResult(name: 'Delhi NCR', state: 'Delhi', country: 'India', latitude: 28.6139, longitude: 77.2090),
    CitySearchResult(name: 'Bengaluru', state: 'Karnataka', country: 'India', latitude: 12.9716, longitude: 77.5946),
    CitySearchResult(name: 'Hyderabad', state: 'Telangana', country: 'India', latitude: 17.3850, longitude: 78.4867),
    CitySearchResult(name: 'Kolkata', state: 'West Bengal', country: 'India', latitude: 22.5726, longitude: 88.3639),
    CitySearchResult(name: 'Chennai', state: 'Tamil Nadu', country: 'India', latitude: 13.0827, longitude: 80.2707),
    CitySearchResult(name: 'Ahmedabad', state: 'Gujarat', country: 'India', latitude: 23.0225, longitude: 72.5714),
    CitySearchResult(name: 'San Francisco', state: 'California', country: 'USA', latitude: 37.7749, longitude: -122.4194),
    CitySearchResult(name: 'London', state: 'England', country: 'UK', latitude: 51.5074, longitude: -0.1278),
  ];

  /// Resolves the user's current position.
  ///
  /// Order of preference:
  /// 1. Device GPS (true "current location" — required for accurate readings).
  /// 2. Client-side network IP lookup (approximate, city-level).
  /// 3. Backend network IP lookup (approximate, city-level).
  ///
  /// If every source fails we return the regional default but deliberately
  /// leave the city unset so the UI never presents a guess as the user's city.
  Future<UserLocationResult> determinePosition() async {
    final gpsResult = await _tryDeviceGps();
    if (gpsResult != null) return gpsResult;

    final clientNetwork = await _tryClientNetworkLocation();
    if (clientNetwork != null) return clientNetwork;

    final backendNetwork = await _tryBackendNetworkLocation();
    if (backendNetwork != null) return backendNetwork;

    return UserLocationResult(
      latitude: defaultLatitude,
      longitude: defaultLongitude,
      isGpsLive: false,
      statusMessage:
          'Location could not be detected. Showing an approximate regional default — tap the location pill to choose your city.',
    );
  }

  bool get _hardwareGpsSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<UserLocationResult?> _tryDeviceGps() async {
    if (!_hardwareGpsSupported) return null;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return null;

      final cityData =
          await _reverseGeocode(position.latitude, position.longitude);

      return UserLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isGpsLive: true,
        statusMessage: 'Precise device GPS location acquired.',
        cityName: cityData['city'],
        stateName: cityData['state'],
        countryName: cityData['country'],
      );
    } catch (_) {
      return null;
    }
  }

  Future<UserLocationResult?> _tryClientNetworkLocation() async {
    // ipapi.co serves HTTPS with CORS enabled, so it works in browsers too.
    try {
      final res = await _dio.get('https://ipapi.co/json/');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final lat = _asDouble(data['latitude']);
        final lon = _asDouble(data['longitude']);
        if (_isValidCoordinate(lat, lon)) {
          return UserLocationResult(
            latitude: lat!,
            longitude: lon!,
            isGpsLive: false,
            statusMessage:
                'Approximate city location resolved from your network address.',
            cityName: _asString(data['city']),
            stateName: _asString(data['region']),
            countryName: _asString(data['country_name']),
          );
        }
      }
    } catch (_) {}

    try {
      final res = await _dio.get('https://freeipapi.com/api/json');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final lat = _asDouble(data['latitude']);
        final lon = _asDouble(data['longitude']);
        if (_isValidCoordinate(lat, lon)) {
          return UserLocationResult(
            latitude: lat!,
            longitude: lon!,
            isGpsLive: false,
            statusMessage:
                'Approximate city location resolved from your network address.',
            cityName: _asString(data['cityName']),
            stateName: _asString(data['regionName']),
            countryName: _asString(data['countryName']),
          );
        }
      }
    } catch (_) {}

    return null;
  }

  Future<UserLocationResult?> _tryBackendNetworkLocation() async {
    final urls = <String>{
      '${ApiConstants.resolvedBaseUrl}${ApiConstants.locationDetectIp}',
      '${ApiConstants.fallbackLocalUrl}${ApiConstants.locationDetectIp}',
      '${ApiConstants.defaultBaseUrl}${ApiConstants.locationDetectIp}',
    };

    for (final url in urls) {
      try {
        final res = await _dio.get(url);
        if (res.statusCode != 200 || res.data is! Map) continue;

        final data = res.data as Map;
        final lat = _asDouble(data['latitude']);
        final lon = _asDouble(data['longitude']);
        if (!_isValidCoordinate(lat, lon)) continue;

        final status = _asString(data['status']);
        if (status == 'fallback') continue;

        return UserLocationResult(
          latitude: lat!,
          longitude: lon!,
          isGpsLive: false,
          statusMessage:
              'Approximate city location resolved from your network address.',
          cityName: _asString(data['city']),
          stateName: _asString(data['state']),
          countryName: _asString(data['country']),
        );
      } catch (_) {}
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _asString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  bool _isValidCoordinate(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (lat.isNaN || lon.isNaN) return false;
    if (lat < -90 || lat > 90) return false;
    if (lon < -180 || lon > 180) return false;
    return lat != 0 && lon != 0;
  }

  /// Searches for cities globally using Open-Meteo's free geocoding service
  Future<List<CitySearchResult>> searchCities(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return popularCities;
    }

    // First filter popular cities for instant offline matching
    final matchedPopular = popularCities.where((c) {
      return c.name.toLowerCase().contains(cleanQuery.toLowerCase()) ||
          (c.state?.toLowerCase().contains(cleanQuery.toLowerCase()) ?? false) ||
          c.country.toLowerCase().contains(cleanQuery.toLowerCase());
    }).toList();

    try {
      final uri = 'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cleanQuery)}&count=8&language=en&format=json';
      final res = await _dio.get(uri);
      if (res.statusCode == 200 && res.data != null && res.data['results'] != null) {
        final List results = res.data['results'] as List;
        final apiResults = results.map((r) {
          return CitySearchResult(
            name: r['name'] as String,
            state: r['admin1'] as String?,
            country: r['country'] as String? ?? '',
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
          );
        }).toList();

        // Merge matching lists avoiding duplicate names
        final seen = <String>{};
        final merged = <CitySearchResult>[];
        for (final item in [...matchedPopular, ...apiResults]) {
          final key = '${item.name}_${item.state}_${item.country}'.toLowerCase();
          if (!seen.contains(key)) {
            seen.add(key);
            merged.add(item);
          }
        }
        return merged;
      }
    } catch (_) {}

    return matchedPopular;
  }

  /// Reverse geocodes coordinates to a clean City, State, Country
  Future<Map<String, String?>> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1';
      final res = await _dio.get(
        uri,
        options: Options(
          headers: {'User-Agent': 'AirGuardAI-Client/1.0'},
        ),
      );
      if (res.statusCode == 200 && res.data != null && res.data['address'] != null) {
        final addr = res.data['address'];
        final city = addr['city'] ?? addr['town'] ?? addr['suburb'] ?? addr['county'] ?? addr['state_district'];
        final state = addr['state'];
        final country = addr['country'];
        return {
          'city': city?.toString(),
          'state': state?.toString(),
          'country': country?.toString(),
        };
      }
    } catch (_) {}
    return {};
  }
}
