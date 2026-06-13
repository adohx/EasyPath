import 'package:accessibility_nav_assistant/models/place.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('Place.fromJson', () {
    test('parses all fields including nested coordinates', () {
      final place = Place.fromJson({
        'id': 'nominatim_123',
        'name': 'Windsor Public Library',
        'address': '850 Ouellette Avenue, Windsor, ON',
        'coordinates': {'lat': 42.3192, 'lon': -83.0391},
        'type': 'library',
      });

      check(place.id).equals('nominatim_123');
      check(place.name).equals('Windsor Public Library');
      check(place.address).equals('850 Ouellette Avenue, Windsor, ON');
      check(place.lat).equals(42.3192);
      check(place.lon).equals(-83.0391);
      check(place.type).equals('library');
    });

    test('defaults address to empty string and type to place when absent',
        () {
      final place = Place.fromJson({
        'id': 'osm_1',
        'name': 'Some Place',
        'coordinates': {'lat': 42.0, 'lon': -83.0},
      });

      check(place.address).equals('');
      check(place.type).equals('place');
    });

    test('accepts integer coordinates from JSON', () {
      final place = Place.fromJson({
        'id': 'osm_2',
        'name': 'Origin',
        'coordinates': {'lat': 42, 'lon': -83},
      });

      check(place.lat).equals(42.0);
      check(place.lon).equals(-83.0);
    });
  });
}
