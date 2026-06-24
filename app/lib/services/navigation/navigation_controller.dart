import 'dart:async';

import '../../core/geo_utils.dart';
import '../../models/functional_point.dart';
import '../../models/place_tag.dart';
import '../../models/risk_point.dart';
import '../../models/route_plan.dart';
import '../../models/tracked_place.dart';
import '../tracked_place_repository.dart';
import '../vibration_service.dart';
import 'exploration_session.dart';
import 'heading_source.dart';
import 'navigation_announcer.dart';
import 'off_route_detector.dart';
import 'position_source.dart';
import 'proximity_alert_engine.dart';

/// Snapshot of navigation state exposed to the UI on every update.
class NavigationState {
  final NavPosition? lastPosition;
  final double? headingDegrees;

  /// Null if [RoutePlan.geometry] is empty (progress unavailable).
  final double? progressFraction;

  /// Best-effort "current street/segment" approximation: the nearest
  /// [NavigationStep.instruction] to the user's projected position along
  /// the route. Null if geometry is empty or no position has arrived yet.
  final String? currentStepDescription;

  final OffRouteSeverity offRouteSeverity;
  final bool routeProgressAvailable;

  const NavigationState({
    this.lastPosition,
    this.headingDegrees,
    this.progressFraction,
    this.currentStepDescription,
    this.offRouteSeverity = OffRouteSeverity.onRoute,
    this.routeProgressAvailable = false,
  });
}

/// A fired alert ready for the screen/announcer pipeline — either a
/// proximity alert or an off-route condition change.
sealed class NavigationEvent {
  const NavigationEvent();
}

class ProximityNavigationEvent extends NavigationEvent {
  final ProximityAlert alert;
  const ProximityNavigationEvent(this.alert);
}

class OffRouteNavigationEvent extends NavigationEvent {
  final OffRouteSeverity severity;
  final bool isEscalation;
  const OffRouteNavigationEvent(this.severity, {required this.isEscalation});
}

class ProgressAnnouncementEvent extends NavigationEvent {
  final double progressFraction;
  const ProgressAnnouncementEvent(this.progressFraction);
}

const _offRouteText =
    'You may be walking away from the route. Please stop and confirm your '
    'direction.';
const _offRouteEscalationText =
    'You still appear to be off the route. Please stop and confirm your '
    'direction immediately.';

/// Orchestrates continuous GPS + compass during an active navigation
/// session: computes progress/current-step, runs off-route detection,
/// evaluates proximity alerts, and drives [NavigationAnnouncer] (TTS +
/// vibration) — the sensing/alerting layer that sits above the existing
/// manual step-paging UI in `NavigationScreen`.
class NavigationController {
  NavigationController({
    required RoutePlan route,
    required PositionSource positionSource,
    required HeadingSource headingSource,
    required NavigationAnnouncer announcer,
    required ExplorationSession explorationSession,
    OffRouteDetector? offRouteDetector,
    Duration progressAnnouncementInterval = const Duration(minutes: 3),
    TrackedPlaceRepository? trackedPlaceRepository,
  }) : _route = route,
       _positionSource = positionSource,
       _headingSource = headingSource,
       _announcer = announcer,
       _explorationSession = explorationSession,
       _offRouteDetector = offRouteDetector ?? OffRouteDetector(),
       _progressAnnouncementInterval = progressAnnouncementInterval,
       _trackedPlaceRepository =
           trackedPlaceRepository ?? TrackedPlaceRepository.instance;

  final RoutePlan _route;
  final PositionSource _positionSource;
  final HeadingSource _headingSource;
  final NavigationAnnouncer _announcer;
  final ExplorationSession _explorationSession;
  final OffRouteDetector _offRouteDetector;
  final Duration _progressAnnouncementInterval;
  final TrackedPlaceRepository _trackedPlaceRepository;

  final _stateController = StreamController<NavigationState>.broadcast();
  final _eventsController = StreamController<NavigationEvent>.broadcast();

  NavigationState _currentState = const NavigationState();
  late final List<GeoPoint> _routeGeometry;
  late final List<double> _stepCumulativeStartDistances;
  late final List<NavigationStep> _steps;
  late final double _routeTotalLength;
  late final bool _routeProgressAvailable;
  late final ProximityAlertEngine _proximityEngine;

  double? _latestCompassHeading;
  bool _hasAnnouncedOffRoute = false;
  bool _hasAnnouncedEscalation = false;
  bool _started = false;

  StreamSubscription<double?>? _headingSubscription;
  StreamSubscription<NavPosition>? _positionSubscription;
  Timer? _progressTimer;

