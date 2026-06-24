import '../services/navigation/proximity_alert_engine.dart';
import '../services/vibration_service.dart';

/// The three user-facing importance levels for a personal tracked place
/// (design doc §2.2.4 / §1.1.3). The label is what the user sees and
/// chooses; the mapping to [AlertCategory], [VibrationPattern], and
/// trigger distance is internal and not user-configurable.
enum PlaceTag { remindIfConvenient, mustRemindNearby, urgentAlert }

extension PlaceTagInfo on PlaceTag {
  String get label => switch (this) {
    PlaceTag.remindIfConvenient => 'Mention if convenient',
    PlaceTag.mustRemindNearby => 'Remind me when nearby',
    PlaceTag.urgentAlert => 'Urgent alert when close',
  };

  /// Which proximity-alert tier this tag joins. Personal places use the
  /// same four-tier system as official risk/functional/exploration
  /// points — see `ProximityAlertEngine`.
  AlertCategory get alertCategory => switch (this) {
    PlaceTag.remindIfConvenient => AlertCategory.explorationPoint,
    PlaceTag.mustRemindNearby => AlertCategory.requiredFunctionalPoint,
    PlaceTag.urgentAlert => AlertCategory.riskPoint,
  };

  VibrationPattern get vibrationPattern => switch (this) {
    PlaceTag.remindIfConvenient => VibrationPattern.shortPulse,
    PlaceTag.mustRemindNearby => VibrationPattern.shortPulse,
    PlaceTag.urgentAlert => VibrationPattern.longPulse,
  };

  double get defaultTriggerDistanceMeters => switch (this) {
    PlaceTag.remindIfConvenient => 50,
    PlaceTag.mustRemindNearby => 80,
    PlaceTag.urgentAlert => 100,
  };
}
