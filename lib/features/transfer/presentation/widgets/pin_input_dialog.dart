import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_animated_builder.dart';

class PinInputDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isVerification;

  const PinInputDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.isVerification = false,
  });

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog>
    with SingleTickerProviderStateMixin {
  final List<String> _pin = [];
  bool _isError = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.vaultGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPink.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.lock_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 20),

            Text(widget.title, style: AppTypography.heading3),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // PIN Dots
            AppAnimatedBuilder(
              listenable: _shakeController,
              builder: (context, child) {
                final offset = _isError
                    ? 10.0 *
                        (0.5 - _shakeController.value) *
                        (1 - _shakeController.value)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: filled ? 20 : 16,
                    height: filled ? 20 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: filled ? AppColors.primaryGradient : null,
                      color: filled ? null : AppColors.surfaceLight,
                      border: Border.all(
                        color: _isError
                            ? AppColors.error
                            : filled
                                ? Colors.transparent
                                : AppColors.glassBorder,
                        width: 2,
                      ),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                color: AppColors.primaryCyan
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),

            // Number Pad
            _buildNumberPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildNumberRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildNumberRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildNumberRow(['7', '8', '9']),
        const SizedBox(height: 12),
        _buildNumberRow(['', '0', '⌫']),
      ],
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) {
        if (n.isEmpty) return const SizedBox(width: 64, height: 64);
        return _buildNumberButton(n);
      }).toList(),
    );
  }

  Widget _buildNumberButton(String value) {
    final isBackspace = value == '⌫';
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isBackspace) {
          if (_pin.isNotEmpty) {
            setState(() {
              _pin.removeLast();
              _isError = false;
            });
          }
        } else if (_pin.length < 4) {
          setState(() {
            _pin.add(value);
            _isError = false;
          });
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                Navigator.pop(context, _pin.join());
              }
            });
          }
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isBackspace
              ? Colors.transparent
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: isBackspace
              ? null
              : Border.all(color: AppColors.glassBorder),
        ),
        child: Center(
          child: isBackspace
              ? Icon(Icons.backspace_outlined,
                  color: AppColors.textSecondary, size: 22)
              : Text(
                  value,
                  style: AppTypography.heading2.copyWith(fontSize: 22),
                ),
        ),
      ),
    );
  }
}
