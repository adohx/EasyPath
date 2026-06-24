import 'dart:convert';

import 'package:accessibility_nav_assistant/config.dart';
import 'package:accessibility_nav_assistant/services/api_service.dart';
import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

final _backendHost = Uri.parse(kBackendBase).host;

const _nominatimHost = 'nominatim.openstreetmap.org';

Map<String, dynamic> _sampleRouteJson() => {
  'id': 'route_001',
  'mode': 'walk',
  'total_duration_seconds': 600,
  'total_walking_distance_meters': 450,
  'transfer_count': 0,
  'legs': [
    {
      'id': 'leg_001',
      'mode': 'walk',
      'from': {'name': 'Current Location'},
      'to': {'name': 'Destination'},
      'duration_seconds': 600,
      'distance_meters': 450,
      'steps': [
        {'instruction': 'Head north', 'distance_meters': 450},
      ],
    },
  ],
  'functional_points': <dynamic>[],
  'risk_points': <dynamic>[],
  'accessibility_summary': {
    'score': 85,
    'street_crossings': 0,
    'transfer_count': 0,
    'known_entrances': 1,
    'audible_signals': 0,
    'construction_alerts': 0,
    'walking_distance_meters': 450,
    'data_complete': true,
  },
};

http.Response _json(Object body, [int statusCode = 200]) =>
    http.Response(jsonEncode(body), statusCode);

void main() {
  group('searchPlaces', () {
    test('returns places from the backend when results are present', () async {
      final client = MockClient((request) async {
        check(request.url.host).equals(_backendHost);
        return _json({
          'query': 'library',
          'results': [
            {
              'id': 'nominatim_1',
              'name': 'Windsor Public Library',
              'address': '850 Ouellette Avenue, Windsor, ON',
              'coordinates': {'lat': 42.3192, 'lon': -83.0391},
              'type': 'library',
            },
          ],
        });
      });

      final places = await ApiService.withClient(
        client,
      ).searchPlaces('library');

      check(places).length.equals(1);
      check(places.first.id).equals('nominatim_1');
      check(places.first.name).equals('Windsor Public Library');
    });

    test(
      'falls back to Nominatim when the backend returns no results',
      () async {
        final client = MockClient((request) async {
          if (request.url.host == _backendHost) {
            return _json({'query': 'library', 'results': <dynamic>[]});
          }
          if (request.url.host == _nominatimHost) {
            return _json([
              {
                'place_id': 999,
                'display_name': 'Windsor Public Library, Windsor, ON',
                'lat': '42.3192',
                'lon': '-83.0391',
                'type': 'library',
                'name': 'Windsor Public Library',
              },
            ]);
          }
          return http.Response('not found', 404);
        });

        final places = await ApiService.withClient(
          client,
        ).searchPlaces('library');

        check(places).length.equals(1);
        check(places.first.id).equals('nominatim_999');
        check(places.first.name).equals('Windsor Public Library');
      },
    );

    test(
      'returns an empty list when the backend and Nominatim both fail',
      () async {
        final client = MockClient(
          (request) async => http.Response('boom', 500),
        );

        final places = await ApiService.withClient(
          client,
        ).searchPlaces('library');

        check(places).isEmpty();
      },
    );
  });

  group('planRoutes', () {
    test('returns routes parsed from the backend response', () async {
      final client = MockClient((request) async {
        check(request.method).equals('POST');
        check(request.url.host).equals(_backendHost);
        return _json({
          'routes': [_sampleRouteJson()],
        });
      });

      final routes = await ApiService.withClient(client).planRoutes(
        originLat: 42.3149,
        originLon: -83.0364,
        destLat: 42.3192,
        destLon: -83.0391,
      );

      check(routes).length.equals(1);
      check(routes.first.id).equals('route_001');
      check(routes.first.accessibilitySummary.score).equals(85);
    });

    test('returns an empty list when the backend fails', () async {
      final client = MockClient((request) async => http.Response('boom', 500));

      final routes = await ApiService.withClient(client).planRoutes(
        originLat: 42.3149,
        originLon: -83.0364,
        destLat: 42.3192,
        destLon: -83.0391,
      );

      check(routes).isEmpty();
    });
  });

  group('nearbyExploration', () {
    test('returns categories parsed from the backend response', () async {
      final client = MockClient((request) async {
        check(request.url.host).equals(_backendHost);
        return _json({
          'center': {'lat': 42.3150, 'lon': -83.0360},
          'radius_meters': 300,
          'categories': {
            'restaurant': [
              {
                'id': 'osm_1',
                'name': "Joe's Cafe",
                'distance_meters': 50,
                'bearing_degrees': 45,
                'coordinates': {'lat': 42.3155, 'lon': -83.0357},
              },
            ],
          },
        });
      });

      final categories = await ApiService.withClient(
        client,
      ).nearbyExploration(lat: 42.3150, lon: -83.0360);

      check(categories).length.equals(1);
      check(categories.first.key).equals('restaurant');
      check(categories.first.items.first.name).equals("Joe's Cafe");
    });

    test('returns an empty list when the backend fails', () async {
      final client = MockClient((request) async => http.Response('boom', 500));

      final categories = await ApiService.withClient(
        client,
      ).nearbyExploration(lat: 42.3150, lon: -83.0360);

      check(categories).isEmpty();
    });
  });
}
