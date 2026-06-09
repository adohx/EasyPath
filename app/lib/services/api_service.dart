import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/functional_point.dart';
import '../models/risk_point.dart';
import '../models/exploration_item.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Tries the own backend, then Nominatim directly, then a local mock.
  Future<List<Place>> searchPlaces(String query) async {
    try {
      final uri = Uri.parse(
        '$kBackendBase/api/places/search'
        '?q=${Uri.encodeComponent(query)}',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
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
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'AccessibilityNavigationAssistant/2.0'},
      ).timeout(const Duration(seconds: 8));
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

    return _mockPlaces(query);
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
      final response = await http
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
            .map((route) =>
                RoutePlan.fromJson(route as Map<String, dynamic>))
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
    return _mockRoutes();
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
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawCategories =
            data['categories'] as Map<String, dynamic>;
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
    return _mockExploration(lat, lon);
  }

  List<ExplorationCategory> _parseCategories(
    Map<String, dynamic> rawCategories,
  ) {
    final result = <ExplorationCategory>[];
    for (final entry in rawCategories.entries) {
      final items = (entry.value as List<dynamic>)
          .map(
            (item) =>
                ExplorationItem.fromJson(item as Map<String, dynamic>),
          )
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

  List<Place> _mockPlaces(String query) => [
        Place(
          id: 'mock_001',
          name: 'Windsor Public Library',
          address: '850 Ouellette Avenue, Windsor, ON',
          lat: 42.3192,
          lon: -83.0391,
          type: 'library',
        ),
        Place(
          id: 'mock_002',
          name: 'Windsor Regional Hospital',
          address: '1995 Lens Avenue, Windsor, ON',
          lat: 42.2800,
          lon: -83.0050,
          type: 'hospital',
        ),
      ];

  List<RoutePlan> _mockRoutes() => [
        RoutePlan(
          id: 'route_001',
          mode: 'transit',
          totalDurationSeconds: 1680,
          totalWalkingDistanceMeters: 450,
          transferCount: 0,
          legs: [
            JourneyLeg(
              id: 'leg_001',
              mode: 'walk',
              fromName: 'Current Location',
              toName: 'Ouellette Ave Bus Stop',
              durationSeconds: 180,
              distanceMeters: 250,
              steps: [
                const NavigationStep(
                  instruction: 'Head north on Ouellette Avenue for '
                      'approximately 250 metres',
                  distanceMeters: 250,
                ),
              ],
            ),
            JourneyLeg(
              id: 'leg_002',
              mode: 'bus',
              fromName: 'Ouellette Ave at Wyandotte St',
              toName: 'Ouellette Ave at Elliott St',
              durationSeconds: 1200,
              distanceMeters: 2100,
              steps: [
                const NavigationStep(
                  instruction: 'Board Route 1A bus towards Downtown at '
                      'Ouellette Ave / Wyandotte St',
                  distanceMeters: 0,
                ),
                const NavigationStep(
                  instruction: 'Ride approximately 2.1 kilometres to '
                      'Ouellette Ave / Elliott St',
                  distanceMeters: 2100,
                ),
                const NavigationStep(
                  instruction: 'Alight here — this is your stop at '
                      'Ouellette Ave / Elliott St',
                  distanceMeters: 0,
                ),
              ],
              transitInfo: {'route': '1A', 'headsign': 'Downtown'},
            ),
            JourneyLeg(
              id: 'leg_003',
              mode: 'walk',
              fromName: 'Ouellette Ave at Elliott St',
              toName: 'Windsor Public Library — Main Entrance',
              durationSeconds: 300,
              distanceMeters: 200,
              steps: [
                const NavigationStep(
                  instruction: 'Walk north on Ouellette Avenue for '
                      'approximately 120 metres',
                  distanceMeters: 120,
                ),
                const NavigationStep(
                  instruction: 'Turn left — the library entrance appears '
                      'to be on your left',
                  distanceMeters: 80,
                ),
              ],
            ),
          ],
          functionalPoints: [
            FunctionalPoint(
              id: 'fp_001',
              type: 'bus_board',
              description: 'Board Route 1A bus at '
                  'Ouellette Ave / Wyandotte St',
              importance: FunctionalPointImportance.required,
              triggerDistanceMeters: 80,
              lat: 42.3170,
              lon: -83.0370,
            ),
            FunctionalPoint(
              id: 'fp_002',
              type: 'bus_alight',
              description: 'Alight at Ouellette Ave / Elliott St',
              importance: FunctionalPointImportance.required,
              triggerDistanceMeters: 80,
              lat: 42.3190,
              lon: -83.0385,
            ),
            FunctionalPoint(
              id: 'fp_003',
              type: 'building_entrance',
              description: 'Windsor Public Library — main entrance',
              importance: FunctionalPointImportance.navigation,
              triggerDistanceMeters: 40,
              lat: 42.3192,
              lon: -83.0391,
            ),
          ],
          riskPoints: [
            RiskPoint(
              id: 'rp_001',
              type: 'intersection',
              description: 'Ouellette Ave at Wyandotte St — busy '
                  'intersection, audible pedestrian signal may be present',
              severity: RiskSeverity.medium,
              triggerDistanceMeters: 100,
              lat: 42.3170,
              lon: -83.0370,
            ),
          ],
          accessibilitySummary: const AccessibilitySummary(
            score: 78,
            streetCrossings: 2,
            transferCount: 0,
            knownEntrances: 1,
            audibleSignals: 1,
            constructionAlerts: 0,
            walkingDistanceMeters: 450,
            dataComplete: true,
          ),
        ),
        RoutePlan(
          id: 'route_002',
          mode: 'walk',
          totalDurationSeconds: 2400,
          totalWalkingDistanceMeters: 1800,
          transferCount: 0,
          legs: [
            JourneyLeg(
              id: 'leg_101',
              mode: 'walk',
              fromName: 'Current Location',
              toName: 'Windsor Public Library — Main Entrance',
              durationSeconds: 2400,
              distanceMeters: 1800,
              steps: [
                const NavigationStep(
                  instruction: 'Head north on Ouellette Avenue for '
                      'approximately 300 metres',
                  distanceMeters: 300,
                ),
                const NavigationStep(
                  instruction: 'Continue north through the Wyandotte '
                      'Street intersection',
                  distanceMeters: 500,
                ),
                const NavigationStep(
                  instruction: 'Continue north on Ouellette Avenue for '
                      'approximately 1 kilometre',
                  distanceMeters: 1000,
                ),
                const NavigationStep(
                  instruction:
                      'The library entrance appears to be on your left',
                  distanceMeters: 0,
                ),
              ],
            ),
          ],
          functionalPoints: [
            FunctionalPoint(
              id: 'fp_101',
              type: 'building_entrance',
              description: 'Windsor Public Library — main entrance',
              importance: FunctionalPointImportance.navigation,
              triggerDistanceMeters: 40,
              lat: 42.3192,
              lon: -83.0391,
            ),
          ],
          riskPoints: [
            RiskPoint(
              id: 'rp_101',
              type: 'intersection',
              description: 'Ouellette Ave at Wyandotte St intersection',
              severity: RiskSeverity.medium,
              triggerDistanceMeters: 100,
              lat: 42.3170,
              lon: -83.0370,
            ),
            RiskPoint(
              id: 'rp_102',
              type: 'intersection',
              description:
                  'Ouellette Ave at University Ave intersection',
              severity: RiskSeverity.low,
              triggerDistanceMeters: 80,
              lat: 42.3180,
              lon: -83.0380,
            ),
          ],
          accessibilitySummary: const AccessibilitySummary(
            score: 65,
            streetCrossings: 4,
            transferCount: 0,
            knownEntrances: 1,
            audibleSignals: 1,
            constructionAlerts: 0,
            walkingDistanceMeters: 1800,
            dataComplete: true,
          ),
        ),
      ];

  List<ExplorationCategory> _mockExploration(double lat, double lon) => [
        ExplorationCategory(
          key: 'restaurant',
          items: [
            ExplorationItem(
              id: 'exp_001',
              name: 'Cafe Ambrosia',
              distanceMeters: 50,
              bearingDegrees: 45,
              lat: lat + 0.0003,
              lon: lon + 0.0003,
            ),
            ExplorationItem(
              id: 'exp_002',
              name: 'The Artichoke',
              distanceMeters: 80,
              bearingDegrees: 180,
              lat: lat - 0.0005,
              lon: lon,
            ),
          ],
        ),
        ExplorationCategory(
          key: 'pharmacy',
          items: [
            ExplorationItem(
              id: 'exp_003',
              name: 'Shoppers Drug Mart',
              distanceMeters: 120,
              bearingDegrees: 270,
              lat: lat,
              lon: lon - 0.001,
            ),
          ],
        ),
        ExplorationCategory(
          key: 'bus_stop',
          items: [
            ExplorationItem(
              id: 'exp_004',
              name: 'Ouellette Ave at Elliott St',
              distanceMeters: 60,
              bearingDegrees: 0,
              lat: lat + 0.0004,
              lon: lon,
            ),
          ],
        ),
        ExplorationCategory(
          key: 'hotel',
          items: [
            ExplorationItem(
              id: 'exp_005',
              name: 'Holiday Inn Windsor',
              distanceMeters: 200,
              bearingDegrees: 90,
              lat: lat,
              lon: lon + 0.002,
            ),
          ],
        ),
      ];
}
