import 'package:geolocator/geolocator.dart';
import '../models/place.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const Place _fallback = Place(
    id: 'origin_default',
    name: 'Current Location (Simulated)',
    address: 'Ouellette Ave & Wyandotte St, Windsor, ON',
    lat: 42.3150,
    lon: -83.0360,
  );

  /// Returns the device's current GPS position as a [Place].
  /// Falls back to the simulated Windsor location on any error.
  Future<Place> getCurrentPlace() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return Place(
        id: 'gps_current',
        name: 'Current Location',
        address:
            '${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.abs().toStringAsFixed(4)}° W',
        lat: position.latitude,
        lon: position.longitude,
      );
    } catch (_) {
      return _fallback;
    }
  }
}
