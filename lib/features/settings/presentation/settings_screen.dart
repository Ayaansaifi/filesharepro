import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/constants/app_constants.dart';
import '../../chat/providers/chat_provider.dart';
import 'privacy_screen.dart';
import '../../profile/presentation/profile_setup_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../vault/services/vault_service.dart';
import '../../status_saver/providers/status_provider.dart';
import '../../transfer/presentation/widgets/pin_input_dialog.dart';
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _alwaysEncrypt = false;
  String _transferMode = 'Nearby (Wi-Fi Direct)';
  final VaultService _vaultService = VaultService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _alwaysEncrypt = prefs.getBool('always_encrypt') ?? false;
        _transferMode = prefs.getString('transfer_mode') ?? 'Nearby (Wi-Fi Direct)';
      });
    }
  }

  Future<void> _toggleEncrypt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('always_encrypt', value);
    setState(() {
      _alwaysEncrypt = value;
    });
  }

  void _showTransferModeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Default Transfer Mode', style: AppTypography.heading4),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Nearby (Wi-Fi Direct)', style: TextStyle(color: Colors.white)),
              trailing: _transferMode == 'Nearby (Wi-Fi Direct)' 
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryCyan) 
                  : null,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('transfer_mode', 'Nearby (Wi-Fi Direct)');
                setState(() => _transferMode = 'Nearby (Wi-Fi Direct)');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('WebRTC (Internet)', style: TextStyle(color: Colors.white)),
              trailing: _transferMode == 'WebRTC (Internet)' 
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryCyan) 
                  : null,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('transfer_mode', 'WebRTC (Internet)');
                setState(() => _transferMode = 'WebRTC (Internet)');
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeVaultPin() async {
    final isSetup = await _vaultService.isVaultSetup();
    if (!isSetup) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault is not setup yet.')));
      return;
    }

    if (!mounted) return;
    final oldPin = await showDialog<String>(
      context: context,
      builder: (_) => const PinInputDialog(
        title: 'Enter Old PIN',
        subtitle: 'Enter current 4-digit PIN',
        isVerification: true,
      ),
    );

    if (oldPin != null && oldPin.length == 4) {
      final valid = await _vaultService.verifyPin(oldPin);
      if (valid) {
        if (!mounted) return;
        final newPin = await showDialog<String>(
          context: context,
          builder: (_) => const PinInputDialog(
            title: 'Enter New PIN',
            subtitle: 'Create your new 4-digit PIN',
          ),
        );

        if (newPin != null && newPin.length == 4) {
          if (!mounted) return;
          final confirmPin = await showDialog<String>(
            context: context,
            builder: (_) => const PinInputDialog(
              title: 'Confirm New PIN',
              subtitle: 'Enter the new PIN again',
            ),
          );

          if (newPin == confirmPin) {
            await _vaultService.changePin(oldPin, newPin);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Vault PIN changed successfully!')));
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ PINs do not match.')));
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Incorrect Old PIN!')));
      }
    }
  }

  Future<void> _clearVault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear Vault?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete all encrypted files inside the vault. This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textHint))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      await _vaultService.clearVault();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault cleared successfully.')));
    }
  }

  Future<void> _clearAllLocalData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear local data?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Clears transfer history, chat prefs, and settings on this device. '
          'Vault files are NOT deleted — use Clear Vault for that.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;

    // TransferHistoryService removed
    final prefs = await SharedPreferences.getInstance();
    final vaultPin = prefs.getString(AppConstants.keyVaultPinHash);
    final vaultSalt = prefs.getString(AppConstants.keyVaultSalt);
    await prefs.clear();
    if (vaultPin != null) await prefs.setString(AppConstants.keyVaultPinHash, vaultPin);
    if (vaultSalt != null) await prefs.setString(AppConstants.keyVaultSalt, vaultSalt);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local app data cleared.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              _buildAppInfo(context, ref),
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
              _buildSettingTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear All Local Data',
                subtitle: 'Transfer history & app prefs (vault separate)',
                iconColor: AppColors.error,
                onTap: _clearAllLocalData,
              ),
              const SizedBox(height: 24),

              // ─── Transfer Settings ──────────────────
              Text('Transfer', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.wifi_tethering_rounded,
                title: 'Default Transfer Mode',
                subtitle: _transferMode,
                onTap: _showTransferModeDialog,
              ),
              _buildSettingTile(
                icon: Icons.lock_rounded,
                title: 'Always Encrypt',
                subtitle: 'Require PIN for every transfer',
                trailing: Switch(
                  value: _alwaysEncrypt,
                  onChanged: _toggleEncrypt,
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
                onTap: _changeVaultPin,
              ),
              _buildSettingTile(
                icon: Icons.delete_sweep_rounded,
                title: 'Clear Vault',
                subtitle: 'Delete all encrypted files',
                iconColor: AppColors.error,
                onTap: _clearVault,
              ),
              const SizedBox(height: 24),

              // ─── Status Saver ───────────────────────
              Text('Status Saver', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.folder_open_rounded,
                title: 'Reset WhatsApp Access',
                subtitle: 'Re-select status folder',
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove(AppConstants.keySafUri);
                  await prefs.remove('saf_uri');
                  
                  // Also reload status provider so UI updates
                  ref.read(statusSaverProvider.notifier).loadStatuses();
                  
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('WhatsApp folder access reset.')),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ─── About ─────────────────────────────
              Text('About', style: AppTypography.heading4),
              const SizedBox(height: 12),
              _buildSettingTile(
                icon: Icons.share_rounded,
                title: 'Share App',
                subtitle: 'Tell your friends about FileShare Pro',
                onTap: () {
                  Share.share(
                    'Hey! Let\'s chat securely on FileShare Pro! Download it and we can share files instantly 🚀\n\nhttps://play.google.com/store/apps/details?id=com.filesharepro.filesharepro',
                    subject: 'Join me on FileShare Pro',
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.star_rounded,
                title: 'Rate App',
                subtitle: 'Leave a review on Play Store',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Play Store...')),
                  );
                },
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

  Widget _buildAppInfo(BuildContext context, WidgetRef ref) {
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
              image: profile?.avatarPath != null && !kIsWeb && File(profile!.avatarPath!).existsSync()
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
            child: profile?.avatarPath == null || kIsWeb
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
              if (profile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSetupScreen(
                      existingProfile: profile,
                      onComplete: (ctx) => Navigator.pop(ctx),
                    ),
                  ),
                );
              }
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
