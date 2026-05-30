class Place {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lon;
  final String type;

  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    this.type = 'place',
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>;
    return Place(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      lat: (coords['lat'] as num).toDouble(),
      lon: (coords['lon'] as num).toDouble(),
      type: json['type'] as String? ?? 'place',
    );
  }
}
