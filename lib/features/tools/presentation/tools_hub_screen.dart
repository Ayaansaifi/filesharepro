import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'image_to_pdf_screen.dart';
import 'image_resizer_screen.dart';
import 'bp_checker_screen.dart';
import 'pdf_maker_screen.dart';
import 'meme_generator_screen.dart';

class ToolsHubScreen extends StatefulWidget {
  const ToolsHubScreen({super.key});

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  static final _tools = <_ToolItem>[
    _ToolItem(
      title: 'Image to PDF',
      titleHi: 'इमेज से PDF',
      subtitle: 'Convert multiple images into a single PDF file',
      icon: Icons.picture_as_pdf_rounded,
      gradient: const [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
      glowColor: const Color(0xFFFF6B6B),
    ),
    _ToolItem(
      title: 'Image Resizer',
      titleHi: 'इमेज रिसाइज़र',
      subtitle: 'Resize & compress images to any dimension',
      icon: Icons.photo_size_select_large_rounded,
      gradient: const [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
      glowColor: const Color(0xFF6C5CE7),
    ),
    _ToolItem(
      title: 'BP Checker',
      titleHi: 'बीपी चेकर',
      subtitle: 'Check & track your blood pressure readings',
      icon: Icons.monitor_heart_rounded,
      gradient: const [Color(0xFF00B894), Color(0xFF00CEC9)],
      glowColor: const Color(0xFF00B894),
    ),
    _ToolItem(
      title: 'PDF Maker',
      titleHi: 'PDF बनाएं',
      subtitle: 'Create professional PDFs from text & notes',
      icon: Icons.note_add_rounded,
      gradient: const [Color(0xFFFDCB6E), Color(0xFFE17055)],
      glowColor: const Color(0xFFFDCB6E),
    ),
    _ToolItem(
      title: 'Meme Generator',
      titleHi: 'मीम मेकर',
      subtitle: 'Create, edit & save funny memes locally',
      icon: Icons.sentiment_very_satisfied_rounded,
      gradient: const [Color(0xFF00CEC9), Color(0xFF74B9FF)],
      glowColor: const Color(0xFF00CEC9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              Color(0xFF0F1630),
              Color(0xFF1A1F38),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              Expanded(child: _buildToolsGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Utility Tools',
                  style: AppTypography.heading1.copyWith(
                    fontSize: 32,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Handy tools at your fingertips ✨',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.primaryCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.build_circle_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        padding: const EdgeInsets.only(bottom: 120, top: 4),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          return _buildToolCard(_tools[index], index);
        },
      ),
    );
  }

  Widget _buildToolCard(_ToolItem tool, int index) {
    final delay = (index * 0.1).clamp(0.0, 0.6);
    final end = (delay + 0.4).clamp(0.0, 1.0);

    final animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(delay, end, curve: Curves.easeOutBack),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: (0.7 + 0.3 * animation.value).clamp(0.7, 1.0),
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - animation.value)),
            child: Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _navigateToTool(index);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: tool.glowColor.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: tool.glowColor.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Stack(
                children: [
                  // Glow circle
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            tool.glowColor.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon container
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: tool.gradient,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: tool.gradient[0].withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(tool.icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          tool.title,
                          style: AppTypography.heading3.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tool.titleHi,
                          style: TextStyle(
                            color: tool.glowColor.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Expanded(
                          child: Text(
                            tool.subtitle,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              height: 1.3,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Arrow
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: tool.glowColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: tool.glowColor.withValues(alpha: 0.2)),
                            ),
                            child: Icon(Icons.arrow_forward_rounded,
                                color: tool.glowColor, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToTool(int index) {
    Widget screen;
    switch (index) {
      case 0:
        screen = const ImageToPdfScreen();
        break;
      case 1:
        screen = const ImageResizerScreen();
        break;
      case 2:
        screen = const BpCheckerScreen();
        break;
      case 3:
        screen = const PdfMakerScreen();
        break;
      case 4:
        screen = const MemeGeneratorScreen();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _ToolItem {
  final String title;
  final String titleHi;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Color glowColor;

  _ToolItem({
    required this.title,
    required this.titleHi,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.glowColor,
  });
}
