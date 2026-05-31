import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../chat/providers/chat_provider.dart';
import 'privacy_screen.dart';
import 'dart:io';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── App Info ────────────────────────────
              _buildAppInfo(ref),
              const SizedBox(height: 24),

              // ─── Privacy & Security ─────────────────
              Text('Security', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.shield_rounded,
                title: 'Privacy & Security',
                subtitle: 'Encryption, permissions, policies',
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                },
              ),
              const SizedBox(height: 24),

              // ─── Transfer Settings ──────────────────
              Text('Transfer', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.wifi_tethering_rounded,
                title: 'Default Transfer Mode',
                subtitle: 'Nearby (Wi-Fi Direct)',
                onTap: () {},
              ),
              _buildSettingTile(
                icon: Icons.lock_rounded,
                title: 'Always Encrypt',
                subtitle: 'Require PIN for every transfer',
                trailing: Switch(
                  value: false,
                  onChanged: (_) {},
                  activeThumbColor: AppColors.primaryCyan,
                ),
              ),
              const SizedBox(height: 24),

              // ─── Vault Settings ─────────────────────
              Text('Vault', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.key_rounded,
                title: 'Change Vault PIN',
                subtitle: 'Update your vault password',
                onTap: () {},
              ),
              _buildSettingTile(
                icon: Icons.delete_sweep_rounded,
                title: 'Clear Vault',
                subtitle: 'Delete all encrypted files',
                iconColor: AppColors.error,
                onTap: () {},
              ),
              const SizedBox(height: 24),

              // ─── Status Saver ───────────────────────
              Text('Status Saver', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.folder_open_rounded,
                title: 'Reset WhatsApp Access',
                subtitle: 'Re-select status folder',
                onTap: () {},
              ),
              const SizedBox(height: 24),

              // ─── About ─────────────────────────────
              Text('About', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.share_rounded,
                title: 'Share App',
                subtitle: 'Tell your friends about FileShare Pro',
                onTap: () {},
              ),
              _buildSettingTile(
                icon: Icons.star_rounded,
                title: 'Rate App',
                subtitle: 'Leave a review on Play Store',
                onTap: () {},
              ),
              _buildSettingTile(
                icon: Icons.info_outline_rounded,
                title: 'Version',
                subtitle: AppConstants.appVersion,
              ),
              const SizedBox(height: 40),

              // ─── Footer ────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Made with ❤️ in India',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🔒 Zero Database • Zero Server • 100% P2P',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryCyan,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfo(WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              image: profile?.avatarPath != null && File(profile!.avatarPath!).existsSync()
                  ? DecorationImage(
                      image: FileImage(File(profile.avatarPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: profile?.avatarPath == null
                ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile?.displayName ?? AppConstants.appName, style: AppTypography.heading3),
                const SizedBox(height: 4),
                Text(
                  profile?.about ?? 'Secure • Fast • Encrypted',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryCyan,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textHint, size: 20),
            onPressed: () {
              // Edit profile functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primaryCyan).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: iconColor ?? AppColors.primaryCyan, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLarge),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
