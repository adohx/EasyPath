import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/functional_point.dart';
import '../models/risk_point.dart';

const _kRouteColors = [
  Color(0xFF1565C0),
  Color(0xFFE65100),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
];

/// Debug map supporting three modes:
/// - places only (home search results, exploration category)
/// - origin + destination, no route
/// - origin + destination + one or more routes
class DebugMapScreen extends StatefulWidget {
  final Place origin;
  final Place? destination;

  /// Routes to draw as polylines. Pass multiple to compare options.
  final List<RoutePlan> routes;

  /// Extra places shown as teal pins (search results, exploration items).
  final List<Place> extraPlaces;

  const DebugMapScreen({
    super.key,
    required this.origin,
    this.destination,
    this.routes = const [],
    this.extraPlaces = const [],
  });

  @override
  State<DebugMapScreen> createState() => _DebugMapScreenState();
}

class _DebugMapScreenState extends State<DebugMapScreen> {
  final _mapController = MapController();
  String? _tooltip;

  List<LatLng> get _allPoints {
    final points = <LatLng>[
      LatLng(widget.origin.lat, widget.origin.lon),
    ];
    if (widget.destination case final destination?) {
      points.add(LatLng(destination.lat, destination.lon));
    }
    for (final place in widget.extraPlaces) {
      points.add(LatLng(place.lat, place.lon));
    }
    for (final route in widget.routes) {
      if (route.geometry.isNotEmpty) {
        points.addAll(
          route.geometry.map((coord) => LatLng(coord[0], coord[1])),
        );
      }
      for (final functionalPoint in route.functionalPoints) {
        points.add(LatLng(functionalPoint.lat, functionalPoint.lon));
      }
      for (final riskPoint in route.riskPoints) {
        points.add(LatLng(riskPoint.lat, riskPoint.lon));
      }
    }
    return points;
  }

  LatLngBounds? _boundsOf(List<LatLng> points) {
    if (points.length < 2) return null;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }
    return LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bounds = _boundsOf(_allPoints);
      if (bounds == null) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(56),
          maxZoom: 16,
        ),
      );
    });
  }

  List<Polyline> get _polylines {
    final lines = <Polyline>[];
    for (var i = 0; i < widget.routes.length; i++) {
      final route = widget.routes[i];
      final color = _kRouteColors[i % _kRouteColors.length];
      final points = route.geometry.isNotEmpty
          ? route.geometry
              .map((coord) => LatLng(coord[0], coord[1]))
              .toList()
          : _fallbackLine(route);
      if (points.isNotEmpty) {
        lines.add(Polyline(points: points, color: color, strokeWidth: 5));
      }
    }
    return lines;
  }

  List<LatLng> _fallbackLine(RoutePlan route) {
    if (widget.destination case final destination?) {
      return [
        LatLng(widget.origin.lat, widget.origin.lon),
        LatLng(destination.lat, destination.lon),
      ];
    }
    return [];
  }

  // Detail markers only make sense for a single route — multiple routes
  // would produce overlapping markers with ambiguous ownership.
  bool get _showDetailMarkers => widget.routes.length == 1;

  String get _title {
    if (widget.destination case final destination?) {
      return 'Map · ${destination.name}';
    }
    return 'Map · ${widget.origin.name}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.origin.lat, widget.origin.lon),
              initialZoom: 14,
              onTap: (_, _) => setState(() => _tooltip = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.ana.accessibility_nav_assistant',
              ),
              if (_polylines.isNotEmpty)
                PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          if (_tooltip case final tip?)
            Positioned(
              bottom: 130,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(tip, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _Legend(
              routeCount: widget.routes.length,
              showDestination: widget.destination != null,
              showResults: widget.extraPlaces.isNotEmpty,
              showDetailMarkers: _showDetailMarkers,
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    markers.add(_pinMarker(
      point: LatLng(widget.origin.lat, widget.origin.lon),
      color: Colors.green[700]!,
      icon: Icons.my_location,
      label: 'Origin: ${widget.origin.name}',
    ));

    if (widget.destination case final destination?) {
      markers.add(_pinMarker(
        point: LatLng(destination.lat, destination.lon),
        color: Colors.red[700]!,
        icon: Icons.place,
        label: 'Destination: ${destination.name}',
      ));
    }

    for (final place in widget.extraPlaces) {
      markers.add(_pinMarker(
        point: LatLng(place.lat, place.lon),
        color: Colors.teal[600]!,
        icon: Icons.location_on,
        label: place.name,
      ));
    }

    if (_showDetailMarkers && widget.routes.isNotEmpty) {
      final route = widget.routes.first;
      for (final functionalPoint in route.functionalPoints) {
        markers.add(_circleMarker(
          point: LatLng(functionalPoint.lat, functionalPoint.lon),
          color: Colors.blue[700]!,
          icon: _functionalPointIcon(functionalPoint),
          label: '[Functional] ${functionalPoint.description}',
        ));
      }
      for (final riskPoint in route.riskPoints) {
        final color = switch (riskPoint.severity) {
          RiskSeverity.high => Colors.red,
          RiskSeverity.medium => Colors.orange,
          RiskSeverity.low => Colors.yellow[700]!,
        };
        markers.add(_circleMarker(
          point: LatLng(riskPoint.lat, riskPoint.lon),
          color: color,
          icon: Icons.warning_rounded,
          label: '[Risk/${riskPoint.severity.name}] ${riskPoint.description}',
        ));
      }
    }

    return markers;
  }

  IconData _functionalPointIcon(FunctionalPoint point) =>
      switch (point.type) {
        'bus_board' || 'bus_alight' => Icons.directions_bus,
        'building_entrance' => Icons.door_front_door,
        'turn' => Icons.turn_right,
        _ => Icons.circle,
      };

  Marker _pinMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) =>
      Marker(
        point: point,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => setState(() => _tooltip = label),
          child: Icon(
            icon,
            color: color,
            size: 36,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      );

  Marker _circleMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) =>
      Marker(
        point: point,
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => setState(() => _tooltip = label),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 3),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  final int routeCount;
  final bool showDestination;
  final bool showResults;
  final bool showDetailMarkers;

  const _Legend({
    required this.routeCount,
    required this.showDestination,
    required this.showResults,
    required this.showDetailMarkers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendItem(
              icon: Icons.my_location,
              color: Colors.green[700]!,
              label: 'Origin',
            ),
            if (showDestination)
              _LegendItem(
                icon: Icons.place,
                color: Colors.red[700]!,
                label: 'Destination',
              ),
            if (showResults)
              _LegendItem(
                icon: Icons.location_on,
                color: Colors.teal[600]!,
                label: 'Results',
              ),
            if (routeCount > 1)
              for (var i = 0; i < routeCount; i++)
                _LegendItem(
                  icon: Icons.route,
                  color: _kRouteColors[i % _kRouteColors.length],
                  label: 'Route ${i + 1}',
                ),
            if (showDetailMarkers && routeCount == 1) ...[
              _LegendItem(
                icon: Icons.route,
                color: _kRouteColors[0],
                label: 'Route',
              ),
              _LegendItem(
                icon: Icons.circle,
                color: Colors.blue[700]!,
                label: 'Functional',
              ),
              _LegendItem(
                icon: Icons.warning_rounded,
                color: Colors.orange,
                label: 'Risk (med)',
              ),
              _LegendItem(
                icon: Icons.warning_rounded,
                color: Colors.yellow[700]!,
                label: 'Risk (low)',
              ),
            ],
            Text(
              'Tap markers for details',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}
