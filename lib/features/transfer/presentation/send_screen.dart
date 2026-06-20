import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/permission_utils.dart';
import '../providers/transfer_provider.dart';
import '../services/transfer_manager.dart';
import 'transfer_progress_screen.dart';
import 'widgets/pin_input_dialog.dart';
import 'radar_discovery_screen.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen>
    with TickerProviderStateMixin {
  List<PlatformFile> _selectedFiles = [];
  bool _encryptEnabled = false;
  String? _encryptionPin;
  String _transferMode = 'nearby';
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _loadDefaultSettings();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _encryptEnabled = prefs.getBool('always_encrypt') ?? false;
        final mode = prefs.getString('transfer_mode') ?? 'Nearby (Wi-Fi Direct)';
        _transferMode =
            mode == 'Nearby (Wi-Fi Direct)' ? 'nearby' : 'longdistance';
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
                _buildModeSelector(),
                const SizedBox(height: 16),

                // ─── Radar Quick-Connect Banner ─────────────────────
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RadarDiscoveryScreen(isSender: true),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radar, color: Colors.white, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nearby Radar — AirDrop Mode',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Auto-discover devices • No QR needed • 0 data',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white70, size: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _buildFilePicker(),
                const SizedBox(height: 20),
                if (_selectedFiles.isNotEmpty) ...[
                  _buildSelectedFiles(),
                  const SizedBox(height: 20),
                ],
                _buildEncryptionToggle(),
                const SizedBox(height: 24),
                if (_selectedFiles.isNotEmpty) _buildActionSection(),
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
        const SizedBox(height: 8),
        Text(
          'Nearby = ShareIt speed on same Wi‑Fi • Long Distance = anywhere via link',
          style: AppTypography.caption,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                'nearby',
                'Nearby',
                Icons.wifi_tethering_rounded,
                'Wi‑Fi Direct • Ultra Fast',
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
            color: isSelected ? Colors.transparent : AppColors.glassBorder,
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
                style: AppTypography.labelLarge.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTypography.caption.copyWith(
                color: isSelected ? Colors.white70 : AppColors.textHint,
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
              'Photos, Videos, APK, Documents — multiple files supported',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
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
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _selectedFiles.length.clamp(0, 8),
          (index) => _buildFileItem(_selectedFiles[index]),
        ),
        if (_selectedFiles.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${_selectedFiles.length - 8} more files',
              style: AppTypography.bodySmall.copyWith(color: AppColors.primaryCyan),
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
          Text(FileUtils.getFileTypeIcon(file.name),
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: AppTypography.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(FileUtils.formatFileSize(file.size),
                    style: AppTypography.caption),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _selectedFiles.remove(file)),
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
              gradient: _encryptEnabled ? AppColors.vaultGradient : null,
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
                      ? 'AES-256 • Receiver needs PIN'
                      : 'Send without encryption',
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
                    _encryptionPin = pin;
                  });
                }
              } else {
                setState(() {
                  _encryptEnabled = false;
                  _encryptionPin = null;
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
    final label = _transferMode == 'nearby'
        ? 'Send via Nearby (ShareIt Mode)'
        : 'Create Connection Link';
    final icon = _transferMode == 'nearby'
        ? Icons.wifi_tethering_rounded
        : Icons.qr_code_2_rounded;

    return GradientButton(
      label: label,
      icon: icon,
      gradient: _transferMode == 'nearby'
          ? AppColors.sendGradient
          : AppColors.receiveGradient,
      onPressed: _startTransfer,
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

  Future<void> _startTransfer() async {
    HapticFeedback.mediumImpact();

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Web preview: UI only. Full file sharing ke liye Android app install karein.',
          ),
        ),
      );
      return;
    }

    if (_transferMode == 'nearby') {
      final hasPerm = await PermissionUtils.requestNearbyPermissions(context);
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions required for Nearby Sharing'),
            ),
          );
        }
        return;
      }
    }

    final files = <File>[];
    for (final pf in _selectedFiles) {
      if (pf.path != null) files.add(File(pf.path!));
    }
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid files to send')),
      );
      return;
    }

    final notifier = ref.read(transferStateProvider.notifier);
    notifier.setMode(
      _transferMode == 'nearby'
          ? TransferMode.nearby
          : TransferMode.longDistance,
    );
    notifier.setEncryption(
      enabled: _encryptEnabled,
      pin: _encryptionPin,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransferProgressScreen(isSender: true),
      ),
    );

    await notifier.startSending(files);
  }
}
