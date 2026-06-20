import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Play Store / GDPR-friendly first-launch consent (local only, no tracking SDK).
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key});

  static const _keyAccepted = 'privacy_consent_accepted_v2';

  static Future<bool> ensureAccepted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyAccepted) == true) return true;
    if (!context.mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
    if (accepted == true) {
      await prefs.setBool(_keyAccepted, true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Privacy & Terms', style: AppTypography.heading4),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Before you continue, please review how FileShare Pro works:',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            _bullet('P2P transfers — files go directly device-to-device. We do not upload your files.'),
            _bullet('Location is used only while sharing to find nearby devices (not tracked on a server).'),
            _bullet('Vault files stay encrypted on your device. You control delete/export.'),
            _bullet('Entertainment ads may use Google AdMob (see Privacy Policy).'),
            _bullet('Do not share illegal or abusive content. You can block/report in-app.'),
            const SizedBox(height: 12),
            Text(
              'By tapping Accept, you agree to our Privacy Policy and Terms & Conditions.',
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Decline', style: TextStyle(color: AppColors.textHint)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Accept', style: TextStyle(color: AppColors.primaryCyan)),
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.primaryCyan)),
          Expanded(child: Text(text, style: AppTypography.caption)),
        ],
      ),
    );
  }
}
