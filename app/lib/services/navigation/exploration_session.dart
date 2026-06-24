import 'dart:developer' as developer;

import '../../core/geo_utils.dart';
import '../../models/exploration_item.dart';
import '../api_service.dart';
import '../vibration_service.dart';
import 'proximity_alert_engine.dart';

/// Builds and holds the set of exploration items relevant to one
/// navigation session.
///
/// There is no "along-route" exploration endpoint yet — only a
/// single-point `nearby` query. To approximate route-wide coverage,
/// [initialize] samples points along the route geometry roughly every
/// [sampleIntervalMeters] (capped at [maxSamples]) and queries
/// [ApiService.nearbyExploration] once per sample, merging and
/// de-duplicating the results by item id.
///
/// The server's per-sample distance/bearing fields are discarded — they
/// were relative to the sample query point, not the user. Each resulting
/// [TrackedPoint] keeps the item's own static coordinates, so
/// [ProximityAlertEngine] always computes live distance against the
/// user's real-time position.
class ExplorationSession {
  ExplorationSession({
    required ApiService apiService,
    this.sampleIntervalMeters = 350,
    this.maxSamples = 12,
    this.triggerDistanceMeters = 50,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final double sampleIntervalMeters;
  final int maxSamples;
  final double triggerDistanceMeters;

  List<TrackedPoint> _items = [];

  /// The exploration points tracked for this session, mapped to
  /// [TrackedPoint] for use by [ProximityAlertEngine].
  List<TrackedPoint> get items => List.unmodifiable(_items);

  /// Fetches and merges exploration items along [routeGeometry] (a list
  /// of `[lat, lon]` pairs). No-ops (and makes no HTTP calls) if
  /// [routeGeometry] is empty.
  Future<void> initialize(List<List<double>> routeGeometry) async {
    if (routeGeometry.isEmpty) {
      _items = [];
      return;
    }

    final samplePoints = _samplePoints(routeGeometry);
    final byId = <String, ExplorationItem>{};

    for (final sample in samplePoints) {
      try {
        final categories = await _apiService.nearbyExploration(
          lat: sample.lat,
          lon: sample.lon,
          radiusMeters: 300,
        );
        for (final category in categories) {
          for (final item in category.items) {
            byId.putIfAbsent(item.id, () => item);
          }
        }
      } catch (e, stackTrace) {
        developer.log(
          'Exploration sample fetch failed',
          name: 'app.navigation.exploration',
          level: 1000,
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    _items = byId.values
        .map(
          (item) => TrackedPoint(
            id: item.id,
            category: AlertCategory.explorationPoint,
            // Just the name — NOT item.ttsText, which bakes in the
            // server's per-sample distance/bearing. NavigationController
            // builds the spoken announcement from the user's live
            // position instead.
            description: item.name,
            triggerDistanceMeters: triggerDistanceMeters,
            lat: item.lat,
            lon: item.lon,
            vibrationPattern: VibrationPattern.shortPulse,
          ),
        )
        .toList();
  }

  List<GeoPoint> _samplePoints(List<List<double>> routeGeometry) {
    final points = routeGeometry
        .map((p) => GeoPoint(p[0], p[1]))
        .toList(growable: false);
    final samples = <GeoPoint>[points.first];

    var cumulativeSinceLastSample = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final segmentLength = distanceMeters(
        points[i].lat,
        points[i].lon,
        points[i + 1].lat,
        points[i + 1].lon,
      );
      cumulativeSinceLastSample += segmentLength;
      if (cumulativeSinceLastSample >= sampleIntervalMeters) {
        samples.add(points[i + 1]);
        cumulativeSinceLastSample = 0;
        if (samples.length >= maxSamples) break;
      }
    }

    return samples;
  }
}
