import 'dart:math' as math;

/// Earth radius in metres, used for haversine-based calculations.
const double kEarthRadiusMeters = 6371000;

double _degToRad(double degrees) => degrees * math.pi / 180;
double _radToDeg(double radians) => radians * 180 / math.pi;

/// Great-circle distance between two coordinates, in metres.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _degToRad(lat1);
  final phi2 = _degToRad(lat2);
  final deltaPhi = _degToRad(lat2 - lat1);
  final deltaLambda = _degToRad(lon2 - lon1);

  final a =
      math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLambda / 2) *
          math.sin(deltaLambda / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return kEarthRadiusMeters * c;
}

/// Initial bearing from point 1 to point 2, in degrees in the range
/// `[0, 360)`, where 0 is north.
double initialBearingDegrees(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final phi1 = _degToRad(lat1);
  final phi2 = _degToRad(lat2);
  final deltaLambda = _degToRad(lon2 - lon1);

  final y = math.sin(deltaLambda) * math.cos(phi2);
  final x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
  final theta = math.atan2(y, x);
  return (_radToDeg(theta) + 360) % 360;
}

/// Smallest signed difference `b - a` in degrees, in the range
/// `(-180, 180]`. Positive means `b` is clockwise from `a`.
double signedBearingDifferenceDegrees(double a, double b) {
  final diff = (b - a) % 360;
  if (diff > 180) return diff - 360;
  if (diff <= -180) return diff + 360;
  return diff;
}

const List<String> _compassDirectionNames = [
  'north',
  'northeast',
  'east',
  'southeast',
  'south',
  'southwest',
  'west',
  'northwest',
];

/// The nearest of the 8 cardinal/intercardinal direction names for
/// [degrees] (e.g. "north", "northeast"). Shared by [ExplorationItem] and
/// the real-time navigation HUD so the 8-way mapping lives in one place.
String compassDirectionLabel(double degrees) {
  final normalized = degrees % 360;
  final index = ((normalized + 22.5) / 45).floor() % 8;
  return _compassDirectionNames[index];
}

/// A single `[lat, lon]` point used by polyline projection.
class GeoPoint {
  final double lat;
  final double lon;

  const GeoPoint(this.lat, this.lon);
}

/// Result of projecting a point onto a polyline route.
class RouteProjection {
  /// Perpendicular ("cross-track") distance from the point to the route,
  /// in metres.
  final double crossTrackDistanceMeters;

  /// Cumulative distance along the route to the projected point, in
  /// metres.
  final double distanceAlongRouteMeters;

  /// Index of the polyline segment (between `route[segmentIndex]` and
  /// `route[segmentIndex + 1]`) that the point projects onto.
  final int segmentIndex;

  /// Bearing of the route at the projected segment, in degrees `[0,
  /// 360)`.
  final double segmentBearingDegrees;

  const RouteProjection({
    required this.crossTrackDistanceMeters,
    required this.distanceAlongRouteMeters,
    required this.segmentIndex,
    required this.segmentBearingDegrees,
  });
}

/// Projects [point] onto the polyline [route] (at least 2 points),
/// returning the closest segment, the perpendicular distance to it, and
/// the cumulative along-route distance to the projection.
///
/// Uses a flat-earth equirectangular projection per segment, which is
/// accurate enough at the city-block scale this app operates at. GPS
/// smoothing, outlier filtering, and true map matching are deferred to a
/// later phase.
///
/// Throws [ArgumentError] if [route] has fewer than 2 points.
RouteProjection projectOntoRoute(GeoPoint point, List<GeoPoint> route) {
  if (route.length < 2) {
    throw ArgumentError.value(route, 'route', 'must contain at least 2 points');
  }

  double bestCrossTrack = double.infinity;
  double bestDistanceAlong = 0;
  int bestSegmentIndex = 0;
  double bestSegmentBearing = 0;

  var cumulativeBefore = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    final start = route[i];
    final end = route[i + 1];
    final segmentLength = distanceMeters(
      start.lat,
      start.lon,
      end.lat,
      end.lon,
    );

    // Local equirectangular projection: convert lat/lon deltas to metres
    // using the segment's mean latitude to scale longitude degrees.
    final meanLatRad = _degToRad((start.lat + end.lat) / 2);
    final metresPerDegreeLat = kEarthRadiusMeters * math.pi / 180;
    final metresPerDegreeLon = metresPerDegreeLat * math.cos(meanLatRad);

    final dx = (end.lon - start.lon) * metresPerDegreeLon;
    final dy = (end.lat - start.lat) * metresPerDegreeLat;
    final px = (point.lon - start.lon) * metresPerDegreeLon;
    final py = (point.lat - start.lat) * metresPerDegreeLat;

    final segmentLengthSquared = dx * dx + dy * dy;
    final t = segmentLengthSquared == 0
        ? 0.0
        : ((px * dx + py * dy) / segmentLengthSquared).clamp(0.0, 1.0);

    final projectedLat = start.lat + (end.lat - start.lat) * t;
    final projectedLon = start.lon + (end.lon - start.lon) * t;
    final crossTrack = distanceMeters(
      point.lat,
      point.lon,
      projectedLat,
      projectedLon,
    );

    if (crossTrack < bestCrossTrack) {
      bestCrossTrack = crossTrack;
      bestDistanceAlong = cumulativeBefore + segmentLength * t;
      bestSegmentIndex = i;
      bestSegmentBearing = initialBearingDegrees(
        start.lat,
        start.lon,
        end.lat,
        end.lon,
      );
    }

    cumulativeBefore += segmentLength;
  }

  return RouteProjection(
    crossTrackDistanceMeters: bestCrossTrack,
    distanceAlongRouteMeters: bestDistanceAlong,
    segmentIndex: bestSegmentIndex,
    segmentBearingDegrees: bestSegmentBearing,
  );
}

/// Total length of [route] in metres, summing consecutive segment
/// distances.
double routeTotalLengthMeters(List<GeoPoint> route) {
  var total = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    total += distanceMeters(
      route[i].lat,
      route[i].lon,
      route[i + 1].lat,
      route[i + 1].lon,
    );
  }
  return total;
}
