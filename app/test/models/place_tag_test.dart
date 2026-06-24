import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/services/navigation/proximity_alert_engine.dart';
import 'package:accessibility_nav_assistant/services/vibration_service.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('PlaceTagInfo', () {
    test('remindIfConvenient maps to the exploration tier', () {
      check(
        PlaceTag.remindIfConvenient.alertCategory,
      ).equals(AlertCategory.explorationPoint);
      check(
        PlaceTag.remindIfConvenient.vibrationPattern,
      ).equals(VibrationPattern.shortPulse);
      check(
        PlaceTag.remindIfConvenient.defaultTriggerDistanceMeters,
      ).equals(50);
    });

    test('mustRemindNearby maps to the required-functional tier', () {
      check(
        PlaceTag.mustRemindNearby.alertCategory,
      ).equals(AlertCategory.requiredFunctionalPoint);
      check(
        PlaceTag.mustRemindNearby.vibrationPattern,
      ).equals(VibrationPattern.shortPulse);
      check(PlaceTag.mustRemindNearby.defaultTriggerDistanceMeters).equals(80);
    });

    test('urgentAlert maps to the risk-point tier', () {
      check(PlaceTag.urgentAlert.alertCategory).equals(AlertCategory.riskPoint);
      check(
        PlaceTag.urgentAlert.vibrationPattern,
      ).equals(VibrationPattern.longPulse);
      check(PlaceTag.urgentAlert.defaultTriggerDistanceMeters).equals(100);
    });

    test('every tag has a distinct, non-empty label', () {
      final labels = PlaceTag.values.map((t) => t.label).toSet();
      check(labels.length).equals(PlaceTag.values.length);
      for (final label in labels) {
        check(label.isNotEmpty).isTrue();
      }
    });
  });
}
