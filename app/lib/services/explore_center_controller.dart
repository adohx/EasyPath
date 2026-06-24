import 'package:flutter/foundation.dart';
import '../models/place.dart';

/// Lets any screen request that the Explore tab show a specific place,
/// without threading state through the whole widget tree. The Explore
/// tab (`ExplorationScreen`) listens for this; the tab shell
/// (`MainTabScreen`) also listens, so it can switch to the Explore tab
/// when a recentre is requested from elsewhere (e.g. a place detail
/// page's "Explore Nearby" button).
class ExploreCenterController extends ChangeNotifier {
  ExploreCenterController._();
  static final ExploreCenterController instance = ExploreCenterController._();

  Place? _pendingCenter;
  Place? get pendingCenter => _pendingCenter;

  void requestRecenter(Place place) {
    _pendingCenter = place;
    notifyListeners();
  }

  /// Call after a listener has applied [pendingCenter], so the same
  /// request isn't re-applied to a freshly mounted Explore tab later.
  void consumePendingCenter() {
    _pendingCenter = null;
  }
}
