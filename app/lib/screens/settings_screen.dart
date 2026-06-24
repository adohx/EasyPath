import 'package:flutter/material.dart';
import '../services/vibration_service.dart';
import 'disclaimer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _vibrationEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVibrationSetting();
  }

  Future<void> _loadVibrationSetting() async {
    final enabled = await VibrationService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _vibrationEnabled = enabled;
      _loading = false;
    });
  }

  Future<void> _setVibrationEnabled(bool value) async {
    setState(() => _vibrationEnabled = value);
    await VibrationService.instance.setEnabled(value);
  }

  void _openSafetyNotice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DisclaimerScreen(reviewOnly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibration alerts'),
            subtitle: const Text(
              'Vibrate for off-route warnings and approaching stops.',
            ),
            value: _vibrationEnabled,
            onChanged: _loading ? null : _setVibrationEnabled,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About / Safety Notice'),
            subtitle: const Text(
              'Review the data sources and safety disclaimer.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSafetyNotice,
          ),
        ],
      ),
    );
  }
}
