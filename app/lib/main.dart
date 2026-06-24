import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/main_tab_screen.dart';

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
    // `vibrant` keeps primary close to the seed's actual saturation —
    // the default `tonalSpot` algorithm mutes a vivid blue seed into a
    // washed grey-blue, which undersells the brand colour everywhere
    // it's referenced via `colorScheme.primary`.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    return MaterialApp(
      title: 'Accessibility Navigator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surface,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.surfaceContainerHighest,
          selectedColor: colorScheme.primaryContainer,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primaryContainer,
          elevation: 1,
        ),
        dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      ),
      home: showDisclaimer ? const DisclaimerScreen() : const MainTabScreen(),
    );
  }
}
