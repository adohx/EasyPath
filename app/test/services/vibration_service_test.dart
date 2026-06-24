import 'package:accessibility_nav_assistant/services/vibration_service.dart';
import 'package:checks/checks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('VibrationService.isEnabled', () {
    test('defaults to true when no preference has been set', () async {
      SharedPreferences.setMockInitialValues({});

      final enabled = await VibrationService.instance.isEnabled();

      check(enabled).isTrue();
    });

    test('persists false after setEnabled(false)', () async {
      SharedPreferences.setMockInitialValues({});

      await VibrationService.instance.setEnabled(false);
      final enabled = await VibrationService.instance.isEnabled();

      check(enabled).isFalse();
    });

    test('persists true after setEnabled(true) following a disable', () async {
      SharedPreferences.setMockInitialValues({});

      await VibrationService.instance.setEnabled(false);
      await VibrationService.instance.setEnabled(true);
      final enabled = await VibrationService.instance.isEnabled();

      check(enabled).isTrue();
    });
  });
}
