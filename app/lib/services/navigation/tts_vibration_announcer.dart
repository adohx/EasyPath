import '../tts_service.dart';
import '../vibration_service.dart';
import 'navigation_announcer.dart';

/// Default [NavigationAnnouncer] backed by the app's real TTS and
/// vibration services.
class TtsVibrationAnnouncer implements NavigationAnnouncer {
  TtsVibrationAnnouncer({TtsService? tts, VibrationService? vibration})
    : _tts = tts ?? TtsService.instance,
      _vibration = vibration ?? VibrationService.instance;

  final TtsService _tts;
  final VibrationService _vibration;

  @override
  Future<void> speak(String text) => _tts.speakInterrupt(text);

  @override
  Future<void> vibrate(VibrationPattern pattern) => _vibration.play(pattern);

  @override
  Future<void> stopVibration() => _vibration.stop();
}
