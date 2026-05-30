import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/place.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/large_button.dart';
import 'route_selection_screen.dart';
import 'exploration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _tts = TtsService.instance;
  final _api = ApiService.instance;
  final _speech = SpeechToText();

  List<Place> _results = [];
  bool _loading = false;
  bool _speechAvailable = false;
  bool _listening = false;
  Place? _selectedOrigin;

  static const Place _defaultOrigin = Place(
    id: 'origin_default',
    name: 'Current Location (Simulated)',
    address: 'Ouellette Ave & Wyandotte St, Windsor, ON',
    lat: 42.3150,
    lon: -83.0360,
  );

  @override
  void initState() {
    super.initState();
    _selectedOrigin = _defaultOrigin;
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts.speak(
          'Welcome to the Accessibility Navigation Assistant. Enter a destination or hold the microphone button to speak.');
    });
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    setState(() => _speechAvailable = available);
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _results = [];
    });
    final results = await _api.searchPlaces(query.trim());
    setState(() {
      _loading = false;
      _results = results;
    });
    if (results.isEmpty) {
      _tts.speak('No locations found. Please try a different search term.');
    } else {
      _tts.speak(
          '${results.length} location${results.length == 1 ? '' : 's'} found. Please select your destination.');
    }
  }

  void _startListening() async {
    if (!_speechAvailable) {
      _tts.speak('Speech recognition is unavailable. Please check microphone permissions.');
      return;
    }
    await _tts.stop();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _controller.text = result.recognizedWords;
          setState(() => _listening = false);
          _search(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(localeId: 'en_CA'),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _listening = false);
  }

  void _selectDestination(Place dest) {
    _tts.speak('Destination: ${dest.name}. Planning route, please wait.');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteSelectionScreen(
          origin: _selectedOrigin!,
          destination: dest,
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
    _speech.cancel();
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
            icon: const Icon(Icons.explore),
            tooltip: 'Explore nearby',
            onPressed: () => _openExploration(_selectedOrigin!),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOriginBar(),
          _buildSearchBar(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_results.isNotEmpty)
            Expanded(child: _buildResults())
          else
            Expanded(child: _buildHint()),
        ],
      ),
    );
  }

  Widget _buildOriginBar() {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'From: ${_selectedOrigin!.name}',
              style: const TextStyle(fontSize: 15, color: Color(0xFF1565C0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Destination input field',
              textField: true,
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Enter destination',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF1565C0), width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF1565C0), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                ),
                onSubmitted: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: _listening ? 'Listening — release to stop' : 'Hold to speak',
            button: true,
            child: GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _listening
                      ? Colors.red[600]
                      : const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Search',
            button: true,
            child: SizedBox(
              width: 64,
              height: 64,
              child: ElevatedButton(
                onPressed: () => _search(_controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child:
                    const Icon(Icons.search, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final place = _results[i];
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
              onTap: () => _selectDestination(place),
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
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.explore, size: 20),
                            label: const Text('Explore Nearby'),
                            onPressed: () => _openExploration(place),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.directions, size: 20),
                            label: const Text('Get Directions'),
                            onPressed: () => _selectDestination(place),
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
      },
    );
  }

  Widget _buildHint() {
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
              onPressed: () => _openExploration(_selectedOrigin!),
              backgroundColor: Colors.teal[700],
            ),
          ],
        ),
      ),
    );
  }
}
