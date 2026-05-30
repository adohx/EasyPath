import 'functional_point.dart';
import 'risk_point.dart';

class NavigationStep {
  final String instruction;
  final double distanceMeters;

  const NavigationStep({
    required this.instruction,
    required this.distanceMeters,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] as String,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
    );
  }
}

class JourneyLeg {
  final String id;
  final String mode;
  final String fromName;
  final String toName;
  final int durationSeconds;
  final double distanceMeters;
  final List<NavigationStep> steps;
  final Map<String, dynamic>? transitInfo;

  const JourneyLeg({
    required this.id,
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.steps,
    this.transitInfo,
  });

  factory JourneyLeg.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List<dynamic>? ?? [])
        .map((s) => NavigationStep.fromJson(s as Map<String, dynamic>))
        .toList();
    return JourneyLeg(
      id: json['id'] as String,
      mode: json['mode'] as String,
      fromName: (json['from'] as Map<String, dynamic>)['name'] as String,
      toName: (json['to'] as Map<String, dynamic>)['name'] as String,
      durationSeconds: json['duration_seconds'] as int,
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      steps: steps,
      transitInfo: json['transit_info'] as Map<String, dynamic>?,
    );
  }

  String get modeLabel {
    switch (mode) {
      case 'walk':
        return 'Walk';
      case 'bus':
        return 'Bus';
      case 'taxi':
        return 'Taxi';
      default:
        return mode;
    }
  }
}

class AccessibilitySummary {
  final int score;
  final int streetCrossings;
  final int transferCount;
  final int knownEntrances;
  final int audibleSignals;
  final int constructionAlerts;
  final double walkingDistanceMeters;
  final bool dataComplete;

  const AccessibilitySummary({
    required this.score,
    required this.streetCrossings,
    required this.transferCount,
    required this.knownEntrances,
    required this.audibleSignals,
    required this.constructionAlerts,
    required this.walkingDistanceMeters,
    required this.dataComplete,
  });

  factory AccessibilitySummary.fromJson(Map<String, dynamic> json) {
    return AccessibilitySummary(
      score: json['score'] as int,
      streetCrossings: json['street_crossings'] as int,
      transferCount: json['transfer_count'] as int,
      knownEntrances: json['known_entrances'] as int,
      audibleSignals: json['audible_signals'] as int,
      constructionAlerts: json['construction_alerts'] as int,
      walkingDistanceMeters:
          (json['walking_distance_meters'] as num).toDouble(),
      dataComplete: json['data_complete'] as bool,
    );
  }

  String get ttsDescription {
    final buf = StringBuffer();
    buf.write('Accessibility score: $score out of 100. ');
    buf.write('$streetCrossings street crossings, ');
    if (audibleSignals > 0) {
      buf.write('$audibleSignals with audible signals. ');
    }
    buf.write(
        'Walking distance approximately ${(walkingDistanceMeters / 1000).toStringAsFixed(1)} kilometres. ');
    buf.write('$transferCount transfer${transferCount == 1 ? '' : 's'}. ');
    if (constructionAlerts > 0) {
      buf.write('Note: construction may be present on this route. ');
    }
    if (!dataComplete) {
      buf.write('Some accessibility information may be incomplete.');
    }
    return buf.toString();
  }
}

class RoutePlan {
  final String id;
  final String mode;
  final int totalDurationSeconds;
  final double totalWalkingDistanceMeters;
  final int transferCount;
  final List<JourneyLeg> legs;
  final List<FunctionalPoint> functionalPoints;
  final List<RiskPoint> riskPoints;
  final AccessibilitySummary accessibilitySummary;

  const RoutePlan({
    required this.id,
    required this.mode,
    required this.totalDurationSeconds,
    required this.totalWalkingDistanceMeters,
    required this.transferCount,
    required this.legs,
    required this.functionalPoints,
    required this.riskPoints,
    required this.accessibilitySummary,
  });

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    return RoutePlan(
      id: json['id'] as String,
      mode: json['mode'] as String,
      totalDurationSeconds: json['total_duration_seconds'] as int,
      totalWalkingDistanceMeters:
          (json['total_walking_distance_meters'] as num).toDouble(),
      transferCount: json['transfer_count'] as int,
      legs: (json['legs'] as List<dynamic>)
          .map((l) => JourneyLeg.fromJson(l as Map<String, dynamic>))
          .toList(),
      functionalPoints: (json['functional_points'] as List<dynamic>)
          .map((fp) => FunctionalPoint.fromJson(fp as Map<String, dynamic>))
          .toList(),
      riskPoints: (json['risk_points'] as List<dynamic>)
          .map((rp) => RiskPoint.fromJson(rp as Map<String, dynamic>))
          .toList(),
      accessibilitySummary: AccessibilitySummary.fromJson(
          json['accessibility_summary'] as Map<String, dynamic>),
    );
  }

  String get modeLabel {
    switch (mode) {
      case 'transit':
        return 'Transit';
      case 'walk':
        return 'Walking';
      default:
        return mode;
    }
  }

  String get durationLabel {
    final min = (totalDurationSeconds / 60).round();
    return '$min min';
  }

  List<NavigationStep> get allSteps =>
      legs.expand((l) => l.steps).toList();

  String get overviewTts {
    final buf = StringBuffer();
    buf.write('Route overview: $modeLabel, ');
    buf.write('approximately $durationLabel. ');
    if (totalWalkingDistanceMeters > 0) {
      buf.write(
          'Walking distance ${(totalWalkingDistanceMeters / 1000).toStringAsFixed(1)} kilometres. ');
    }
    buf.write('${legs.length} segment${legs.length == 1 ? '' : 's'}. ');
    if (riskPoints.isNotEmpty) {
      buf.write(
          'Caution: ${riskPoints.length} risk point${riskPoints.length == 1 ? '' : 's'} on this route. ');
    }
    return buf.toString();
  }
}
