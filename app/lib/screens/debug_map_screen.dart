import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/functional_point.dart';
import '../models/risk_point.dart';

class DebugMapScreen extends StatefulWidget {
  final Place origin;
  final Place destination;
  final RoutePlan route;

  const DebugMapScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.route,
  });

  @override
  State<DebugMapScreen> createState() => _DebugMapScreenState();
}

class _DebugMapScreenState extends State<DebugMapScreen> {
  String? _tooltip;

  // ── Derived data ──────────────────────────────────────────────────────────

  LatLng get _originLL =>
      LatLng(widget.origin.lat, widget.origin.lon);

  LatLng get _destLL =>
      LatLng(widget.destination.lat, widget.destination.lon);

  LatLng get _center {
    final lat = (widget.origin.lat + widget.destination.lat) / 2;
    final lon = (widget.origin.lon + widget.destination.lon) / 2;
    return LatLng(lat, lon);
  }

  List<LatLng> get _polyline {
    final geo = widget.route.geometry;
    if (geo.isNotEmpty) {
      return geo.map((p) => LatLng(p[0], p[1])).toList();
    }
    // Fallback: straight line origin → destination
    return [_originLL, _destLL];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map: ${widget.destination.name}'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onTap: (pos, pt) => setState(() => _tooltip = null),
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ana.accessibility_nav_assistant',
              ),

              // Route polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _polyline,
                    color: const Color(0xFF1565C0),
                    strokeWidth: 5,
                  ),
                ],
              ),

              // Markers layer
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Tooltip popup
          if (_tooltip != null)
            Positioned(
              bottom: 130,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_tooltip!, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),

          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Origin — green
    markers.add(_pinMarker(
      point: _originLL,
      color: Colors.green[700]!,
      icon: Icons.my_location,
      label: 'Origin: ${widget.origin.name}',
    ));

    // Destination — red
    markers.add(_pinMarker(
      point: _destLL,
      color: Colors.red[700]!,
      icon: Icons.place,
      label: 'Destination: ${widget.destination.name}',
    ));

    // Functional points — blue
    for (final fp in widget.route.functionalPoints) {
      markers.add(_circleMarker(
        point: LatLng(fp.lat, fp.lon),
        color: Colors.blue[700]!,
        icon: _fpIcon(fp),
        label: '[Functional] ${fp.description}',
      ));
    }

    // Risk points — orange (medium) / yellow (low)
    for (final rp in widget.route.riskPoints) {
      final color = rp.severity == RiskSeverity.high
          ? Colors.red
          : rp.severity == RiskSeverity.medium
              ? Colors.orange
              : Colors.yellow[700]!;
      markers.add(_circleMarker(
        point: LatLng(rp.lat, rp.lon),
        color: color,
        icon: Icons.warning_rounded,
        label: '[Risk/${rp.severity.name}] ${rp.description}',
      ));
    }

    return markers;
  }

  IconData _fpIcon(FunctionalPoint fp) {
    switch (fp.type) {
      case 'bus_board':
      case 'bus_alight':
        return Icons.directions_bus;
      case 'building_entrance':
        return Icons.door_front_door;
      case 'turn':
        return Icons.turn_right;
      default:
        return Icons.circle;
    }
  }

  Marker _pinMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => setState(() => _tooltip = label),
        child: Icon(icon, color: color, size: 36,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
      ),
    );
  }

  Marker _circleMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Marker(
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
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _legendItem(Icons.my_location, Colors.green[700]!, 'Origin'),
            _legendItem(Icons.place, Colors.red[700]!, 'Destination'),
            _legendItem(Icons.circle, Colors.blue[700]!, 'Functional'),
            _legendItem(Icons.warning_rounded, Colors.orange, 'Risk (med)'),
            _legendItem(Icons.warning_rounded, Colors.yellow[700]!, 'Risk (low)'),
            Text(
              'Tap markers for details',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
