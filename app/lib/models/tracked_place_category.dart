/// A category a personal place can be filed under. Built-in categories
/// reuse the same id keys as the official exploration categories in
/// `exploration_item.dart` where they overlap (e.g. 'restaurant'), so
/// personal and official places merge into the same group when browsing.
class TrackedPlaceCategory {
  final String id;
  final String label;
  final bool isUserDefined;

  const TrackedPlaceCategory({
    required this.id,
    required this.label,
    this.isUserDefined = false,
  });

  factory TrackedPlaceCategory.fromJson(Map<String, dynamic> json) {
    return TrackedPlaceCategory(
      id: json['id'] as String,
      label: json['label'] as String,
      isUserDefined: json['is_user_defined'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'is_user_defined': isUserDefined,
  };
}

const kUncategorizedCategoryId = 'uncategorized';

/// Categories available before the user defines any of their own.
const List<TrackedPlaceCategory> kBuiltInTrackedPlaceCategories = [
  TrackedPlaceCategory(id: kUncategorizedCategoryId, label: 'Uncategorized'),
  TrackedPlaceCategory(id: 'work_life', label: 'Work & Life'),
  TrackedPlaceCategory(id: 'known_contacts', label: 'Known Contacts'),
  TrackedPlaceCategory(id: 'hazard_detour', label: 'Hazard Detour'),
  TrackedPlaceCategory(id: 'restaurant', label: 'Restaurants & Cafes'),
  TrackedPlaceCategory(id: 'pharmacy', label: 'Pharmacies'),
  TrackedPlaceCategory(id: 'bus_stop', label: 'Bus Stops'),
  TrackedPlaceCategory(id: 'hotel', label: 'Hotels'),
  TrackedPlaceCategory(id: 'supermarket', label: 'Supermarkets'),
];
