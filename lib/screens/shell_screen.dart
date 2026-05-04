import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    switch (location) {
      case '/feed':        return 0;
      case '/log':         return 1;
      case '/challenges':  return 2;
      case '/dashboard':   return 3;
      case '/profile':     return 4;
      default:             return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        backgroundColor: const Color(0xFF0D1120),
        indicatorColor: const Color(0xFF0057FF).withOpacity(0.2),
        onDestinationSelected: (index) {
          switch (index) {
            case 0: context.go('/feed'); break;
            case 1: context.go('/log'); break;
            case 2: context.go('/challenges'); break;
            case 3: context.go('/dashboard'); break;
            case 4: context.go('/profile'); break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Challenges'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
