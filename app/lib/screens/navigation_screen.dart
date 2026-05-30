import 'package:flutter/material.dart';
import '../models/route_plan.dart';
import '../services/tts_service.dart';

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

  @override
  void initState() {
    super.initState();
    _steps = widget.route.allSteps;
    if (_steps.isEmpty) {
      _steps = [
        const NavigationStep(
            instruction: 'You have arrived at your destination.',
            distanceMeters: 0)
      ];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
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
          'This is the last step. You have arrived at your destination.');
    }
  }

  void _repeat() => _speakCurrent();

  void _endNavigation() {
    _tts.stop();
    setState(() => _navEnded = true);
    _tts.speak(
        'Simulated navigation ended. Thank you for using the Accessibility Navigation Assistant.');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_current];
    final isFirst = _current == 0;
    final isLast = _current == _steps.length - 1;
    final progress = (_current + 1) / _steps.length;

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
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(progress),
            Expanded(child: _buildStepDisplay(step, isLast)),
            _buildControlPanel(isFirst, isLast),
          ],
        ),
      ),
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
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white24,
          color: const Color(0xFF42A5F5),
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
                border: Border.all(
                  color: Colors.white24,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.navigation,
                      color: Colors.white70, size: 40),
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
                          color: Colors.white60, fontSize: 18),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isLast)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: const Text(
                'Final step · Arriving at destination',
                style:
                    TextStyle(color: Colors.greenAccent, fontSize: 16),
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
                      label: const Text('Previous',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
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
                      label: const Text('Repeat',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
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
                      label: const Text('Next',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
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
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.redAccent, size: 24),
              label: const Text(
                'End Navigation',
                style:
                    TextStyle(color: Colors.redAccent, fontSize: 17),
              ),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side:
                      const BorderSide(color: Colors.redAccent, width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
