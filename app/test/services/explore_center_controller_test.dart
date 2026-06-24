import 'package:accessibility_nav_assistant/models/place.dart';
import 'package:accessibility_nav_assistant/services/explore_center_controller.dart';
import 'package:checks/checks.dart';
import 'package:test/test.dart';

const _place = Place(
  id: 'p1',
  name: 'Windsor Public Library',
  address: '850 Ouellette Avenue',
  lat: 42.3192,
  lon: -83.0391,
);

void main() {
  group('ExploreCenterController', () {
    test('requestRecenter sets pendingCenter and notifies listeners', () {
      final controller = ExploreCenterController.instance;
      controller.consumePendingCenter();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.requestRecenter(_place);

      check(controller.pendingCenter).equals(_place);
      check(notified).isTrue();
    });

    test('consumePendingCenter clears the pending value', () {
      final controller = ExploreCenterController.instance;
      controller.requestRecenter(_place);

      controller.consumePendingCenter();

      check(controller.pendingCenter).isNull();
    });
  });
}
