import 'package:accessibility_nav_assistant/models/place.dart';
import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/screens/place_detail_screen.dart';
import 'package:accessibility_nav_assistant/screens/route_selection_screen.dart';
import 'package:accessibility_nav_assistant/screens/track_place_screen.dart';
import 'package:accessibility_nav_assistant/services/explore_center_controller.dart';
import 'package:accessibility_nav_assistant/services/tracked_place_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _place = Place(
  id: 'place_1',
  name: 'Windsor Public Library',
  address: '850 Ouellette Avenue',
  lat: 42.3192,
  lon: -83.0391,
);

/// "Get Directions" calls `LocationService.instance.getCurrentPlace()`,
/// which hangs forever under `flutter_test` if `GeolocatorPlatform.instance`
/// is left unmocked (unlike a plain `package:test` unit test, the
/// default test binary messenger never auto-rejects the channel call) —
/// so it must be substituted, same as in `location_service_test.dart`.
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
    ExploreCenterController.instance.consumePendingCenter();
  });

  group('PlaceDetailScreen', () {
    testWidgets('shows the place name and address', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlaceDetailScreen(place: _place)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Windsor Public Library'), findsOneWidget);
      expect(find.text('850 Ouellette Avenue'), findsOneWidget);
    });

    testWidgets('offers "Track This Place" when nothing matches yet', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlaceDetailScreen(place: _place)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Track This Place'), findsOneWidget);
      expect(find.text('Edit Tracked Place'), findsNothing);
    });

    testWidgets('offers "Edit Tracked Place" when a nearby personal place '
        'already exists', (tester) async {
      await TrackedPlaceRepository.instance.add(
        name: 'Windsor Public Library',
        lat: _place.lat + 0.00005, // a few metres off — still a match
        lon: _place.lon,
        categoryId: 'uncategorized',
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );

      await tester.pumpWidget(
        const MaterialApp(home: PlaceDetailScreen(place: _place)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Tracked Place'), findsOneWidget);
      expect(find.text('Track This Place'), findsNothing);
    });

    testWidgets('tapping Track pushes TrackPlaceScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlaceDetailScreen(place: _place)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Track This Place'));
      await tester.pumpAndSettle();

      expect(find.byType(TrackPlaceScreen), findsOneWidget);
    });

    testWidgets('tapping Get Directions pushes RouteSelectionScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: PlaceDetailScreen(place: _place)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Directions'));
      // RouteSelectionScreen shows a perpetual spinner while its own
      // (unrelated) network call is pending, so pumpAndSettle() would
      // never terminate — pump a bounded number of times instead.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(RouteSelectionScreen), findsOneWidget);
    });

    testWidgets('tapping Explore Nearby requests a recentre and pops back '
        'to the first route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlaceDetailScreen(place: _place),
                    ),
                  ),
                  child: const Text('Open Place Detail'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Place Detail'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaceDetailScreen), findsOneWidget);

      await tester.tap(find.text('Explore Nearby'));
      await tester.pumpAndSettle();

      expect(find.byType(PlaceDetailScreen), findsNothing);
      expect(find.text('Open Place Detail'), findsOneWidget);
      expect(ExploreCenterController.instance.pendingCenter, _place);
    });
  });
}
