import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/gradient_button.dart';

/// UI preview of Send screen — actual transfer Android par hota hai.
class WebSendPreviewScreen extends StatefulWidget {
  const WebSendPreviewScreen({super.key});

  @override
  State<WebSendPreviewScreen> createState() => _WebSendPreviewScreenState();
}

class _WebSendPreviewScreenState extends State<WebSendPreviewScreen> {
  String _mode = 'nearby';
  bool _encrypt = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Send Files'),
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfer Mode', style: AppTypography.heading4),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _modeCard('nearby', 'Nearby', Icons.wifi_tethering_rounded, AppColors.sendGradient)),
                  const SizedBox(width: 12),
                  Expanded(child: _modeCard('longdistance', 'Long Distance', Icons.language_rounded, AppColors.receiveGradient)),
                ],
              ),
              const SizedBox(height: 24),
              GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 48, color: AppColors.primaryCyan.withValues(alpha: 0.8)),
                    const SizedBox(height: 12),
                    Text('Tap to select files', style: AppTypography.heading4),
                    Text('Photos, videos, docs — movies bhi', style: AppTypography.caption, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('PIN Encryption'),
                subtitle: const Text('Extra security for sensitive files'),
                value: _encrypt,
                activeTrackColor: AppColors.primaryCyan,
                onChanged: (v) => setState(() => _encrypt = v),
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Start Transfer (Android only)',
                icon: Icons.send_rounded,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _mode == 'nearby'
                            ? 'Nearby mode — Wi‑Fi Direct Android par chalega'
                            : 'Long Distance — WebRTC link se kahi se bhi share',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(String id, String title, IconData icon, Gradient gradient) {
    final selected = _mode == id;
    return GestureDetector(
      onTap: () => setState(() => _mode = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected ? gradient : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 8),
            Text(title, style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
