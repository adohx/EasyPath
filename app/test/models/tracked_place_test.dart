import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/models/tracked_place.dart';
import 'package:accessibility_nav_assistant/models/tracked_place_category.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

TrackedPlace _samplePlace() => TrackedPlace(
  id: 'tp_1',
  name: 'Water puddle',
  lat: 42.3150,
  lon: -83.0360,
  categoryId: 'hazard_detour',
  tag: PlaceTag.urgentAlert,
  addedVia: 'button_capture',
  createdAt: DateTime.utc(2026, 6, 22, 10, 30),
);

void main() {
  group('TrackedPlace', () {
    test('round-trips through toJson/fromJson', () {
      final place = _samplePlace();

      final restored = TrackedPlace.fromJson(place.toJson());

      check(restored.id).equals(place.id);
      check(restored.name).equals(place.name);
      check(restored.lat).equals(place.lat);
      check(restored.lon).equals(place.lon);
      check(restored.categoryId).equals(place.categoryId);
      check(restored.tag).equals(place.tag);
      check(restored.isPaused).equals(place.isPaused);
      check(restored.addedVia).equals(place.addedVia);
      check(restored.createdAt).equals(place.createdAt);
    });

    test('fromJson defaults isPaused to false when absent', () {
      final json = _samplePlace().toJson()..remove('is_paused');

      final restored = TrackedPlace.fromJson(json);

      check(restored.isPaused).isFalse();
    });

    test('fromJson defaults categoryId to uncategorized when absent', () {
      final json = _samplePlace().toJson()..remove('category_id');

      final restored = TrackedPlace.fromJson(json);

      check(restored.categoryId).equals(kUncategorizedCategoryId);
    });

    test('copyWith overrides only the given fields', () {
      final place = _samplePlace();

      final updated = place.copyWith(
        name: 'Slippery puddle',
        tag: PlaceTag.mustRemindNearby,
      );

      check(updated.id).equals(place.id);
      check(updated.lat).equals(place.lat);
      check(updated.lon).equals(place.lon);
      check(updated.name).equals('Slippery puddle');
      check(updated.tag).equals(PlaceTag.mustRemindNearby);
      check(updated.categoryId).equals(place.categoryId);
    });

    test('copyWith can toggle isPaused', () {
      final place = _samplePlace();

      final paused = place.copyWith(isPaused: true);

      check(paused.isPaused).isTrue();
      check(place.isPaused).isFalse();
    });
  });
}
