import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/large_button.dart';
import 'home_screen.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimer_accepted', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: const Text(
                  'Safety Notice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accessibility Navigation Assistant · Phase 1',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _DisclaimerItem(
                        icon: Icons.info_outline,
                        text:
                            'This is a Phase 1 demo. All route and location data is simulated (mock data) for testing purposes only and does not reflect real conditions.',
                      ),
                      SizedBox(height: 16),
                      _DisclaimerItem(
                        icon: Icons.warning_amber_rounded,
                        text:
                            'This app cannot replace your personal judgement. Route information is for reference only. Always rely on actual conditions when travelling.',
                      ),
                      SizedBox(height: 16),
                      _DisclaimerItem(
                        icon: Icons.schedule,
                        text:
                            'Bus times shown are scheduled times only and do not represent real-time arrivals. Please check live transit information before travelling.',
                      ),
                      SizedBox(height: 16),
                      _DisclaimerItem(
                        icon: Icons.construction,
                        text:
                            'Road works and temporary closures may not be captured. Watch for on-site notices when travelling.',
                      ),
                      SizedBox(height: 16),
                      _DisclaimerItem(
                        icon: Icons.security,
                        text:
                            'At intersections, bus stops, and other key points, prioritise your own safety and actual environment over any app guidance.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LargeButton(
                label: 'I Understand — Continue',
                icon: Icons.check_circle_outline,
                onPressed: () => _accept(context),
                semanticLabel:
                    'I have read the safety notice. Tap to continue to the app.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DisclaimerItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }
}
