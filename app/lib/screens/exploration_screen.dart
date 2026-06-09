import 'package:flutter/material.dart';
import '../models/place.dart';
import '../models/exploration_item.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import 'debug_map_screen.dart';

class ExplorationScreen extends StatefulWidget {
  final Place centerPlace;

  const ExplorationScreen({super.key, required this.centerPlace});

  @override
  State<ExplorationScreen> createState() => _ExplorationScreenState();
}

class _ExplorationScreenState extends State<ExplorationScreen> {
  final _ttsService = TtsService.instance;
  final _apiService = ApiService.instance;

  List<ExplorationCategory> _categories = [];
  bool _loading = true;
  int _selectedCategoryIndex = 0;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadExploration();
  }

  Future<void> _loadExploration() async {
    setState(() => _loading = true);
    final categories = await _apiService.nearbyExploration(
      lat: widget.centerPlace.lat,
      lon: widget.centerPlace.lon,
    );
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

  List<ExplorationItem> get _currentItems {
    if (_categories.isEmpty) return [];
    return _categories[_selectedCategoryIndex].items;
  }

  ExplorationItem? get _currentItem {
    if (_currentItems.isEmpty) return null;
    return _currentItems[_currentItemIndex];
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

  void _playPrev() {
    if (_currentItemIndex > 0) {
      setState(() => _currentItemIndex--);
      _ttsService.speakInterrupt(_currentItem!.ttsText);
    } else {
      _ttsService.speakInterrupt('This is the first location.');
    }
  }

  void _playNext() {
    if (_currentItemIndex < _currentItems.length - 1) {
      setState(() => _currentItemIndex++);
      _ttsService.speakInterrupt(_currentItem!.ttsText);
    } else {
      _ttsService.speakInterrupt('This is the last location.');
    }
  }

  void _repeatCurrent() {
    if (_currentItem != null) {
      _ttsService.speakInterrupt(_currentItem!.ttsText);
    }
  }

  void _playAll() {
    if (_currentItems.isEmpty) return;
    final text = _currentItems.map((item) => item.ttsText).join('. Next: ');
    _ttsService.speakInterrupt(
      'All ${_categories[_selectedCategoryIndex].label}: $text.',
    );
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore · ${widget.centerPlace.name}'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _currentItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'View category on map',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DebugMapScreen(
                    origin: widget.centerPlace,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const _EmptyExplorationView()
              : Column(
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
                        selectedIndex: _currentItemIndex,
                        onSelectItem: _selectItem,
                      ),
                    ),
                    if (_currentItems.isNotEmpty)
                      _ExplorationPlayerControls(
                        currentIndex: _currentItemIndex,
                        totalItems: _currentItems.length,
                        onPrevious: _playPrev,
                        onRepeat: _repeatCurrent,
                        onNext: _playNext,
                        onReadAll: _playAll,
                      ),
                  ],
                ),
    );
  }
}

class _EmptyExplorationView extends StatelessWidget {
  const _EmptyExplorationView();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'No nearby exploration data available.',
          style: TextStyle(fontSize: 16),
        ),
      );
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
    return Container(
      color: Colors.teal[50],
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
              label:
                  '${category.label}, ${category.items.length} locations',
              selected: selected,
              button: true,
              child: ChoiceChip(
                label: Text(
                  '${category.label} (${category.items.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.teal[800],
                  ),
                ),
                selected: selected,
                selectedColor: Colors.teal[700],
                onSelected: (_) => onSelect(index),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExplorationItemList extends StatelessWidget {
  final List<ExplorationItem> items;
  final int selectedIndex;
  final void Function(int) onSelectItem;

  const _ExplorationItemList({
    required this.items,
    required this.selectedIndex,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No locations in this category.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = index == selectedIndex;
        return Semantics(
          label: item.ttsText,
          selected: isSelected,
          button: true,
          child: Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Colors.teal[50] : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(color: Colors.teal[700]!, width: 2)
                  : BorderSide.none,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    isSelected ? Colors.teal[700] : Colors.teal[100],
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.teal[800],
                    fontWeight: FontWeight.bold,
                  ),
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
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => onSelectItem(index),
              ),
              onTap: () => onSelectItem(index),
            ),
          ),
        );
      },
    );
  }
}

class _ExplorationPlayerControls extends StatelessWidget {
  final int currentIndex;
  final int totalItems;
  final VoidCallback onPrevious;
  final VoidCallback onRepeat;
  final VoidCallback onNext;
  final VoidCallback onReadAll;

  const _ExplorationPlayerControls({
    required this.currentIndex,
    required this.totalItems,
    required this.onPrevious,
    required this.onRepeat,
    required this.onNext,
    required this.onReadAll,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = currentIndex == 0;
    final isLast = currentIndex == totalItems - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${currentIndex + 1} / $totalItems',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Previous location',
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: isFirst ? null : onPrevious,
                      icon: const Icon(Icons.arrow_back, size: 22),
                      label: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Repeat current location',
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: onRepeat,
                      icon: const Icon(Icons.volume_up, size: 22),
                      label: const Text(
                        'Repeat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Next location',
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: isLast ? null : onNext,
                      icon: const Icon(Icons.arrow_forward, size: 22),
                      label: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.playlist_play, size: 22),
              label: const Text(
                'Read All Locations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: onReadAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal[800],
                side: BorderSide(color: Colors.teal[700]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
