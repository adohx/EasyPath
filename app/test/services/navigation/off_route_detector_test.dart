import 'package:accessibility_nav_assistant/core/geo_utils.dart';
import 'package:accessibility_nav_assistant/services/navigation/off_route_detector.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

RouteProjection _projectionWithCrossTrack(double crossTrackMeters) {
  return RouteProjection(
    crossTrackDistanceMeters: crossTrackMeters,
    distanceAlongRouteMeters: 0,
    segmentIndex: 0,
    segmentBearingDegrees: 0,
  );
}

void main() {
  group('OffRouteDetector', () {
    test('a single bad sample does not trigger off-route', () {
      final detector = OffRouteDetector(consecutiveBadSamplesToFlag: 3);

      final result = detector.update(
        projection: _projectionWithCrossTrack(100),
        heading: 0,
        speedMetersPerSecond: 1.5,
      );

      check(result.severity).equals(OffRouteSeverity.deviating);
      check(result.justBecameOffRoute).isFalse();
    });

    test('reports off-route exactly once after the consecutive-bad-sample '
        'threshold is reached', () {
      final detector = OffRouteDetector(consecutiveBadSamplesToFlag: 3);

      final results = List.generate(
        5,
        (_) => detector.update(
          projection: _projectionWithCrossTrack(100),
          heading: 0,
          speedMetersPerSecond: 1.5,
        ),
      );

      check(results[0].severity).equals(OffRouteSeverity.deviating);
      check(results[1].severity).equals(OffRouteSeverity.deviating);
      check(results[2].severity).equals(OffRouteSeverity.offRoute);
      check(results[2].justBecameOffRoute).isTrue();
      check(results[3].severity).equals(OffRouteSeverity.offRoute);
      check(results[3].justBecameOffRoute).isFalse();
      check(results[4].justBecameOffRoute).isFalse();
    });

    test('a good sample resets the counter and clears off-route severity', () {
      final detector = OffRouteDetector(consecutiveBadSamplesToFlag: 3);

      for (var i = 0; i < 3; i++) {
        detector.update(
          projection: _projectionWithCrossTrack(100),
          heading: 0,
          speedMetersPerSecond: 1.5,
        );
      }
      final afterGoodSample = detector.update(
        projection: _projectionWithCrossTrack(0),
        heading: 0,
        speedMetersPerSecond: 1.5,
      );
      final afterAnotherBadSample = detector.update(
        projection: _projectionWithCrossTrack(100),
        heading: 0,
        speedMetersPerSecond: 1.5,
      );

      check(afterGoodSample.severity).equals(OffRouteSeverity.onRoute);
      // The counter was reset, so a single subsequent bad sample alone
      // should not immediately re-trigger off-route.
      check(afterAnotherBadSample.severity).equals(OffRouteSeverity.deviating);
      check(afterAnotherBadSample.justBecameOffRoute).isFalse();
    });

    test('heading mismatch is ignored while the user is stationary', () {
      final detector = OffRouteDetector(
        consecutiveBadSamplesToFlag: 1,
        headingMismatchThresholdDegrees: 60,
        stationarySpeedThreshold: 0.3,
      );

      final result = detector.update(
        projection: _projectionWithCrossTrack(0),
        heading: 180, // 180 degrees off the route's 0-degree bearing
        speedMetersPerSecond: 0.0,
      );

      check(result.severity).equals(OffRouteSeverity.onRoute);
    });

    test('the same heading mismatch counts once the user is moving', () {
      final detector = OffRouteDetector(
        consecutiveBadSamplesToFlag: 1,
        headingMismatchThresholdDegrees: 60,
        stationarySpeedThreshold: 0.3,
      );

      final result = detector.update(
        projection: _projectionWithCrossTrack(0),
        heading: 180,
        speedMetersPerSecond: 1.5,
      );

      check(result.severity).equals(OffRouteSeverity.offRoute);
    });

    test('escalates to shouldEscalate after sustained off-route samples', () {
      final detector = OffRouteDetector(
        consecutiveBadSamplesToFlag: 3,
        escalateAfterBadSamples: 5,
      );

      final results = List.generate(
        5,
        (_) => detector.update(
          projection: _projectionWithCrossTrack(100),
          heading: 0,
          speedMetersPerSecond: 1.5,
        ),
      );

      check(results[2].shouldEscalate).isFalse();
      check(results[3].shouldEscalate).isFalse();
      check(results[4].shouldEscalate).isTrue();
    });

    test('reset() clears the consecutive-bad-sample counter', () {
      final detector = OffRouteDetector(consecutiveBadSamplesToFlag: 3);
      for (var i = 0; i < 3; i++) {
        detector.update(
          projection: _projectionWithCrossTrack(100),
          heading: 0,
          speedMetersPerSecond: 1.5,
        );
      }

      detector.reset();
      final result = detector.update(
        projection: _projectionWithCrossTrack(100),
        heading: 0,
        speedMetersPerSecond: 1.5,
      );

      check(result.severity).equals(OffRouteSeverity.deviating);
      check(result.justBecameOffRoute).isFalse();
    });
  });
}
