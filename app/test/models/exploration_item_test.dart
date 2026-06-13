import 'package:accessibility_nav_assistant/models/exploration_item.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('ExplorationItem.fromJson', () {
    test('parses fields including nested coordinates', () {
      final item = ExplorationItem.fromJson({
        'id': 'osm_1',
        'name': "Joe's Cafe",
        'distance_meters': 50,
        'bearing_degrees': 45,
        'coordinates': {'lat': 42.3155, 'lon': -83.0357},
      });

      check(item.id).equals('osm_1');
      check(item.name).equals("Joe's Cafe");
      check(item.distanceMeters).equals(50.0);
      check(item.bearingDegrees).equals(45.0);
      check(item.lat).equals(42.3155);
      check(item.lon).equals(-83.0357);
    });
  });

  group('distanceLabel', () {
    test('formats sub-kilometre distances in metres', () {
      final item = _itemWithDistance(120);
      check(item.distanceLabel).equals('120 metres');
    });

    test('formats distances of 1km or more in kilometres', () {
      final item = _itemWithDistance(1500);
      check(item.distanceLabel).equals('1.5 kilometres');
    });
  });

  group('bearingLabel', () {
    test('maps bearing degrees to the eight compass directions', () {
      check(_itemWithBearing(0).bearingLabel).equals('north');
      check(_itemWithBearing(45).bearingLabel).equals('northeast');
      check(_itemWithBearing(90).bearingLabel).equals('east');
      check(_itemWithBearing(135).bearingLabel).equals('southeast');
      check(_itemWithBearing(180).bearingLabel).equals('south');
      check(_itemWithBearing(225).bearingLabel).equals('southwest');
      check(_itemWithBearing(270).bearingLabel).equals('west');
      check(_itemWithBearing(315).bearingLabel).equals('northwest');
      check(_itemWithBearing(360).bearingLabel).equals('north');
    });
  });

  test('ttsText combines name, distance and bearing', () {
    final item = ExplorationItem(
      id: 'osm_1',
      name: 'Shoppers Drug Mart',
      distanceMeters: 120,
      bearingDegrees: 270,
      lat: 42.3150,
      lon: -83.0400,
    );

    check(item.ttsText)
        .equals('Shoppers Drug Mart, approximately 120 metres to the west');
  });

  group('ExplorationCategory.label', () {
    test('uses the known label for recognised category keys', () {
      const category = ExplorationCategory(key: 'pharmacy', items: []);
      check(category.label).equals('Pharmacies');
    });

    test('falls back to the raw key for unknown categories', () {
      const category = ExplorationCategory(key: 'unknown_category', items: []);
      check(category.label).equals('unknown_category');
    });
  });
}

ExplorationItem _itemWithDistance(double distanceMeters) => ExplorationItem(
      id: 'osm_1',
      name: 'Item',
      distanceMeters: distanceMeters,
      bearingDegrees: 0,
      lat: 42.3150,
      lon: -83.0360,
    );

ExplorationItem _itemWithBearing(double bearingDegrees) => ExplorationItem(
      id: 'osm_1',
      name: 'Item',
      distanceMeters: 10,
      bearingDegrees: bearingDegrees,
      lat: 42.3150,
      lon: -83.0360,
    );
