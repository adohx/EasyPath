import 'package:accessibility_nav_assistant/services/navigation/proximity_alert_engine.dart';
import 'package:accessibility_nav_assistant/services/vibration_service.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

const _riskPoint = TrackedPoint(
  id: 'risk_1',
  category: AlertCategory.riskPoint,
  description: 'Busy intersection ahead',
  triggerDistanceMeters: 100,
  lat: 0,
  lon: 0,
  vibrationPattern: VibrationPattern.longPulse,
);

const _requiredFunctionalPoint = TrackedPoint(
  id: 'required_1',
  category: AlertCategory.requiredFunctionalPoint,
  description: 'Board the bus here',
  triggerDistanceMeters: 80,
  lat: 0,
  lon: 0,
  vibrationPattern: VibrationPattern.shortThenLong,
);

const _navigationFunctionalPoint = TrackedPoint(
  id: 'navigation_1',
  category: AlertCategory.navigationFunctionalPoint,
  description: 'Turn left here',
  triggerDistanceMeters: 50,
  lat: 0,
  lon: 0,
  vibrationPattern: VibrationPattern.shortPulse,
);

const _explorationPoint = TrackedPoint(
  id: 'exploration_1',
  category: AlertCategory.explorationPoint,
  description: 'Cafe Ambrosia nearby',
  triggerDistanceMeters: 50,
  lat: 0,
  lon: 0,
  vibrationPattern: VibrationPattern.shortPulse,
);

void main() {
  group('ProximityAlertEngine', () {
    test('orders simultaneous alerts by priority: risk first, then '
        'required-functional, then navigation-functional, then '
        'exploration', () {
      final engine = ProximityAlertEngine([
        _explorationPoint,
        _navigationFunctionalPoint,
        _requiredFunctionalPoint,
        _riskPoint,
      ]);

      final alerts = engine.update(lat: 0, lon: 0);

      check(
        alerts.map((a) => a.point.id).toList(),
      ).deepEquals(['risk_1', 'required_1', 'navigation_1', 'exploration_1']);
    });

    test('respects each point\'s own trigger distance rather than a '
        'shared constant', () {
      // 0.0009 degrees of longitude at the equator is roughly 100 metres.
      const farPoint = TrackedPoint(
        id: 'far_required',
        category: AlertCategory.requiredFunctionalPoint,
        description: 'Far required point',
        triggerDistanceMeters: 200,
        lat: 0,
        lon: 0.0009,
        vibrationPattern: VibrationPattern.shortPulse,
      );
      const nearPointWithSmallTrigger = TrackedPoint(
        id: 'near_navigation',
        category: AlertCategory.navigationFunctionalPoint,
        description: 'Near navigation point, small trigger radius',
        triggerDistanceMeters: 50,
        lat: 0,
        lon: 0.0009,
        vibrationPattern: VibrationPattern.shortPulse,
      );
      final engine = ProximityAlertEngine([
        farPoint,
        nearPointWithSmallTrigger,
      ]);

      final alerts = engine.update(lat: 0, lon: 0);

      check(
        alerts.map((a) => a.point.id).toList(),
      ).deepEquals(['far_required']);
    });

    test('does not re-fire an already-announced point', () {
      final engine = ProximityAlertEngine([_riskPoint]);

      final first = engine.update(lat: 0, lon: 0);
      final second = engine.update(lat: 0, lon: 0);

      check(first.map((a) => a.point.id).toList()).deepEquals(['risk_1']);
      check(second).isEmpty();
    });

    test('a point with allowRepeat re-fires on every in-range call', () {
      const repeatingPoint = TrackedPoint(
        id: 'repeating',
        category: AlertCategory.explorationPoint,
        description: 'Repeating point',
        triggerDistanceMeters: 50,
        lat: 0,
        lon: 0,
        vibrationPattern: VibrationPattern.shortPulse,
        allowRepeat: true,
      );
      final engine = ProximityAlertEngine([repeatingPoint]);

      final first = engine.update(lat: 0, lon: 0);
      final second = engine.update(lat: 0, lon: 0);

      check(first.map((a) => a.point.id).toList()).deepEquals(['repeating']);
      check(second.map((a) => a.point.id).toList()).deepEquals(['repeating']);
    });

    test('a point outside its trigger distance does not fire', () {
      const farAway = TrackedPoint(
        id: 'far_away',
        category: AlertCategory.riskPoint,
        description: 'Far away risk point',
        triggerDistanceMeters: 50,
        lat: 1,
        lon: 1,
        vibrationPattern: VibrationPattern.longPulse,
      );
      final engine = ProximityAlertEngine([farAway]);

      final alerts = engine.update(lat: 0, lon: 0);

      check(alerts).isEmpty();
    });
  });
}
