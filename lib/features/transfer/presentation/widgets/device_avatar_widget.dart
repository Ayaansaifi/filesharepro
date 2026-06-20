import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'radar_painter.dart';

enum DeviceConnectionState { discovered, connecting, connected, failed }

/// Animated device avatar placed on the radar.
/// Pulses when first discovered, shows connection status.
class DeviceAvatarWidget extends StatefulWidget {
  final RadarDevice device;
  final DeviceConnectionState state;
  final VoidCallback onTap;

  const DeviceAvatarWidget({
    super.key,
    required this.device,
    required this.state,
    required this.onTap,
  });

  @override
  State<DeviceAvatarWidget> createState() => _DeviceAvatarWidgetState();
}

class _DeviceAvatarWidgetState extends State<DeviceAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: widget.state == DeviceConnectionState.discovered
            ? widget.onTap
            : null,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: widget.state == DeviceConnectionState.discovered
                ? _pulseAnim.value
                : 1.0,
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatar(),
              const SizedBox(height: 4),
              _buildLabel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    Color ringColor;
    Color bgColor;
    Widget icon;

    switch (widget.state) {
      case DeviceConnectionState.discovered:
        ringColor = AppColors.primaryCyan;
        bgColor = AppColors.primaryCyan.withValues(alpha: 0.15);
        icon = Text(
          widget.device.name.isNotEmpty ? widget.device.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primaryCyan,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
      case DeviceConnectionState.connecting:
        ringColor = AppColors.accentOrange;
        bgColor = AppColors.accentOrange.withValues(alpha: 0.15);
        icon = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentOrange,
          ),
        );
      case DeviceConnectionState.connected:
        ringColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.15);
        icon = const Icon(Icons.check_rounded, color: AppColors.success, size: 20);
      case DeviceConnectionState.failed:
        ringColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.1);
        icon = const Icon(Icons.close_rounded, color: AppColors.error, size: 20);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: ringColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(child: icon),
    );
  }

  Widget _buildLabel() {
    String label;
    Color color;

    switch (widget.state) {
      case DeviceConnectionState.discovered:
        label = widget.device.name;
        color = AppColors.textPrimary;
      case DeviceConnectionState.connecting:
        label = 'Connecting...';
        color = AppColors.accentOrange;
      case DeviceConnectionState.connected:
        label = 'Connected!';
        color = AppColors.success;
      case DeviceConnectionState.failed:
        label = 'Failed';
        color = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