  /// Current state snapshot.
  NavigationState get currentState => _currentState;

  /// Emits a new [NavigationState] on every position update.
  Stream<NavigationState> get stateUpdates => _stateController.stream;

  /// Fires once per navigation event needing TTS/vibration; the screen
  /// can optionally listen here for non-audio purposes (e.g. showing a
  /// transient banner).
  Stream<NavigationEvent> get events => _eventsController.stream;

  /// Begins listening to position/heading streams and evaluating alerts.
  ///
  /// Throws [StateError] if already started.
  Future<void> start() async {
    if (_started) {
      throw StateError('NavigationController has already been started.');
    }
    _started = true;

    _routeGeometry = _route.geometry
        .map((p) => GeoPoint(p[0], p[1]))
        .toList(growable: false);
    _routeProgressAvailable = _routeGeometry.length >= 2;
    _routeTotalLength = _routeProgressAvailable
        ? routeTotalLengthMeters(_routeGeometry)
        : 0;

    _steps = _route.allSteps;
    _stepCumulativeStartDistances = [];
    var cumulative = 0.0;
    for (final step in _steps) {
      _stepCumulativeStartDistances.add(cumulative);
      cumulative += step.distanceMeters;
    }

    final personalPlaces = await _trackedPlaceRepository.getActive();
    _proximityEngine = ProximityAlertEngine([
      ..._route.riskPoints.map(_riskPointToTrackedPoint),
      ..._route.functionalPoints.map(_functionalPointToTrackedPoint),
      ..._explorationSession.items,
      ...personalPlaces.map(_trackedPlaceToTrackedPoint),
    ]);

    _currentState = NavigationState(
      routeProgressAvailable: _routeProgressAvailable,
    );
    _stateController.add(_currentState);

    _headingSubscription = _headingSource.headings().listen((heading) {
      _latestCompassHeading = heading;
    });

    _positionSubscription = _positionSource.positions().listen(_handlePosition);

    if (_routeProgressAvailable) {
      _progressTimer = Timer.periodic(
        _progressAnnouncementInterval,
        (_) => unawaited(_announceProgress()),
      );
    }
  }

  /// Maps a user's personal place (design doc §1.1.3, §2.3) into the
  /// same four-tier [ProximityAlertEngine] used by official points — the
  /// tag's [PlaceTagInfo] extension owns the tier/vibration/distance
  /// mapping (§2.2.4), so this is just a one-to-one translation.
  TrackedPoint _trackedPlaceToTrackedPoint(TrackedPlace place) => TrackedPoint(
    id: 'personal_${place.id}',
    category: place.tag.alertCategory,
    description: place.name,
    triggerDistanceMeters: place.tag.defaultTriggerDistanceMeters,
    lat: place.lat,
    lon: place.lon,
    vibrationPattern: place.tag.vibrationPattern,
  );

  TrackedPoint _riskPointToTrackedPoint(RiskPoint point) => TrackedPoint(
    id: point.id,
    category: AlertCategory.riskPoint,
    description: point.description,
    triggerDistanceMeters: point.triggerDistanceMeters,
    lat: point.lat,
    lon: point.lon,
    vibrationPattern: VibrationPattern.longPulse,
  );

  TrackedPoint _functionalPointToTrackedPoint(FunctionalPoint point) {
    const transitBoardAlightTypes = {'bus_board', 'bus_alight'};
    final isTransitBoardAlight = transitBoardAlightTypes.contains(point.type);
    return TrackedPoint(
      id: point.id,
      category: point.importance == FunctionalPointImportance.required
          ? AlertCategory.requiredFunctionalPoint
          : AlertCategory.navigationFunctionalPoint,
      description: point.description,
      triggerDistanceMeters: point.triggerDistanceMeters,
      lat: point.lat,
      lon: point.lon,
      vibrationPattern: isTransitBoardAlight
          ? VibrationPattern.shortThenLong
          : VibrationPattern.shortPulse,
    );
  }

