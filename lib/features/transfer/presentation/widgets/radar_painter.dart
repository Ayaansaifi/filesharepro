import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Radar sweep CustomPainter — draws concentric rings + rotating sweep arm.
/// Uses RepaintBoundary in parent for 60fps isolation.
class RadarPainter extends CustomPainter {
  final double sweepAngle; // 0.0 to 2*pi (current rotation)
  final List<RadarDevice> devices;

  RadarPainter({required this.sweepAngle, required this.devices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // ── Concentric Rings ──────────────────────────────────────
    final ringPaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), ringPaint);
    }

    // Cross-hair lines
    final crossPaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      crossPaint,
    );

    // ── Sweep Trail ───────────────────────────────────────────
    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - 1.2,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          AppColors.primaryCyan.withValues(alpha: 0.0),
          AppColors.primaryCyan.withValues(alpha: 0.35),
        ],
      ).createShader(sweepRect)
      ..style = PaintingStyle.fill;

    canvas.drawArc(sweepRect, sweepAngle - 1.2, 1.2, true, sweepPaint);

    // ── Sweep Arm ─────────────────────────────────────────────
    final armPaint = Paint()
      ..color = AppColors.primaryCyan.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final armEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, armEnd, armPaint);

    // ── Center Dot (pulsing handled by animation above) ───────
    final dotPaint = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.primaryCyan, AppColors.primaryCyan.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: 8));
    canvas.drawCircle(center, 8, dotPaint);

    final dotCorePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3, dotCorePaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) =>
      oldDelegate.sweepAngle != sweepAngle ||
      oldDelegate.devices.length != devices.length;
}

/// Represents a device visible on the radar.
class RadarDevice {
  final String endpointId;
  final String name;
  final double angle;   // angle from center (radians)
  final double distance; // normalized 0.0 to 1.0

  RadarDevice({
    required this.endpointId,
    required this.name,
    required this.angle,
    required this.distance,
  });

  /// Deterministically place device based on name hash
  factory RadarDevice.fromEndpoint(String endpointId, String name) {
    final hash = name.hashCode.abs();
    final angle = (hash % 360) * (math.pi / 180);
    final distance = 0.35 + (hash % 50) / 100.0; // 0.35 - 0.85
    return RadarDevice(
      endpointId: endpointId,
      name: name,
      angle: angle,
      distance: distance,
    );
  }

  Offset positionInCircle(Offset center, double maxRadius) {
    return Offset(
      center.dx + maxRadius * distance * math.cos(angle),
      center.dy + maxRadius * distance * math.sin(angle),
    );
  }
}
