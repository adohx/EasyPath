import 'package:accessibility_nav_assistant/models/place.dart';
import 'package:accessibility_nav_assistant/screens/main_tab_screen.dart';
import 'package:accessibility_nav_assistant/services/explore_center_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HomeScreen and ExplorationScreen (when centred on GPS) both call
/// `LocationService.instance.getCurrentPlace()` on mount, which hangs
/// forever under `flutter_test` unless `GeolocatorPlatform.instance` is
/// faked — same reasoning as the other screen tests in this suite.
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

/// MainTabScreen's tabs are built with no injected fakes, so their own
/// (unrelated) real network calls may stay pending — pumpAndSettle()
/// would never terminate, as established elsewhere in this suite. A
/// bounded pump is used instead wherever real settling isn't required.
Future<void> _pumpBriefly(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
    ExploreCenterController.instance.consumePendingCenter();
  });

  group('MainTabScreen', () {
    testWidgets('renders all four destinations', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainTabScreen()));
      await _pumpBriefly(tester);

      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(
        find.descendant(of: navBar, matching: find.text('Search')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Explore')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('My Places')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navBar, matching: find.text('Settings')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a destination switches the selected index', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MainTabScreen()));
      await _pumpBriefly(tester);

      final navBar = find.byType(NavigationBar);
      expect(tester.widget<NavigationBar>(navBar).selectedIndex, 0);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Settings')),
      );
      await _pumpBriefly(tester);

      expect(tester.widget<NavigationBar>(navBar).selectedIndex, 3);
    });

    testWidgets(
      'ExploreCenterController notifications switch the selected index '
      'to Explore',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: MainTabScreen()));
        await _pumpBriefly(tester);

        final navBar = find.byType(NavigationBar);
        expect(tester.widget<NavigationBar>(navBar).selectedIndex, 0);

        ExploreCenterController.instance.requestRecenter(
          const Place(
            id: 'p1',
            name: 'Windsor Public Library',
            address: '850 Ouellette Avenue',
            lat: 42.3192,
            lon: -83.0391,
          ),
        );
        await _pumpBriefly(tester);

        expect(tester.widget<NavigationBar>(navBar).selectedIndex, 1);
      },
    );
  });
}