  Future<void> _handlePosition(NavPosition position) async {
    RouteProjection? projection;
    double? progressFraction;
    String? currentStepDescription;
    var severity = OffRouteSeverity.onRoute;

    if (_routeProgressAvailable) {
      projection = projectOntoRoute(
        GeoPoint(position.lat, position.lon),
        _routeGeometry,
      );
      progressFraction = _routeTotalLength == 0
          ? 0
          : (projection.distanceAlongRouteMeters / _routeTotalLength).clamp(
              0.0,
              1.0,
            );
      currentStepDescription = _currentStepDescriptionFor(
        projection.distanceAlongRouteMeters,
      );

      final heading = _latestCompassHeading ?? position.gpsHeadingDegrees;
      final result = _offRouteDetector.update(
        projection: projection,
        heading: heading,
        speedMetersPerSecond: position.speedMetersPerSecond,
      );
      severity = result.severity;
      await _handleOffRouteResult(result);
    }

    _currentState = NavigationState(
      lastPosition: position,
      headingDegrees: _latestCompassHeading ?? position.gpsHeadingDegrees,
      progressFraction: progressFraction,
      currentStepDescription: currentStepDescription,
      offRouteSeverity: severity,
      routeProgressAvailable: _routeProgressAvailable,
    );
    _stateController.add(_currentState);

    final alerts = _proximityEngine.update(
      lat: position.lat,
      lon: position.lon,
    );
    for (final alert in alerts) {
      _eventsController.add(ProximityNavigationEvent(alert));
      await _announcer.speak(_announcementTextFor(alert, position));
      await _announcer.vibrate(alert.point.vibrationPattern);
    }
  }

  /// Builds the spoken text for [alert]. Functional/risk point
  /// descriptions are already full sentences from the backend. For
  /// exploration points, the distance and bearing are recomputed live
  /// from [position] rather than trusting the server's per-sample
  /// values, which were relative to the sample query point, not the
  /// user.
  String _announcementTextFor(ProximityAlert alert, NavPosition position) {
    if (alert.point.category != AlertCategory.explorationPoint) {
      return alert.point.description;
    }
    final bearing = initialBearingDegrees(
      position.lat,
      position.lon,
      alert.point.lat,
      alert.point.lon,
    );
    final direction = compassDirectionLabel(bearing);
    final distanceLabel = alert.distanceMeters < 1000
        ? '${alert.distanceMeters.round()} metres'
        : '${(alert.distanceMeters / 1000).toStringAsFixed(1)} kilometres';
    return '${alert.point.description}, approximately $distanceLabel to '
        'the $direction';
  }

  Future<void> _handleOffRouteResult(OffRouteResult result) async {
    if (result.justBecameOffRoute) {
      _hasAnnouncedOffRoute = true;
      _hasAnnouncedEscalation = false;
      _eventsController.add(
        const OffRouteNavigationEvent(
          OffRouteSeverity.offRoute,
          isEscalation: false,
        ),
      );
      await _announcer.speak(_offRouteText);
      await _announcer.vibrate(VibrationPattern.longPulse);
      return;
    }

    if (result.severity == OffRouteSeverity.offRoute &&
        result.shouldEscalate &&
        !_hasAnnouncedEscalation) {
      _hasAnnouncedEscalation = true;
      _eventsController.add(
        const OffRouteNavigationEvent(
          OffRouteSeverity.offRoute,
          isEscalation: true,
        ),
      );
      await _announcer.speak(_offRouteEscalationText);
      await _announcer.vibrate(VibrationPattern.continuousShort);
      return;
    }

    if (result.severity != OffRouteSeverity.offRoute && _hasAnnouncedOffRoute) {
      _hasAnnouncedOffRoute = false;
      _hasAnnouncedEscalation = false;
      await _announcer.stopVibration();
    }
  }

  String? _currentStepDescriptionFor(double distanceAlongRoute) {
    if (_steps.isEmpty) return null;
    var nearestIndex = 0;
    for (var i = 0; i < _steps.length; i++) {
      if (_stepCumulativeStartDistances[i] <= distanceAlongRoute) {
        nearestIndex = i;
      } else {
        break;
      }
    }
    return _steps[nearestIndex].instruction;
  }

  /// On-demand progress announcement (e.g. user taps "where am I").
  /// Speaks immediately regardless of the periodic interval.
  Future<void> announceProgressNow() => _announceProgress();

  Future<void> _announceProgress() async {
    final fraction = _currentState.progressFraction;
    if (!_routeProgressAvailable || fraction == null) {
      await _announcer.speak('Your route progress is not yet available.');
      return;
    }
    final percent = (fraction * 100).round();
    final step = _currentState.currentStepDescription;
    final text = step == null
        ? 'You have completed approximately $percent percent of your route.'
        : 'You have completed approximately $percent percent of your '
              'route. You are $step';
    _eventsController.add(ProgressAnnouncementEvent(fraction));
    await _announcer.speak(text);
  }

  /// Stops listening and releases stream subscriptions/timers.
  Future<void> dispose() async {
    await _headingSubscription?.cancel();
    await _positionSubscription?.cancel();
    _progressTimer?.cancel();
    await _stateController.close();
    await _eventsController.close();
  }
}
