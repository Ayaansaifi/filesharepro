import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/services/local_network_service.dart';
import '../providers/chat_provider.dart';
import 'chat_room_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  
  List<LocalDevice> _discoveredDevices = [];
  late AnimationController _pulseController;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscovery();
    });
  }

  void _startDiscovery() {
    final network = ref.read(localNetworkServiceProvider);
    final profile = ref.read(myProfileProvider);
    if (profile == null) return;

    network.onDevicesChanged = (devices) {
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
        });
      }
    };
    network.startDiscovery(profile);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    final network = ref.read(localNetworkServiceProvider);
    network.stopDiscovery();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _connectToDevice(LocalDevice device) async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final chatRooms = ref.read(chatRoomsProvider.notifier);
      final success = await chatRooms.connectTo(device.ip, device.id, device.name);
      
      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(roomCode: device.id),
          ),
        );
      } else {
        _showSnackBar('Failed to connect to ${device.name}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Nearby Wi-Fi Radar', style: AppTypography.heading3),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                
                // Radar Animation
                SizedBox(
                  height: 250,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 100 + (_pulseController.value * 150),
                            height: 100 + (_pulseController.value * 150),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryCyan.withValues(alpha: 1 - _pulseController.value),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 40),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                Text(
                  'Scanning Local Network...',
                  style: AppTypography.bodyMedium,
                ),
                Text(
                  'Make sure both devices are on the same Wi-Fi\nor connected via Mobile Hotspot.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: AppColors.textHint),
                ),
                
                const SizedBox(height: 40),
                
                // Results List
                Expanded(
                  child: _discoveredDevices.isEmpty
                      ? Center(
                          child: Text(
                            'No devices found yet.\nKeep this screen open on both phones.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryCyan.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person, color: AppColors.primaryCyan),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(device.name, style: AppTypography.heading4),
                                          Text(device.ip, style: AppTypography.caption),
                                        ],
                                      ),
                                    ),
                                    _isConnecting
                                        ? const CircularProgressIndicator(strokeWidth: 2)
                                        : TextButton(
                                            onPressed: () => _connectToDevice(device),
                                            style: TextButton.styleFrom(
                                              backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            ),
                                            child: const Text('Connect', style: TextStyle(color: AppColors.primaryCyan)),
                                          ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
