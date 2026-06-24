import 'package:flutter/material.dart';
import '../core/geo_utils.dart';
import '../core/place_icons.dart';
import '../models/place.dart';
import '../models/exploration_item.dart';
import '../models/tracked_place.dart';
import '../services/api_service.dart';
import '../services/explore_center_controller.dart';
import '../services/location_service.dart';
import '../services/tracked_place_repository.dart';
import '../services/tts_service.dart';
import 'debug_map_screen.dart';
import 'place_detail_screen.dart';

/// Converts an exploration result into the shared [Place] shape the
/// detail screen expects.
Place _itemToPlace(ExplorationItem item) => Place(
  id: item.id,
  name: item.name,
  address: '${item.distanceLabel} · ${item.bearingLabel}',
  lat: item.lat,
  lon: item.lon,
);

/// Default radius for both the official Overpass query and the personal
/// places merged into it — keeping these two values the same makes the
/// merge behave like "everything (official or personal) actually near
/// the centre point," not "every personal place ever tracked."
const double kExplorationRadiusMeters = 300;

/// Explore tab / screen. Without a [centerPlace], it resolves the
/// device's current location itself (so it can be used as a standalone
/// bottom-nav tab, not just something pushed with an explicit place).
/// The centre can be changed at any time from within the screen, and
/// can also be set externally via [ExploreCenterController] (e.g. a
/// place detail page's "Explore Nearby" button).
class ExplorationScreen extends StatefulWidget {
  final Place? centerPlace;
  final double radiusMeters;
  final ApiService? apiService;
  final TrackedPlaceRepository? trackedPlaceRepository;

  const ExplorationScreen({
    super.key,
    this.centerPlace,
    this.radiusMeters = kExplorationRadiusMeters,
    this.apiService,
    this.trackedPlaceRepository,
  });

  @override
  State<ExplorationScreen> createState() => _ExplorationScreenState();
}

class _ExplorationScreenState extends State<ExplorationScreen> {
  final _ttsService = TtsService.instance;
  late final ApiService _apiService;
  late final TrackedPlaceRepository _trackedPlaceRepository;
  final _exploreCenterController = ExploreCenterController.instance;

