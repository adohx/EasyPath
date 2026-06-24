import 'package:accessibility_nav_assistant/screens/disclaimer_screen.dart';
import 'package:accessibility_nav_assistant/screens/main_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accepting lands on `MainTabScreen`, whose `IndexedStack` mounts every
/// tab (including `HomeScreen`/`ExplorationScreen`) up front, both of
/// which call `LocationService.instance.getCurrentPlace()` on mount —
/// that hangs forever under `flutter_test` unless faked, same as the
/// other screen tests in this suite.
class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 42.3150,
    longitude: -83.0360,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// MainTabScreen's other tabs make their own (unrelated, unmocked) real
/// network calls, so pumpAndSettle() would never terminate once it's on
/// screen — a bounded pump is used instead, as established elsewhere.
Future<void> _pumpBriefly(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
  });

  group('DisclaimerScreen', () {
    testWidgets(
      'default (reviewOnly: false) accepts, persists, and replaces with '
      'MainTabScreen',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: DisclaimerScreen()));
        await tester.pumpAndSettle();

        expect(find.text('I Understand — Continue'), findsOneWidget);

        await tester.tap(find.text('I Understand — Continue'));
        await _pumpBriefly(tester);

        expect(find.byType(MainTabScreen), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('disclaimer_accepted'), isTrue);
      },
    );

    testWidgets(
      'reviewOnly: true shows a Close button that pops without writing '
      'the acceptance preference',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const DisclaimerScreen(reviewOnly: true),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Close'), findsOneWidget);
        expect(find.text('I Understand — Continue'), findsNothing);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(DisclaimerScreen), findsNothing);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('disclaimer_accepted'), isNull);
      },
    );
  });
}
