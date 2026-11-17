import 'package:dio/dio.dart';
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

  UserLocationResult({
    required this.latitude,
    required this.longitude,
    required this.isGpsLive,
    required this.statusMessage,
    this.cityName,
    this.stateName,
    this.countryName,
  });

  String get displayLocation {
    if (cityName != null && cityName!.isNotEmpty) {
      if (stateName != null && stateName!.isNotEmpty) {
        return '$cityName, $stateName';
      }
      return '$cityName, ${countryName ?? "India"}';
    }
    return '${latitude.toStringAsFixed(2)}°N, ${longitude.toStringAsFixed(2)}°E';
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

  /// Determines position using backend IP detection and GPS
  Future<UserLocationResult> determinePosition() async {
    // 1. Try our high-accuracy backend network IP detection first
    try {
      final backendUrl = '${ApiConstants.fallbackLocalUrl}${ApiConstants.locationDetectIp}';
      final res = await _dio.get(backendUrl);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final lat = (data['latitude'] as num).toDouble();
        final lon = (data['longitude'] as num).toDouble();
        final city = data['city'] as String?;
        final state = data['state'] as String?;
        final country = data['country'] as String?;

        return UserLocationResult(
          latitude: lat,
          longitude: lon,
          isGpsLive: true,
          statusMessage: 'Location resolved via network: $city, $state',
          cityName: city ?? 'Pune',
          stateName: state ?? 'Maharashtra',
          countryName: country ?? 'India',
        );
      }
    } catch (_) {
      // Backend IP detection didn't respond or timed out, try GPS
    }

    // 2. Try hardware/browser GPS
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );

        final cityData = await _reverseGeocode(position.latitude, position.longitude);

        return UserLocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
          isGpsLive: true,
          statusMessage: 'Live GPS location retrieved.',
          cityName: cityData['city'] ?? 'Current Location',
          stateName: cityData['state'],
          countryName: cityData['country'],
        );
      }
    } catch (_) {
      // GPS unavailable
    }

    // 3. Direct freeipapi fallback
    try {
      final ipRes = await _dio.get('https://freeipapi.com/api/json');
      if (ipRes.statusCode == 200 && ipRes.data != null) {
        final data = ipRes.data;
        final lat = (data['latitude'] as num).toDouble();
        final lon = (data['longitude'] as num).toDouble();
        final city = data['cityName'] as String?;
        final state = data['regionName'] as String?;
        final country = data['countryName'] as String?;

        return UserLocationResult(
          latitude: lat,
          longitude: lon,
          isGpsLive: true,
          statusMessage: 'Location resolved via network ($city, $state).',
          cityName: city ?? 'Pune',
          stateName: state ?? 'Maharashtra',
          countryName: country ?? 'India',
        );
      }
    } catch (_) {}

    // 4. Default fallback: Pune
    return UserLocationResult(
      latitude: defaultLatitude,
      longitude: defaultLongitude,
      isGpsLive: false,
      statusMessage: 'Defaulting to Pune regional location.',
      cityName: 'Pune',
      stateName: 'Maharashtra',
      countryName: 'India',
    );
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
