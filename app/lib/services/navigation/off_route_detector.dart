import '../../core/geo_utils.dart';

enum OffRouteSeverity { onRoute, deviating, offRoute }

/// Result of feeding one sample into [OffRouteDetector].
class OffRouteResult {
  final OffRouteSeverity severity;

  /// True exactly on the sample where severity first reached
  /// [OffRouteSeverity.offRoute] after not having been there — used to
  /// fire the "long pulse once" alert exactly once per departure.
  final bool justBecameOffRoute;

  /// True once off-route has persisted for `escalateAfterBadSamples`
  /// consecutive bad samples — used to fire the "continuous short"
  /// escalation. Only meaningful while [severity] is
  /// [OffRouteSeverity.offRoute].
  final bool shouldEscalate;

  const OffRouteResult({
    required this.severity,
    required this.justBecameOffRoute,
    required this.shouldEscalate,
  });
}

/// Detects basic off-route conditions from lateral deviation from the
/// route geometry and heading-vs-route-direction mismatch.
///
/// Requires [consecutiveBadSamplesToFlag] consecutive bad samples before
/// reporting [OffRouteSeverity.offRoute], so a single noisy GPS fix
/// cannot trigger an alert. Heading mismatch is ignored while the user
/// is judged stationary (speed below [stationarySpeedThreshold]) — a
/// user standing still and turning to look around should not be flagged
/// for "facing the wrong way", but a user standing far from the route
/// geometry is still off-route regardless of heading.
///
/// GPS smoothing, outlier filtering, and map matching are deferred to a
/// later phase; this detector intentionally uses only the raw lateral
/// distance and heading numbers already computed by [projectOntoRoute].
class OffRouteDetector {
  OffRouteDetector({
    this.lateralDeviationThresholdMeters = 25,
    this.headingMismatchThresholdDegrees = 60,
    this.consecutiveBadSamplesToFlag = 3,
    this.escalateAfterBadSamples = 8,
    this.stationarySpeedThreshold = 0.3,
  });

  final double lateralDeviationThresholdMeters;
  final double headingMismatchThresholdDegrees;
  final int consecutiveBadSamplesToFlag;
  final int escalateAfterBadSamples;
  final double stationarySpeedThreshold;

  int _consecutiveBadSamples = 0;
  bool _wasOffRoute = false;

  /// Feeds one position+heading+route-projection sample.
  ///
  /// [heading] is the best-available facing direction (compass, falling
  /// back to GPS course) — null if neither is available.
  OffRouteResult update({
    required RouteProjection projection,
    required double? heading,
    required double speedMetersPerSecond,
  }) {
    final isStationary = speedMetersPerSecond < stationarySpeedThreshold;
    final lateralBad =
        projection.crossTrackDistanceMeters > lateralDeviationThresholdMeters;
    final headingBad =
        !isStationary &&
        heading != null &&
        signedBearingDifferenceDegrees(
              heading,
              projection.segmentBearingDegrees,
            ).abs() >
            headingMismatchThresholdDegrees;
    final sampleBad = lateralBad || headingBad;

    if (sampleBad) {
      _consecutiveBadSamples++;
    } else {
      _consecutiveBadSamples = 0;
    }

    final isOffRouteNow = _consecutiveBadSamples >= consecutiveBadSamplesToFlag;
    final justBecameOffRoute = isOffRouteNow && !_wasOffRoute;
    final shouldEscalate =
        isOffRouteNow && _consecutiveBadSamples >= escalateAfterBadSamples;
    final severity = isOffRouteNow
        ? OffRouteSeverity.offRoute
        : (sampleBad ? OffRouteSeverity.deviating : OffRouteSeverity.onRoute);

    _wasOffRoute = isOffRouteNow;

    return OffRouteResult(
      severity: severity,
      justBecameOffRoute: justBecameOffRoute,
      shouldEscalate: shouldEscalate,
    );
  }

  /// Resets internal debounce state (call when navigation restarts).
  void reset() {
    _consecutiveBadSamples = 0;
    _wasOffRoute = false;
  }
}
