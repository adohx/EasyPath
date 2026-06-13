import 'package:accessibility_nav_assistant/models/risk_point.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

Map<String, dynamic> _riskJson(String severity) => {
      'id': 'rp_001',
      'type': 'intersection',
      'description': 'Ouellette Ave at Wyandotte St',
      'severity': severity,
      'trigger_distance_meters': 100,
      'coordinates': {'lat': 42.3170, 'lon': -83.0370},
    };

void main() {
  group('RiskPoint.fromJson', () {
    test('parses coordinates and trigger distance', () {
      final point = RiskPoint.fromJson(_riskJson('medium'));

      check(point.id).equals('rp_001');
      check(point.triggerDistanceMeters).equals(100.0);
      check(point.lat).equals(42.3170);
      check(point.lon).equals(-83.0370);
    });

    test('maps severity strings to RiskSeverity and labels', () {
      check(RiskPoint.fromJson(_riskJson('high')).severity)
          .equals(RiskSeverity.high);
      check(RiskPoint.fromJson(_riskJson('medium')).severity)
          .equals(RiskSeverity.medium);
      check(RiskPoint.fromJson(_riskJson('low')).severity)
          .equals(RiskSeverity.low);

      check(RiskPoint.fromJson(_riskJson('high')).severityLabel)
          .equals('High Risk');
      check(RiskPoint.fromJson(_riskJson('medium')).severityLabel)
          .equals('Medium Risk');
      check(RiskPoint.fromJson(_riskJson('low')).severityLabel)
          .equals('Low Risk');
    });

    test('treats unrecognised severity strings as low', () {
      check(RiskPoint.fromJson(_riskJson('unknown')).severity)
          .equals(RiskSeverity.low);
    });
  });
}
