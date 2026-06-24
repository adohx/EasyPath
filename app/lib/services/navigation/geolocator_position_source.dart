import 'package:geolocator/geolocator.dart';
import 'position_source.dart';

/// Wraps [Geolocator.getPositionStream] as a [PositionSource].
///
/// Assumes location permission has already been granted — permission
/// requests stay in the screen, matching the existing one-shot
/// `LocationService` flow.
class GeolocatorPositionSource implements PositionSource {
  GeolocatorPositionSource({LocationSettings? locationSettings})
    : _locationSettings =
          locationSettings ??
          const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          );

  final LocationSettings _locationSettings;

  @override
  Stream<NavPosition> positions() {
    return Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).map(
      (position) => NavPosition(
        lat: position.latitude,
        lon: position.longitude,
        gpsHeadingDegrees: position.headingAccuracy >= 0
            ? position.heading
            : null,
        accuracyMeters: position.accuracy,
        speedMetersPerSecond: position.speed,
        timestamp: position.timestamp,
      ),
    );
  }
}
