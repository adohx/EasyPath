import 'package:flutter/material.dart';
import '../services/explore_center_controller.dart';
import 'exploration_screen.dart';
import 'home_screen.dart';
import 'personal_places_screen.dart';
import 'settings_screen.dart';

/// App root once the safety disclaimer has been accepted. Hosts the
/// four primary tabs behind a single bottom `NavigationBar`, with one
/// root `Navigator` shared by every screen pushed from any tab.
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  final _exploreCenterController = ExploreCenterController.instance;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _exploreCenterController.addListener(_onRecenterRequested);
  }

  void _onRecenterRequested() {
    if (_exploreCenterController.pendingCenter == null) return;
    setState(() => _selectedIndex = 1);
  }

  @override
  void dispose() {
    _exploreCenterController.removeListener(_onRecenterRequested);
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          ExplorationScreen(),
          PersonalPlacesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'My Places',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
