import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/geo_utils.dart';
import '../models/route_plan.dart';
import '../services/api_service.dart';
import '../services/navigation/compass_heading_source.dart';
import '../services/navigation/exploration_session.dart';
import '../services/navigation/geolocator_position_source.dart';
import '../services/navigation/navigation_controller.dart';
import '../services/navigation/off_route_detector.dart';
import '../services/navigation/position_source.dart';
import '../services/navigation/tts_vibration_announcer.dart';
import '../services/tts_service.dart';
import '../services/vibration_service.dart';
import '../services/voice_service.dart';
import 'track_place_screen.dart';

class NavigationScreen extends StatefulWidget {
  final RoutePlan route;

  const NavigationScreen({super.key, required this.route});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _tts = TtsService.instance;
  late List<NavigationStep> _steps;
  int _current = 0;
  bool _navEnded = false;

  NavigationController? _navController;
  bool _isInitializingSensors = true;
  String? _sensorError;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _steps = widget.route.allSteps;
    if (_steps.isEmpty) {
      _steps = [
        const NavigationStep(
          instruction: 'You have arrived at your destination.',
          distanceMeters: 0,
        ),
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
    unawaited(_initializeRealTimeNavigation());
  }

  /// Starts continuous GPS/compass sensing, proximity alerts, and
  /// off-route detection on top of the existing manual step-paging UI.
  /// Failures here (permission denied, sensor errors) degrade to the
  /// manual-only experience rather than blocking navigation — Phase 4's
  /// sensing layer is additive.
  Future<void> _initializeRealTimeNavigation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _finishSensorInit(
          error:
              'Location permission was not granted, so real-time '
              'alerts are unavailable. Manual step controls still work '
              'below.',
        );
        return;
      }

      final explorationSession = ExplorationSession(
        apiService: ApiService.instance,
      );
      await explorationSession.initialize(widget.route.geometry);

