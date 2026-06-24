import 'package:accessibility_nav_assistant/screens/disclaimer_screen.dart';
import 'package:accessibility_nav_assistant/screens/settings_screen.dart';
import 'package:accessibility_nav_assistant/services/vibration_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration_platform_interface/vibration_platform_interface.dart';

/// `setEnabled(false)` calls `VibrationService.stop()`, which calls the
/// real `vibration` plugin's `cancel()` — a platform-channel call that
/// hangs forever under `flutter_test` unless `VibrationPlatform.instance`
/// is faked, the same hazard documented for `GeolocatorPlatform`.
class _FakeVibrationPlatform extends VibrationPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel() async {}

  @override
  Future<bool> hasVibrator() async => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VibrationPlatform.instance = _FakeVibrationPlatform();
  });

  group('SettingsScreen', () {
    testWidgets('reflects the persisted vibration setting on load', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'vibration_enabled': false});

      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchWidget.value, isFalse);
    });

    testWidgets('toggling the switch persists the new vibration setting', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(await VibrationService.instance.isEnabled(), isFalse);
    });

    testWidgets(
      '"About / Safety Notice" pushes a read-only DisclaimerScreen whose '
      'button closes without writing the acceptance preference',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('About / Safety Notice'));
        await tester.pumpAndSettle();

        expect(find.byType(DisclaimerScreen), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(DisclaimerScreen), findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('disclaimer_accepted'), isNull);
      },
    );
  });
}
