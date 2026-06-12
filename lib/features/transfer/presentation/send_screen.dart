import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/permission_utils.dart';
import '../services/nearby_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/pin_input_dialog.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen>
    with TickerProviderStateMixin {
  List<PlatformFile> _selectedFiles = [];
  bool _encryptEnabled = false;

  String _transferMode = 'nearby'; // 'nearby' or 'longdistance'
  bool _isGeneratingLink = false;
  String? _roomCode;
  late AnimationController _fadeController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadDefaultSettings();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _encryptEnabled = prefs.getBool('always_encrypt') ?? false;
        final mode = prefs.getString('transfer_mode') ?? 'Nearby (Wi-Fi Direct)';
        _transferMode = mode == 'Nearby (Wi-Fi Direct)' 
            ? 'nearby' 
            : 'longdistance';
        
        // Sync tab selection with default transfer mode
        _tabController.index = _transferMode == 'nearby' ? 0 : 1;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Send Files'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: FadeTransition(
          opacity: _fadeController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Mode Selector ─────────────────────
                _buildModeSelector(),
                const SizedBox(height: 24),

                // ─── File Picker ───────────────────────
                _buildFilePicker(),
                const SizedBox(height: 20),

                // ─── Selected Files List ───────────────
                if (_selectedFiles.isNotEmpty) ...[
                  _buildSelectedFiles(),
                  const SizedBox(height: 20),
                ],

                // ─── Encryption Toggle ─────────────────
                _buildEncryptionToggle(),
                const SizedBox(height: 24),

                // ─── Action Button ─────────────────────
                if (_selectedFiles.isNotEmpty)
                  _buildActionSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Transfer Mode', style: AppTypography.heading4),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                'nearby',
                'Nearby',
                Icons.wifi_tethering_rounded,
                'Wi-Fi Direct • Ultra Fast',
                AppColors.sendGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModeCard(
                'longdistance',
                'Long Distance',
                Icons.language_rounded,
                'Internet P2P • Any City',
                AppColors.receiveGradient,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard(
    String mode,
    String title,
    IconData icon,
    String description,
    Gradient gradient,
  ) {
    final isSelected = _transferMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _transferMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (gradient as LinearGradient)
                        .colors
                        .first
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(title,
                style: AppTypography.labelLarge
                    .copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? Colors.white70
                    : AppColors.textHint,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return GestureDetector(
      onTap: _pickFiles,
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Tap to Select Files', style: AppTypography.heading4),
            const SizedBox(height: 6),
            Text(
              'Images, Videos, Documents, Any File',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selected (${_selectedFiles.length})',
              style: AppTypography.heading4,
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedFiles.clear()),
              child: Text(
                'Clear All',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _selectedFiles.length.clamp(0, 5),
          (index) => _buildFileItem(_selectedFiles[index]),
        ),
        if (_selectedFiles.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${_selectedFiles.length - 5} more files',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryCyan,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileItem(PlatformFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Text(
            FileUtils.getFileTypeIcon(file.name),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: AppTypography.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  FileUtils.formatFileSize(file.size),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _selectedFiles.remove(file));
            },
            child: const Icon(Icons.close_rounded,
                color: AppColors.textHint, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionToggle() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: _encryptEnabled
                  ? AppColors.vaultGradient
                  : null,
              color: _encryptEnabled ? null : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _encryptEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lock with Password', style: AppTypography.labelLarge),
                Text(
                  _encryptEnabled
                      ? 'AES-256 Encryption • PIN Protected'
                      : 'Files will be sent without encryption',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: _encryptEnabled,
            onChanged: (val) async {
              if (val) {
                final pin = await showDialog<String>(
                  context: context,
                  builder: (_) => const PinInputDialog(
                    title: 'Set PIN for File',
                    subtitle: 'Receiver will need this PIN to open',
                  ),
                );
                if (pin != null && pin.length == 4) {
                  setState(() {
                    _encryptEnabled = true;
                  });
                }
              } else {
                setState(() {
                  _encryptEnabled = false;
                });
              }
            },
            activeTrackColor: AppColors.primaryCyan.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primaryCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    if (_transferMode == 'nearby') {
      return GradientButton(
        label: 'Search Nearby Devices',
        icon: Icons.wifi_tethering_rounded,
        gradient: AppColors.sendGradient,
        onPressed: _startNearbySearch,
      );
    } else {
      return Column(
        children: [
          GradientButton(
            label: 'Generate Sharing Code',
            icon: Icons.qr_code_2_rounded,
            gradient: AppColors.receiveGradient,
            isLoading: _isGeneratingLink,
            onPressed: _generateRoomCode,
          ),
          if (_roomCode != null) ...[
            const SizedBox(height: 20),
            _buildRoomCodeCard(),
          ],
        ],
      );
    }
  }

  Widget _buildRoomCodeCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Your Sharing Code', style: AppTypography.heading4),
          const SizedBox(height: 16),
          // Room Code Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _roomCode!.split('').map((c) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c,
                    style: AppTypography.heading2.copyWith(fontSize: 20),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: 'filesharepro://$_roomCode',
              size: 160,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Share this code with receiver',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'Share via WhatsApp',
                  icon: Icons.share_rounded,
                  height: 48,
                  onPressed: _shareCode,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _roomCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Icon(Icons.copy_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      setState(() => _selectedFiles = result.files);
    }
  }

  void _startNearbySearch() async {
    HapticFeedback.mediumImpact();
    
    final hasPerm = await PermissionUtils.requestNearbyPermissions(context);
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions required for Nearby Sharing')),
        );
      }
      return;
    }
    
    // Start nearby hosting so receiver can discover us
    final nearbyService = NearbyService();
    nearbyService.startHosting(
      deviceName: 'FileShare Pro',
      onDeviceConnected: (deviceInfo) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected to ${deviceInfo['name'] ?? 'Device'}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      onError: (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $error'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📡 Broadcasting... Waiting for receiver to connect'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _generateRoomCode() {
    setState(() => _isGeneratingLink = true);

    // Generate 6-character room code using cryptographic randomness
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = String.fromCharCodes(
      List.generate(6, (_) {
        return chars.codeUnitAt(random.nextInt(chars.length));
      }),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _roomCode = code;
          _isGeneratingLink = false;
        });
      }
    });
  }

  void _shareCode() {
    final message = '🔗 FileShare Pro\n\n'
        'I want to send you files securely!\n'
        '📥 Code: $_roomCode\n\n'
        'Open FileShare Pro app → Receive → Enter this code\n\n'
        'Don\'t have the app? Download here:\n'
        'https://play.google.com/store/apps/details?id=com.fileshare.pro';

    Share.share(message, subject: 'FileShare Pro Invite');
  }
}
