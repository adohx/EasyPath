import 'package:accessibility_nav_assistant/models/tracked_place_category.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  group('kBuiltInTrackedPlaceCategories', () {
    test('contains the uncategorized fallback', () {
      check(
        kBuiltInTrackedPlaceCategories.map((c) => c.id),
      ).contains(kUncategorizedCategoryId);
    });

    test('has no duplicate ids', () {
      final ids = kBuiltInTrackedPlaceCategories.map((c) => c.id).toList();
      check(ids.toSet().length).equals(ids.length);
    });

    test('built-in categories are not marked as user-defined', () {
      for (final category in kBuiltInTrackedPlaceCategories) {
        check(category.isUserDefined).isFalse();
      }
    });
  });

  group('TrackedPlaceCategory', () {
    test('round-trips through toJson/fromJson', () {
      const category = TrackedPlaceCategory(
        id: 'custom_1',
        label: 'My Custom Category',
        isUserDefined: true,
      );

      final restored = TrackedPlaceCategory.fromJson(category.toJson());

      check(restored.id).equals(category.id);
      check(restored.label).equals(category.label);
      check(restored.isUserDefined).isTrue();
    });
  });
}
