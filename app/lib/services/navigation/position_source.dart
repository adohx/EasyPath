/// A single positioning sample, independent of any platform plugin type,
/// used throughout the real-time navigation pipeline.
class NavPosition {
  final double lat;
  final double lon;

  /// GPS course-over-ground in degrees, or null if unavailable.
  final double? gpsHeadingDegrees;

  final double accuracyMeters;

  /// Device ground speed in metres per second.
  final double speedMetersPerSecond;

  final DateTime timestamp;

  const NavPosition({
    required this.lat,
    required this.lon,
    required this.gpsHeadingDegrees,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
    required this.timestamp,
  });
}

/// Supplies a stream of position updates during navigation.
abstract class PositionSource {
  Stream<NavPosition> positions();
}
