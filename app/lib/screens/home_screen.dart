import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import '../services/accessibility_focus_service.dart';
import '../services/location_service.dart';
import '../widgets/large_button.dart';
import 'route_selection_screen.dart';
import 'exploration_screen.dart';
import 'debug_map_screen.dart';

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
    final a = sin(dLat / 2) * sin(dLat / 2) +
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

  void _selectDestination(Place destination) {
    if (_selectedOrigin == null) return;
    _ttsService.speak(
      'Destination: ${destination.name}. Planning route, please wait.',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteSelectionScreen(
          origin: _selectedOrigin!,
          destination: destination,
        ),
      ),
    );
  }

  void _openExploration(Place place) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExplorationScreen(centerPlace: place),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Accessibility Navigator'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
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
          // ExcludeSemantics so TalkBack skips this button on initial focus.
          // TalkBack users reach exploration via the hint body button instead,
          // which is always reachable without an accidental first-focus grab.
          ExcludeSemantics(
            child: IconButton(
              icon: const Icon(Icons.explore),
              tooltip: 'Explore nearby',
              onPressed: _selectedOrigin == null
                  ? null
                  : () => _openExploration(_selectedOrigin!),
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
          _OriginBar(
            isLocating: _locating,
            originName: _selectedOrigin?.name,
          ),
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
                onSortChanged: (order) =>
                    setState(() => _sortOrder = order),
                onSelectDestination: _selectDestination,
                onExplore: _openExploration,
              ),
            )
          else
            Expanded(
              child: _HintView(
                canExplore: _selectedOrigin != null,
                onExplore: _selectedOrigin == null
                    ? null
                    : () => _openExploration(_selectedOrigin!),
              ),
            ),
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
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (isLocating)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(
              Icons.my_location,
              color: Color(0xFF1565C0),
              size: 20,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isLocating
                  ? 'Acquiring location…'
                  : 'From: ${originName ?? "Unknown"}',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
          const SizedBox(width: 8),
          // sortKey(1): TalkBack reaches mic button first among search elements
          Semantics(
            sortKey: const OrdinalSortKey(1),
            label: isListening ? 'Stop listening' : 'Tap to speak',
            button: true,
            child: SizedBox(
              width: 64,
              height: 64,
              child: ElevatedButton(
                onPressed: isListening ? null : onMicTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isListening
                      ? Colors.red[600]
                      : const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            sortKey: const OrdinalSortKey(3),
            label: 'Search',
            button: true,
            child: SizedBox(
              width: 64,
              height: 64,
              child: ElevatedButton(
                onPressed: () => onSearch(controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 32),
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
  final void Function(Place) onSelectDestination;
  final void Function(Place) onExplore;

  const _ResultsList({
    required this.sortedPlaces,
    required this.sortOrder,
    required this.distanceTo,
    required this.formatDistance,
    required this.resultsStatusKey,
    required this.onSortChanged,
    required this.onSelectDestination,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ),
        _SortBar(sortOrder: sortOrder, onChanged: onSortChanged),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedPlaces.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final place = sortedPlaces[index];
              return Semantics(
                label: '${place.name}, ${place.address}',
                button: true,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelectDestination(place),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            place.address,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.near_me,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatDistance(distanceTo(place)),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.explore, size: 20),
                                  label: const Text('Explore Nearby'),
                                  onPressed: () => onExplore(place),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.directions,
                                    size: 20,
                                  ),
                                  label: const Text('Get Directions'),
                                  onPressed: () =>
                                      onSelectDestination(place),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF1565C0),
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
      child: Row(
        children: [
          Text(
            'Sort:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          DropdownButton<_SortOrder>(
            value: sortOrder,
            isDense: true,
            underline: const SizedBox(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1565C0),
            ),
            items: const [
              DropdownMenuItem(
                value: _SortOrder.distanceAsc,
                child: Text('Distance: Near → Far'),
              ),
              DropdownMenuItem(
                value: _SortOrder.distanceDesc,
                child: Text('Distance: Far → Near'),
              ),
              DropdownMenuItem(
                value: _SortOrder.nameAsc,
                child: Text('Name: A → Z'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _HintView extends StatelessWidget {
  final bool canExplore;
  final VoidCallback? onExplore;

  const _HintView({required this.canExplore, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Type a destination\nor hold the microphone to speak',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            LargeButton(
              label: 'Explore Current Location',
              icon: Icons.explore,
              onPressed: onExplore,
              backgroundColor: Colors.teal[700],
            ),
          ],
        ),
      ),
    );
  }
}
