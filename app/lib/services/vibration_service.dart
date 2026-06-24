import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// The four vibration semantics defined by the product design doc
/// (§3.2.1): a short pulse for ordinary navigation points, a long pulse
/// for risk points and off-route warnings, a short-then-long pulse for
/// transit board/alight points, and continuous short pulses for
/// conditions needing immediate attention.
enum VibrationPattern { shortPulse, longPulse, shortThenLong, continuousShort }

/// Plays the vibration patterns used during real-time navigation, with a
/// persisted user-facing on/off toggle (the design doc requires that
/// vibration can always be disabled). Intensity/rhythm adjustment is
/// intentionally out of scope for this iteration.
class VibrationService {
  VibrationService._();
  static final VibrationService instance = VibrationService._();

  static const _prefsKey = 'vibration_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    if (!enabled) {
      await stop();
    }
  }

  /// Plays [pattern] if vibration is enabled and the device has a
  /// vibrator. No-ops if vibration is disabled or unsupported.
  Future<void> play(VibrationPattern pattern) async {
    if (!await isEnabled()) return;
    try {
      if (!await Vibration.hasVibrator()) return;
      switch (pattern) {
        case VibrationPattern.shortPulse:
          await Vibration.vibrate(duration: 120);
        case VibrationPattern.longPulse:
          await Vibration.vibrate(duration: 500);
        case VibrationPattern.shortThenLong:
          await Vibration.vibrate(pattern: [0, 120, 150, 500]);
        case VibrationPattern.continuousShort:
          await Vibration.vibrate(
            pattern: [0, 120, 120, 120, 120, 120],
            repeat: 0,
          );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Vibration playback failed',
        name: 'app.vibration',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stops any ongoing vibration (used to end
  /// [VibrationPattern.continuousShort] once the condition clears).
  Future<void> stop() async {
    try {
      await Vibration.cancel();
    } catch (e, stackTrace) {
      developer.log(
        'Vibration cancel failed',
        name: 'app.vibration',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
