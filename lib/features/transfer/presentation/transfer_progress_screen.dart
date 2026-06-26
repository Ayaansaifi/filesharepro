import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../providers/transfer_provider.dart';
import '../services/transfer_manager.dart';
import '../../../core/services/local_network_service.dart';

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

              // ─── Sender: pick nearby receiver (SHAREit-style) ──
              if (widget.isSender &&
                  state.isWaiting &&
                  state.mode == TransferMode.nearby)
                _buildSenderDevicePicker(state, context, ref),

              if (widget.isSender &&
                  state.isWaiting &&
                  state.connectionLink != null)
                _buildSenderLinkSection(state, context),

              if (!widget.isSender &&
                  state.isWaiting &&
                  state.answerLink != null)
                _buildReceiverAnswerSection(state, context),

              if (widget.isSender &&
                  state.isWaiting &&
                  state.connectionLink != null)
                _buildPasteAnswerSection(context, ref),

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

  Widget _buildSenderLinkSection(TransferUiState state, BuildContext context) {
    final link = state.connectionLink!;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Share with Receiver', style: AppTypography.labelLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(data: link, size: 140, backgroundColor: Colors.white),
            ),
            if (state.roomCode != null) ...[
              const SizedBox(height: 8),
              Text('Code: ${state.roomCode}', style: AppTypography.caption),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Share Link',
                    icon: Icons.share_rounded,
                    height: 44,
                    onPressed: () {
                      Share.share(
                        'FileShare Pro — receive my files:\n$link\n\n'
                        'Open app → Receive → Paste Link\n'
                        'https://play.google.com/store/apps/details?id=${AppConstants.appPackage}',
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverAnswerSection(TransferUiState state, BuildContext context) {
    final link = state.answerLink!;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Send this back to Sender', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            Text(
              'Share via WhatsApp/SMS so sender can paste answer',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Share Answer',
                    icon: Icons.reply_rounded,
                    height: 44,
                    gradient: AppColors.receiveGradient,
                    onPressed: () => Share.share('FileShare Pro answer:\n$link'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Answer link copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasteAnswerSection(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GradientButton(
        label: 'Paste Receiver Answer',
        icon: Icons.paste_rounded,
        height: 44,
        gradient: AppColors.primaryGradient,
        onPressed: () async {
          final data = await Clipboard.getData('text/plain');
          final text = data?.text?.trim();
          if (text == null || !text.startsWith('filesharepro://')) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copy receiver answer link first'),
                ),
              );
            }
            return;
          }
          await ref.read(transferStateProvider.notifier).applyReceiverAnswer(text);
        },
      ),
    );
  }

  Widget _buildSenderDevicePicker(
      TransferUiState state, BuildContext context, WidgetRef ref) {
    final devices = state.discoveredDevices;

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, color: AppColors.primaryCyan, size: 20),
                  const SizedBox(width: 8),
                  Text('Pick a receiver', style: AppTypography.labelLarge),
                  const Spacer(),
                  if (devices.isNotEmpty)
                    Text('${devices.length} found',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.success)),
                ],
              ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryCyan),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Scanning nearby devices…\n'
                          'Make sure the receiver opened "Receive" on the same Wi-Fi.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return _buildDevicePickRow(device, ref);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevicePickRow(LocalDevice device, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.mediumImpact();
        ref
            .read(transferStateProvider.notifier)
            .connectAndSend(device);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.sendGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smartphone_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: AppTypography.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(device.ip,
                      style: AppTypography.caption.copyWith(fontSize: 10)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.send_rounded,
                      color: AppColors.primaryCyan, size: 14),
                  SizedBox(width: 4),
                  Text('Send',
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
