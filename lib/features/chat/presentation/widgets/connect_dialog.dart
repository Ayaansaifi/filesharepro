import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../providers/chat_provider.dart';

/// Bottom sheet dialog for creating or joining a chat room
class ConnectDialog extends ConsumerStatefulWidget {
  final bool isJoin;

  const ConnectDialog({super.key, required this.isJoin});

  @override
  ConsumerState<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends ConsumerState<ConnectDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _generatedCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: widget.isJoin
                    ? AppColors.receiveGradient
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isJoin
                            ? AppColors.primaryPurple
                            : AppColors.primaryCyan)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                widget.isJoin ? Icons.login_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.isJoin ? 'Join Chat Room' : 'Create Chat Room',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 6),
            Text(
              widget.isJoin
                  ? 'Enter the room code shared by your friend'
                  : 'Share the code with your friend to start chatting',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (widget.isJoin) ...[
              // Join: Code input
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  style: AppTypography.heading3.copyWith(
                    letterSpacing: 6,
                    fontSize: 24,
                  ),
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: AppTypography.heading3.copyWith(
                      color: AppColors.textHint,
                      letterSpacing: 6,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 20),

              GradientButton(
                label: 'Join Room',
                icon: Icons.login_rounded,
                gradient: AppColors.receiveGradient,
                isLoading: _isLoading,
                onPressed: () => _joinRoom(context),
              ),
            ] else ...[
              // Create: Show generated code
              if (_generatedCode != null) ...[
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Your Room Code',
                          style: AppTypography.caption),
                      const SizedBox(height: 8),
                      Text(
                        _generatedCode!,
                        style: AppTypography.heading1.copyWith(
                          letterSpacing: 8,
                          color: AppColors.primaryCyan,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMiniAction(
                            icon: Icons.copy_rounded,
                            label: 'Copy',
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: _generatedCode!));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Code copied!'),
                                  backgroundColor: AppColors.surface,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          _buildMiniAction(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: () {
                              // TODO: Share via share_plus
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Waiting for peer to join...',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryCyan,
                  ),
                ),
              ] else ...[
                GradientButton(
                  label: 'Create Room',
                  icon: Icons.add_rounded,
                  gradient: AppColors.primaryGradient,
                  isLoading: _isLoading,
                  onPressed: () => _createRoom(context),
                ),
              ],
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryCyan, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final code = await ref
        .read(chatRoomsProvider.notifier)
        .createRoom('My Device');

    setState(() {
      _isLoading = false;
      _generatedCode = code;
    });
  }

  Future<void> _joinRoom(BuildContext context) async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a 6-character room code'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final success = await ref
        .read(chatRoomsProvider.notifier)
        .joinRoom(code, 'My Device');

    setState(() => _isLoading = false);

    if (success && context.mounted) {
      Navigator.pop(context); // close dialog
    }
  }
}
