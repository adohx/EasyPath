import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/exploration_item.dart';

class ApiService {
  ApiService._() : _client = http.Client();

  @visibleForTesting
  ApiService.withClient(this._client);

  static final ApiService instance = ApiService._();

  final http.Client _client;

  /// Tries the own backend, then Nominatim directly. Returns an empty
  /// list if both fail rather than fabricating results.
  Future<List<Place>> searchPlaces(String query) async {
    try {
      final uri = Uri.parse(
        '$kBackendBase/api/places/search'
        '?q=${Uri.encodeComponent(query)}',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>;
        if (results.isNotEmpty) {
          return results
              .map((r) => Place.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Backend place search failed',
        name: 'app.api',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
    }

    try {
      // Windsor context appended so generic terms like "library" find
      // Windsor results first.
      final searchQuery = _withWindsorContext(query);
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': searchQuery,
        'format': 'jsonv2',
        'countrycodes': 'ca',
        'limit': '10',
        'viewbox': '-83.3,42.6,-82.7,42.1',
        // '0' is a soft viewbox preference, not a hard filter.
        'bounded': '0',
        'addressdetails': '1',
      });
      final response = await _client
          .get(
            uri,
            headers: {'User-Agent': 'AccessibilityNavigationAssistant/2.0'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return data.map((item) {
            final entry = item as Map<String, dynamic>;
            final display = entry['display_name'] as String? ?? '';
            final name = (entry['name'] as String?)?.isNotEmpty == true
                ? entry['name'] as String
                : display.split(',').first.trim();
            return Place(
              id: 'nominatim_${entry['place_id']}',
              name: name,
              address: display,
              lat: double.parse(entry['lat'] as String),
              lon: double.parse(entry['lon'] as String),
              type: entry['type'] as String? ?? 'place',
            );
          }).toList();
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Nominatim place search failed',
        name: 'app.api',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
    }

    return [];
  }

  Future<List<RoutePlan>> planRoutes({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String originName = 'Current Location',
    String destinationName = 'Destination',
  }) async {
    try {
      final uri = Uri.parse('$kBackendBase/api/routes/plan');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'origin': {'lat': originLat, 'lon': originLon},
              'destination': {'lat': destLat, 'lon': destLon},
              'origin_name': originName,
              'destination_name': destinationName,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>;
        return routes
            .map((route) => RoutePlan.fromJson(route as Map<String, dynamic>))
            .toList();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Route planning failed',
        name: 'app.api',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
    }
    return [];
  }

  Future<List<ExplorationCategory>> nearbyExploration({
    required double lat,
    required double lon,
    int radiusMeters = 300,
  }) async {
    try {
      final uri = Uri.parse(
        '$kBackendBase/api/exploration/nearby'
        '?lat=$lat&lon=$lon&radius_meters=$radiusMeters',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawCategories = data['categories'] as Map<String, dynamic>;
        return _parseCategories(rawCategories);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Nearby exploration failed',
        name: 'app.api',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
    }
    return [];
  }

  List<ExplorationCategory> _parseCategories(
    Map<String, dynamic> rawCategories,
  ) {
    final result = <ExplorationCategory>[];
    for (final entry in rawCategories.entries) {
      final items = (entry.value as List<dynamic>)
          .map((item) => ExplorationItem.fromJson(item as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) {
        result.add(ExplorationCategory(key: entry.key, items: items));
      }
    }
    return result;
  }

  String _withWindsorContext(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('windsor') || lower.contains('ontario')) {
      return query;
    }
    return '$query Windsor Ontario';
  }
}
