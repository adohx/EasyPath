import '../../core/geo_utils.dart';
import '../vibration_service.dart';

/// Alert priority order, highest first: risk points must be able to
/// interrupt lower-priority alerts per the design doc.
enum AlertCategory {
  riskPoint,
  requiredFunctionalPoint,
  navigationFunctionalPoint,
  explorationPoint,
}

/// A single trackable point the proximity engine watches during a
/// navigation session, regardless of its underlying model type
/// (`RiskPoint`, `FunctionalPoint`, or `ExplorationItem`).
class TrackedPoint {
  final String id;
  final AlertCategory category;
  final String description;
  final double triggerDistanceMeters;
  final double lat;
  final double lon;
  final VibrationPattern vibrationPattern;

  /// Whether this point may be announced more than once. Always false
  /// for the points currently produced by [NavigationController]; kept
  /// as a field so a future "allow repeat" setting does not require
  /// restructuring callers.
  final bool allowRepeat;

  const TrackedPoint({
    required this.id,
    required this.category,
    required this.description,
    required this.triggerDistanceMeters,
    required this.lat,
    required this.lon,
    required this.vibrationPattern,
    this.allowRepeat = false,
  });
}

/// One fired alert, ready for the caller to announce.
class ProximityAlert {
  final TrackedPoint point;
  final double distanceMeters;

  const ProximityAlert({required this.point, required this.distanceMeters});
}

int _categoryPriority(AlertCategory category) => switch (category) {
  AlertCategory.riskPoint => 0,
  AlertCategory.requiredFunctionalPoint => 1,
  AlertCategory.navigationFunctionalPoint => 2,
  AlertCategory.explorationPoint => 3,
};

/// Tracks a fixed set of points for one navigation session and decides,
/// on each position update, which alerts should fire — highest priority
/// first, each point firing at most once unless [TrackedPoint.allowRepeat].
///
/// Each point's own [TrackedPoint.triggerDistanceMeters] is respected as
/// given; the engine never hardcodes the design doc's suggested
/// 60-100m/30-80m ranges — those are already encoded server-side per
/// point type.
class ProximityAlertEngine {
  ProximityAlertEngine(List<TrackedPoint> points) : _points = List.of(points);

  final List<TrackedPoint> _points;
  final Set<String> _announced = {};

  /// Read-only snapshot of currently tracked points (for UI / tests).
  List<TrackedPoint> get points => List.unmodifiable(_points);

  /// Feeds one user position, returning all alerts that newly crossed
  /// their trigger distance, ordered by priority (risk first, then
  /// required-functional, then navigation-functional, then
  /// exploration), ties broken by ascending distance.
  List<ProximityAlert> update({required double lat, required double lon}) {
    final candidates = <ProximityAlert>[];
    for (final point in _points) {
      if (_announced.contains(point.id) && !point.allowRepeat) continue;
      final distance = distanceMeters(lat, lon, point.lat, point.lon);
      if (distance <= point.triggerDistanceMeters) {
        candidates.add(ProximityAlert(point: point, distanceMeters: distance));
      }
    }

    candidates.sort((a, b) {
      final priorityDiff =
          _categoryPriority(a.point.category) -
          _categoryPriority(b.point.category);
      if (priorityDiff != 0) return priorityDiff;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    for (final alert in candidates) {
      if (!alert.point.allowRepeat) {
        _announced.add(alert.point.id);
      }
    }

    return candidates;
  }
}
