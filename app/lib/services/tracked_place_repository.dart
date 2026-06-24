import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/place_tag.dart';
import '../models/tracked_place.dart';
import '../models/tracked_place_category.dart';

/// Local persistence for the user's personal place library (design doc
/// §1.1.3, §2.3). Everything lives on-device via `shared_preferences` —
/// there is no account system, and the dataset is small enough that a
/// JSON blob per key is appropriate; revisit with a real local database
/// only if this grows large.
class TrackedPlaceRepository {
  TrackedPlaceRepository._();
  static final TrackedPlaceRepository instance = TrackedPlaceRepository._();

  static const _placesKey = 'tracked_places';
  static const _customCategoriesKey = 'tracked_place_custom_categories';

  final _random = Random();

  Future<List<TrackedPlace>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_placesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => TrackedPlace.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Places that are not paused — what `NavigationController` should
  /// consider for proximity alerts.
  Future<List<TrackedPlace>> getActive() async {
    final all = await getAll();
    return all.where((place) => !place.isPaused).toList();
  }

  Future<TrackedPlace> add({
    required String name,
    required double lat,
    required double lon,
    required String categoryId,
    required PlaceTag tag,
    required String addedVia,
  }) async {
    final place = TrackedPlace(
      id: _generateId('tp'),
      name: name,
      lat: lat,
      lon: lon,
      categoryId: categoryId,
      tag: tag,
      addedVia: addedVia,
      createdAt: DateTime.now(),
    );
    final all = await getAll();
    await _saveAll([...all, place]);
    return place;
  }

  Future<void> update(TrackedPlace place) async {
    final all = await getAll();
    final updated = [
      for (final existing in all) existing.id == place.id ? place : existing,
    ];
    await _saveAll(updated);
  }

  Future<void> delete(String id) async {
    final all = await getAll();
    await _saveAll(all.where((place) => place.id != id).toList());
  }

  Future<void> setPaused(String id, bool paused) async {
    final all = await getAll();
    final updated = [
      for (final place in all)
        place.id == id ? place.copyWith(isPaused: paused) : place,
    ];
    await _saveAll(updated);
  }

  Future<void> _saveAll(List<TrackedPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _placesKey,
      jsonEncode(places.map((p) => p.toJson()).toList()),
    );
  }

  /// Built-in categories plus any the user has defined, in that order.
  Future<List<TrackedPlaceCategory>> getCategories() async {
    final custom = await _getCustomCategories();
    return [...kBuiltInTrackedPlaceCategories, ...custom];
  }

  Future<TrackedPlaceCategory> addCategory(String label) async {
    final category = TrackedPlaceCategory(
      id: _generateId('cat'),
      label: label,
      isUserDefined: true,
    );
    final custom = await _getCustomCategories();
    await _saveCustomCategories([...custom, category]);
    return category;
  }

  Future<List<TrackedPlaceCategory>> _getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customCategoriesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => TrackedPlaceCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveCustomCategories(
    List<TrackedPlaceCategory> categories,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customCategoriesKey,
      jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
  }

  String _generateId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
}
