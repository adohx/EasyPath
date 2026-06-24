import 'package:flutter/material.dart';
import '../core/geo_utils.dart';
import '../models/place.dart';
import '../models/tracked_place.dart';
import '../services/explore_center_controller.dart';
import '../services/location_service.dart';
import '../services/tracked_place_repository.dart';
import 'route_selection_screen.dart';
import 'track_place_screen.dart';

/// The shared landing page for a place tapped from either Search
/// (`HomeScreen`) or Explore (`ExplorationScreen`). Presents the three
/// next actions a user might want, instead of stacking them as buttons
/// on every list card: get directions there now, track it as a
/// personal place, or explore around it.
class PlaceDetailScreen extends StatefulWidget {
  final Place place;
  final TrackedPlaceRepository? trackedPlaceRepository;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.trackedPlaceRepository,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

/// A fresh search/explore coordinate and a previously-saved one rarely
/// land on the exact same lat/lon — this is generous enough to treat
/// "the library" found twice as the same place, tight enough not to
/// match a different nearby building.
const double _kSamePlaceToleranceMeters = 15;

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late final TrackedPlaceRepository _repository;
  TrackedPlace? _matchedTrackedPlace;
  bool _loadingMatch = true;
  bool _requestingDirections = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.trackedPlaceRepository ?? TrackedPlaceRepository.instance;
    _refreshTrackedMatch();
  }

  Future<void> _refreshTrackedMatch() async {
    setState(() => _loadingMatch = true);
    final all = await _repository.getAll();
    TrackedPlace? match;
    for (final candidate in all) {
      final distance = distanceMeters(
        widget.place.lat,
        widget.place.lon,
        candidate.lat,
        candidate.lon,
      );
      if (distance <= _kSamePlaceToleranceMeters) {
        match = candidate;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _matchedTrackedPlace = match;
      _loadingMatch = false;
    });
  }

  Future<void> _getDirections() async {
    setState(() => _requestingDirections = true);
    final origin = await LocationService.instance.getCurrentPlace();
    if (!mounted) return;
    setState(() => _requestingDirections = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RouteSelectionScreen(origin: origin, destination: widget.place),
      ),
    );
  }

  Future<void> _track() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => TrackPlaceScreen(
          name: widget.place.name,
          lat: widget.place.lat,
          lon: widget.place.lon,
          addedVia: 'search',
          existingPlace: _matchedTrackedPlace,
        ),
      ),
    );
    if (result != null) {
      await _refreshTrackedMatch();
    }
  }

  void _exploreNearby() {
    ExploreCenterController.instance.requestRecenter(widget.place);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isTracked = _matchedTrackedPlace != null;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Place Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.place.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (widget.place.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.place.address,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            _ActionButton(
              icon: Icons.directions,
              label: 'Get Directions',
              sublabel: 'Plan a one-time trip here. Nothing is saved.',
              loading: _requestingDirections,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              onPressed: _requestingDirections ? null : _getDirections,
            ),
            const SizedBox(height: 16),
            _ActionButton(
              icon: isTracked ? Icons.bookmark : Icons.bookmark_add_outlined,
              label: isTracked ? 'Edit Tracked Place' : 'Track This Place',
              sublabel: isTracked
                  ? 'Already saved to My Places. Tap to change its '
                        'category or importance.'
                  : 'Save it to My Places with a category and an '
                        'importance level.',
              loading: _loadingMatch,
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
              onPressed: _loadingMatch ? null : _track,
            ),
            const SizedBox(height: 16),
            _ActionButton(
              icon: Icons.explore,
              label: 'Explore Nearby',
              sublabel: 'See what categories of places are around here.',
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              onPressed: _exploreNearby,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $sublabel',
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          child: Row(
            children: [
              loading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: foregroundColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: foregroundColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
