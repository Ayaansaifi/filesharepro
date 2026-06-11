import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../models/contact_model.dart';
import '../models/user_profile.dart';
import '../providers/chat_provider.dart';
import '../../../core/utils/permission_utils.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final Strategy strategy = Strategy.P2P_STAR;
  bool _isDiscovering = false;
  bool _isAdvertising = false;
  
  // endpointId -> name
  final Map<String, String> _discoveredEndpoints = {};
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
    _requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopDiscoveryAndAdvertising();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final hasPerm = await PermissionUtils.requestNearbyPermissions(context);
    if (!hasPerm && mounted) {
      _showSnackBar('Location permission is required for Radar', isError: true);
      return;
    }
    
    // Request additional Bluetooth permissions required by nearby_connections package
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
  }

  Future<void> _stopDiscoveryAndAdvertising() async {
    await Nearby().stopDiscovery();
    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
    setState(() {
      _isDiscovering = false;
      _isAdvertising = false;
      _discoveredEndpoints.clear();
    });
  }

  Future<void> _startAdvertising() async {
    final profile = ref.read(myProfileProvider);
    final name = profile?.displayName ?? 'Unknown User';
    
    try {
      final success = await Nearby().startAdvertising(
        name,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _exchangeProfileData(id);
          }
        },
        onDisconnected: (id) {},
      );
      
      if (success) {
        setState(() => _isAdvertising = true);
        _showSnackBar('Visible to nearby users');
      }
    } catch (e) {
      _showSnackBar('Failed to advertise: $e', isError: true);
    }
  }

  Future<void> _startDiscovery() async {
    try {
      final success = await Nearby().startDiscovery(
        'filesharepro',
        strategy,
        onEndpointFound: (id, name, serviceId) {
          final blocked = ref.read(blockedUsersProvider);
          if (blocked.contains(name)) return;
          
          setState(() {
            _discoveredEndpoints[id] = name;
          });
          HapticFeedback.lightImpact();
        },
        onEndpointLost: (id) {
          setState(() {
            _discoveredEndpoints.remove(id);
          });
        },
      );
      
      if (success) {
        setState(() => _isDiscovering = true);
      }
    } catch (e) {
      _showSnackBar('Failed to start discovery: $e', isError: true);
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    final blocked = ref.read(blockedUsersProvider);
    if (blocked.contains(info.endpointName)) {
       Nearby().rejectConnection(id);
       return;
    }

    // Auto-accept connection for pairing
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES) {
          final str = String.fromCharCodes(payload.bytes!);
          _handleReceivedProfile(str);
        }
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );
  }

  Future<void> _exchangeProfileData(String endpointId) async {
    final profile = ref.read(myProfileProvider);
    if (profile == null) return;
    
    final data = json.encode(profile.toJson());
    await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(data.codeUnits));
    _showSnackBar('Paired successfully!');
  }

  void _handleReceivedProfile(String jsonStr) {
    try {
      final Map<String, dynamic> data = json.decode(jsonStr);
      final profile = UserProfile.fromJson(data);
      
      final contact = AppContact(
        id: profile.uniqueId,
        displayName: profile.displayName,
        phoneNumber: '', // Local app users might not share phone numbers directly
        deviceId: profile.uniqueId, // Using profile ID as device ID for now
      );
      
      ref.read(contactsServiceProvider).savePairedContact(contact);
      
      // Refresh contacts list provider if exists
      // ref.invalidate(pairedContactsProvider);
      
      _showSnackBar('Added ${profile.displayName} to contacts!', isError: false);
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showSnackBar('Failed to read profile data', isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Add Contact Radar', style: AppTypography.heading3),
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
                      if (_isDiscovering || _isAdvertising)
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
                        child: const Icon(Icons.radar_rounded, color: Colors.white, size: 40),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                Text(
                  _isDiscovering ? 'Scanning for nearby users...' : 
                  _isAdvertising ? 'Visible to nearby users...' : 'Radar Inactive',
                  style: AppTypography.bodyMedium,
                ),
                
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GradientButton(
                      label: _isDiscovering ? 'Stop Scan' : 'Scan',
                      icon: Icons.search_rounded,
                      gradient: _isDiscovering ? const LinearGradient(colors: [AppColors.error, Colors.redAccent]) : AppColors.primaryGradient,
                      onPressed: _isDiscovering ? _stopDiscoveryAndAdvertising : _startDiscovery,
                    ),
                    const SizedBox(width: 16),
                    GradientButton(
                      label: _isAdvertising ? 'Hide' : 'Be Visible',
                      icon: Icons.visibility_rounded,
                      gradient: _isAdvertising ? const LinearGradient(colors: [AppColors.error, Colors.redAccent]) : AppColors.receiveGradient,
                      onPressed: _isAdvertising ? _stopDiscoveryAndAdvertising : _startAdvertising,
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Results List
                Expanded(
                  child: _discoveredEndpoints.isEmpty
                      ? Center(
                          child: Text(
                            'No devices found yet.\nMake sure the other device is "Visible".',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _discoveredEndpoints.length,
                          itemBuilder: (context, index) {
                            final entry = _discoveredEndpoints.entries.elementAt(index);
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
                                      child: Text(entry.value, style: AppTypography.heading4),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Nearby().requestConnection(
                                          'filesharepro',
                                          entry.key,
                                          onConnectionInitiated: _onConnectionInit,
                                          onConnectionResult: (id, status) {
                                            if (status == Status.CONNECTED) {
                                              _exchangeProfileData(id);
                                            }
                                          },
                                          onDisconnected: (id) {},
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: const Text('Pair', style: TextStyle(color: AppColors.primaryCyan)),
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
