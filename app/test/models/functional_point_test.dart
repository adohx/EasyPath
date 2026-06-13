import 'package:accessibility_nav_assistant/models/functional_point.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('FunctionalPoint.fromJson', () {
    test('parses required importance and coordinates', () {
      final point = FunctionalPoint.fromJson({
        'id': 'fp_001',
        'type': 'bus_board',
        'description': 'Board Route 1A bus at Ouellette Ave / Wyandotte St',
        'importance': 'required',
        'trigger_distance_meters': 80,
        'coordinates': {'lat': 42.3170, 'lon': -83.0370},
      });

      check(point.id).equals('fp_001');
      check(point.importance).equals(FunctionalPointImportance.required);
      check(point.triggerDistanceMeters).equals(80.0);
      check(point.lat).equals(42.3170);
      check(point.lon).equals(-83.0370);
      check(point.importanceLabel).equals('Required');
    });

    test('parses navigation importance', () {
      final point = FunctionalPoint.fromJson({
        'id': 'fp_002',
        'type': 'building_entrance',
        'description': 'Windsor Public Library — main entrance',
        'importance': 'navigation',
        'trigger_distance_meters': 40,
        'coordinates': {'lat': 42.3192, 'lon': -83.0391},
      });

      check(point.importance).equals(FunctionalPointImportance.navigation);
      check(point.importanceLabel).equals('Navigation');
    });
  });
}
