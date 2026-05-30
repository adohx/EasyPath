enum RiskSeverity { low, medium, high }

class RiskPoint {
  final String id;
  final String type;
  final String description;
  final RiskSeverity severity;
  final double triggerDistanceMeters;
  final double lat;
  final double lon;

  const RiskPoint({
    required this.id,
    required this.type,
    required this.description,
    required this.severity,
    required this.triggerDistanceMeters,
    required this.lat,
    required this.lon,
  });

  factory RiskPoint.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>;
    final sev = json['severity'] as String;
    return RiskPoint(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      severity: sev == 'high'
          ? RiskSeverity.high
          : sev == 'medium'
              ? RiskSeverity.medium
              : RiskSeverity.low,
      triggerDistanceMeters:
          (json['trigger_distance_meters'] as num).toDouble(),
      lat: (coords['lat'] as num).toDouble(),
      lon: (coords['lon'] as num).toDouble(),
    );
  }

  String get severityLabel {
    switch (severity) {
      case RiskSeverity.high:
        return 'High Risk';
      case RiskSeverity.medium:
        return 'Medium Risk';
      case RiskSeverity.low:
        return 'Low Risk';
    }
  }
}
