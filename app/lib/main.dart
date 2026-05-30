import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getBool('disclaimer_accepted') ?? false;
  runApp(AnaApp(showDisclaimer: !accepted));
}

class AnaApp extends StatelessWidget {
  final bool showDisclaimer;

  const AnaApp({super.key, required this.showDisclaimer});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accessibility Navigator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: showDisclaimer ? const DisclaimerScreen() : const HomeScreen(),
    );
  }
}
