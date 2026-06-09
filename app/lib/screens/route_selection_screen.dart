import 'package:flutter/material.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import 'debug_map_screen.dart';
import 'route_detail_screen.dart';

class RouteSelectionScreen extends StatefulWidget {
  final Place origin;
  final Place destination;

  const RouteSelectionScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final _ttsService = TtsService.instance;
  final _apiService = ApiService.instance;

  List<RoutePlan> _routes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final routes = await _apiService.planRoutes(
        originLat: widget.origin.lat,
        originLon: widget.origin.lon,
        destLat: widget.destination.lat,
        destLon: widget.destination.lon,
        originName: widget.origin.name,
        destinationName: widget.destination.name,
      );
      setState(() {
        _routes = routes;
        _loading = false;
      });
      if (routes.isNotEmpty) {
        _ttsService.speak(
          '${routes.length} route${routes.length == 1 ? '' : 's'} found. '
          'The fastest option is ${routes.first.modeLabel}, '
          'approximately ${routes.first.durationLabel}. '
          'Please select a route.',
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Route planning failed. Please try again.';
      });
      _ttsService.speak('Route planning failed. Please try again.');
    }
  }

  void _selectRoute(RoutePlan route) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          route: route,
          origin: widget.origin,
          destination: widget.destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Route'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on map',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DebugMapScreen(
                  origin: widget.origin,
                  destination: widget.destination,
                  routes: _routes,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _DestinationHeader(destination: widget.destination),
          Expanded(
            child: _RouteBody(
              loading: _loading,
              error: _error,
              routes: _routes,
              onSelectRoute: _selectRoute,
              onReadAloud: (route) => _ttsService.speak(route.overviewTts),
              onRetry: _loadRoutes,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationHeader extends StatelessWidget {
  final Place destination;

  const _DestinationHeader({required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.place, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                Text(
                  destination.address,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<RoutePlan> routes;
  final void Function(RoutePlan) onSelectRoute;
  final void Function(RoutePlan) onReadAloud;
  final VoidCallback onRetry;

  const _RouteBody({
    required this.loading,
    required this.error,
    required this.routes,
    required this.onSelectRoute,
    required this.onReadAloud,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _RouteCard(
        route: routes[index],
        index: index + 1,
        onTap: () => onSelectRoute(routes[index]),
        onTtsPreview: () => onReadAloud(routes[index]),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final RoutePlan route;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onTtsPreview;

  const _RouteCard({
    required this.route,
    required this.index,
    required this.onTap,
    required this.onTtsPreview,
  });

  Color get _scoreColor {
    final score = route.accessibilitySummary.score;
    if (score >= 80) return Colors.green[700]!;
    if (score >= 60) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  @override
  Widget build(BuildContext context) {
    final summary = route.accessibilitySummary;
    return Semantics(
      label: 'Route $index: ${route.modeLabel}, ${route.durationLabel}, '
          'accessibility score ${summary.score}',
      button: true,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Option $index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      route.modeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _scoreColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'A11y ${summary.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(Icons.timer, route.durationLabel),
                const SizedBox(height: 6),
                _InfoRow(
                  Icons.directions_walk,
                  'Walk ${(route.totalWalkingDistanceMeters / 1000).toStringAsFixed(1)} km',
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  Icons.transfer_within_a_station,
                  '${summary.transferCount} transfer${summary.transferCount == 1 ? '' : 's'}'
                  '  ·  '
                  '${summary.streetCrossings} crossing${summary.streetCrossings == 1 ? '' : 's'}',
                ),
                if (route.riskPoints.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    Icons.warning_amber_rounded,
                    '${route.riskPoints.length} risk point${route.riskPoints.length == 1 ? '' : 's'}',
                    color: Colors.orange[700]!,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.volume_up, size: 20),
                        label: const Text('Read Aloud'),
                        onPressed: onTtsPreview,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        label: const Text('View Details'),
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.grey[700]!;
    return Row(
      children: [
        Icon(icon, size: 18, color: textColor),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 15, color: textColor)),
      ],
    );
  }
}
