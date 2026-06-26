import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../providers/transfer_provider.dart';
import '../../../core/services/local_network_service.dart';
import 'transfer_progress_screen.dart';

class RadarDiscoveryScreen extends ConsumerStatefulWidget {
  final bool isSender;
  const RadarDiscoveryScreen({super.key, required this.isSender});

  @override
  ConsumerState<RadarDiscoveryScreen> createState() => _RadarDiscoveryScreenState();
}

class _RadarDiscoveryScreenState extends ConsumerState<RadarDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isSender) {
        // Sender searches for receivers
        ref.read(transferStateProvider.notifier).startNearbyDiscovery();
      } else {
        // Receiver waits for senders
        ref.read(transferStateProvider.notifier).startNearbyDiscovery();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _connectToDevice(LocalDevice device) {
    if (widget.isSender) {
      ref.read(transferStateProvider.notifier).connectAndSend(device);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TransferProgressScreen(isSender: true),
        ),
      );
    } else {
      // Receiver doesn't initiate connection, they just wait.
      // Actually, if they tap, maybe we can just show a toast.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait for the sender to send files to you')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferStateProvider);
    final devices = state.discoveredDevices;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isSender ? 'Select Receiver' : 'Waiting for Sender'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
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
                widget.isSender ? 'Scanning for receivers...' : 'Visible to senders',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: devices.isEmpty
                    ? Center(
                        child: Text(
                          'No devices found yet.\nMake sure both devices are on the same Wi-Fi.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
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
                                  if (widget.isSender)
                                    TextButton(
                                      onPressed: () => _connectToDevice(device),
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: const Text('Send', style: TextStyle(color: AppColors.primaryCyan)),
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
      ),
    );
  }
}
