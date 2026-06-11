import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/animated_bottom_nav.dart';
import '../features/transfer/presentation/home_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/status_saver/presentation/status_screen.dart';
import '../features/entertainment/presentation/entertainment_feed_screen.dart';
import '../features/downloader/presentation/downloader_screen.dart';
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
    const DownloaderScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
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
      extendBody: true,
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
