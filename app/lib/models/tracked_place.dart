import 'place_tag.dart';
import 'tracked_place_category.dart';

/// A user-saved personal place (design doc §1.1.3 "个人地点 Tracked
/// Place"). Persisted entirely on-device — see
/// `TrackedPlaceRepository`.
class TrackedPlace {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String categoryId;
  final PlaceTag tag;
  final bool isPaused;

  /// How this place was added: 'search' (pre-trip dual-path) or
  /// 'button_capture' (in-trip quick capture).
  final String addedVia;
  final DateTime createdAt;

  const TrackedPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.categoryId,
    required this.tag,
    required this.addedVia,
    required this.createdAt,
    this.isPaused = false,
  });

  factory TrackedPlace.fromJson(Map<String, dynamic> json) {
    return TrackedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      categoryId: json['category_id'] as String? ?? kUncategorizedCategoryId,
      tag: PlaceTag.values.byName(json['tag'] as String),
      isPaused: json['is_paused'] as bool? ?? false,
      addedVia: json['added_via'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lon': lon,
    'category_id': categoryId,
    'tag': tag.name,
    'is_paused': isPaused,
    'added_via': addedVia,
    'created_at': createdAt.toIso8601String(),
  };

  TrackedPlace copyWith({
    String? name,
    String? categoryId,
    PlaceTag? tag,
    bool? isPaused,
  }) {
    return TrackedPlace(
      id: id,
      name: name ?? this.name,
      lat: lat,
      lon: lon,
      categoryId: categoryId ?? this.categoryId,
      tag: tag ?? this.tag,
      isPaused: isPaused ?? this.isPaused,
      addedVia: addedVia,
      createdAt: createdAt,
    );
  }
}
