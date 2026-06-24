import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/screens/personal_places_screen.dart';
import 'package:accessibility_nav_assistant/services/tracked_place_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PersonalPlacesScreen', () {
    testWidgets('shows an empty state when no places are tracked', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PersonalPlacesScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text("You haven't tracked any personal places yet."),
        findsOneWidget,
      );
    });

    testWidgets('lists tracked places with their category and tag', (
      tester,
    ) async {
      await TrackedPlaceRepository.instance.add(
        name: 'Water puddle',
        lat: 0,
        lon: 0,
        categoryId: 'hazard_detour',
        tag: PlaceTag.urgentAlert,
        addedVia: 'button_capture',
      );

      await tester.pumpWidget(const MaterialApp(home: PersonalPlacesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Water puddle'), findsOneWidget);
      expect(find.textContaining(PlaceTag.urgentAlert.label), findsOneWidget);
    });

    testWidgets('pausing a place updates its status without deleting it', (
      tester,
    ) async {
      final place = await TrackedPlaceRepository.instance.add(
        name: 'Construction zone',
        lat: 0,
        lon: 0,
        categoryId: 'uncategorized',
        tag: PlaceTag.mustRemindNearby,
        addedVia: 'search',
      );

      await tester.pumpWidget(const MaterialApp(home: PersonalPlacesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Pause alerts'));
      await tester.pumpAndSettle();

      final all = await TrackedPlaceRepository.instance.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, place.id);
      expect(all.first.isPaused, isTrue);
      expect(find.textContaining('Paused'), findsOneWidget);
    });

    testWidgets('deleting a place requires confirmation and then removes it', (
      tester,
    ) async {
      await TrackedPlaceRepository.instance.add(
        name: 'Old cafe',
        lat: 0,
        lon: 0,
        categoryId: 'restaurant',
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );

      await tester.pumpWidget(const MaterialApp(home: PersonalPlacesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete personal place?'), findsOneWidget);

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      final all = await TrackedPlaceRepository.instance.getAll();
      expect(all, isEmpty);
    });

    testWidgets('filtering by importance level narrows the list', (
      tester,
    ) async {
      await TrackedPlaceRepository.instance.add(
        name: 'Urgent place',
        lat: 0,
        lon: 0,
        categoryId: 'uncategorized',
        tag: PlaceTag.urgentAlert,
        addedVia: 'search',
      );
      await TrackedPlaceRepository.instance.add(
        name: 'Casual place',
        lat: 0,
        lon: 0,
        categoryId: 'uncategorized',
        tag: PlaceTag.remindIfConvenient,
        addedVia: 'search',
      );

      await tester.pumpWidget(const MaterialApp(home: PersonalPlacesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Urgent place'), findsOneWidget);
      expect(find.text('Casual place'), findsOneWidget);

      // The chip row is a horizontally-scrolling list, so only the first
      // few chips are built into the tree until scrolled into view.
      await tester.ensureVisible(find.text(PlaceTag.remindIfConvenient.label));
      await tester.tap(find.text(PlaceTag.remindIfConvenient.label));
      await tester.pumpAndSettle();

      expect(find.text('Casual place'), findsOneWidget);
      expect(find.text('Urgent place'), findsNothing);
    });
  });
}
