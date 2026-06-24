import 'dart:convert';

import 'package:accessibility_nav_assistant/models/place.dart';
import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/screens/exploration_screen.dart';
import 'package:accessibility_nav_assistant/services/api_service.dart';
import 'package:accessibility_nav_assistant/services/explore_center_controller.dart';
import 'package:accessibility_nav_assistant/services/tracked_place_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _centerPlace = Place(
  id: 'origin',
  name: 'Windsor Public Library',
  address: '850 Ouellette Avenue',
  lat: 0,
  lon: 0,
);

/// Same reasoning as `place_detail_screen_test.dart`: any code path that
/// reaches `LocationService.instance.getCurrentPlace()` hangs forever
/// under `flutter_test` unless `GeolocatorPlatform.instance` is faked.
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

http.Response _nearbyResponse({double lat = 0, double lon = 0}) =>
    http.Response(
      jsonEncode({
        'center': {'lat': lat, 'lon': lon},
        'radius_meters': 300,
        'categories': {
          'restaurant': [
            {
              'id': 'official_1',
              'name': 'Official Cafe',
              'distance_meters': 80,
              'bearing_degrees': 10,
              'coordinates': {'lat': lat + 0.0007, 'lon': lon},
            },
          ],
        },
      }),
      200,
    );

http.Response _searchResponse(List<Place> places) => http.Response(
  jsonEncode({
    'results': places
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'address': p.address,
            'coordinates': {'lat': p.lat, 'lon': p.lon},
            'type': p.type,
          },
        )
        .toList(),
  }),
  200,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
    ExploreCenterController.instance.consumePendingCenter();
  });

  group('ExplorationScreen personal-place merge', () {
    testWidgets(
      'merges an active personal place into its matching official category',
      (tester) async {
        await TrackedPlaceRepository.instance.add(
          name: 'My Favourite Cafe',
          // ~0.00045 deg lat from the centre (~50m), well inside the
          // restaurant category's typical results.
          lat: 0.00045,
          lon: 0,
          categoryId: 'restaurant',
          tag: PlaceTag.remindIfConvenient,
          addedVia: 'search',
        );
        final apiService = ApiService.withClient(
          MockClient((_) async => _nearbyResponse()),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExplorationScreen(
              centerPlace: _centerPlace,
              apiService: apiService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Official Cafe'), findsOneWidget);
        expect(find.text('My Favourite Cafe'), findsOneWidget);
        expect(find.byIcon(Icons.bookmark), findsOneWidget);
      },
    );

    testWidgets('creates a new category group for a personal place with no '
        'official equivalent', (tester) async {
      await TrackedPlaceRepository.instance.add(
        name: 'My Desk',
        lat: 0.0001,
        lon: 0,
        categoryId: 'work_life',
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );
      final apiService = ApiService.withClient(
        MockClient((_) async => _nearbyResponse()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExplorationScreen(
            centerPlace: _centerPlace,
            apiService: apiService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work & Life (1)'), findsOneWidget);
    });

    testWidgets(
      'does not merge a personal place that is far from the centre point',
      (tester) async {
        await TrackedPlaceRepository.instance.add(
          name: 'My Distant Cafe',
          // ~1.1km away — well outside the default 300m explore radius.
          lat: _centerPlace.lat + 0.01,
          lon: _centerPlace.lon,
          categoryId: 'restaurant',
          tag: PlaceTag.remindIfConvenient,
          addedVia: 'search',
        );
        final apiService = ApiService.withClient(
          MockClient((_) async => _nearbyResponse()),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExplorationScreen(
              centerPlace: _centerPlace,
              apiService: apiService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Official Cafe'), findsOneWidget);
        expect(find.text('My Distant Cafe'), findsNothing);
      },
    );
  });

  group('ExplorationScreen centre resolution', () {
    testWidgets('resolves the centre from GPS when no centerPlace is given', (
      tester,
    ) async {
      final apiService = ApiService.withClient(
        MockClient((_) async => _nearbyResponse()),
      );

      await tester.pumpWidget(
        MaterialApp(home: ExplorationScreen(apiService: apiService)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Exploring around: Current Location'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the change-location sheet lets the user pick a search result as '
      'the new centre',
      (tester) async {
        const newCenter = Place(
          id: 'p2',
          name: 'Devonshire Mall',
          address: '3100 Howard Avenue',
          lat: 5,
          lon: 5,
        );
        final apiService = ApiService.withClient(
          MockClient((request) async {
            if (request.url.path.contains('/api/places/search')) {
              return _searchResponse([newCenter]);
            }
            return _nearbyResponse();
          }),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExplorationScreen(
              centerPlace: _centerPlace,
              apiService: apiService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Exploring around: Windsor Public Library'),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.edit_location_alt));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Devonshire Mall');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        final resultTile = find.widgetWithText(Card, 'Devonshire Mall');
        expect(resultTile, findsOneWidget);
        await tester.tap(resultTile);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Exploring around: Devonshire Mall'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ExploreCenterController recentres an already-mounted Explore screen',
      (tester) async {
        const newCenter = Place(
          id: 'p3',
          name: 'Caboto Club',
          address: '2175 Parent Avenue',
          lat: 9,
          lon: 9,
        );
        final apiService = ApiService.withClient(
          MockClient((_) async => _nearbyResponse()),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ExplorationScreen(
              centerPlace: _centerPlace,
              apiService: apiService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Exploring around: Windsor Public Library'),
          findsOneWidget,
        );

        ExploreCenterController.instance.requestRecenter(newCenter);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Exploring around: Caboto Club'),
          findsOneWidget,
        );
        expect(ExploreCenterController.instance.pendingCenter, isNull);
      },
    );
  });
}
