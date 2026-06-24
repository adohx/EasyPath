import 'dart:convert';

import 'package:accessibility_nav_assistant/services/api_service.dart';
import 'package:accessibility_nav_assistant/services/navigation/exploration_session.dart';
import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Response _json(Object body, [int statusCode = 200]) =>
    http.Response(jsonEncode(body), statusCode);

Map<String, dynamic> _categoryResponse(List<Map<String, dynamic>> items) => {
  'center': {'lat': 0, 'lon': 0},
  'radius_meters': 300,
  'categories': {'restaurant': items},
};

Map<String, dynamic> _item(String id, {double lat = 0, double lon = 0}) => {
  'id': id,
  'name': 'Item $id',
  'distance_meters': 9999, // deliberately wrong/stale; must be ignored
  'bearing_degrees': 270, // deliberately wrong/stale; must be ignored
  'coordinates': {'lat': lat, 'lon': lon},
};

void main() {
  group('ExplorationSession.initialize', () {
    test(
      'makes no HTTP calls and stays empty for an empty route geometry',
      () async {
        var callCount = 0;
        final client = MockClient((request) async {
          callCount++;
          return _json(_categoryResponse([]));
        });
        final session = ExplorationSession(
          apiService: ApiService.withClient(client),
        );

        await session.initialize([]);

        check(session.items).isEmpty();
        check(callCount).equals(0);
      },
    );

    test('de-duplicates items returned by overlapping samples', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        // Every sample returns the same two items — one of which
        // ('shared') appears in every response.
        return _json(
          _categoryResponse([_item('shared'), _item('unique_$callCount')]),
        );
      });
      final session = ExplorationSession(
        apiService: ApiService.withClient(client),
        sampleIntervalMeters: 100,
        maxSamples: 4,
      );
      // A route long enough to produce multiple samples at 100m spacing.
      final geometry = [
        [0.0, 0.0],
        [0.0, 0.01],
      ];

      await session.initialize(geometry);

      final ids = session.items.map((p) => p.id).toSet();
      check(ids.where((id) => id == 'shared').length).equals(1);
      check(callCount).isGreaterThan(1);
    });

    test('discards the server-provided distance/bearing and keeps the '
        "item's own static coordinates", () async {
      final client = MockClient((request) async {
        return _json(_categoryResponse([_item('a', lat: 1.5, lon: 2.5)]));
      });
      final session = ExplorationSession(
        apiService: ApiService.withClient(client),
      );

      await session.initialize([
        [0.0, 0.0],
        [0.0, 0.001],
      ]);

      check(session.items).length.equals(1);
      check(session.items.first.lat).equals(1.5);
      check(session.items.first.lon).equals(2.5);
    });

    test('never samples more than maxSamples points', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return _json(_categoryResponse([]));
      });
      final session = ExplorationSession(
        apiService: ApiService.withClient(client),
        sampleIntervalMeters: 10,
        maxSamples: 3,
      );
      // A long route, sampled every ~10m, would otherwise yield many
      // more than 3 samples.
      final geometry = [
        [0.0, 0.0],
        [0.0, 0.05],
      ];

      await session.initialize(geometry);

      check(callCount).isLessOrEqual(3);
    });

    test('continues past a failed sample without throwing', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response('boom', 500);
        }
        return _json(_categoryResponse([_item('ok')]));
      });
      final session = ExplorationSession(
        apiService: ApiService.withClient(client),
        sampleIntervalMeters: 100,
        maxSamples: 4,
      );
      final geometry = [
        [0.0, 0.0],
        [0.0, 0.01],
      ];

      await session.initialize(geometry);

      check(session.items.map((p) => p.id)).contains('ok');
    });
  });
}
