import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../services/nearby_service.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../../../core/utils/permission_utils.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with TickerProviderStateMixin {
  String _receiveMode = 'code'; // 'code', 'qr', 'nearby'
  final _codeController = TextEditingController();
  bool _isConnecting = false;
  String _connectionStatus = '';
  bool _isNearbySearching = false;
  NearbyService? _nearbyService;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // ─── Receive Mode Tabs ───────────────────
              _buildModeTabs(),
              const SizedBox(height: 24),

              // ─── Content based on mode ───────────────
              if (_receiveMode == 'code') _buildCodeEntry(),
              if (_receiveMode == 'qr') _buildQrScanner(),
              if (_receiveMode == 'nearby') _buildNearbyWaiting(),
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
          _buildTab('code', 'Enter Code', Icons.dialpad_rounded),
          _buildTab('qr', 'Scan QR', Icons.qr_code_scanner_rounded),
          _buildTab('nearby', 'Nearby', Icons.wifi_tethering_rounded),
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
          setState(() => _receiveMode = mode);
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
                  color: isActive ? Colors.white : AppColors.textHint,
                  size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: isActive ? Colors.white : AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      children: [
        // Illustration
        _PulseAnimation(
          controller: _pulseController,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.receiveGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.download_rounded,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 24),

        Text('Enter Sharing Code', style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'Ask the sender for their 6-digit code',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: 24),

        // Code Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: AppTypography.heading2.copyWith(
              letterSpacing: 8,
              fontSize: 28,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: '------',
              hintStyle: AppTypography.heading2.copyWith(
                color: AppColors.textHint,
                letterSpacing: 8,
                fontSize: 28,
              ),
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              UpperCaseTextFormatter(),
            ],
            onChanged: (val) => setState(() {}),
          ),
        ),
        const SizedBox(height: 24),

        GradientButton(
          label: _connectionStatus.isNotEmpty ? _connectionStatus : 'Connect',
          icon: Icons.link_rounded,
          gradient: AppColors.receiveGradient,
          isLoading: _isConnecting,
          enabled: _codeController.text.length == 6,
          onPressed: _connectWithCode,
        ),
      ],
    );
  }

  Widget _buildQrScanner() {
    return Column(
      children: [
        Text('Scan Sender\'s QR Code', style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'Point your camera at the QR code shown on sender\'s screen',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // QR Scanner
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 300,
            child: MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final value = barcode.rawValue;
                  if (value != null && value.startsWith('filesharepro://')) {
                    final code = value.replaceFirst('filesharepro://', '');
                    _codeController.text = code;
                    setState(() => _receiveMode = 'code');
                    _connectWithCode();
                    break;
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'QR code will be automatically detected',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _buildNearbyWaiting() {
    // Start discovery when this tab is shown
    if (!_isNearbySearching) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startNearbyDiscovery());
    }
    return Column(
      children: [
        const SizedBox(height: 40),
        _PulseAnimation(
          controller: _pulseController,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.sendGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Colors.white, size: 50),
          ),
        ),
        const SizedBox(height: 32),

        Text('Waiting for Sender', style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'Make sure both devices are on the same network\nor within Wi-Fi Direct range',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Animated dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return AppAnimatedBuilder(
              listenable: _pulseController,
              builder: (context, child) {
                final delay = i * 0.3;
                final value = (_pulseController.value + delay) % 1.0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryCyan.withValues(alpha: 0.3 + value * 0.7),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _connectWithCode() {
    if (_codeController.text.length != 6) return;
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Looking up room code...';
    });
    HapticFeedback.mediumImpact();

    // Use signaling service to look up and connect
    final signaling = SignalingService();
    final webrtc = WebRTCService();
    
    () async {
      try {
        final roomCode = _codeController.text.trim().toUpperCase();
        setState(() => _connectionStatus = 'Connecting to $roomCode...');
        
        // Try to get signal data for this room
        final signalData = await signaling.getSignalData(roomCode);
        
        if (signalData != null) {
          setState(() => _connectionStatus = 'Found room! Creating connection...');
          
          final unpacked = signaling.unpackageSignalData(signalData);
          if (unpacked != null) {
            final answer = await webrtc.createAnswer(unpacked['sdp']);
            if (answer != null) {
              final answerData = signaling.packageSignalData(
                type: 'answer',
                sdp: answer,
              );
              await signaling.storeSignalData('${roomCode}_answer', answerData);
              
              setState(() => _connectionStatus = 'Connected! Waiting for files...');
              
              webrtc.onTransferComplete = (fileName) {
                if (mounted) {
                  setState(() {
                    _isConnecting = false;
                    _connectionStatus = '';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Received: $fileName'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              };
              
              webrtc.onTransferProgress = (progress) {
                if (mounted) {
                  setState(() {
                    _connectionStatus = 'Receiving: ${(progress * 100).toStringAsFixed(0)}%';
                  });
                }
              };
              
              return;
            }
          }
        }
        
        // If we get here, connection failed
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _connectionStatus = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Room not found. Ask sender for a new code.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _connectionStatus = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection error: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }();
  }

  void _startNearbyDiscovery() async {
    if (_isNearbySearching) return;
    
    final hasPerm = await PermissionUtils.requestNearbyPermissions(context);
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions required for Nearby Sharing')),
        );
      }
      return;
    }
    
    _nearbyService = NearbyService();
    setState(() => _isNearbySearching = true);
    
    _nearbyService!.startDiscovery(
      onDeviceFound: (deviceInfo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📱 Found: ${deviceInfo['name'] ?? 'Device'}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isNearbySearching = false);
        }
      },
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
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
