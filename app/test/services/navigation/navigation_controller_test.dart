import 'dart:async';
import 'dart:convert';

import 'package:accessibility_nav_assistant/models/functional_point.dart';
import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/models/risk_point.dart';
import 'package:accessibility_nav_assistant/models/route_plan.dart';
import 'package:accessibility_nav_assistant/services/api_service.dart';
import 'package:accessibility_nav_assistant/services/navigation/exploration_session.dart';
import 'package:accessibility_nav_assistant/services/navigation/heading_source.dart';
import 'package:accessibility_nav_assistant/services/navigation/navigation_announcer.dart';
import 'package:accessibility_nav_assistant/services/navigation/navigation_controller.dart';
import 'package:accessibility_nav_assistant/services/navigation/off_route_detector.dart';
import 'package:accessibility_nav_assistant/services/navigation/position_source.dart';
import 'package:accessibility_nav_assistant/services/tracked_place_repository.dart';
import 'package:accessibility_nav_assistant/services/vibration_service.dart';
import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class FakePositionSource implements PositionSource {
  final _controller = StreamController<NavPosition>();

  @override
  Stream<NavPosition> positions() => _controller.stream;

  void emit(NavPosition position) => _controller.add(position);
}

class FakeHeadingSource implements HeadingSource {
  final _controller = StreamController<double?>();

  @override
  Stream<double?> headings() => _controller.stream;

  void emit(double? heading) => _controller.add(heading);
}

sealed class AnnouncerCall {}

class SpeakCall extends AnnouncerCall {
  final String text;
  SpeakCall(this.text);

  @override
  String toString() => 'SpeakCall($text)';
}

class VibrateCall extends AnnouncerCall {
  final VibrationPattern pattern;
  VibrateCall(this.pattern);

  @override
  String toString() => 'VibrateCall($pattern)';
}

class StopVibrationCall extends AnnouncerCall {
  @override
  String toString() => 'StopVibrationCall()';
}

class FakeAnnouncer implements NavigationAnnouncer {
  final List<AnnouncerCall> calls = [];

  @override
  Future<void> speak(String text) async {
    calls.add(SpeakCall(text));
  }

  @override
  Future<void> vibrate(VibrationPattern pattern) async {
    calls.add(VibrateCall(pattern));
  }

  @override
  Future<void> stopVibration() async {
    calls.add(StopVibrationCall());
  }
}

NavPosition _pos(
  double lat,
  double lon, {
  double? heading = 90,
  double speed = 1.5,
}) => NavPosition(
  lat: lat,
  lon: lon,
  gpsHeadingDegrees: heading,
  accuracyMeters: 5,
  speedMetersPerSecond: speed,
  timestamp: DateTime.now(),
);

/// Flushes pending microtasks so a fed position's full async handling
/// chain (off-route detection, proximity alerts, state publish) settles
/// before the test makes assertions.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

RoutePlan _buildRoute({
  List<List<double>> geometry = const [
    [0.0, 0.0],
    [0.0, 0.01],
  ],
}) {
  return RoutePlan(
    id: 'route_test',
    mode: 'walk',
    totalDurationSeconds: 600,
    totalWalkingDistanceMeters: 1112,
    transferCount: 0,
    legs: const [
      JourneyLeg(
        id: 'leg_1',
        mode: 'walk',
        fromName: 'Start',
        toName: 'End',
        durationSeconds: 600,
        distanceMeters: 1112,
        steps: [
          NavigationStep(
            instruction: 'Head east along the path',
            distanceMeters: 600,
          ),
          NavigationStep(
            instruction: 'Continue east to the destination',
            distanceMeters: 512,
          ),
        ],
      ),
    ],
    functionalPoints: const [
      FunctionalPoint(
        id: 'fp_1',
        type: 'building_entrance',
        description: 'The entrance is ahead',
        importance: FunctionalPointImportance.navigation,
        triggerDistanceMeters: 30,
        lat: 0,
        lon: 0.0095,
      ),
    ],
    riskPoints: const [
      RiskPoint(
        id: 'risk_1',
        type: 'intersection',
        description: 'Busy crossing ahead',
        severity: RiskSeverity.medium,
        triggerDistanceMeters: 50,
        lat: 0,
        lon: 0.0045,
      ),
    ],
    accessibilitySummary: const AccessibilitySummary(
      score: 80,
      streetCrossings: 1,
      transferCount: 0,
      knownEntrances: 1,
      audibleSignals: 0,
      constructionAlerts: 0,
      walkingDistanceMeters: 1112,
      dataComplete: true,
    ),
    geometry: geometry,
  );
}