  Place? _center;
  List<ExplorationCategory> _categories = [];
  Set<String> _personalItemIds = {};
  bool _loading = true;
  int _selectedCategoryIndex = 0;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService.instance;
    _trackedPlaceRepository =
        widget.trackedPlaceRepository ?? TrackedPlaceRepository.instance;
    _exploreCenterController.addListener(_onExternalRecenterRequested);
    _initializeCenterAndLoad();
  }

  Future<void> _initializeCenterAndLoad() async {
    _center =
        widget.centerPlace ?? await LocationService.instance.getCurrentPlace();
    if (!mounted) return;
    await _loadExploration();
  }

  void _onExternalRecenterRequested() {
    final pending = _exploreCenterController.pendingCenter;
    if (pending == null) return;
    _exploreCenterController.consumePendingCenter();
    setState(() => _center = pending);
    _loadExploration();
  }

  Future<void> _changeLocation() async {
    final selected = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangeLocationSheet(apiService: _apiService),
    );
    if (selected != null) {
      setState(() => _center = selected);
      await _loadExploration();
    }
  }

  Future<void> _loadExploration() async {
    final center = _center;
    if (center == null) return;
    setState(() => _loading = true);
    final official = await _apiService.nearbyExploration(
      lat: center.lat,
      lon: center.lon,
      radiusMeters: widget.radiusMeters.round(),
    );
    final personalPlaces = await _trackedPlaceRepository.getActive();
    final categories = _mergePersonalPlaces(center, official, personalPlaces);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
      _selectedCategoryIndex = 0;
      _currentItemIndex = 0;
    });
    if (categories.isNotEmpty) {
      final categoryNames = categories.map((c) => c.label).join(', ');
      _ttsService.speak(
        '${categories.length} categories nearby: $categoryNames. '
        'Select a category to explore.',
      );
    }
  }

  /// Merges the user's active personal places (design doc §2.1.2) into
  /// the official, location-dependent category results — by category
  /// key where they overlap (e.g. 'restaurant'), as new category groups
  /// otherwise. Each personal place's distance/bearing is computed live
  /// from [center], never trusting any stale stored value.
  List<ExplorationCategory> _mergePersonalPlaces(
    Place center,
    List<ExplorationCategory> official,
    List<TrackedPlace> personalPlaces,
  ) {
    final itemsByKey = <String, List<ExplorationItem>>{
      for (final category in official) category.key: List.of(category.items),
    };
    final personalIds = <String>{};
    for (final place in personalPlaces) {
      final distance = distanceMeters(
        center.lat,
        center.lon,
        place.lat,
        place.lon,
      );
      // Only personal places actually near this centre point belong in
      // *this* exploration session — otherwise every tracked place would
      // show up everywhere, regardless of how far away it actually is.
      if (distance > widget.radiusMeters) continue;
      final id = 'tracked_${place.id}';
      personalIds.add(id);
      final item = ExplorationItem(
        id: id,
        name: place.name,
        distanceMeters: distance,
        bearingDegrees: initialBearingDegrees(
          center.lat,
          center.lon,
          place.lat,
          place.lon,
        ),
        lat: place.lat,
        lon: place.lon,
      );
      itemsByKey.putIfAbsent(place.categoryId, () => []).add(item);
    }
    _personalItemIds = personalIds;

    return itemsByKey.entries.map((entry) {
      final items = List.of(entry.value)
        ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return ExplorationCategory(key: entry.key, items: items);
    }).toList();
  }

  Future<void> _openItemDetail(ExplorationItem item) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(place: _itemToPlace(item)),
      ),
    );
    if (result != null) {
      await _loadExploration();
    }
  }

  List<ExplorationItem> get _currentItems {
    if (_categories.isEmpty) return [];
    return _categories[_selectedCategoryIndex].items;
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _currentItemIndex = 0;
    });
    final category = _categories[index];
    final count = category.items.length;
    _ttsService.speakInterrupt(
      '${category.label}, $count location${count == 1 ? '' : 's'}. '
      '${category.items.isNotEmpty ? category.items.first.ttsText : ''}',
    );
  }

  void _selectItem(int index) {
    setState(() => _currentItemIndex = index);
    _ttsService.speakInterrupt(_currentItems[index].ttsText);
  }

  @override
  void dispose() {
    _exploreCenterController.removeListener(_onExternalRecenterRequested);
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          if (center != null && !_loading && _currentItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'View category on map',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DebugMapScreen(
                    origin: center,
                    extraPlaces: _currentItems
                        .map(
                          (item) => Place(
                            id: item.id,
                            name: item.name,
                            address: item.distanceLabel,
                            lat: item.lat,
                            lon: item.lon,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: center == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _CenterHeader(
                  centerName: center.name,
                  onChangeLocation: _changeLocation,
                ),
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_categories.isEmpty)
                  const Expanded(child: _EmptyExplorationView())
                else
                  Expanded(
                    child: Column(
                      children: [
                        _ExplorationCategoryChips(
                          categories: _categories,
                          selectedIndex: _selectedCategoryIndex,
                          onSelect: _selectCategory,
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _ExplorationItemList(
                            items: _currentItems,
                            categoryKey:
                                _categories[_selectedCategoryIndex].key,
                            selectedIndex: _currentItemIndex,
                            personalItemIds: _personalItemIds,
                            onSelectItem: _selectItem,
                            onOpenDetail: _openItemDetail,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CenterHeader extends StatelessWidget {
  final String centerName;
  final VoidCallback onChangeLocation;

  const _CenterHeader({
    required this.centerName,
    required this.onChangeLocation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(
              Icons.explore,
              size: 16,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Exploring around: $centerName',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            button: true,
            label: 'Change exploration location',
            child: IconButton(
              icon: Icon(Icons.edit_location_alt, color: colorScheme.secondary),
              onPressed: onChangeLocation,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeLocationSheet extends StatefulWidget {
  final ApiService apiService;

  const _ChangeLocationSheet({required this.apiService});

  @override
  State<_ChangeLocationSheet> createState() => _ChangeLocationSheetState();
}

class _ChangeLocationSheetState extends State<_ChangeLocationSheet> {
  final _controller = TextEditingController();
  List<Place> _results = [];
  bool _loadingResults = false;
  bool _usingCurrentLocation = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _usingCurrentLocation = true);
    final place = await LocationService.instance.getCurrentPlace();
    if (!mounted) return;
    Navigator.of(context).pop(place);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loadingResults = true);
    final results = await widget.apiService.searchPlaces(query.trim());
    if (!mounted) return;
    setState(() {
      _loadingResults = false;
      _results = results;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Change Exploration Location',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Use my current location',
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _usingCurrentLocation ? null : _useCurrentLocation,
                icon: _usingCurrentLocation
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Use My Current Location'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Semantics(
            label: 'Search for a place to explore',
            textField: true,
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search for a place',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingResults)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final place = _results[index];
                  final colorScheme = Theme.of(context).colorScheme;
                  return Semantics(
                    button: true,
                    label: '${place.name}, ${place.address}',
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(place),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: colorScheme.secondaryContainer,
                                child: Icon(
                                  iconForPlaceType(place.type),
                                  color: colorScheme.onSecondaryContainer,
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
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: colorScheme.outline,
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
      ),
    );
  }
}

class _EmptyExplorationView extends StatelessWidget {
  const _EmptyExplorationView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_off,
              size: 64,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No nearby exploration data available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorationCategoryChips extends StatelessWidget {
  final List<ExplorationCategory> categories;
  final int selectedIndex;
  final void Function(int) onSelect;

  const _ExplorationCategoryChips({
    required this.categories,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            final selected = index == selectedIndex;
            return Semantics(
              label: '${category.label}, ${category.items.length} locations',
              selected: selected,
              button: true,
              child: ChoiceChip(
                label: Text(
                  '${category.label} (${category.items.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? colorScheme.onSecondary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: selected,
                selectedColor: colorScheme.secondary,
                onSelected: (_) => onSelect(index),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Maps a rough category/type hint to a representative icon, for quick
/// visual scanning of mixed-category result lists.
IconData _iconForCategoryKey(String key) {
  switch (key) {
    case 'restaurant':
      return Icons.restaurant;
    case 'pharmacy':
      return Icons.local_pharmacy;
    case 'hospital':
      return Icons.local_hospital;
    case 'bus_stop':
      return Icons.directions_bus;
    case 'hotel':
      return Icons.hotel;
    case 'parking':
      return Icons.local_parking;
    case 'supermarket':
      return Icons.shopping_cart;
    case 'atm':
      return Icons.atm;
    case 'work_life':
      return Icons.work_outline;
    case 'known_contacts':
      return Icons.people_outline;
    case 'hazard_detour':
      return Icons.warning_amber_rounded;
    default:
      return Icons.place_outlined;
  }
}

class _ExplorationItemList extends StatelessWidget {
  final List<ExplorationItem> items;
  final String categoryKey;
  final int selectedIndex;
  final Set<String> personalItemIds;
  final void Function(int) onSelectItem;
  final void Function(ExplorationItem) onOpenDetail;

  const _ExplorationItemList({
    required this.items,
    required this.categoryKey,
    required this.selectedIndex,
    required this.personalItemIds,
    required this.onSelectItem,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No locations in this category.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = index == selectedIndex;
        final isPersonal = personalItemIds.contains(item.id);
        final colorScheme = Theme.of(context).colorScheme;
        return Semantics(
          label: isPersonal ? '${item.ttsText}, tracked' : item.ttsText,
          selected: isSelected,
          button: true,
          child: Card(
            color: isSelected
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? BorderSide(color: colorScheme.secondary, width: 1.5)
                  : BorderSide.none,
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: isPersonal
                  ? CircleAvatar(
                      backgroundColor: colorScheme.secondary,
                      child: Icon(
                        Icons.bookmark,
                        color: colorScheme.onSecondary,
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: isSelected
                          ? colorScheme.secondary
                          : colorScheme.secondaryContainer,
                      child: Icon(
                        _iconForCategoryKey(categoryKey),
                        color: isSelected
                            ? colorScheme.onSecondary
                            : colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
              title: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${item.distanceLabel}  ·  ${item.bearingLabel}',
                style: TextStyle(fontSize: 14, color: colorScheme.outline),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Speak this location',
                onPressed: () => onSelectItem(index),
              ),
              onTap: () => onOpenDetail(item),
            ),
          ),
        );
      },
    );
  }
}
