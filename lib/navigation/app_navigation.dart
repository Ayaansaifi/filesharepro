import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/animated_bottom_nav.dart';
import '../features/transfer/presentation/home_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/status_saver/presentation/status_screen.dart';
import '../features/entertainment/presentation/entertainment_feed_screen.dart';
import '../features/services/presentation/services_screen.dart';
class AppNavigation extends ConsumerStatefulWidget {
  const AppNavigation({super.key});

  @override
  ConsumerState<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends ConsumerState<AppNavigation> {
  int _currentIndex = 0;

  final _screens = [
    const HomeScreen(),
    const ChatListScreen(),
    const StatusScreen(),
    const EntertainmentFeedScreen(),
    const ServicesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (kIsWeb) _buildWebPreviewBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
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

  Widget _buildWebPreviewBanner() {
    return Material(
      color: const Color(0xFF1E293B),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF00F2FE), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Web preview — full P2P/Nearby works on Android app. UI check ke liye yahan theek hai.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
