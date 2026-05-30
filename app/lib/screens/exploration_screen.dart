import 'package:flutter/material.dart';
import '../models/place.dart';
import '../models/exploration_item.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';

class ExplorationScreen extends StatefulWidget {
  final Place centerPlace;

  const ExplorationScreen({super.key, required this.centerPlace});

  @override
  State<ExplorationScreen> createState() => _ExplorationScreenState();
}

class _ExplorationScreenState extends State<ExplorationScreen> {
  final _tts = TtsService.instance;
  final _api = ApiService.instance;

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
    final cats = await _api.nearbyExploration(
      lat: widget.centerPlace.lat,
      lon: widget.centerPlace.lon,
    );
    setState(() {
      _categories = cats;
      _loading = false;
      _selectedCategoryIndex = 0;
      _currentItemIndex = 0;
    });
    if (cats.isNotEmpty) {
      final catNames = cats.map((c) => c.label).join(', ');
      _tts.speak(
          '${cats.length} categories nearby: $catNames. Select a category to explore.');
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
    final cat = _categories[index];
    _tts.speakInterrupt(
        '${cat.label}, ${cat.items.length} location${cat.items.length == 1 ? '' : 's'}. '
        '${cat.items.isNotEmpty ? cat.items.first.ttsText : ''}');
  }

  void _playPrev() {
    if (_currentItemIndex > 0) {
      setState(() => _currentItemIndex--);
      _tts.speakInterrupt(_currentItem!.ttsText);
    } else {
      _tts.speakInterrupt('This is the first location.');
    }
  }

  void _playNext() {
    if (_currentItemIndex < _currentItems.length - 1) {
      setState(() => _currentItemIndex++);
      _tts.speakInterrupt(_currentItem!.ttsText);
    } else {
      _tts.speakInterrupt('This is the last location.');
    }
  }

  void _repeatCurrent() {
    if (_currentItem != null) {
      _tts.speakInterrupt(_currentItem!.ttsText);
    }
  }

  void _playAll() {
    if (_currentItems.isEmpty) return;
    final text = _currentItems.map((i) => i.ttsText).join('. Next: ');
    _tts.speakInterrupt(
        'All ${_categories[_selectedCategoryIndex].label}: $text.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore · ${widget.centerPlace.name}'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    _buildCategoryChips(),
                    const Divider(height: 1),
                    Expanded(child: _buildItemList()),
                    if (_currentItems.isNotEmpty) _buildPlayerControls(),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text('No nearby exploration data available.',
          style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.teal[50],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = i == _selectedCategoryIndex;
            return Semantics(
              label: '${cat.label}, ${cat.items.length} locations',
              selected: selected,
              button: true,
              child: ChoiceChip(
                label: Text(
                  '${cat.label} (${cat.items.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        selected ? Colors.white : Colors.teal[800],
                  ),
                ),
                selected: selected,
                selectedColor: Colors.teal[700],
                onSelected: (_) => _selectCategory(i),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemList() {
    final items = _currentItems;
    if (items.isEmpty) {
      return const Center(
          child: Text('No locations in this category.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final isSelected = i == _currentItemIndex;
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? Colors.teal[700]
                    : Colors.teal[100],
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.teal[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                item.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${item.distanceLabel}  ·  ${item.bearingLabel}',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () {
                  setState(() => _currentItemIndex = i);
                  _tts.speakInterrupt(item.ttsText);
                },
              ),
              onTap: () {
                setState(() => _currentItemIndex = i);
                _tts.speakInterrupt(item.ttsText);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerControls() {
    final items = _currentItems;
    final isFirst = _currentItemIndex == 0;
    final isLast = _currentItemIndex == items.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_currentItemIndex + 1} / ${items.length}',
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
                      onPressed: isFirst ? null : _playPrev,
                      icon: const Icon(Icons.arrow_back, size: 22),
                      label: const Text('Previous',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
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
                      onPressed: _repeatCurrent,
                      icon: const Icon(Icons.volume_up, size: 22),
                      label: const Text('Repeat',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
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
                      onPressed: isLast ? null : _playNext,
                      icon: const Icon(Icons.arrow_forward, size: 22),
                      label: const Text('Next',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
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
              label: const Text('Read All Locations',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: _playAll,
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
