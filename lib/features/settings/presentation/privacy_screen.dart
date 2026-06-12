import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy, Security & Terms'),
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
              _buildFeatureTile(
                icon: Icons.lock_rounded,
                title: 'End-to-End Encryption',
                description: 'All your chats and files are encrypted with AES-256 before leaving your device. Nobody else can read them.',
              ),
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.phonelink_off_rounded,
                title: 'Zero Server Architecture',
                description: 'This app is 100% Peer-to-Peer. We do not have any database or servers storing your messages or files.',
              ),
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.security_rounded,
                title: 'Local Vault',
                description: 'Your private files are stored securely on your device, encrypted and protected by a PIN.',
              ),
              const SizedBox(height: 32),
              
              Text('Permissions', style: AppTypography.heading4),
              const SizedBox(height: 16),
              _buildPermissionTile(
                icon: Icons.camera_alt_rounded,
                title: 'Camera',
                description: 'Used to scan QR codes for pairing devices and sending photos.',
              ),
              _buildPermissionTile(
                icon: Icons.location_on_rounded,
                title: 'Location',
                description: 'Used only to discover nearby devices for Wi-Fi Direct file transfers. We do not track your location.',
              ),
              _buildPermissionTile(
                icon: Icons.folder_rounded,
                title: 'Storage',
                description: 'Required to select files and save received items securely. We do not support or include any unauthorized content downloading mechanisms.',
              ),
              _buildPermissionTile(
                icon: Icons.contacts_rounded,
                title: 'Contacts',
                description: 'Only used locally on your device to show names instead of phone numbers. We do not upload your contacts anywhere.',
              ),
              _buildPermissionTile(
                icon: Icons.mic_rounded,
                title: 'Microphone',
                description: 'Required to record and send voice notes.',
              ),
              const SizedBox(height: 32),
              
              Text('Terms of Service', style: AppTypography.heading4),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 16,
                child: Text(
                  'By using this app, you agree to our Terms of Service. This app provides secure file sharing and local service bookings. We have strictly removed any third-party downloading systems. You agree not to misuse the platform for sharing illegal or objectionable content. The services booked through this platform are fulfilled by independent providers.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    // Open the github pages privacy policy
                    final url = Uri.parse('https://ayaansaifi.github.io/fileshare-privacy-policy/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primaryCyan),
                  label: Text('View Full Privacy & Terms', style: AppTypography.labelMedium.copyWith(color: AppColors.primaryCyan)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({required IconData icon, required String title, required String description}) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryCyan, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.heading4.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(description, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textHint, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelLarge),
                const SizedBox(height: 2),
                Text(description, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
