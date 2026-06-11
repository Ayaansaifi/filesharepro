import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../chat/providers/chat_provider.dart';
import '../../profile/presentation/profile_setup_screen.dart';
import '../../../navigation/app_navigation.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Secure P2P Chat',
      description: 'Chat directly with your friends without any servers. Your data never leaves your devices.',
      icon: Icons.security_rounded,
      color: AppColors.primaryCyan,
    ),
    OnboardingPageData(
      title: 'Lightning Fast Transfers',
      description: 'Share large files in seconds using WebRTC and local Wi-Fi technology.',
      icon: Icons.bolt_rounded,
      color: AppColors.primaryPurple,
    ),
    OnboardingPageData(
      title: 'Private Vault',
      description: 'Keep your sensitive files safe with a 4-digit PIN encrypted vault.',
      icon: Icons.lock_rounded,
      color: AppColors.success,
    ),
  ];

  void _nextPage() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Finish onboarding
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('has_seen_onboarding', true);

      if (!mounted) return;

      final profile = ref.read(myProfileProvider);
      if (profile == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              onComplete: (ctx) {
                Navigator.pushReplacement(
                  ctx,
                  MaterialPageRoute(builder: (_) => const AppNavigation()),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppNavigation()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () {
                    _pageController.animateToPage(
                      _pages.length - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Text(
                    'Skip',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.textHint),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Indicators & Button
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primaryCyan
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ).copyWith(
                          elevation: WidgetStateProperty.all(0),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPageData data) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: data.color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(data.icon, size: 80, color: data.color),
          ),
          const SizedBox(height: 48),
          Text(
            data.title,
            style: AppTypography.heading1.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
