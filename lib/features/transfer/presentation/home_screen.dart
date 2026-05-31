import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';

import '../../../core/widgets/app_animated_builder.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../chat/presentation/chat_list_screen.dart';
import 'send_screen.dart';
import 'receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgAnimController;
  late AnimationController _cardAnimController;
  late Animation<double> _sendCardAnim;
  late Animation<double> _receiveCardAnim;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _sendCardAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cardAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _receiveCardAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _cardAnimController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
      ),
    );

    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ──────────────────────────────
              _buildHeader(),
              const SizedBox(height: 32),

              // ─── Send & Receive Cards ────────────────
              Expanded(
                child: Column(
                  children: [
                    // Send Card
                    Expanded(
                      child: AppAnimatedBuilder(
                        listenable: _sendCardAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - _sendCardAnim.value)),
                            child: Opacity(
                              opacity: _sendCardAnim.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildActionCard(
                          title: 'Send Files',
                          subtitle: 'Share files securely with encryption',
                          icon: Icons.upload_rounded,
                          gradient: AppColors.sendGradient,
                          features: ['🔒 PIN Encryption', '⚡ Ultra Fast', '🌐 Any Distance'],
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              _createRoute(const SendScreen()),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Receive Card
                    Expanded(
                      child: AppAnimatedBuilder(
                        listenable: _receiveCardAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 30 * (1 - _receiveCardAnim.value)),
                            child: Opacity(
                              opacity: _receiveCardAnim.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildActionCard(
                          title: 'Receive Files',
                          subtitle: 'Accept incoming file transfers',
                          icon: Icons.download_rounded,
                          gradient: AppColors.receiveGradient,
                          features: ['📱 QR Scan', '🛡️ Verified', '📁 All Formats'],
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.push(
                              context,
                              _createRoute(const ReceiveScreen()),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── File Chat Card ───────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    _createRoute(const ChatListScreen()),
                  );
                },
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('File Chat', style: AppTypography.heading4),
                            const SizedBox(height: 2),
                            Text(
                              'Send files like WhatsApp messages',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Color(0xFF25D366),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ─── Quick Stats ─────────────────────────
              _buildQuickStats(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // App icon with gradient
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryCyan.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FileShare Pro', style: AppTypography.heading3),
              Text(
                'Secure • Fast • Encrypted',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        // Settings button
        GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 14,
          onTap: () {
            // Navigate to settings
            Navigator.push(context, _createRoute(const SettingsScreen()));
          },
          child: const Icon(
            Icons.settings_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (gradient as LinearGradient)
                            .colors
                            .first
                            .withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.heading3),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ],
            ),
            const Spacer(),
            // Feature chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((f) => _buildFeatureChip(f)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildStatItem('Files Sent', '0', Icons.arrow_upward_rounded)),
          Container(width: 1, height: 30, color: AppColors.glassBorder),
          Expanded(child: _buildStatItem('Received', '0', Icons.arrow_downward_rounded)),
          Container(width: 1, height: 30, color: AppColors.glassBorder),
          Expanded(child: _buildStatItem('Encrypted', '0', Icons.lock_rounded)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryCyan, size: 16),
            const SizedBox(width: 4),
            Text(value, style: AppTypography.heading4),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption),
      ],
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }
}
