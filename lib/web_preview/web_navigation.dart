import 'package:flutter/material.dart';
import '../core/widgets/animated_bottom_nav.dart';
import '../features/entertainment/presentation/entertainment_feed_screen.dart';
import '../features/services/presentation/services_screen.dart';
import 'web_home_screen.dart';
import 'web_stub_screens.dart';

class WebNavigation extends StatefulWidget {
  const WebNavigation({super.key});

  @override
  State<WebNavigation> createState() => _WebNavigationState();
}

class _WebNavigationState extends State<WebNavigation> {
  int _currentIndex = 0;

  late final _screens = [
    const WebHomeScreen(),
    const WebChatPreviewScreen(),
    const WebStatusPreviewScreen(),
    const EntertainmentFeedScreen(),
    const ServicesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: const Color(0xFF1E293B),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.chrome_reader_mode, color: Color(0xFF00F2FE), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chrome preview — Send/Receive/Vault/Status Android app par full kaam karte hain.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _screens[_currentIndex],
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
