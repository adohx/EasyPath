import 'package:flutter/material.dart';
import '../models/place_tag.dart';
import '../models/tracked_place.dart';
import '../models/tracked_place_category.dart';
import '../services/tracked_place_repository.dart';
import '../services/tts_service.dart';

/// Saves a place to the user's personal place library (design doc
/// §1.1.3, §2.1.3): pick a category, then pick an importance tag.
///
/// Pass [existingPlace] to edit an already-tracked place instead of
/// creating a new one — name, category and tag are all editable then.
/// Set [skipCategoryStep] for in-trip quick capture, which files the new
/// place under "Uncategorized" and asks only for the tag.
///
/// Pops with the saved [TrackedPlace] on success, or `null` if the user
/// backs out.
class TrackPlaceScreen extends StatefulWidget {
  final String name;
  final double lat;
  final double lon;
  final String addedVia;
  final bool skipCategoryStep;
  final TrackedPlace? existingPlace;

  const TrackPlaceScreen({
    super.key,
    required this.name,
    required this.lat,
    required this.lon,
    required this.addedVia,
    this.skipCategoryStep = false,
    this.existingPlace,
  });

  @override
  State<TrackPlaceScreen> createState() => _TrackPlaceScreenState();
}

class _TrackPlaceScreenState extends State<TrackPlaceScreen> {
  final _tts = TtsService.instance;
  final _repository = TrackedPlaceRepository.instance;
  late final TextEditingController _nameController;

  List<TrackedPlaceCategory> _categories = [];
  bool _loadingCategories = true;
  late int _step;
  String? _selectedCategoryId;

  bool get _isEditing => widget.existingPlace != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingPlace?.name ?? widget.name,
    );
    _selectedCategoryId =
        widget.existingPlace?.categoryId ?? kUncategorizedCategoryId;
    _step = widget.skipCategoryStep ? 1 : 0;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _repository.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loadingCategories = false;
    });
    if (_step == 0) {
      _speakCategoryPrompt();
    } else {
      _speakTagPrompt();
    }
  }

  void _speakCategoryPrompt() {
    final names = _categories.map((c) => c.label).join(', ');
    _tts.speakInterrupt('Please choose a category: $names.');
  }

  void _speakTagPrompt() {
    final names = PlaceTag.values.map((t) => t.label).join('. ');
    _tts.speakInterrupt('Please choose its importance: $names.');
  }

  void _selectCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _step = 1;
    });
    _speakTagPrompt();
  }

  Future<void> _addCustomCategory(String label) async {
    if (label.trim().isEmpty) return;
    final category = await _repository.addCategory(label.trim());
    if (!mounted) return;
    setState(() {
      _categories = [..._categories, category];
    });
    _selectCategory(category.id);
  }

  Future<void> _selectTag(PlaceTag tag) async {
    final name = _nameController.text.trim().isEmpty
        ? widget.name
        : _nameController.text.trim();
    final categoryId = _selectedCategoryId ?? kUncategorizedCategoryId;

    final TrackedPlace saved;
    if (_isEditing) {
      saved = widget.existingPlace!.copyWith(
        name: name,
        categoryId: categoryId,
        tag: tag,
      );
      await _repository.update(saved);
      _tts.speakInterrupt('Updated $name.');
    } else {
      saved = await _repository.add(
        name: name,
        lat: widget.lat,
        lon: widget.lon,
        categoryId: categoryId,
        tag: tag,
        addedVia: widget.addedVia,
      );
      _tts.speakInterrupt('Saved $name as a personal place. ${tag.label}.');
    }
    if (mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Personal Place' : 'Track This Place'),
        leading: _step == 1 && !widget.skipCategoryStep
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to category',
                onPressed: () => setState(() => _step = 0),
              )
            : null,
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : _step == 0
          ? _CategoryStep(
              name: _nameController.text,
              nameController: _isEditing ? _nameController : null,
              categories: _categories,
              selectedCategoryId: _selectedCategoryId,
              onSelectCategory: _selectCategory,
              onAddCategory: _addCustomCategory,
            )
          : _TagStep(
              name: _nameController.text,
              selectedTag: widget.existingPlace?.tag,
              onSelectTag: _selectTag,
            ),
    );
  }
}

class _CategoryStep extends StatefulWidget {
  final String name;
  final TextEditingController? nameController;
  final List<TrackedPlaceCategory> categories;
  final String? selectedCategoryId;
  final void Function(String categoryId) onSelectCategory;
  final void Function(String label) onAddCategory;

  const _CategoryStep({
    required this.name,
    required this.nameController,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    required this.onAddCategory,
  });

  @override
  State<_CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends State<_CategoryStep> {
  final _newCategoryController = TextEditingController();
  bool _addingCategory = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: widget.nameController != null
              ? TextField(
                  controller: widget.nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                )
              : Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Choose a category',
            style: TextStyle(fontSize: 16, color: colorScheme.outline),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final category in widget.categories)
                Semantics(
                  button: true,
                  selected: category.id == widget.selectedCategoryId,
                  label: category.label,
                  child: Card(
                    color: category.id == widget.selectedCategoryId
                        ? colorScheme.tertiaryContainer
                        : null,
                    child: ListTile(
                      title: Text(category.label),
                      onTap: () => widget.onSelectCategory(category.id),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_addingCategory)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'New category name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          widget.onAddCategory(_newCategoryController.text),
                      child: const Text('Save'),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add a new category'),
                  onPressed: () => setState(() => _addingCategory = true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagStep extends StatelessWidget {
  final String name;
  final PlaceTag? selectedTag;
  final void Function(PlaceTag tag) onSelectTag;

  const _TagStep({
    required this.name,
    required this.selectedTag,
    required this.onSelectTag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'How important is this for real-time alerts?',
            style: TextStyle(fontSize: 16, color: colorScheme.outline),
          ),
          const SizedBox(height: 24),
          for (final tag in PlaceTag.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                selected: tag == selectedTag,
                label: tag.label,
                child: SizedBox(
                  height: 72,
                  child: ElevatedButton(
                    onPressed: () => onSelectTag(tag),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tag == selectedTag
                          ? colorScheme.tertiary
                          : colorScheme.tertiaryContainer,
                      foregroundColor: tag == selectedTag
                          ? colorScheme.onTertiary
                          : colorScheme.onTertiaryContainer,
                    ),
                    child: Text(
                      tag.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
