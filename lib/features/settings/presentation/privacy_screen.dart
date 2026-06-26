import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/constants/app_constants.dart';

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
              // ─── Core Privacy Features ───────────────────
              Text('Privacy Features', style: AppTypography.heading4),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.folder_shared_rounded,
                title: 'WhatsApp Statuses',
                description: 'The app requests access ONLY to the WhatsApp ".Statuses" folder locally on your device. We never access other files or upload your data to any server.',
              ),
              const SizedBox(height: 32),

              // ─── Utility Tools Privacy ───────────────────
              Text('Utility Tools Privacy', style: AppTypography.heading4),
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.picture_as_pdf_rounded,
                title: 'Image to PDF & PDF Maker',
                description: 'All image and PDF processing happens entirely on your device. No images, text, or generated PDFs are uploaded to any server.',
              ),
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.photo_size_select_large_rounded,
                title: 'Image Resizer',
                description: 'Image resizing and compression is done locally on your device. No images are transmitted externally at any point.',
              ),
              const SizedBox(height: 16),
              _buildFeatureTile(
                icon: Icons.monitor_heart_rounded,
                title: 'BP Checker — Health Disclaimer',
                description: 'The BP Checker stores readings locally on your device using SharedPreferences. No health data is transmitted to us or any third party.',
                isWarning: true,
              ),
              const SizedBox(height: 12),
              // BP Disclaimer Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The BP Checker is NOT a medical device. It only analyses values you manually enter. '
                        'It is NOT a substitute for professional medical advice. '
                        'Always consult a qualified healthcare professional.',
                        style: AppTypography.caption.copyWith(
                          color: Colors.red[200],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ─── Permissions ────────────────────────────
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
                description: 'Required to select files, save received items, and process images in utility tools. We do not upload your files anywhere.',
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

              // ─── Terms of Service ────────────────────────
              Text('Terms of Service', style: AppTypography.heading4),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 16,
                child: Text(
                  'By using this app, you agree to our Terms of Service. FileShare Pro provides secure file sharing, '
                  'encrypted vault, WhatsApp status saver, utility tools (Image to PDF, Image Resizer, BP Checker, PDF Maker), '
                  'and local service bookings. All data is processed locally on your device. '
                  'You agree not to misuse the platform for sharing illegal or objectionable content. '
                  'The BP Checker is for informational purposes only and is not a medical device.',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),

              Center(
                child: Column(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(AppConstants.privacyPolicyUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded,
                          color: AppColors.primaryCyan),
                      label: Text('View Full Privacy Policy',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.primaryCyan)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final url = Uri.parse(AppConstants.termsUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.article_outlined,
                          color: AppColors.primaryCyan),
                      label: Text('View Full Terms & Conditions',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.primaryCyan)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ─── Version ─────────────────────────────────
              Center(
                child: Text(
                  'FileShare Pro v${AppConstants.appVersion}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textHint),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String description,
    bool isWarning = false,
  }) {
    final color =
        isWarning ? AppColors.error : AppColors.primaryCyan;
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
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.heading4.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(description,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
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