Future<ExplorationSession> _buildExplorationSession(
  List<List<double>> geometry,
) async {
  final client = MockClient((request) async {
    return http.Response(
      jsonEncode({
        'center': {'lat': 0, 'lon': 0},
        'radius_meters': 300,
        'categories': {
          'restaurant': [
            {
              'id': 'exp_1',
              'name': 'Cafe Test',
              // Deliberately wrong/stale — relative to the sample query
              // point, not the user. NavigationController must ignore
              // these and recompute live.
              'distance_meters': 9999,
              'bearing_degrees': 123,
              'coordinates': {'lat': 0, 'lon': 0.003},
            },
          ],
        },
      }),
      200,
    );
  });
  final session = ExplorationSession(apiService: ApiService.withClient(client));
  await session.initialize(geometry);
  return session;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NavigationController', () {
    test(
      'does not announce anything when far from every tracked point',
      () async {
        final route = _buildRoute();
        final explorationSession = await _buildExplorationSession(
          route.geometry,
        );
        final positionSource = FakePositionSource();
        final headingSource = FakeHeadingSource();
        final announcer = FakeAnnouncer();
        final controller = NavigationController(
          route: route,
          positionSource: positionSource,
          headingSource: headingSource,
          announcer: announcer,
          explorationSession: explorationSession,
          offRouteDetector: OffRouteDetector(
            consecutiveBadSamplesToFlag: 2,
            escalateAfterBadSamples: 4,
          ),
        );

        await controller.start();
        positionSource.emit(_pos(0, 0.0001));
        await _settle();

        check(announcer.calls).isEmpty();
        await controller.dispose();
      },
    );

    test('announces a risk-point alert with speak then vibrate, in that '
        'order', () async {
      final route = _buildRoute();
      final explorationSession = await _buildExplorationSession(route.geometry);
      final positionSource = FakePositionSource();
      final headingSource = FakeHeadingSource();
      final announcer = FakeAnnouncer();
      final controller = NavigationController(
        route: route,
        positionSource: positionSource,
        headingSource: headingSource,
        announcer: announcer,
        explorationSession: explorationSession,
        offRouteDetector: OffRouteDetector(
          consecutiveBadSamplesToFlag: 2,
          escalateAfterBadSamples: 4,
        ),
      );

      await controller.start();
      positionSource.emit(_pos(0, 0.0045)); // exactly at the risk point
      await _settle();

      check(announcer.calls).length.equals(2);
      final speakCall = announcer.calls[0] as SpeakCall;
      final vibrateCall = announcer.calls[1] as VibrateCall;
      check(speakCall.text).equals('Busy crossing ahead');
      check(vibrateCall.pattern).equals(VibrationPattern.longPulse);
      await controller.dispose();
    });

    test('detects sustained off-route deviation, escalates after enough '
        'bad samples, then clears on return to the route', () async {
      final route = _buildRoute();
      final explorationSession = await _buildExplorationSession(route.geometry);
      final positionSource = FakePositionSource();
      final headingSource = FakeHeadingSource();
      final announcer = FakeAnnouncer();
      final controller = NavigationController(
        route: route,
        positionSource: positionSource,
        headingSource: headingSource,
        announcer: announcer,
        explorationSession: explorationSession,
        offRouteDetector: OffRouteDetector(
          consecutiveBadSamplesToFlag: 2,
          escalateAfterBadSamples: 4,
          lateralDeviationThresholdMeters: 25,
        ),
      );

      await controller.start();

      // First bad sample: deviating, not yet off-route.
      positionSource.emit(_pos(0.001, 0.0015));
      await _settle();
      check(announcer.calls).isEmpty();

      // Second consecutive bad sample: crosses the off-route threshold.
      positionSource.emit(_pos(0.001, 0.0016));
      await _settle();
      check(announcer.calls).length.equals(2);
      final offRouteText = (announcer.calls[0] as SpeakCall).text;
      check(
        offRouteText.contains('off the route') ||
            offRouteText.contains('walking away'),
      ).isTrue();
      check(
        (announcer.calls[1] as VibrateCall).pattern,
      ).equals(VibrationPattern.longPulse);

      // Third and fourth consecutive bad samples: escalation fires once
      // the fourth is reached.
      positionSource.emit(_pos(0.001, 0.0017));
      await _settle();
      check(announcer.calls).length.equals(2); // unchanged

      positionSource.emit(_pos(0.001, 0.0018));
      await _settle();
      check(announcer.calls).length.equals(4);
      check(
        (announcer.calls[3] as VibrateCall).pattern,
      ).equals(VibrationPattern.continuousShort);

      // A good sample (back on the route line) clears off-route and
      // stops any ongoing vibration.
      positionSource.emit(_pos(0, 0.0019, heading: 90));
      await _settle();
      check(announcer.calls).length.equals(5);
      check(announcer.calls.last).isA<StopVibrationCall>();

      await controller.dispose();
    });

    test('announces an exploration point using the live distance/bearing '
        'to the user, not the stale server value', () async {
      final route = _buildRoute();
      final explorationSession = await _buildExplorationSession(route.geometry);
      final positionSource = FakePositionSource();
      final headingSource = FakeHeadingSource();
      final announcer = FakeAnnouncer();
      final controller = NavigationController(
        route: route,
        positionSource: positionSource,
        headingSource: headingSource,
        announcer: announcer,
        explorationSession: explorationSession,
        offRouteDetector: OffRouteDetector(
          consecutiveBadSamplesToFlag: 2,
          escalateAfterBadSamples: 4,
        ),
      );

      await controller.start();
      // The exploration item is at lon 0.003 (~333m from the start);
      // standing right on it should trigger its alert.
      positionSource.emit(_pos(0, 0.003));
      await _settle();

      check(announcer.calls).length.equals(2);
      final speakCall = announcer.calls[0] as SpeakCall;
      check(speakCall.text).contains('Cafe Test');
      check(speakCall.text).contains('metres');
      check(speakCall.text).not((it) => it.contains('9999'));

      await controller.dispose();
    });

    test('announceProgressNow speaks immediately with the current '
        'progress percentage', () async {
      final route = _buildRoute();
      final explorationSession = await _buildExplorationSession(route.geometry);
      final positionSource = FakePositionSource();
      final headingSource = FakeHeadingSource();
      final announcer = FakeAnnouncer();
      final controller = NavigationController(
        route: route,
        positionSource: positionSource,
        headingSource: headingSource,
        announcer: announcer,
        explorationSession: explorationSession,
        progressAnnouncementInterval: const Duration(hours: 1),
      );

      await controller.start();
      // Halfway along the route.
      positionSource.emit(_pos(0, 0.005));
      await _settle();
      final callsBefore = announcer.calls.length;

      await controller.announceProgressNow();

      check(announcer.calls.length).equals(callsBefore + 1);
      final progressCall = announcer.calls.last as SpeakCall;
      check(progressCall.text).contains('50 percent');

      await controller.dispose();
    });

    test('degrades gracefully when the route has no geometry: progress is '
        'unavailable and feeding positions does not throw', () async {
      final route = _buildRoute(geometry: const []);
      final explorationSession = await _buildExplorationSession(route.geometry);
      final positionSource = FakePositionSource();
      final headingSource = FakeHeadingSource();
      final announcer = FakeAnnouncer();
      final controller = NavigationController(
        route: route,
        positionSource: positionSource,
        headingSource: headingSource,
        announcer: announcer,
        explorationSession: explorationSession,
      );

      await controller.start();

      check(controller.currentState.routeProgressAvailable).isFalse();
      check(controller.currentState.progressFraction).isNull();

      positionSource.emit(_pos(0, 0.0001));
      await _settle();

      check(controller.currentState.progressFraction).isNull();
      check(controller.currentState.currentStepDescription).isNull();

      await controller.dispose();
    });

    test('includes an active personal place mapped to its tag\'s tier, '
        'and excludes a paused one entirely', () async {
      final route = _buildRoute();
      final explorationSession = await _buildExplorationSession(route.geometry);
      final activePlace = await TrackedPlaceRepository.instance.add(
        name: 'Water puddle',
        lat: 0,
        lon: 0.002,
        categoryId: 'hazard_detour',
        tag: PlaceTag.urgentAlert,
        addedVia: 'button_capture',
      );
      final pausedPlace = await TrackedPlaceRepository.instance.add(
        name: 'Resolved construction',
        lat: 0,
        lon: 0.0021,
        categoryId: 'uncategorized',
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );
      await TrackedPlaceRepository.instance.setPaused(pausedPlace.id, true);

      final positionSource = FakePositionSource();
      final headingSource = FakeHeadingSource();
      final announcer = FakeAnnouncer();
      final controller = NavigationController(
        route: route,
        positionSource: positionSource,
        headingSource: headingSource,
        announcer: announcer,
        explorationSession: explorationSession,
        offRouteDetector: OffRouteDetector(
          consecutiveBadSamplesToFlag: 2,
          escalateAfterBadSamples: 4,
        ),
      );

      await controller.start();
      positionSource.emit(_pos(0, 0.002)); // exactly at the active place
      await _settle();

      check(announcer.calls).length.equals(2);
      check((announcer.calls[0] as SpeakCall).text).equals(activePlace.name);
      check(
        (announcer.calls[1] as VibrateCall).pattern,
      ).equals(VibrationPattern.longPulse);
      check(
        announcer.calls.whereType<SpeakCall>().any(
          (call) => call.text.contains('Resolved construction'),
        ),
      ).isFalse();

      await controller.dispose();
    });
  });
}
