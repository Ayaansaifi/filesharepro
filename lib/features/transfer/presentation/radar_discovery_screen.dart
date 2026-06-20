import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../services/nearby_service.dart';
import 'widgets/radar_painter.dart';
import 'widgets/device_avatar_widget.dart';

/// Full-screen radar discovery UI for finding nearby devices via
/// Google Nearby Connections API.
///
/// Uses CustomPainter radar with rotating sweep + device avatars positioned
/// as Stack children over the radar canvas.
///
/// Calls existing [NearbyService] — zero new P2P logic required.
class RadarDiscoveryScreen extends ConsumerStatefulWidget {
  /// Whether this device is the sender (advertising) or receiver (discovering).
  final bool isSender;
  final void Function(String endpointId, String deviceName)? onDeviceConnected;

  const RadarDiscoveryScreen({
    super.key,
    this.isSender = true,
    this.onDeviceConnected,
  });

  @override
  ConsumerState<RadarDiscoveryScreen> createState() =>
      _RadarDiscoveryScreenState();
}

class _RadarDiscoveryScreenState extends ConsumerState<RadarDiscoveryScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ────────────────────────────────
  late AnimationController _sweepCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Nearby Service ───────────────────────────────────────
  final NearbyService _nearbyService = NearbyService();

  // ── State ────────────────────────────────────────────────
  final Map<String, RadarDevice> _devices = {};
  final Map<String, DeviceConnectionState> _connectionStates = {};
  String _statusText = 'Initializing radar...';
  bool _isActive = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();

    // Sweep animation: full rotation every 3 seconds
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Center pulse animation
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Start discovering/advertising after frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRadar());
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _pulseCtrl.dispose();
    _nearbyService.dispose();
    super.dispose();
  }

  // ── Start Nearby ─────────────────────────────────────────

  Future<void> _startRadar() async {
    if (kIsWeb) {
      setState(() => _statusText = 'Nearby Connections requires Android device.');
      return;
    }

    _nearbyService.onStatusChange = (status) {
      if (mounted) setState(() => _statusText = status);
    };

    _nearbyService.onDeviceFound = (device) {
      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          final rd = RadarDevice.fromEndpoint(device.address, device.name);
          _devices[device.address] = rd;
          _connectionStates[device.address] = DeviceConnectionState.discovered;
          _statusText = '${_devices.length} device(s) found';
          _isActive = true;
        });
      }
    };

    _nearbyService.onError = (err) {
      if (mounted) setState(() => _statusText = '⚠️ $err');
    };

    if (widget.isSender) {
      // Sender = Advertise
      await _nearbyService.startHosting(
        deviceName: 'FileShare Pro',
        onDeviceConnected: (info) {
          if (mounted) {
            setState(() => _statusText = '📡 Receiver found!');
          }
        },
        onError: (e) {
          if (mounted) setState(() => _statusText = 'Hosting error: $e');
        },
      );
      setState(() => _statusText = '📡 Broadcasting... waiting for receiver');
    } else {
      // Receiver = Discover
      await _nearbyService.startDiscovery(
        onDeviceFound: (info) {
          final name = info['name'] as String? ?? 'Device';
          final id = info['address'] as String? ?? '';
          if (id.isNotEmpty && mounted) {
            HapticFeedback.lightImpact();
            setState(() {
              final rd = RadarDevice.fromEndpoint(id, name);
              _devices[id] = rd;
              _connectionStates[id] = DeviceConnectionState.discovered;
              _statusText = '${_devices.length} device(s) found';
              _isActive = true;
            });
          }
        },
        onError: (e) {
          if (mounted) setState(() => _statusText = 'Discovery error: $e');
        },
      );
      setState(() => _statusText = '🔍 Scanning for nearby senders...');
    }
  }

  // ── Connect to Device ────────────────────────────────────

  Future<void> _connectToDevice(String endpointId) async {
    if (_connectingId != null) return;
    _connectingId = endpointId;

    setState(() => _connectionStates[endpointId] = DeviceConnectionState.connecting);
    HapticFeedback.mediumImpact();

    final success = await _nearbyService.connectToHost(endpointId);

    if (mounted) {
      setState(() {
        _connectionStates[endpointId] = success
            ? DeviceConnectionState.connected
            : DeviceConnectionState.failed;
        _connectingId = null;
      });

      if (success) {
        HapticFeedback.heavyImpact();
        final device = _devices[endpointId];
        widget.onDeviceConnected?.call(endpointId, device?.name ?? 'Device');
        _showConnectedSheet(device?.name ?? 'Device');
      }
    }
  }

  // ── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.radar, color: AppColors.primaryCyan, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Nearby Radar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Toggle sender/receiver mode hint
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.15),
              side: BorderSide(color: AppColors.primaryCyan.withValues(alpha: 0.3)),
              label: Text(
                widget.isSender ? '📡 Sender' : '🔍 Receiver',
                style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status Text ─────────────────────────────
          _buildStatusBar(),

          // ── Radar Canvas ────────────────────────────
          Expanded(child: _buildRadarCanvas()),

          // ── Device List ─────────────────────────────
          if (_devices.isNotEmpty) _buildDeviceList(),

          // ── Bottom Info ─────────────────────────────
          _buildBottomInfo(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _sweepCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _sweepCtrl.value * 2 * math.pi,
              child: child,
            ),
            child: const Icon(Icons.radar, color: AppColors.primaryCyan, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (_isActive)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadarCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size / 2, size / 2);
        final maxRadius = size / 2 - 16;

        return RepaintBoundary( // isolate radar repaints for 60fps
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  // ── Radar Canvas ───────────────────────
                  AnimatedBuilder(
                    animation: _sweepCtrl,
                    builder: (context, child) => CustomPaint(
                      size: Size(size, size),
                      painter: RadarPainter(
                        sweepAngle: _sweepCtrl.value * 2 * math.pi,
                        devices: _devices.values.toList(),
                      ),
                    ),
                  ),

                  // ── Device Avatars overlaid on radar ───
                  ..._devices.entries.map((entry) {
                    final rd = entry.value;
                    final pos = rd.positionInCircle(center, maxRadius);
                    return Positioned(
                      left: pos.dx - 22, // center the 44px avatar
                      top: pos.dy - 30,  // slightly above for label
                      child: DeviceAvatarWidget(
                        device: rd,
                        state: _connectionStates[entry.key] ??
                            DeviceConnectionState.discovered,
                        onTap: () => _connectToDevice(entry.key),
                      ),
                    );
                  }),

                  // ── Center Pulsing Dot ─────────────────
                  Positioned.fill(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryCyan,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryCyan.withValues(alpha: 0.5),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.phone_android,
                              color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceList() {
    return Container(
      height: 100,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Found Devices (tap on radar to connect)',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _devices.length,
              itemBuilder: (_, i) {
                final entry = _devices.entries.elementAt(i);
                final connState = _connectionStates[entry.key] ??
                    DeviceConnectionState.discovered;
                return GestureDetector(
                  onTap: connState == DeviceConnectionState.discovered
                      ? () => _connectToDevice(entry.key)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: connState == DeviceConnectionState.connected
                            ? AppColors.success
                            : AppColors.primaryCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android,
                          color: AppColors.primaryCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.value.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        if (connState == DeviceConnectionState.connecting) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentOrange,
                            ),
                          ),
                        ] else if (connState == DeviceConnectionState.connected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 14),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi, color: AppColors.textHint, size: 14),
          const SizedBox(width: 6),
          const Text(
            'Wi-Fi Direct • Bluetooth • No Internet Required',
            style: TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showConnectedSheet(String deviceName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.success, width: 2),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Connected to $deviceName!',
                style: AppTypography.heading3),
            const SizedBox(height: 6),
            const Text(
              'You can now send files directly over Wi-Fi Direct.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Start Transferring',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