      final controller = NavigationController(
        route: widget.route,
        positionSource: GeolocatorPositionSource(),
        headingSource: CompassHeadingSource(),
        announcer: TtsVibrationAnnouncer(),
        explorationSession: explorationSession,
      );
      await controller.start();
      final vibrationEnabled = await VibrationService.instance.isEnabled();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _navController = controller;
        _vibrationEnabled = vibrationEnabled;
        _isInitializingSensors = false;
      });
    } catch (e, stackTrace) {
      developer.log(
        'Failed to start real-time navigation sensing',
        name: 'app.navigation',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );
      _finishSensorInit(
        error:
            'Real-time navigation alerts could not be started. '
            'Manual step controls still work below.',
      );
    }
  }

  void _finishSensorInit({String? error}) {
    if (!mounted) return;
    setState(() {
      _isInitializingSensors = false;
      _sensorError = error;
    });
  }

  Future<void> _toggleVibration() async {
    final newValue = !_vibrationEnabled;
    await VibrationService.instance.setEnabled(newValue);
    if (mounted) {
      setState(() => _vibrationEnabled = newValue);
    }
  }

  /// In-trip quick capture (design doc §2.1.3 "行中实时捕捉"). Hardware
  /// button capture (cane button / headset remote) needs a separate
  /// native feasibility spike — this in-app button ships the same voice
  /// flow now, with a touch trigger instead.
  void _captureCurrentLocation() {
    final position = _navController?.currentState.lastPosition;
    if (position == null) {
      _tts.speakInterrupt('Still acquiring your location.');
      return;
    }
    _tts.speakThenRun(
      'Please say the name or note for this location.',
      () => unawaited(_finishCapture(position)),
    );
  }

  Future<void> _finishCapture(NavPosition position) async {
    final name = await VoiceService.instance.listen();
    if (name.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackPlaceScreen(
          name: name,
          lat: position.lat,
          lon: position.lon,
          addedVia: 'button_capture',
          skipCategoryStep: true,
        ),
      ),
    );
  }

  void _speakCurrent() {
    if (_navEnded) return;
    final step = _steps[_current];
    final prefix = 'Step ${_current + 1} of ${_steps.length}. ';
    _tts.speakInterrupt('$prefix${step.instruction}');
  }

  void _prev() {
    if (_current > 0) {
      setState(() => _current--);
      _speakCurrent();
    } else {
      _tts.speakInterrupt('This is the first step.');
    }
  }

  void _next() {
    if (_current < _steps.length - 1) {
      setState(() => _current++);
      _speakCurrent();
    } else {
      _tts.speakInterrupt(
        'This is the last step. You have arrived at your destination.',
      );
    }
  }

  void _repeat() => _speakCurrent();

  void _endNavigation() {
    _tts.stop();
    setState(() => _navEnded = true);
    _tts.speak(
      'Navigation ended. Thank you for using the Accessibility Navigation Assistant.',
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    final controller = _navController;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_current];
    final isFirst = _current == 0;
    final isLast = _current == _steps.length - 1;
    final progress = (_current + 1) / _steps.length;

    // Deliberately stays dark regardless of the app's light theme: this
    // screen is used outdoors mid-walk, where a dark, high-contrast UI
    // reduces glare and battery draw compared to the rest of the app.
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: Text('Navigation · ${widget.route.modeLabel}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'End navigation',
          onPressed: _endNavigation,
        ),
        actions: [
          if (!_isInitializingSensors && _sensorError == null) ...[
            Semantics(
              button: true,
              label: 'Mark this location as a personal place',
              child: IconButton(
                icon: const Icon(Icons.add_location_alt),
                tooltip: 'Mark this location',
                onPressed: _captureCurrentLocation,
              ),
            ),
            Semantics(
              button: true,
              label: _vibrationEnabled
                  ? 'Vibration alerts on. Tap to turn off.'
                  : 'Vibration alerts off. Tap to turn on.',
              child: IconButton(
                icon: Icon(
                  _vibrationEnabled ? Icons.vibration : Icons.do_not_disturb_on,
                ),
                tooltip: 'Toggle vibration alerts',
                onPressed: _toggleVibration,
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(progress),
            _buildSensorPanel(),
            Expanded(child: _buildStepDisplay(step, isLast)),
            _buildControlPanel(isFirst, isLast),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorPanel() {
    if (_isInitializingSensors) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'Starting real-time navigation sensors…',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      );
    }
    if (_sensorError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          _sensorError!,
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
        ),
      );
    }
    final controller = _navController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<NavigationState>(
      stream: controller.stateUpdates,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        return _SensorHud(state: snapshot.data ?? controller.currentState);
      },
    );
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Semantics(
            label:
                'Navigation progress: step ${_current + 1} of ${_steps.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Step ${_current + 1} of ${_steps.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          color: Theme.of(context).colorScheme.primary,
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildStepDisplay(NavigationStep step, bool isLast) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            label: step.instruction,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                children: [
                  const Icon(Icons.navigation, color: Colors.white70, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    step.instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  if (step.distanceMeters > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      step.distanceMeters < 1000
                          ? 'approx. ${step.distanceMeters.round()} metres'
                          : 'approx. ${(step.distanceMeters / 1000).toStringAsFixed(1)} kilometres',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isLast)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: const Text(
                'Final step · Arriving at destination',
                style: TextStyle(color: Colors.greenAccent, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(bool isFirst, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Previous step',
                  child: SizedBox(
                    height: 72,
                    child: ElevatedButton.icon(
                      onPressed: isFirst ? null : _prev,
                      icon: const Icon(Icons.arrow_back, size: 28),
                      label: const Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Repeat current step',
                  child: SizedBox(
                    height: 72,
                    child: ElevatedButton.icon(
                      onPressed: _repeat,
                      icon: const Icon(Icons.volume_up, size: 28),
                      label: const Text(
                        'Repeat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Next step',
                  child: SizedBox(
                    height: 72,
                    child: ElevatedButton.icon(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward, size: 28),
                      label: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton.icon(
              onPressed: _endNavigation,
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: Colors.redAccent,
                size: 24,
              ),
              label: const Text(
                'End Navigation',
                style: TextStyle(color: Colors.redAccent, fontSize: 17),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the real-time sensing HUD: facing direction, route progress,
/// the current-step approximation, and an off-route warning when
/// applicable.
class _SensorHud extends StatelessWidget {
  const _SensorHud({required this.state});

  final NavigationState state;

  static const _textStyle = TextStyle(color: Colors.white70, fontSize: 14);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${_headingText()}. ${_progressText()}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_headingText(), style: _textStyle),
              const SizedBox(height: 4),
              Text(_progressText(), style: _textStyle),
              if (state.offRouteSeverity != OffRouteSeverity.onRoute) ...[
                const SizedBox(height: 4),
                Text(
                  state.offRouteSeverity == OffRouteSeverity.offRoute
                      ? 'You may be off the route.'
                      : 'Checking your direction…',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _headingText() {
    final heading = state.headingDegrees;
    if (heading == null) return 'Facing direction unavailable';
    return 'Facing ${compassDirectionLabel(heading)}';
  }

  String _progressText() {
    if (!state.routeProgressAvailable) {
      return 'Route progress is unavailable for this route';
    }
    final fraction = state.progressFraction;
    if (fraction == null) return 'Waiting for a GPS fix…';
    final percent = (fraction * 100).round();
    final step = state.currentStepDescription;
    return step == null ? '$percent% complete' : '$percent% complete — $step';
  }
}
