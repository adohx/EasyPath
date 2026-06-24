import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../core/place_icons.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import '../services/accessibility_focus_service.dart';
import '../services/location_service.dart';
import 'debug_map_screen.dart';
import 'place_detail_screen.dart';

enum _SortOrder { distanceAsc, distanceDesc, nameAsc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _ttsService = TtsService.instance;
  final _apiService = ApiService.instance;
  final _voiceService = VoiceService.instance;
  final _locationService = LocationService.instance;
  final _resultsStatusKey = GlobalKey();

  List<Place> _results = [];
  bool _loading = false;
  bool _listening = false;
  bool _locating = true;
  Place? _selectedOrigin;
  _SortOrder _sortOrder = _SortOrder.distanceAsc;

  double _distanceTo(Place place) {
    if (_selectedOrigin == null) return 0;
    const earthRadiusMeters = 6371000.0;
    final lat1 = _selectedOrigin!.lat * pi / 180;
    final lat2 = place.lat * pi / 180;
    final dLat = (place.lat - _selectedOrigin!.lat) * pi / 180;
    final dLon = (place.lon - _selectedOrigin!.lon) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthRadiusMeters * atan2(sqrt(a), sqrt(1 - a));
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  List<Place> get _sortedResults {
    final list = List<Place>.from(_results);
    switch (_sortOrder) {
      case _SortOrder.distanceAsc:
        list.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
      case _SortOrder.distanceDesc:
        list.sort((a, b) => _distanceTo(b).compareTo(_distanceTo(a)));
      case _SortOrder.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _ttsService.speak(
        'Welcome to the Accessibility Navigation Assistant. '
        'Acquiring your location. Enter a destination or tap '
        'the microphone button to speak.',
      );
      final place = await _locationService.getCurrentPlace();
      if (mounted) {
        setState(() {
          _selectedOrigin = place;
          _locating = false;
        });
      }
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _results = [];
    });
    final results = await _apiService.searchPlaces(query.trim());
    setState(() {
      _loading = false;
      _results = results;
    });
    if (results.isEmpty) {
      _ttsService.speak(
        'No locations found. Please try a different search term.',
      );
    } else {
      _ttsService.speak(
        '${results.length} location${results.length == 1 ? '' : 's'} found. '
        'Please select your destination.',
      );
      AccessibilityFocusService.focusWidget(_resultsStatusKey);
    }
  }

  Future<void> _startListening() async {
    setState(() => _listening = true);
    final text = await _voiceService.listen();
    setState(() => _listening = false);
    if (text.isEmpty) return;
    _controller.text = text;
    _search(text);
  }

  void _openPlaceDetail(Place place) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on map',
            onPressed: _selectedOrigin == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DebugMapScreen(
                        origin: _selectedOrigin!,
                        extraPlaces: _results,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _controller,
            isListening: _listening,
            onSearch: _search,
            onMicTap: _startListening,
            onChanged: () => setState(() {}),
          ),
          _OriginBar(isLocating: _locating, originName: _selectedOrigin?.name),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: _ResultsList(
                sortedPlaces: _sortedResults,
                sortOrder: _sortOrder,
                distanceTo: _distanceTo,
                formatDistance: _formatDistance,
                resultsStatusKey: _resultsStatusKey,
                onSortChanged: (order) => setState(() => _sortOrder = order),
                onOpenDetail: _openPlaceDetail,
              ),
            )
          else
            const Expanded(child: _HintView()),
        ],
      ),
    );
  }
}

class _OriginBar extends StatelessWidget {
  final bool isLocating;
  final String? originName;

  const _OriginBar({required this.isLocating, required this.originName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primaryContainer,
              child: isLocating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.my_location,
                      color: colorScheme.onPrimaryContainer,
                      size: 16,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isLocating
                    ? 'Acquiring location…'
                    : 'From: ${originName ?? "Unknown"}',
                style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final void Function(String) onSearch;
  final VoidCallback onMicTap;
  final VoidCallback onChanged;

  const _SearchBar({
    required this.controller,
    required this.isListening,
    required this.onSearch,
    required this.onMicTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              label: 'Destination input field',
              textField: true,
              // sortKey(2): TalkBack reaches text field after mic button
              sortKey: const OrdinalSortKey(2),
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Enter destination',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            onChanged();
                          },
                        )
                      : null,
                ),
                onSubmitted: onSearch,
                onChanged: (_) => onChanged(),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // sortKey(1): TalkBack reaches mic button first among search elements
          Semantics(
            sortKey: const OrdinalSortKey(1),
            label: isListening ? 'Stop listening' : 'Tap to speak',
            button: true,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: colorScheme.error.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton(
                onPressed: isListening ? null : onMicTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isListening
                      ? colorScheme.error
                      : colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: isListening
                      ? colorScheme.onError
                      : colorScheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<Place> sortedPlaces;
  final _SortOrder sortOrder;
  final double Function(Place) distanceTo;
  final String Function(double) formatDistance;
  final GlobalKey resultsStatusKey;
  final void Function(_SortOrder) onSortChanged;
  final void Function(Place) onOpenDetail;

  const _ResultsList({
    required this.sortedPlaces,
    required this.sortOrder,
    required this.distanceTo,
    required this.formatDistance,
    required this.resultsStatusKey,
    required this.onSortChanged,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = sortedPlaces.length;
    final statusText =
        '$count location${count == 1 ? '' : 's'} found. '
        'Please select your destination.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // liveRegion: TalkBack automatically announces when this text changes
        Semantics(
          key: resultsStatusKey,
          liveRegion: true,
          label: statusText,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 14, color: colorScheme.outline),
            ),
          ),
        ),
        _SortBar(sortOrder: sortOrder, onChanged: onSortChanged),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sortedPlaces.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final place = sortedPlaces[index];
              return Semantics(
                label: '${place.name}, ${place.address}',
                button: true,
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onOpenDetail(place),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(
                              iconForPlaceType(place.type),
                              color: colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  place.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  place.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.near_me,
                                      size: 14,
                                      color: colorScheme.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formatDistance(distanceTo(place)),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colorScheme.outline),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SortBar extends StatelessWidget {
  final _SortOrder sortOrder;
  final void Function(_SortOrder) onChanged;

  const _SortBar({required this.sortOrder, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Near → Far'),
            selected: sortOrder == _SortOrder.distanceAsc,
            onSelected: (_) => onChanged(_SortOrder.distanceAsc),
          ),
          ChoiceChip(
            label: const Text('Far → Near'),
            selected: sortOrder == _SortOrder.distanceDesc,
            onSelected: (_) => onChanged(_SortOrder.distanceDesc),
          ),
          ChoiceChip(
            label: const Text('Name A → Z'),
            selected: sortOrder == _SortOrder.nameAsc,
            onSelected: (_) => onChanged(_SortOrder.nameAsc),
          ),
        ],
      ),
    );
  }
}

class _HintView extends StatelessWidget {
  const _HintView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 80, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Type a destination\nor hold the microphone to speak',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
