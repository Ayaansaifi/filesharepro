import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/app_animated_builder.dart';
import 'web_send_preview.dart';
import 'web_receive_preview.dart';

class WebHomeScreen extends StatefulWidget {
  const WebHomeScreen({super.key});

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen> with TickerProviderStateMixin {
  late AnimationController _cardAnimController;
  late Animation<double> _sendCardAnim;
  late Animation<double> _receiveCardAnim;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sendCardAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardAnimController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _receiveCardAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardAnimController, curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack)),
    );
    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              AppAnimatedBuilder(
                listenable: _sendCardAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _sendCardAnim.value)),
                    child: Opacity(opacity: _sendCardAnim.value.clamp(0.0, 1.0), child: child),
                  );
                },
                child: _buildActionCard(
                  title: 'Send Files',
                  subtitle: 'Share files securely with encryption',
                  icon: Icons.upload_rounded,
                  gradient: AppColors.sendGradient,
                  features: const ['🔒 PIN Encryption', '⚡ Ultra Fast', '🌐 Any Distance'],
                  onTap: () => Navigator.push(context, _route(const WebSendPreviewScreen())),
                ),
              ),
              const SizedBox(height: 16),
              AppAnimatedBuilder(
                listenable: _receiveCardAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _receiveCardAnim.value)),
                    child: Opacity(opacity: _receiveCardAnim.value.clamp(0.0, 1.0), child: child),
                  );
                },
                child: _buildActionCard(
                  title: 'Receive Files',
                  subtitle: 'Accept incoming file transfers',
                  icon: Icons.download_rounded,
                  gradient: AppColors.receiveGradient,
                  features: const ['📱 QR Scan', '🛡️ Verified', '📁 All Formats'],
                  onTap: () => Navigator.push(context, _route(const WebReceivePreviewScreen())),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File Chat — Android app par available')),
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
                          gradient: const LinearGradient(colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('File Chat', style: AppTypography.heading4),
                            Text('Send files like WhatsApp messages', style: AppTypography.caption),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('NEW', style: TextStyle(color: Color(0xFF25D366), fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('0', 'Files Sent', Icons.arrow_upward_rounded),
                    Container(width: 1, height: 30, color: AppColors.glassBorder),
                    _stat('0', 'Received', Icons.arrow_downward_rounded),
                    Container(width: 1, height: 30, color: AppColors.glassBorder),
                    _stat('Demo', 'Preview', Icons.chrome_reader_mode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.share_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onLongPress: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Secure Vault — Android app par long-press se kholo')),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FileShare Pro', style: AppTypography.heading3),
                Text('Secure • Fast • Encrypted', style: AppTypography.caption.copyWith(color: AppColors.primaryCyan, letterSpacing: 1)),
              ],
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: 14,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings — Android app par full available')),
            );
          },
          child: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon) {
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
        Text(label, style: AppTypography.caption),
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
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
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
                  decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.heading3),
                      Text(subtitle, style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 18),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((f) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(f, style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Route _route(Widget page) => PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      );
}
