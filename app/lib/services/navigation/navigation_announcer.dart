import '../vibration_service.dart';

/// Abstracts the TTS + vibration side effects of a navigation alert so
/// [NavigationController] can be unit-tested without platform channels.
abstract class NavigationAnnouncer {
  /// Speaks [text] via TTS, interrupting any in-progress speech.
  Future<void> speak(String text);

  /// Plays the given vibration pattern (if vibration is enabled).
  Future<void> vibrate(VibrationPattern pattern);

  /// Stops any ongoing continuous vibration.
  Future<void> stopVibration();
}
