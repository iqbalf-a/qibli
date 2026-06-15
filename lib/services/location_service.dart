import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// Result returned by [LocationService.fetchLocation].
class LocationResult {
  final double lat;
  final double lng;
  final String cityName;

  const LocationResult({
    required this.lat,
    required this.lng,
    required this.cityName,
  });
}

/// Shared service for GPS-based location fetching with reverse geocoding.
///
/// Usage:
/// ```dart
/// final result = await LocationService.fetchLocation();
/// if (result != null) { ... }
/// ```
///
/// Returns null when permission is denied or location services are unavailable.
/// Returns a [LocationResult] with a coordinate-based [cityName] fallback when
/// reverse geocoding fails.
class LocationService {
  LocationService._();

  /// Requests location permission, gets the device position, and reverse-geocodes
  /// it into a human-readable city name.
  ///
  /// Returns null when:
  /// - Location permission is denied / denied forever
  /// - The device cannot obtain a position
  static Future<LocationResult?> fetchLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final cityName = await _resolveCityName(position);
      return LocationResult(
        lat: position.latitude,
        lng: position.longitude,
        cityName: cityName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocodes [position] into a city/country string.
  /// Falls back to a lat/lng coordinate string if geocoding fails.
  static Future<String> _resolveCityName(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final area = (place.subAdministrativeArea?.isNotEmpty == true)
            ? place.subAdministrativeArea!
            : (place.locality?.isNotEmpty == true)
                ? place.locality!
                : place.administrativeArea ?? '';
        final countryCode = place.isoCountryCode ?? place.country ?? '';
        return '$area, $countryCode';
      }
    } catch (_) {
      // Fall through to coordinate fallback
    }
    return '${position.latitude.toStringAsFixed(2)}, '
        '${position.longitude.toStringAsFixed(2)}';
  }
}
