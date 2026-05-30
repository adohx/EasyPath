const Map<String, String> kCategoryLabels = {
  'restaurant': 'Restaurants & Cafes',
  'pharmacy': 'Pharmacies',
  'bus_stop': 'Bus Stops',
  'hotel': 'Hotels',
  'parking': 'Parking',
  'supermarket': 'Supermarkets',
  'hospital': 'Hospitals',
  'atm': 'ATMs',
};

class ExplorationItem {
  final String id;
  final String name;
  final double distanceMeters;
  final double bearingDegrees;
  final double lat;
  final double lon;

  const ExplorationItem({
    required this.id,
    required this.name,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.lat,
    required this.lon,
  });

  factory ExplorationItem.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>;
    return ExplorationItem(
      id: json['id'] as String,
      name: json['name'] as String,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      bearingDegrees: (json['bearing_degrees'] as num).toDouble(),
      lat: (coords['lat'] as num).toDouble(),
      lon: (coords['lon'] as num).toDouble(),
    );
  }

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} metres';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} kilometres';
  }

  String get bearingLabel {
    const dirs = ['north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest'];
    final index = ((bearingDegrees + 22.5) / 45).floor() % 8;
    return dirs[index];
  }

  String get ttsText =>
      '$name, approximately $distanceLabel to the $bearingLabel';
}

class ExplorationCategory {
  final String key;
  final List<ExplorationItem> items;

  const ExplorationCategory({required this.key, required this.items});

  String get label => kCategoryLabels[key] ?? key;
}
