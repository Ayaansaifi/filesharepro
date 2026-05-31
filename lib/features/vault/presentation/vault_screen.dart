import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../../transfer/presentation/widgets/pin_input_dialog.dart';
import '../services/vault_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with SingleTickerProviderStateMixin {
  final VaultService _vaultService = VaultService();
  bool _isLocked = true;
  bool _isSetup = false;
  bool _isLoading = true;
  String? _currentPin;
  List<VaultItem> _items = [];
  Map<String, dynamic> _stats = {};
  late AnimationController _lockAnimController;

  @override
  void initState() {
    super.initState();
    _lockAnimController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _checkVaultSetup();
  }

  @override
  void dispose() {
    _lockAnimController.dispose();
    super.dispose();
  }

  Future<void> _checkVaultSetup() async {
    final setup = await _vaultService.isVaultSetup();
    setState(() {
      _isSetup = setup;
      _isLoading = false;
    });
  }

  Future<void> _loadVaultItems() async {
    final items = await _vaultService.getVaultItems();
    final stats = await _vaultService.getVaultStats();
    setState(() {
      _items = items;
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryCyan))
            : !_isSetup
                ? _buildSetupScreen()
                : _isLocked
                    ? _buildLockScreen()
                    : _buildVaultContent(),
      ),
    );
  }

  // ─── Setup Screen (First Time) ───────────────────────────

  Widget _buildSetupScreen() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedLockIcon(controller: _lockAnimController),
          const SizedBox(height: 32),
          Text('Setup Your Vault', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Text(
            'Create a secure, encrypted space to store your\nprivate files. Protected with military-grade AES-256.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          GradientButton(
            label: 'Create Vault PIN',
            icon: Icons.lock_rounded,
            gradient: AppColors.vaultGradient,
            onPressed: _setupVaultPin,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded,
                  color: AppColors.success, size: 16),
              const SizedBox(width: 6),
              Text(
                'AES-256 Encryption • Hidden from Gallery',
                style: AppTypography.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Lock Screen ─────────────────────────────────────────

  Widget _buildLockScreen() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedLockIcon(controller: _lockAnimController),
          const SizedBox(height: 32),
          Text('Vault Locked', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Text(
            'Enter your 4-digit PIN to unlock',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 40),
          GradientButton(
            label: 'Unlock Vault',
            icon: Icons.lock_open_rounded,
            gradient: AppColors.vaultGradient,
            onPressed: _unlockVault,
          ),
        ],
      ),
    );
  }

  // ─── Vault Content ───────────────────────────────────────

  Widget _buildVaultContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.vaultGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Vault', style: AppTypography.heading3),
                    Text(
                      '${_stats['totalFiles'] ?? 0} files • ${FileUtils.formatFileSize(_stats['totalSize'] ?? 0)}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.all(10),
                borderRadius: 14,
                onTap: () => setState(() => _isLocked = true),
                child: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Stats Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildStatChip('🖼️ ${_stats['images'] ?? 0}', 'Images'),
              const SizedBox(width: 8),
              _buildStatChip('🎬 ${_stats['videos'] ?? 0}', 'Videos'),
              const SizedBox(width: 8),
              _buildStatChip('📄 ${_stats['documents'] ?? 0}', 'Docs'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Add File Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GradientButton(
            label: 'Add Files to Vault',
            icon: Icons.add_rounded,
            gradient: AppColors.vaultGradient,
            height: 48,
            onPressed: _addFilesToVault,
          ),
        ),
        const SizedBox(height: 16),

        // Files Grid
        Expanded(
          child: _items.isEmpty
              ? _buildEmptyVault()
              : _buildVaultGrid(),
        ),
      ],
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            Text(value, style: AppTypography.labelLarge),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyVault() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              color: AppColors.textHint, size: 64),
          const SizedBox(height: 16),
          Text('Vault is Empty', style: AppTypography.heading4),
          const SizedBox(height: 8),
          Text(
            'Add files to keep them encrypted\nand hidden from gallery',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVaultGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildVaultItemCard(item);
      },
    );
  }

  Widget _buildVaultItemCard(VaultItem item) {
    IconData icon;
    Color iconColor;
    switch (item.fileType) {
      case 'image':
        icon = Icons.image_rounded;
        iconColor = AppColors.primaryCyan;
        break;
      case 'video':
        icon = Icons.videocam_rounded;
        iconColor = AppColors.accentPink;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        iconColor = AppColors.warning;
    }

    return GestureDetector(
      onTap: () => _viewVaultFile(item),
      onLongPress: () => _showVaultItemOptions(item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.originalName,
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              FileUtils.formatFileSize(item.originalSize),
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────

  Future<void> _setupVaultPin() async {
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PinInputDialog(
        title: 'Create Vault PIN',
        subtitle: 'This PIN will protect all your vault files',
      ),
    );

    if (pin != null && pin.length == 4) {
      if (!mounted) return;
      // Confirm PIN
      final confirmPin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PinInputDialog(
          title: 'Confirm PIN',
          subtitle: 'Enter the same PIN again',
        ),
      );

      if (confirmPin == pin) {
        await _vaultService.setupVault(pin);
        setState(() {
          _isSetup = true;
          _isLocked = false;
          _currentPin = pin;
        });
        _loadVaultItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Vault created successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ PINs don\'t match. Try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _unlockVault() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const PinInputDialog(
        title: 'Enter Vault PIN',
        subtitle: 'Enter your 4-digit PIN',
        isVerification: true,
      ),
    );

    if (pin != null && pin.length == 4) {
      final valid = await _vaultService.verifyPin(pin);
      if (valid) {
        HapticFeedback.mediumImpact();
        setState(() {
          _isLocked = false;
          _currentPin = pin;
        });
        _loadVaultItems();
      } else {
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('❌ Wrong PIN!'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _addFilesToVault() async {
    if (_currentPin == null) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      int added = 0;
      for (final file in result.files) {
        if (file.path != null) {
          final item = await _vaultService.addToVault(
            File(file.path!),
            _currentPin!,
          );
          if (item != null) added++;
        }
      }

      _loadVaultItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $added files added to vault!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _viewVaultFile(VaultItem item) async {
    if (_currentPin == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      ),
    );

    final decrypted = await _vaultService.decryptVaultFile(item, _currentPin!);
    if (mounted) Navigator.pop(context); // Close loading

    if (decrypted != null && item.fileType == 'image') {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(decrypted, fit: BoxFit.contain),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decrypted != null
                  ? 'File decrypted: ${item.originalName}'
                  : '❌ Failed to decrypt',
            ),
            backgroundColor:
                decrypted != null ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showVaultItemOptions(VaultItem item) {
    HapticFeedback.mediumImpact();
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
            Text(item.originalName, style: AppTypography.heading4),
            Text(
              FileUtils.formatFileSize(item.originalSize),
              style: AppTypography.caption,
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.visibility_rounded,
              label: 'View File',
              onTap: () {
                Navigator.pop(ctx);
                _viewVaultFile(item);
              },
            ),
            _buildOptionTile(
              icon: Icons.save_alt_rounded,
              label: 'Export to Gallery',
              onTap: () async {
                Navigator.pop(ctx);
                if (_currentPin != null) {
                  final exported = await _vaultService.exportFromVault(
                      item, _currentPin!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          exported != null
                              ? '✅ Exported: ${item.originalName}'
                              : '❌ Export failed',
                        ),
                        backgroundColor: exported != null
                            ? AppColors.success
                            : AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_rounded,
              label: 'Delete from Vault',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Delete File?'),
                    content: Text(
                      'This will permanently delete "${item.originalName}" from vault.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _vaultService.removeFromVault(item);
                  _loadVaultItems();
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(color: color),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _AnimatedLockIcon extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedLockIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppAnimatedBuilder(
      listenable: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.08);
        final glowOpacity = 0.2 + (controller.value * 0.3);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPink.withValues(alpha: glowOpacity),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: AppColors.vaultGradient,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 44),
      ),
    );
  }
}
