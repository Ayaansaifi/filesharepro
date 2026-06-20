import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/ai_provider.dart';

/// 3 animated smart reply suggestion chips shown above the message input.
/// Appears when the last received message is available and AI is enabled.
class AiReplyButtons extends ConsumerStatefulWidget {
  final String lastReceivedMessage;
  final void Function(String reply) onReplySelected;

  const AiReplyButtons({
    super.key,
    required this.lastReceivedMessage,
    required this.onReplySelected,
  });

  @override
  ConsumerState<AiReplyButtons> createState() => _AiReplyButtonsState();
}

class _AiReplyButtonsState extends ConsumerState<AiReplyButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation =
        Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(aiEnabledProvider);
    if (!aiEnabled || widget.lastReceivedMessage.isEmpty) {
      return const SizedBox.shrink();
    }

    final repliesAsync =
        ref.watch(suggestedRepliesProvider(widget.lastReceivedMessage));

    return repliesAsync.when(
      loading: () => _buildLoadingChips(),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (replies) {
        if (replies.isEmpty) return const SizedBox.shrink();
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildChips(replies),
          ),
        );
      },
    );
  }

  Widget _buildChips(List<String> replies) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primaryPurple, size: 14),
              const SizedBox(width: 4),
              Text(
                'AI Suggestions',
                style: TextStyle(
                  color: AppColors.primaryPurple.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: replies
                  .map((reply) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ReplyChip(
                          text: reply,
                          onTap: () => widget.onReplySelected(reply),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 80,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Single Reply Chip ────────────────────────────────────────────

class _ReplyChip extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _ReplyChip({required this.text, required this.onTap});

  @override
  State<_ReplyChip> createState() => _ReplyChipState();
}

class _ReplyChipState extends State<_ReplyChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp: (_) {
        _scaleCtrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.forward(),
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (_, child) =>
            Transform.scale(scale: _scaleCtrl.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF8E44AD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
