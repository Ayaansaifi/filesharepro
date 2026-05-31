import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_animated_builder.dart';

class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Gradient? gradient;
  final IconData? icon;
  final double? width;
  final double height;
  final bool isLoading;
  final bool enabled;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient,
    this.icon,
    this.width,
    this.height = 56,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppColors.primaryGradient;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _onTapDown() : null,
      onTapUp: widget.enabled ? (_) => _onTapUp() : null,
      onTapCancel: widget.enabled ? _onTapCancel : null,
      onTap: widget.enabled && !widget.isLoading ? widget.onPressed : null,
      child: AppAnimatedBuilder(
        listenable: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? effectiveGradient
                : LinearGradient(
                    colors: [
                      AppColors.surfaceLight,
                      AppColors.surfaceLight,
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.enabled && !_isPressed
                ? [
                    BoxShadow(
                      color: AppColors.primaryCyan.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(widget.label, style: AppTypography.button),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _onTapDown() {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }
}
