enum FunctionalPointImportance { required, navigation }

class FunctionalPoint {
  final String id;
  final String type;
  final String description;
  final FunctionalPointImportance importance;
  final double triggerDistanceMeters;
  final double lat;
  final double lon;

  const FunctionalPoint({
    required this.id,
    required this.type,
    required this.description,
    required this.importance,
    required this.triggerDistanceMeters,
    required this.lat,
    required this.lon,
  });

  factory FunctionalPoint.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>;
    return FunctionalPoint(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      importance: (json['importance'] as String) == 'required'
          ? FunctionalPointImportance.required
          : FunctionalPointImportance.navigation,
      triggerDistanceMeters:
          (json['trigger_distance_meters'] as num).toDouble(),
      lat: (coords['lat'] as num).toDouble(),
      lon: (coords['lon'] as num).toDouble(),
    );
  }

  String get importanceLabel =>
      importance == FunctionalPointImportance.required ? 'Required' : 'Navigation';
}
