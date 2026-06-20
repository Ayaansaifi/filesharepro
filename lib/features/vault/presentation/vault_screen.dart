import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../../transfer/presentation/widgets/pin_input_dialog.dart';
import '../services/vault_service.dart';
import 'package:flutter/foundation.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with SingleTickerProviderStateMixin {
  final VaultService _vaultService = VaultService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLocked = true;
  bool _isSetup = false;
  bool _isLoading = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isAddingFiles = false;
  String? _currentPin;
  List<VaultItem> _items = [];
  Map<String, dynamic> _stats = {};
  String _filter = 'all';
  bool _showRestoreBanner = false;
  late AnimationController _lockAnimController;

  @override
  void initState() {
    super.initState();
    _lockAnimController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _initVault();
  }

  @override
  void dispose() {
    _lockAnimController.dispose();
    super.dispose();
  }

  Future<void> _initVault() async {
    if (kIsWeb) {
      setState(() => _isLoading = false);
      return;
    }
    await _checkBiometricAvailability();
    await _checkVaultSetup();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      
      setState(() {
        _isBiometricAvailable = canCheck && isDeviceSupported && available.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Biometric check error: $e');
      setState(() => _isBiometricAvailable = false);
    }
  }

  Future<void> _checkVaultSetup() async {
    final onDisk = await _vaultService.hasExistingVaultOnDisk();
    final setup = await _vaultService.isVaultSetup();
    final bioEnabled = await _vaultService.isBiometricEnabled();
    setState(() {
      _isSetup = setup;
      _isBiometricEnabled = bioEnabled;
      _isLoading = false;
      _showRestoreBanner = onDisk && !setup;
    });
    
    // Auto-attempt biometric if vault is setup and biometric is enabled
    if (setup && bioEnabled && _isBiometricAvailable) {
      _unlockWithBiometric();
    }
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
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_rounded, size: 80, color: AppColors.textHint),
                const SizedBox(height: 24),
                Text('Vault Not Supported', style: AppTypography.heading2),
                const SizedBox(height: 12),
                Text(
                  'The secure vault feature requires local device storage\nand is only available on Android and iOS apps.',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryCyan))
              : !_isSetup
                  ? (_showRestoreBanner ? _buildRestoreScreen() : _buildSetupScreen())
                  : _isLocked
                      ? _buildLockScreen()
                      : _buildVaultContent(),
        ),
      ),
    );
  }

  Widget _buildRestoreScreen() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done_rounded, color: AppColors.primaryCyan, size: 72),
          const SizedBox(height: 24),
          Text('Vault Found on Device', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Text(
            'Your encrypted files are still saved on this phone.\nEnter your old vault PIN to restore access.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GradientButton(
            label: 'Restore with PIN',
            icon: Icons.lock_open_rounded,
            gradient: AppColors.vaultGradient,
            onPressed: () async {
              await _vaultService.isVaultSetup();
              _unlockVault();
            },
          ),
        ],
      ),
    );
  }

  // ─── Setup Screen (First Time) ───────────────────────────

  Widget _buildSetupScreen() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Premium gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            decoration: const BoxDecoration(
              gradient: AppColors.vaultGradient,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              children: [
                _AnimatedLockIcon(controller: _lockAnimController),
                const SizedBox(height: 20),
                const Text(
                  'Secure Vault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Military-grade encryption for your private files',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Security features list
                _buildFeatureRow(Icons.lock_rounded, 'AES-256 Encryption',
                    'Files are encrypted before being stored'),
                const SizedBox(height: 16),
                _buildFeatureRow(Icons.visibility_off_rounded,
                    'Hidden from Gallery',
                    'Files invisible to other apps and gallery'),
                const SizedBox(height: 16),
                _buildFeatureRow(Icons.fingerprint_rounded,
                    'Biometric Support',
                    'Unlock with fingerprint for quick access'),
                const SizedBox(height: 16),
                _buildFeatureRow(Icons.storage_rounded, 'Offline Storage',
                    'Files stay safe even without internet'),
                const SizedBox(height: 36),
                GradientButton(
                  label: 'Create Vault PIN',
                  icon: Icons.lock_rounded,
                  gradient: AppColors.vaultGradient,
                  onPressed: _setupVaultPin,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security_rounded,
                          color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Your files never leave your device',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.vaultGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.labelLarge.copyWith(fontSize: 14)),
              Text(subtitle, style: AppTypography.caption),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Lock Screen with Fingerprint ────────────────────────

  Widget _buildLockScreen() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            decoration: const BoxDecoration(
              gradient: AppColors.vaultGradient,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(
              children: [
                AppAnimatedBuilder(
                  listenable: _lockAnimController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_lockAnimController.value * 0.04),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white
                                  .withValues(alpha: 0.2 * _lockAnimController.value),
                              blurRadius: 24,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 44),
                      ),
                    );
                  },
                  child: const SizedBox(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vault Locked',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter PIN or use fingerprint to unlock',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                // PIN unlock
                GradientButton(
                  label: 'Unlock with PIN',
                  icon: Icons.dialpad_rounded,
                  gradient: AppColors.vaultGradient,
                  onPressed: _unlockVault,
                ),

                // Fingerprint
                if (_isBiometricAvailable &&
                    _isBiometricEnabled) ...
                  [
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _unlockWithBiometric,
                      child: Column(
                        children: [
                          AppAnimatedBuilder(
                            listenable: _lockAnimController,
                            builder: (ctx, child) {
                              return Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.accentPink
                                          .withValues(alpha: 0.2),
                                      AppColors.accentOrange
                                          .withValues(alpha: 0.2),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.accentPink
                                        .withValues(alpha: 0.5 +
                                            _lockAnimController.value *
                                                0.4),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentPink
                                          .withValues(
                                              alpha: 0.15 *
                                                  _lockAnimController
                                                      .value),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                    Icons.fingerprint_rounded,
                                    color: AppColors.accentPink,
                                    size: 40),
                              );
                            },
                            child: const SizedBox(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Touch to unlock',
                            style: AppTypography.labelMedium.copyWith(
                                color: AppColors.accentPink),
                          ),
                        ],
                      ),
                    ),
                  ],

                if (_isBiometricAvailable && !_isBiometricEnabled) ...
                  [
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _showSnackBar(
                          'Unlock with PIN first, then enable fingerprint'),
                      icon: const Icon(Icons.fingerprint_rounded,
                          color: AppColors.textHint, size: 20),
                      label: Text(
                        'Enable Fingerprint Unlock',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textHint),
                      ),
                    ),
                  ],

                const SizedBox(height: 16),
                TextButton(
                  onPressed: _forgotPin,
                  child: Text(
                    'Forgot PIN? Reset Vault',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryCyan,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
              GlassCard(
                padding: const EdgeInsets.all(10),
                borderRadius: 14,
                onTap: () => setState(() => _isLocked = true),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 20),
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
              // Fingerprint toggle
              if (_isBiometricAvailable)
                GlassCard(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 14,
                  onTap: _toggleBiometric,
                  child: Icon(
                    Icons.fingerprint_rounded,
                    color: _isBiometricEnabled 
                        ? AppColors.primaryCyan 
                        : AppColors.textHint,
                    size: 20,
                  ),
                ),
              const SizedBox(width: 8),
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
            label: _isAddingFiles ? 'Encrypting...' : 'Add Files to Vault',
            icon: _isAddingFiles ? Icons.lock_clock_rounded : Icons.add_rounded,
            gradient: AppColors.vaultGradient,
            height: 48,
            isLoading: _isAddingFiles,
            enabled: !_isAddingFiles,
            onPressed: _addFilesToVault,
          ),
        ),
        const SizedBox(height: 16),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All'),
                _filterChip('image', 'Photos'),
                _filterChip('video', 'Videos'),
                _filterChip('document', 'Docs'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Files Grid
        Expanded(
          child: _filteredItems.isEmpty
              ? _buildEmptyVault()
              : _buildVaultGrid(),
        ),
      ],
    );
  }

  List<VaultItem> get _filteredItems {
    if (_filter == 'all') return _items;
    return _items.where((i) => i.fileType == _filter).toList();
  }

  Widget _filterChip(String key, String label) {
    final selected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = key),
        selectedColor: AppColors.primaryCyan.withValues(alpha: 0.3),
        checkmarkColor: AppColors.primaryCyan,
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryCyan : AppColors.textSecondary,
        ),
      ),
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
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
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
        if (!mounted) return;
        
        // Security Question setup
        final securityAnswer = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _SecurityQuestionDialog(),
        );

        await _vaultService.setupVault(pin, securityAnswer: securityAnswer);
        
        // Ask if user wants to enable fingerprint
        if (_isBiometricAvailable && mounted) {
          final enableBio = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded,
                      color: AppColors.primaryCyan, size: 28),
                  const SizedBox(width: 12),
                  Text('Enable Fingerprint?', style: AppTypography.heading4),
                ],
              ),
              content: Text(
                'Use your fingerprint to quickly unlock the vault instead of entering PIN every time.',
                style: AppTypography.bodySmall,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Not Now',
                      style: TextStyle(color: AppColors.textHint)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Enable',
                      style: TextStyle(color: AppColors.primaryCyan)),
                ),
              ],
            ),
          );
          
          if (enableBio == true) {
            await _vaultService.setBiometricEnabled(true);
            setState(() => _isBiometricEnabled = true);
          }
        }
        
        setState(() {
          _isSetup = true;
          _isLocked = false;
          _currentPin = pin;
        });
        _loadVaultItems();
        _showSnackBar('✅ Vault created successfully!');
      } else {
        if (mounted) {
          _showSnackBar('❌ PINs don\'t match. Try again.', isError: true);
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
          _showSnackBar('❌ Wrong PIN!', isError: true);
        }
      }
    }
  }

  Future<void> _forgotPin() async {
    final answer = await showDialog<String>(
      context: context,
      builder: (_) => const _SecurityQuestionDialog(isRecovery: true),
    );
    
    if (answer != null && answer.isNotEmpty) {
      if (!mounted) return;
      final newPin = await showDialog<String>(
        context: context,
        builder: (_) => const PinInputDialog(
          title: 'Enter New PIN',
          subtitle: 'Create your new 4-digit PIN',
        ),
      );
      
      if (newPin != null && newPin.length == 4) {
        final success = await _vaultService.resetPinWithRecovery(answer, newPin);
        if (mounted) {
          if (success) {
            setState(() {
              _isLocked = false;
              _isSetup = true;
              _currentPin = newPin;
              _showRestoreBanner = false;
            });
            _loadVaultItems();
            _showSnackBar('✅ Vault PIN reset — you are unlocked!');
          } else {
            _showSnackBar('❌ Incorrect security answer or recovery data not found.', isError: true);
          }
        }
      }
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (!_isBiometricAvailable || !_isBiometricEnabled) return;
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock your secure vault',
      );
      
      if (authenticated) {
        HapticFeedback.mediumImpact();
        // Retrieve the stored PIN for decryption operations
        final storedPin = await _vaultService.getStoredPinForBiometric();
        if (storedPin != null) {
          setState(() {
            _isLocked = false;
            _currentPin = storedPin;
          });
          _loadVaultItems();
          _showSnackBar('🔓 Vault unlocked with fingerprint!');
        } else {
          _showSnackBar('Fingerprint verified but PIN not found. Use PIN to unlock.', isError: true);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric error: $e');
      if (mounted) {
        _showSnackBar('Fingerprint failed. Use PIN instead.', isError: true);
      }
    }
  }

  Future<void> _toggleBiometric() async {
    if (_isBiometricEnabled) {
      // Disable biometric
      await _vaultService.setBiometricEnabled(false);
      setState(() => _isBiometricEnabled = false);
      _showSnackBar('Fingerprint unlock disabled');
    } else {
      // Enable biometric — verify PIN first
      if (_currentPin != null) {
        try {
          final authenticated = await _localAuth.authenticate(
            localizedReason: 'Verify to enable fingerprint unlock',
          );
          
          if (authenticated) {
            await _vaultService.setBiometricEnabled(true);
            setState(() => _isBiometricEnabled = true);
            _showSnackBar('✅ Fingerprint unlock enabled!');
          }
        } on PlatformException catch (e) {
          debugPrint('Biometric enable error: $e');
          _showSnackBar('Could not enable fingerprint', isError: true);
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
      setState(() => _isAddingFiles = true);
      
      int added = 0;
      int failed = 0;
      for (final file in result.files) {
        if (file.path != null) {
          try {
            final item = await _vaultService.addToVault(
              File(file.path!),
              _currentPin!,
            );
            if (item != null) {
              added++;
            } else {
              failed++;
            }
          } catch (e) {
            debugPrint('Error adding file to vault: $e');
            failed++;
          }
        }
      }

      setState(() => _isAddingFiles = false);
      _loadVaultItems();
      
      if (mounted) {
        if (failed > 0) {
          _showSnackBar('Added $added files, $failed failed', isError: failed > added);
        } else {
          _showSnackBar('✅ $added files added to vault!');
        }
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

    if (decrypted != null) {
      if (item.fileType == 'image') {
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
        // Open with system viewer
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${item.originalName}');
          await tempFile.writeAsBytes(decrypted);
          
          final result = await OpenFilex.open(tempFile.path);
          if (result.type != ResultType.done) {
            if (mounted) _showSnackBar('Could not open file: ${result.message}', isError: true);
          }
        } catch (e) {
          if (mounted) _showSnackBar('Error opening file: $e', isError: true);
        }
      }
    } else {
      if (mounted) {
        _showSnackBar('❌ Failed to decrypt', isError: true);
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
              icon: Icons.drive_file_rename_outline_rounded,
              label: 'Rename',
              onTap: () async {
                Navigator.pop(ctx);
                final controller = TextEditingController(text: item.originalName);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Rename File'),
                    content: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'New name'),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, controller.text.trim()),
                        child: const Text('Save', style: TextStyle(color: AppColors.primaryCyan)),
                      ),
                    ],
                  ),
                );
                if (newName != null && newName.isNotEmpty) {
                  await _vaultService.renameVaultItem(item.id, newName);
                  _loadVaultItems();
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.photo_library_rounded,
              label: 'Move to Gallery (Keep in Vault)',
              onTap: () async {
                Navigator.pop(ctx);
                if (_currentPin != null) {
                  final exported = await _vaultService.exportFromVault(item, _currentPin!);
                  if (mounted) {
                    _showSnackBar(
                      exported != null ? '✅ Saved to gallery: ${item.originalName}' : '❌ Export failed',
                      isError: exported == null,
                    );
                  }
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.unarchive_rounded,
              label: 'Restore to Phone & Remove from Vault',
              onTap: () async {
                Navigator.pop(ctx);
                if (_currentPin != null) {
                  final exported = await _vaultService.exportFromVault(
                    item,
                    _currentPin!,
                    removeFromVaultAfter: true,
                  );
                  if (mounted) {
                    if (exported != null) {
                      _showSnackBar('✅ Restored to phone & removed from vault');
                      _loadVaultItems();
                    } else {
                      _showSnackBar('❌ Restore failed', isError: true);
                    }
                  }
                }
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_rounded,
              label: 'Delete Permanently',
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
                  final success = await _vaultService.removeFromVault(item);
                  if (mounted) {
                    if (success) {
                      _showSnackBar('✅ Deleted ${item.originalName}');
                    } else {
                      _showSnackBar('❌ Failed to delete file', isError: true);
                    }
                    _loadVaultItems();
                  }
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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

class _SecurityQuestionDialog extends StatefulWidget {
  final bool isRecovery;
  const _SecurityQuestionDialog({this.isRecovery = false});

  @override
  State<_SecurityQuestionDialog> createState() => _SecurityQuestionDialogState();
}

class _SecurityQuestionDialogState extends State<_SecurityQuestionDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.isRecovery ? 'Security Question' : 'Set Security Question',
        style: AppTypography.heading4,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isRecovery 
              ? 'Answer your security question to reset PIN.' 
              : 'This will help you recover your vault if you forget your PIN.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Question: What is your childhood hero?', style: AppTypography.labelLarge.copyWith(color: AppColors.primaryCyan)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your answer',
              hintStyle: const TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: Colors.black12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
        ),
        TextButton(
          onPressed: () {
            final ans = _controller.text.trim();
            if (ans.isNotEmpty) {
              Navigator.pop(context, ans);
            }
          },
          child: Text(widget.isRecovery ? 'Submit' : 'Save', style: const TextStyle(color: AppColors.primaryCyan)),
        ),
      ],
    );
  }
}
