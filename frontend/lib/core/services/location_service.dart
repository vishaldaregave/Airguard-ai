import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class UserLocationResult {
  final double latitude;
  final double longitude;
  final bool isGpsLive;
  final String statusMessage;

  UserLocationResult({
    required this.latitude,
    required this.longitude,
    required this.isGpsLive,
    required this.statusMessage,
  });
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  // Default regional coordinate: New Delhi, India
  static const double defaultLatitude = 28.6139;
  static const double defaultLongitude = 77.2090;

  Future<UserLocationResult> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return UserLocationResult(
          latitude: defaultLatitude,
          longitude: defaultLongitude,
          isGpsLive: false,
          statusMessage: 'Location services disabled. Using New Delhi regional coordinates.',
        );
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return UserLocationResult(
            latitude: defaultLatitude,
            longitude: defaultLongitude,
            isGpsLive: false,
            statusMessage: 'Location permission denied. Using default regional location.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return UserLocationResult(
          latitude: defaultLatitude,
          longitude: defaultLongitude,
          isGpsLive: false,
          statusMessage: 'Location permission permanently denied. Using default location.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return UserLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        isGpsLive: true,
        statusMessage: 'Live GPS location retrieved.',
      );
    } catch (e) {
      return UserLocationResult(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        isGpsLive: false,
        statusMessage: 'Unable to acquire GPS fix. Fallback to regional coordinates.',
      );
    }
  }
}
