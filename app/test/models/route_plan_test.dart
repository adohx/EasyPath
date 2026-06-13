import 'package:accessibility_nav_assistant/models/functional_point.dart';
import 'package:accessibility_nav_assistant/models/risk_point.dart';
import 'package:accessibility_nav_assistant/models/route_plan.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

Map<String, dynamic> _sampleRouteJson() => {
      'id': 'route_001',
      'mode': 'walk',
      'total_duration_seconds': 1200,
      'total_walking_distance_meters': 900,
      'transfer_count': 0,
      'legs': [
        {
          'id': 'leg_001',
          'mode': 'walk',
          'from': {'name': 'Current Location'},
          'to': {'name': 'Windsor Public Library'},
          'duration_seconds': 1200,
          'distance_meters': 900,
          'steps': [
            {
              'instruction': 'Head north on Ouellette Avenue',
              'distance_meters': 300,
            },
          ],
        },
      ],
      'functional_points': [
        {
          'id': 'fp_001',
          'type': 'building_entrance',
          'description': 'Windsor Public Library — main entrance',
          'importance': 'navigation',
          'trigger_distance_meters': 40,
          'coordinates': {'lat': 42.3192, 'lon': -83.0391},
        },
      ],
      'risk_points': [
        {
          'id': 'rp_001',
          'type': 'intersection',
          'description': 'Ouellette Ave at Wyandotte St',
          'severity': 'medium',
          'trigger_distance_meters': 100,
          'coordinates': {'lat': 42.3170, 'lon': -83.0370},
        },
      ],
      'accessibility_summary': {
        'score': 78,
        'street_crossings': 2,
        'transfer_count': 0,
        'known_entrances': 1,
        'audible_signals': 1,
        'construction_alerts': 0,
        'walking_distance_meters': 900,
        'data_complete': true,
      },
      'geometry': [
        [42.3149, -83.0364],
        [42.3192, -83.0391],
      ],
    };

JourneyLeg _legWithMode(String mode) => JourneyLeg.fromJson({
      'id': 'leg',
      'mode': mode,
      'from': {'name': 'A'},
      'to': {'name': 'B'},
      'duration_seconds': 1,
      'distance_meters': 1,
      'steps': <dynamic>[],
    });

void main() {
  group('NavigationStep.fromJson', () {
    test('parses instruction and distance', () {
      final step = NavigationStep.fromJson({
        'instruction': 'Turn left',
        'distance_meters': 50,
      });

      check(step.instruction).equals('Turn left');
      check(step.distanceMeters).equals(50.0);
    });
  });

  group('JourneyLeg.fromJson', () {
    test('parses from/to names, steps and transit info', () {
      final leg = JourneyLeg.fromJson({
        'id': 'leg_001',
        'mode': 'bus',
        'from': {'name': 'Stop A'},
        'to': {'name': 'Stop B'},
        'duration_seconds': 600,
        'distance_meters': 2000,
        'steps': [
          {'instruction': 'Board the bus', 'distance_meters': 0},
        ],
        'transit_info': {'route': '1A'},
      });

      check(leg.fromName).equals('Stop A');
      check(leg.toName).equals('Stop B');
      check(leg.steps).length.equals(1);
      check(leg.transitInfo?['route']).equals('1A');
    });

    test('defaults steps to empty list and transit info to null', () {
      final leg = JourneyLeg.fromJson({
        'id': 'leg_002',
        'mode': 'walk',
        'from': {'name': 'A'},
        'to': {'name': 'B'},
        'duration_seconds': 1,
        'distance_meters': 1,
      });

      check(leg.steps).isEmpty();
      check(leg.transitInfo).isNull();
    });

    test('modeLabel maps known modes and falls back to the raw value', () {
      check(_legWithMode('walk').modeLabel).equals('Walk');
      check(_legWithMode('bus').modeLabel).equals('Bus');
      check(_legWithMode('taxi').modeLabel).equals('Taxi');
      check(_legWithMode('ferry').modeLabel).equals('ferry');
    });
  });

  group('AccessibilitySummary', () {
    test('fromJson parses all fields', () {
      final summary = AccessibilitySummary.fromJson({
        'score': 78,
        'street_crossings': 2,
        'transfer_count': 1,
        'known_entrances': 1,
        'audible_signals': 1,
        'construction_alerts': 0,
        'walking_distance_meters': 900,
        'data_complete': true,
      });

      check(summary.score).equals(78);
      check(summary.walkingDistanceMeters).equals(900.0);
      check(summary.dataComplete).isTrue();
    });

    test('ttsDescription mentions audible signals, construction and '
        'incomplete data', () {
      const summary = AccessibilitySummary(
        score: 60,
        streetCrossings: 3,
        transferCount: 1,
        knownEntrances: 1,
        audibleSignals: 1,
        constructionAlerts: 1,
        walkingDistanceMeters: 1500,
        dataComplete: false,
      );

      final tts = summary.ttsDescription;
      check(tts).contains('Accessibility score: 60 out of 100');
      check(tts).contains('1 with audible signals');
      check(tts).contains('1.5 kilometres');
      check(tts).contains('1 transfer.');
      check(tts).contains('construction may be present');
      check(tts).contains('Some accessibility information may be incomplete');
    });

    test('ttsDescription omits optional notes when not applicable', () {
      const summary = AccessibilitySummary(
        score: 85,
        streetCrossings: 0,
        transferCount: 0,
        knownEntrances: 1,
        audibleSignals: 0,
        constructionAlerts: 0,
        walkingDistanceMeters: 500,
        dataComplete: true,
      );

      final tts = summary.ttsDescription;
      check(tts).contains('0 transfers.');
      check(tts).not((s) => s.contains('audible signals'));
      check(tts).not((s) => s.contains('construction'));
      check(tts).not((s) => s.contains('incomplete'));
    });
  });

  group('RoutePlan.fromJson', () {
    test('parses nested legs, functional points, risk points and geometry',
        () {
      final route = RoutePlan.fromJson(_sampleRouteJson());

      check(route.id).equals('route_001');
      check(route.legs).length.equals(1);
      check(route.functionalPoints).length.equals(1);
      check(route.functionalPoints.first.importance)
          .equals(FunctionalPointImportance.navigation);
      check(route.riskPoints).length.equals(1);
      check(route.riskPoints.first.severity).equals(RiskSeverity.medium);
      check(route.accessibilitySummary.score).equals(78);
      check(route.geometry).deepEquals([
        [42.3149, -83.0364],
        [42.3192, -83.0391],
      ]);
    });

    test('defaults geometry to an empty list when absent', () {
      final json = _sampleRouteJson()..remove('geometry');
      final route = RoutePlan.fromJson(json);
      check(route.geometry).isEmpty();
    });

    test('modeLabel and durationLabel', () {
      final route = RoutePlan.fromJson(_sampleRouteJson());
      check(route.modeLabel).equals('Walking');
      check(route.durationLabel).equals('20 min');
    });

    test('allSteps flattens steps across all legs', () {
      final route = RoutePlan.fromJson(_sampleRouteJson());
      check(route.allSteps).length.equals(1);
      check(route.allSteps.first.instruction)
          .equals('Head north on Ouellette Avenue');
    });

    test('overviewTts mentions risk points when present', () {
      final route = RoutePlan.fromJson(_sampleRouteJson());
      check(route.overviewTts).contains('1 risk point on this route');
    });

    test('overviewTts omits the risk point caution when there are none', () {
      final json = _sampleRouteJson()..['risk_points'] = <dynamic>[];
      final route = RoutePlan.fromJson(json);
      check(route.overviewTts).not((s) => s.contains('risk point'));
    });
  });
}
