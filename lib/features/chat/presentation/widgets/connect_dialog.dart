import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../providers/chat_provider.dart';
import 'package:share_plus/share_plus.dart';

class ConnectDialog extends ConsumerStatefulWidget {
  final bool isJoin;

  const ConnectDialog({super.key, required this.isJoin});

  @override
  ConsumerState<ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends ConsumerState<ConnectDialog> {
  final _codeController = TextEditingController();
  final _answerController = TextEditingController();
  bool _isLoading = false;
  String? _generatedCode;
  String? _joinerAnswerLink;

  @override
  void dispose() {
    _codeController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: widget.isJoin ? AppColors.receiveGradient : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                widget.isJoin ? Icons.login_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isJoin ? 'Join Chat' : 'New Chat',
              style: AppTypography.heading3,
            ),
            const SizedBox(height: 6),
            Text(
              widget.isJoin
                  ? 'Host ka link paste karo — WhatsApp jaisa secure chat'
                  : 'Link share karo, phir answer link paste karo',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.isJoin) ...[
              _linkField(_codeController, 'Paste host connection link...'),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Join Chat',
                icon: Icons.login_rounded,
                gradient: AppColors.receiveGradient,
                isLoading: _isLoading,
                onPressed: () => _joinRoom(context),
              ),
              if (_joinerAnswerLink != null) ...[
                const SizedBox(height: 20),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Answer link — host ko bhejo', style: AppTypography.caption),
                      const SizedBox(height: 8),
                      Text(
                        _joinerAnswerLink!,
                        style: AppTypography.caption.copyWith(fontSize: 10),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _joinerAnswerLink!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Answer link copied')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy'),
                          ),
                          TextButton.icon(
                            onPressed: () => Share.share('FileShare Pro chat answer:\n$_joinerAnswerLink'),
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              if (_generatedCode != null) ...[
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Room Code', style: AppTypography.caption),
                      const SizedBox(height: 8),
                      Text(
                        _generatedCode!,
                        style: AppTypography.heading1.copyWith(
                          letterSpacing: 6,
                          color: AppColors.whatsAppGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _miniAction(Icons.copy_rounded, 'Copy Link', () => _copyHostLink(context)),
                          const SizedBox(width: 16),
                          _miniAction(Icons.share_rounded, 'Share', () => _shareHostLink(context)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Step 2: Joiner ka answer link paste karo',
                    style: AppTypography.caption.copyWith(color: AppColors.whatsAppGreen)),
                const SizedBox(height: 8),
                _linkField(_answerController, 'Paste answer link from joiner...'),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Connect',
                  icon: Icons.link_rounded,
                  gradient: AppColors.primaryGradient,
                  onPressed: () => _applyAnswer(context),
                ),
              ] else
                GradientButton(
                  label: 'Create Chat',
                  icon: Icons.add_rounded,
                  gradient: AppColors.primaryGradient,
                  isLoading: _isLoading,
                  onPressed: () => _createRoom(context),
                ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _linkField(TextEditingController c, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: c,
        maxLines: 3,
        minLines: 1,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none),
      ),
    );
  }

  Widget _miniAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.whatsAppGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.whatsAppGreen, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _copyHostLink(BuildContext context) async {
    final signaling = ref.read(chatServiceProvider).signaling;
    final signalData = await signaling.getSignalData(_generatedCode!);
    if (signalData == null) return;
    final link = signaling.generateQrContent(
      roomCode: _generatedCode!,
      signalData: signalData,
    );
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Host link copied — WhatsApp par bhejo')),
      );
    }
  }

  Future<void> _shareHostLink(BuildContext context) async {
    final signaling = ref.read(chatServiceProvider).signaling;
    final signalData = await signaling.getSignalData(_generatedCode!);
    if (signalData == null) return;
    final link = signaling.generateQrContent(
      roomCode: _generatedCode!,
      signalData: signalData,
    );
    await Share.share('FileShare Pro secure chat:\n$link');
  }

  Future<void> _createRoom(BuildContext context) async {
    setState(() => _isLoading = true);
    final code = await ref.read(chatRoomsProvider.notifier).createRoom('Me');
    setState(() {
      _isLoading = false;
      _generatedCode = code;
    });
  }

  Future<void> _joinRoom(BuildContext context) async {
    final link = _codeController.text.trim();
    final signaling = ref.read(chatServiceProvider).signaling;
    final parsed = signaling.parseQrContent(link);
    if (parsed == null || parsed['roomCode'] == null || parsed['signalData'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link — poora link paste karo')),
      );
      return;
    }
    await signaling.storeSignalData(parsed['roomCode']!, parsed['signalData']!);
    setState(() => _isLoading = true);
    final success = await ref.read(chatRoomsProvider.notifier).joinRoom(parsed['roomCode']!, 'Me');
    final answerLink = ref.read(chatRoomsProvider.notifier).lastAnswerLink;
    setState(() {
      _isLoading = false;
      _joinerAnswerLink = answerLink;
    });
    if (success && context.mounted && answerLink == null) {
      Navigator.pop(context);
    }
  }

  Future<void> _applyAnswer(BuildContext context) async {
    final link = _answerController.text.trim();
    if (link.isEmpty) return;
    final ok = await ref.read(chatRoomsProvider.notifier).applyReceiverAnswer(link);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Connected! Chat shuru karo' : 'Answer link invalid')),
      );
      if (ok) Navigator.pop(context);
    }
  }
}
