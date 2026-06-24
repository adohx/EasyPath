import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/models/tracked_place_category.dart';
import 'package:accessibility_nav_assistant/services/tracked_place_repository.dart';
import 'package:checks/checks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('TrackedPlaceRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getAll returns an empty list when nothing has been added', () async {
      final all = await TrackedPlaceRepository.instance.getAll();

      check(all).isEmpty();
    });

    test('add persists a place and assigns it a unique id', () async {
      final repo = TrackedPlaceRepository.instance;

      final place = await repo.add(
        name: 'Water puddle',
        lat: 42.31,
        lon: -83.03,
        categoryId: 'hazard_detour',
        tag: PlaceTag.urgentAlert,
        addedVia: 'button_capture',
      );
      final all = await repo.getAll();

      check(place.id.isNotEmpty).isTrue();
      check(all).length.equals(1);
      check(all.first.name).equals('Water puddle');
      check(all.first.tag).equals(PlaceTag.urgentAlert);
    });

    test('getActive excludes paused places', () async {
      final repo = TrackedPlaceRepository.instance;
      final active = await repo.add(
        name: 'Active place',
        lat: 0,
        lon: 0,
        categoryId: kUncategorizedCategoryId,
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );
      final paused = await repo.add(
        name: 'Paused place',
        lat: 0,
        lon: 0,
        categoryId: kUncategorizedCategoryId,
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );
      await repo.setPaused(paused.id, true);

      final activePlaces = await repo.getActive();

      check(activePlaces.map((p) => p.id)).deepEquals([active.id]);
    });

    test('setPaused(false) re-activates a paused place', () async {
      final repo = TrackedPlaceRepository.instance;
      final place = await repo.add(
        name: 'Place',
        lat: 0,
        lon: 0,
        categoryId: kUncategorizedCategoryId,
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );
      await repo.setPaused(place.id, true);
      await repo.setPaused(place.id, false);

      final activePlaces = await repo.getActive();

      check(activePlaces.map((p) => p.id)).contains(place.id);
    });

    test('update overwrites the stored fields for a place', () async {
      final repo = TrackedPlaceRepository.instance;
      final place = await repo.add(
        name: 'Original name',
        lat: 0,
        lon: 0,
        categoryId: kUncategorizedCategoryId,
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );

      await repo.update(place.copyWith(name: 'Updated name'));
      final all = await repo.getAll();

      check(all.single.name).equals('Updated name');
    });

    test('delete removes a place permanently', () async {
      final repo = TrackedPlaceRepository.instance;
      final place = await repo.add(
        name: 'Place to delete',
        lat: 0,
        lon: 0,
        categoryId: kUncategorizedCategoryId,
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );

      await repo.delete(place.id);
      final all = await repo.getAll();

      check(all).isEmpty();
    });

    test('getCategories returns the built-ins when none are custom', () async {
      final categories = await TrackedPlaceRepository.instance.getCategories();

      check(categories.length).equals(kBuiltInTrackedPlaceCategories.length);
    });

    test(
      'addCategory persists a custom category alongside the built-ins',
      () async {
        final repo = TrackedPlaceRepository.instance;

        final category = await repo.addCategory('Favourite Walks');
        final categories = await repo.getCategories();

        check(category.isUserDefined).isTrue();
        check(
          categories.length,
        ).equals(kBuiltInTrackedPlaceCategories.length + 1);
        check(categories.map((c) => c.label)).contains('Favourite Walks');
      },
    );
  });
}
