import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class WebChatPreviewScreen extends StatelessWidget {
  const WebChatPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      icon: Icons.chat_rounded,
      title: 'File Chat',
      subtitle: 'P2P encrypted chat + file sharing',
      color: const Color(0xFF25D366),
      features: const [
        'WhatsApp-style file bubbles',
        'End-to-end encrypted messages',
        'Voice notes & contacts sync',
      ],
    );
  }
}

class WebStatusPreviewScreen extends StatelessWidget {
  const WebStatusPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      icon: Icons.auto_awesome_rounded,
      title: 'Status Saver',
      subtitle: 'WhatsApp statuses save karo gallery mein',
      color: AppColors.primaryCyan,
      features: const [
        'Images & videos batch save',
        'Saved tab — pehle save kiye hue',
        'Public gallery folder — uninstall ke baad bhi',
      ],
    );
  }
}

class _StubScaffold extends StatelessWidget {
  const _StubScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.features,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: color),
              ),
              const SizedBox(height: 24),
              Text(title, style: AppTypography.heading2),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f, style: AppTypography.bodySmall)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.android_rounded, color: Color(0xFF3DDC84)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Yeh feature Android app par full kaam karta hai. UI preview ke liye Home tab check karo.',
                        style: AppTypography.caption,
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
}
