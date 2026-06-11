
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../providers/transfer_provider.dart';
import '../services/transfer_manager.dart';

class TransferProgressScreen extends ConsumerStatefulWidget {
  final bool isSender;

  const TransferProgressScreen({super.key, required this.isSender});

  @override
  ConsumerState<TransferProgressScreen> createState() =>
      _TransferProgressScreenState();
}

class _TransferProgressScreenState
    extends ConsumerState<TransferProgressScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
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
    final state = ref.watch(transferStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isSender ? 'Sending' : 'Receiving'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _handleCancel(context, ref),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // ─── Progress Ring ──────────────────────
              _buildProgressSection(state),
              const SizedBox(height: 32),

              // ─── Status Message ─────────────────────
              _buildStatusSection(state),
              const SizedBox(height: 24),

              // ─── File Info ──────────────────────────
              if (state.currentFileName != null)
                _buildFileInfo(state),

              const Spacer(),

              // ─── Action Button ──────────────────────
              _buildActionButton(state, context, ref),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(TransferUiState state) {
    if (state.isTransferring || state.isCompleted) {
      return ProgressRing(
        progress: state.progress,
        size: 180,
        centerText: state.isCompleted ? 'Done!' : null,
      );
    }

    // Waiting / Connecting animation
    return AppAnimatedBuilder(
      listenable: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.06);
        final glowAlpha = 0.2 + (_pulseController.value * 0.3);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (widget.isSender
                        ? AppColors.primaryCyan
                        : AppColors.primaryPurple)
                    .withValues(alpha: glowAlpha),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          gradient: widget.isSender
              ? AppColors.sendGradient
              : AppColors.receiveGradient,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getStatusIcon(state),
          color: Colors.white,
          size: 64,
        ),
      ),
    );
  }

  IconData _getStatusIcon(TransferUiState state) {
    switch (state.transferState) {
      case TransferState.idle:
      case TransferState.waiting:
        return Icons.wifi_tethering_rounded;
      case TransferState.connecting:
        return Icons.sync_rounded;
      case TransferState.connected:
        return Icons.link_rounded;
      case TransferState.transferring:
        return widget.isSender
            ? Icons.upload_rounded
            : Icons.download_rounded;
      case TransferState.completed:
        return Icons.check_circle_rounded;
      case TransferState.error:
        return Icons.error_outline_rounded;
    }
  }

  Widget _buildStatusSection(TransferUiState state) {
    final title = _getStatusTitle(state);
    final subtitle = state.statusMessage;

    return Column(
      children: [
        Text(title, style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (state.isTransferring) ...[
          const SizedBox(height: 12),
          Text(
            '${(state.progress * 100).toStringAsFixed(0)}%',
            style: AppTypography.heading2.copyWith(
              color: AppColors.primaryCyan,
            ),
          ),
          if (state.totalFiles > 1)
            Text(
              'File ${state.filesSent + 1} of ${state.totalFiles}',
              style: AppTypography.caption,
            ),
        ],
        if (state.hasError) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              state.errorMessage ?? 'An error occurred',
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusTitle(TransferUiState state) {
    switch (state.transferState) {
      case TransferState.idle:
        return 'Ready';
      case TransferState.waiting:
        return widget.isSender ? 'Waiting for Receiver' : 'Waiting for Sender';
      case TransferState.connecting:
        return 'Connecting...';
      case TransferState.connected:
        return 'Connected!';
      case TransferState.transferring:
        return widget.isSender ? 'Sending...' : 'Receiving...';
      case TransferState.completed:
        return '🎉 Transfer Complete!';
      case TransferState.error:
        return 'Transfer Failed';
    }
  }

  Widget _buildFileInfo(TransferUiState state) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insert_drive_file_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.currentFileName ?? '',
                  style: AppTypography.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (state.totalFiles > 0)
                  Text(
                    '${state.filesSent} of ${state.totalFiles} files',
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
          if (state.encryptionEnabled)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_rounded,
                  color: AppColors.success, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      TransferUiState state, BuildContext context, WidgetRef ref) {
    if (state.isCompleted) {
      return GradientButton(
        label: 'Done',
        icon: Icons.check_rounded,
        gradient: AppColors.successGradient,
        onPressed: () => Navigator.pop(context),
      );
    }

    if (state.hasError) {
      return Column(
        children: [
          GradientButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            gradient: AppColors.primaryGradient,
            onPressed: () {
              ref.read(transferStateProvider.notifier).cancel();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please start the transfer again.')));
            },
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Go Back',
            icon: Icons.arrow_back_rounded,
            gradient: LinearGradient(
              colors: [AppColors.surfaceLight, AppColors.surface],
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    }

    return GradientButton(
      label: 'Cancel Transfer',
      icon: Icons.close_rounded,
      gradient: LinearGradient(
        colors: [
          AppColors.error.withValues(alpha: 0.8),
          AppColors.error,
        ],
      ),
      onPressed: () => _handleCancel(context, ref),
    );
  }

  void _handleCancel(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Transfer?'),
        content: const Text('This will stop the ongoing transfer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              ref.read(transferStateProvider.notifier).cancel();
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back
            },
            child: const Text('Cancel Transfer',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
