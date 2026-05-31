import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_animated_builder.dart';

class ProgressRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Gradient? gradient;
  final String? centerText;
  final Widget? centerWidget;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 8,
    this.gradient,
    this.centerText,
    this.centerWidget,
  });

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAnimatedBuilder(
      listenable: _pulseController,
      builder: (context, child) {
        final glowOpacity = 0.2 + (_pulseController.value * 0.3);
        return Container(
          width: widget.size + 20,
          height: widget.size + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryCyan.withValues(alpha: glowOpacity),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: widget.strokeWidth,
                color: AppColors.surfaceLight,
              ),
            ),
            // Progress arc
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _GradientProgressPainter(
                  progress: widget.progress,
                  strokeWidth: widget.strokeWidth,
                  gradient: widget.gradient ?? AppColors.primaryGradient,
                ),
              ),
            ),
            // Center content
            widget.centerWidget ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.centerText ??
                          '${(widget.progress * 100).toInt()}%',
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                        fontSize: widget.size * 0.22,
                      ),
                    ),
                    if (widget.progress < 1.0)
                      Text(
                        'Transferring...',
                        style: AppTypography.caption.copyWith(
                          fontSize: widget.size * 0.09,
                        ),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _GradientProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Gradient gradient;

  _GradientProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
