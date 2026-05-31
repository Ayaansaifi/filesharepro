
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/file_utils.dart';
import '../../models/chat_message.dart';

/// WhatsApp-style file message bubble
class FileBubble extends StatelessWidget {
  final ChatMessage message;

  const FileBubble({super.key, required this.message});

  bool get isSent => message.direction == MessageDirection.sent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isSent ? 60 : 0,
          right: isSent ? 0 : 60,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onFileTap(context),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showFileOptions(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: isSent
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryCyan.withValues(alpha: 0.15),
                          AppColors.primaryPurple.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          AppColors.surfaceLight.withValues(alpha: 0.6),
                          AppColors.surface.withValues(alpha: 0.8),
                        ],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isSent ? 16 : 4),
                  bottomRight: Radius.circular(isSent ? 4 : 16),
                ),
                border: Border.all(
                  color: isSent
                      ? AppColors.primaryCyan.withValues(alpha: 0.2)
                      : AppColors.surfaceLight.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // File card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // File icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: _getFileGradient(),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: _getFileIcon(),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // File info
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.fileName ?? 'Unknown file',
                                style: AppTypography.labelMedium.copyWith(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${message.fileSize != null ? FileUtils.formatFileSize(message.fileSize!) : '0 B'} • ${(message.fileExtension?.toUpperCase() ?? '').replaceAll('.', '')}',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status / Download icon
                        const SizedBox(width: 8),
                        _buildStatusIcon(),
                      ],
                    ),
                  ),

                  // Timestamp + status
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                        if (isSent) ...[
                          const SizedBox(width: 4),
                          _buildDeliveryIcon(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (!isSent && message.status == MessageStatus.delivered) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.download_rounded,
            color: AppColors.success, size: 18),
      );
    }

    if (message.status == MessageStatus.sending) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryCyan,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDeliveryIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded,
            size: 14, color: AppColors.textHint);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            size: 14, color: AppColors.textHint);
      case MessageStatus.delivered:
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded,
            size: 14, color: AppColors.primaryCyan.withValues(alpha: 0.8));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded,
            size: 14, color: AppColors.error);
      case MessageStatus.downloading:
        return const Icon(Icons.downloading_rounded,
            size: 14, color: AppColors.primaryCyan);
    }
  }

  LinearGradient _getFileGradient() {
    final name = message.fileName ?? '';
    if (FileUtils.isImage(name)) {
      return const LinearGradient(
        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
      );
    }
    if (FileUtils.isVideo(name)) {
      return const LinearGradient(
        colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
      );
    }
    final ext = message.fileExtension?.toLowerCase() ?? '';
    if (ext == '.pdf') {
      return const LinearGradient(
        colors: [Color(0xFFFF5722), Color(0xFFD84315)],
      );
    }
    if (ext == '.apk') {
      return const LinearGradient(
        colors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
      );
    }
    return AppColors.primaryGradient;
  }

  Widget _getFileIcon() {
    IconData icon;
    final name = message.fileName ?? '';
    if (FileUtils.isImage(name)) {
      icon = Icons.image_rounded;
    } else if (FileUtils.isVideo(name)) {
      icon = Icons.videocam_rounded;
    } else {
      final ext = message.fileExtension?.toLowerCase() ?? '';
      switch (ext) {
        case '.pdf':
          icon = Icons.picture_as_pdf_rounded;
        case '.doc':
        case '.docx':
          icon = Icons.description_rounded;
        case '.mp3':
        case '.wav':
        case '.aac':
          icon = Icons.audiotrack_rounded;
        case '.zip':
        case '.rar':
          icon = Icons.folder_zip_rounded;
        case '.apk':
          icon = Icons.android_rounded;
        default:
          icon = Icons.insert_drive_file_rounded;
      }
    }
    return Icon(icon, color: Colors.white, size: 22);
  }

  void _onFileTap(BuildContext context) {
    HapticFeedback.lightImpact();
    // TODO: Open file with system viewer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📎 ${message.fileName ?? 'File'}'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showFileOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
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
            Text(message.fileName ?? 'Unknown file',
                style: AppTypography.labelLarge, maxLines: 2),
            Text(message.fileSize != null ? FileUtils.formatFileSize(message.fileSize!) : 'Unknown size',
                style: AppTypography.caption),
            const SizedBox(height: 20),
            _buildOption(
              icon: Icons.open_in_new_rounded,
              label: 'Open File',
              onTap: () => Navigator.pop(context),
            ),
            _buildOption(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () => Navigator.pop(context),
            ),
            _buildOption(
              icon: Icons.save_alt_rounded,
              label: 'Save to Gallery',
              onTap: () => Navigator.pop(context),
            ),
            _buildOption(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(label,
          style: AppTypography.labelMedium.copyWith(color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
