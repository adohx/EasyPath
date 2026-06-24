import 'package:accessibility_nav_assistant/models/place_tag.dart';
import 'package:accessibility_nav_assistant/models/tracked_place.dart';
import 'package:accessibility_nav_assistant/screens/track_place_screen.dart';
import 'package:accessibility_nav_assistant/services/tracked_place_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<TrackedPlace?> _pumpAndPush(
  WidgetTester tester,
  TrackPlaceScreen screen,
) async {
  TrackedPlace? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await Navigator.of(
              context,
            ).push<TrackedPlace>(MaterialPageRoute(builder: (_) => screen));
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TrackPlaceScreen', () {
    testWidgets(
      'lets the user pick a category then a tag, and saves a new place',
      (tester) async {
        await _pumpAndPush(
          tester,
          const TrackPlaceScreen(
            name: 'Water puddle',
            lat: 42.31,
            lon: -83.03,
            addedVia: 'search',
          ),
        );

        expect(find.text('Uncategorized'), findsOneWidget);
        await tester.tap(find.text('Uncategorized'));
        await tester.pumpAndSettle();

        expect(find.text(PlaceTag.urgentAlert.label), findsOneWidget);
        await tester.tap(find.text(PlaceTag.urgentAlert.label));
        await tester.pumpAndSettle();

        final saved = await TrackedPlaceRepository.instance.getAll();
        expect(saved, hasLength(1));
        expect(saved.first.name, 'Water puddle');
        expect(saved.first.tag, PlaceTag.urgentAlert);
        expect(saved.first.categoryId, 'uncategorized');
      },
    );

    testWidgets('skipCategoryStep goes straight to the tag step', (
      tester,
    ) async {
      await _pumpAndPush(
        tester,
        const TrackPlaceScreen(
          name: 'Quick capture',
          lat: 0,
          lon: 0,
          addedVia: 'button_capture',
          skipCategoryStep: true,
        ),
      );

      expect(find.text('Choose a category'), findsNothing);
      expect(find.text(PlaceTag.mustRemindNearby.label), findsOneWidget);
    });

    testWidgets(
      'editing an existing place updates it instead of creating a new one',
      (tester) async {
        final existing = await TrackedPlaceRepository.instance.add(
          name: 'Old name',
          lat: 1,
          lon: 2,
          categoryId: 'uncategorized',
          tag: PlaceTag.remindIfConvenient,
          addedVia: 'search',
        );

        await _pumpAndPush(
          tester,
          TrackPlaceScreen(
            name: existing.name,
            lat: existing.lat,
            lon: existing.lon,
            addedVia: existing.addedVia,
            existingPlace: existing,
          ),
        );

        await tester.tap(find.text('Uncategorized'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(PlaceTag.urgentAlert.label));
        await tester.pumpAndSettle();

        final all = await TrackedPlaceRepository.instance.getAll();
        expect(all, hasLength(1));
        expect(all.first.id, existing.id);
        expect(all.first.tag, PlaceTag.urgentAlert);
      },
    );
  });
}
