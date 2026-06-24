import 'package:accessibility_nav_assistant/core/geo_utils.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('distanceMeters', () {
    test('is zero for identical points', () {
      check(
        distanceMeters(42.3150, -83.0360, 42.3150, -83.0360),
      ).isCloseTo(0, 0.01);
    });

    test('matches the known length of one degree of latitude', () {
      // One degree of latitude is approximately 111,195 metres.
      final distance = distanceMeters(0, 0, 1, 0);
      check(distance).isCloseTo(111195, 1200);
    });
  });

  group('initialBearingDegrees', () {
    test('is approximately 0 for a due-north pair', () {
      final bearing = initialBearingDegrees(0, 0, 1, 0);
      check(bearing).isCloseTo(0, 0.5);
    });

    test('is approximately 90 for a due-east pair', () {
      final bearing = initialBearingDegrees(0, 0, 0, 1);
      check(bearing).isCloseTo(90, 0.5);
    });
  });

  group('signedBearingDifferenceDegrees', () {
    test('is zero for identical headings', () {
      check(signedBearingDifferenceDegrees(45, 45)).equals(0);
    });

    test('wraps around the 0/360 boundary as a small positive value', () {
      check(signedBearingDifferenceDegrees(350, 10)).isCloseTo(20, 0.01);
    });

    test('wraps around the 0/360 boundary as a small negative value', () {
      check(signedBearingDifferenceDegrees(10, 350)).isCloseTo(-20, 0.01);
    });
  });

  group('compassDirectionLabel', () {
    test('maps 0 degrees to north', () {
      check(compassDirectionLabel(0)).equals('north');
    });

    test('maps 90 degrees to east', () {
      check(compassDirectionLabel(90)).equals('east');
    });

    test('maps 359 degrees to north', () {
      check(compassDirectionLabel(359)).equals('north');
    });
  });

  group('projectOntoRoute', () {
    final route = [
      const GeoPoint(0, 0),
      const GeoPoint(0, 0.01),
      const GeoPoint(0.01, 0.01),
    ];

    test('throws for a route with fewer than 2 points', () {
      check(
        () => projectOntoRoute(const GeoPoint(0, 0), [const GeoPoint(0, 0)]),
      ).throws<ArgumentError>();
    });

    test('reports near-zero cross-track distance for a point on the route', () {
      final projection = projectOntoRoute(const GeoPoint(0, 0.005), route);
      check(projection.crossTrackDistanceMeters).isCloseTo(0, 1);
      check(projection.segmentIndex).equals(0);
    });

    test('reports the perpendicular distance for an offset point', () {
      // Roughly 0.00027 degrees of latitude is about 30 metres.
      final projection = projectOntoRoute(
        const GeoPoint(0.00027, 0.005),
        route,
      );
      check(projection.crossTrackDistanceMeters).isCloseTo(30, 3);
    });

    test('clamps projection to the last vertex beyond the route end', () {
      final projection = projectOntoRoute(const GeoPoint(0.02, 0.01), route);
      check(projection.segmentIndex).equals(1);
      check(
        projection.distanceAlongRouteMeters,
      ).isCloseTo(routeTotalLengthMeters(route), 0.5);
    });

    test('accumulates distance along the route from the route start', () {
      final firstSegmentLength = distanceMeters(
        route[0].lat,
        route[0].lon,
        route[1].lat,
        route[1].lon,
      );
      // Halfway along the second segment, latitude 0 -> 0.01.
      final halfSecondSegment = distanceMeters(
        route[1].lat,
        route[1].lon,
        0.005,
        0.01,
      );
      final projection = projectOntoRoute(const GeoPoint(0.005, 0.01), route);
      check(projection.segmentIndex).equals(1);
      check(
        projection.distanceAlongRouteMeters,
      ).isCloseTo(firstSegmentLength + halfSecondSegment, 1);
    });
  });

  group('routeTotalLengthMeters', () {
    test('sums consecutive segment distances', () {
      final route = [
        const GeoPoint(0, 0),
        const GeoPoint(0, 0.01),
        const GeoPoint(0.01, 0.01),
      ];
      final expected =
          distanceMeters(0, 0, 0, 0.01) + distanceMeters(0, 0.01, 0.01, 0.01);
      check(routeTotalLengthMeters(route)).isCloseTo(expected, 0.01);
    });
  });
}
