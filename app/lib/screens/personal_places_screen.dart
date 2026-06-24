import 'package:flutter/material.dart';
import '../models/place_tag.dart';
import '../models/tracked_place.dart';
import '../models/tracked_place_category.dart';
import '../services/tracked_place_repository.dart';
import '../services/tts_service.dart';
import 'track_place_screen.dart';

/// Manages the user's personal place library (design doc §2.3).
///
/// Deliberately independent of any current location or search — unlike
/// the explore/search flow, this list never changes because the user
/// moved. Default view is a flat list with category/tag filter chips,
/// not a category drill-down.
class PersonalPlacesScreen extends StatefulWidget {
  const PersonalPlacesScreen({super.key});

  @override
  State<PersonalPlacesScreen> createState() => _PersonalPlacesScreenState();
}

class _PersonalPlacesScreenState extends State<PersonalPlacesScreen> {
  final _repository = TrackedPlaceRepository.instance;
  final _tts = TtsService.instance;

  List<TrackedPlace> _places = [];
  List<TrackedPlaceCategory> _categories = [];
  bool _loading = true;
  String? _categoryFilter;
  PlaceTag? _tagFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final places = await _repository.getAll();
    final categories = await _repository.getCategories();
    places.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _places = places;
      _categories = categories;
      _loading = false;
    });
  }

  List<TrackedPlace> get _filteredPlaces {
    return _places.where((place) {
      if (_categoryFilter != null && place.categoryId != _categoryFilter) {
        return false;
      }
      if (_tagFilter != null && place.tag != _tagFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  String _categoryLabel(String id) {
    for (final category in _categories) {
      if (category.id == id) return category.label;
    }
    return id;
  }

  Future<void> _togglePause(TrackedPlace place) async {
    final willPause = !place.isPaused;
    await _repository.setPaused(place.id, willPause);
    _tts.speak(willPause ? '${place.name} paused.' : '${place.name} resumed.');
    await _load();
  }

  Future<void> _delete(TrackedPlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete personal place?'),
        content: Text('This will permanently delete "${place.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.delete(place.id);
      _tts.speak('${place.name} deleted.');
      await _load();
    }
  }

  Future<void> _edit(TrackedPlace place) async {
    final updated = await Navigator.of(context).push<TrackedPlace>(
      MaterialPageRoute(
        builder: (_) => TrackPlaceScreen(
          name: place.name,
          lat: place.lat,
          lon: place.lon,
          addedVia: place.addedVia,
          existingPlace: place,
        ),
      ),
    );
    if (updated != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Places')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
          ? const _EmptyPersonalPlacesView()
          : Column(
              children: [
                _PersonalPlacesFilterBar(
                  categories: _categories,
                  selectedCategoryId: _categoryFilter,
                  selectedTag: _tagFilter,
                  onCategoryChanged: (id) =>
                      setState(() => _categoryFilter = id),
                  onTagChanged: (tag) => setState(() => _tagFilter = tag),
                ),
                Expanded(
                  child: _filteredPlaces.isEmpty
                      ? const Center(
                          child: Text('No personal places match this filter.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredPlaces.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final place = _filteredPlaces[index];
                            return _PersonalPlaceCard(
                              place: place,
                              categoryLabel: _categoryLabel(place.categoryId),
                              onEdit: () => _edit(place),
                              onTogglePause: () => _togglePause(place),
                              onDelete: () => _delete(place),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _EmptyPersonalPlacesView extends StatelessWidget {
  const _EmptyPersonalPlacesView();

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
              Icons.bookmark_outline,
              size: 80,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'You haven\'t tracked any personal places yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalPlacesFilterBar extends StatelessWidget {
  final List<TrackedPlaceCategory> categories;
  final String? selectedCategoryId;
  final PlaceTag? selectedTag;
  final void Function(String?) onCategoryChanged;
  final void Function(PlaceTag?) onTagChanged;

  const _PersonalPlacesFilterBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedTag,
    required this.onCategoryChanged,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'All categories',
                  selected: selectedCategoryId == null,
                  onSelected: () => onCategoryChanged(null),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: category.label,
                      selected: selectedCategoryId == category.id,
                      onSelected: () => onCategoryChanged(category.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'All importance levels',
                  selected: selectedTag == null,
                  onSelected: () => onTagChanged(null),
                ),
                for (final tag in PlaceTag.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: tag.label,
                      selected: selectedTag == tag,
                      onSelected: () => onTagChanged(tag),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: colorScheme.tertiary,
        labelStyle: TextStyle(
          color: selected
              ? colorScheme.onTertiary
              : colorScheme.onSurfaceVariant,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _PersonalPlaceCard extends StatelessWidget {
  final TrackedPlace place;
  final String categoryLabel;
  final VoidCallback onEdit;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  const _PersonalPlaceCard({
    required this.place,
    required this.categoryLabel,
    required this.onEdit,
    required this.onTogglePause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${place.name}, $categoryLabel, ${place.tag.label}'
          '${place.isPaused ? ', paused' : ''}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: place.isPaused
                            ? colorScheme.outline
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$categoryLabel  ·  ${place.tag.label}'
                      '${place.isPaused ? '  ·  Paused' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(
                  place.isPaused
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                ),
                tooltip: place.isPaused ? 'Resume alerts' : 'Pause alerts',
                onPressed: onTogglePause,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
