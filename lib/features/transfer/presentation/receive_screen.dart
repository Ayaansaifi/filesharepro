import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../../../core/utils/permission_utils.dart';
import '../providers/transfer_provider.dart';
import 'transfer_progress_screen.dart';
import 'radar_discovery_screen.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen>
    with TickerProviderStateMixin {
  String _receiveMode = 'nearby';
  final _linkController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isConnecting = false;
  bool _nearbyStarted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNearbyDiscovery();
      _nearbyStarted = true;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _linkController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Receive Files'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeTabs(),
              const SizedBox(height: 24),
              if (_receiveMode == 'link') _buildLinkEntry(),
              if (_receiveMode == 'qr') _buildQrScanner(),
              if (_receiveMode == 'nearby')
                _buildNearbySection(transferState.discoveredDevices),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          _buildTab('nearby', 'Nearby', Icons.wifi_tethering_rounded),
          _buildTab('link', 'Paste Link', Icons.link_rounded),
          _buildTab('qr', 'Scan QR', Icons.qr_code_scanner_rounded),
        ],
      ),
    );
  }

  Widget _buildTab(String mode, String label, IconData icon) {
    final isActive = _receiveMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _receiveMode = mode;
            if (mode == 'nearby' && !_nearbyStarted) {
              _nearbyStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _startNearbyDiscovery();
              });
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isActive ? Colors.white : AppColors.textHint, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: isActive ? Colors.white : AppColors.textHint,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkEntry() {
    return Column(
      children: [
        _PulseAnimation(
          controller: _pulseController,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.receiveGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_rounded,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 24),
        Text('Paste Sender Link', style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'Sender shares a link via WhatsApp/SMS — paste it here',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: _linkController,
            maxLines: 4,
            minLines: 2,
            style: AppTypography.bodySmall,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'filesharepro://CODE#...',
              hintStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: 'Decrypt PIN (if sender encrypted)',
              prefixIcon: Icon(Icons.lock_outline, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Connect & Receive',
          icon: Icons.link_rounded,
          gradient: AppColors.receiveGradient,
          isLoading: _isConnecting,
          enabled: _linkController.text.trim().isNotEmpty,
          onPressed: _connectWithLink,
        ),
      ],
    );
  }

  Widget _buildQrScanner() {
    return Column(
      children: [
        Text('Scan Sender QR', style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'Point camera at sender\'s QR code on Transfer screen',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue;
                  if (value != null && value.startsWith('filesharepro://')) {
                    _linkController.text = value;
                    _connectWithLink();
                    break;
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbySection(List devices) {
    final transferState = ref.watch(transferStateProvider);
    // If a sender has connected and is transferring, show progress UI inline.
    if (transferState.isTransferring || transferState.isCompleted) {
      return _buildReceivingStatus(transferState);
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        _PulseAnimation(
          controller: _pulseController,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.sendGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 24),
        Text('Waiting for Sender', style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'You are visible to nearby senders on the same Wi‑Fi.\n'
          'Just wait — the sender will connect to you automatically, like ShareIt.',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Visible status card
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppColors.sendGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.visibility_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You\'re Visible!',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.success)),
                    const SizedBox(height: 2),
                    Text(
                      'Tell the sender to tap "Send" and pick your device',
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ─── Radar Banner ────────────────────────────────
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RadarDiscoveryScreen(isSender: false),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00D4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open Radar — Visual Discovery',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'See devices on animated radar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),

        // Show nearby devices the receiver can see (informational)
        if (devices.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Devices on your network',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.textHint)),
          ),
          ...devices.map((device) => _buildDeviceTile(device)),
        ],

        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.wifi_rounded,
                  color: AppColors.primaryCyan, size: 32),
              const SizedBox(height: 8),
              Text(
                'Tip: For best results, both phones should be on the same '
                'Wi‑Fi network, or one phone\'s mobile hotspot.',
                style: AppTypography.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceivingStatus(TransferUiState transferState) {
    return Column(
      children: [
        const SizedBox(height: 24),
        _PulseAnimation(
          controller: _pulseController,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: transferState.transferState.toString().contains('completed')
                  ? AppColors.receiveGradient
                  : AppColors.sendGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              transferState.transferState.toString().contains('completed')
                  ? Icons.check_rounded
                  : Icons.download_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          transferState.transferState.toString().contains('completed')
              ? 'Transfer Complete!'
              : 'Receiving Files...',
          style: AppTypography.heading3,
        ),
        const SizedBox(height: 8),
        if (transferState.currentFileName != null)
          Text(
            transferState.currentFileName!,
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (transferState.transferState.toString().contains('transferring')) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: transferState.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceLight,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primaryCyan),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(transferState.progress * 100).toStringAsFixed(0)}%',
            style: AppTypography.labelLarge
                .copyWith(color: AppColors.primaryCyan),
          ),
        ],
        if (transferState.filesSent > 0) ...[
          const SizedBox(height: 12),
          Text(
            '${transferState.filesSent} file(s) received',
            style: AppTypography.bodySmall,
          ),
        ],
      ],
    );
  }

  Future<void> _startNearbyDiscovery() async {
    final hasPerm = await PermissionUtils.requestNearbyPermissions(context);
    if (!hasPerm) return;

    await ref.read(transferStateProvider.notifier).startNearbyDiscovery();
  }

  Widget _buildDeviceTile(dynamic device) {
    // Receiver view: devices are informational only — the sender initiates.
    final name = device.name as String? ?? 'Unknown device';
    final ip = device.ip as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.sendGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smartphone_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.labelLarge),
                Text(ip, style: AppTypography.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.visibility_rounded,
              color: AppColors.success, size: 20),
        ],
      ),
    );
  }

  Future<void> _connectWithLink() async {
    if (kIsWeb) {
      _showWebOnlyMessage();
      return;
    }
    final link = _linkController.text.trim();
    if (link.isEmpty) return;

    setState(() => _isConnecting = true);
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransferProgressScreen(isSender: false),
      ),
    );

    ref.read(transferStateProvider.notifier).setReceiverDecryptPin(
      _pinController.text.trim().isEmpty ? null : _pinController.text.trim(),
    );
    await ref.read(transferStateProvider.notifier).startWebRTCReceiveFromLink(link);
    if (mounted) setState(() => _isConnecting = false);
  }
  void _showWebOnlyMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Long-distance/Nearby sharing Android app par available hai.'),
      ),
    );
  }
}

class _PulseAnimation extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _PulseAnimation({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppAnimatedBuilder(
      listenable: controller,
      builder: (context, child) {
        final scale = 1.0 + (controller.value * 0.05);
        return Transform.scale(scale: scale, child: child);
      },
      child: child,
    );
  }
}
