import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/chat_message.dart';

class TextBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatMessage? replyToMessage;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const TextBubble({
    super.key,
    required this.message,
    this.replyToMessage,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSent = message.direction == MessageDirection.sent;
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    // Deleted message — show WhatsApp-style tombstone
    if (message.isDeleted || message.type == MessageType.deleted) {
      return _buildDeletedBubble(isSent, timeStr);
    }

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isSent
                ? AppColors.whatsAppSentBubble
                : AppColors.whatsAppReceivedBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: Radius.circular(isSent ? 8 : 2),
              bottomRight: Radius.circular(isSent ? 2 : 8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
            border: isSelected
                ? Border.all(color: AppColors.primaryCyan, width: 2)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Forwarded indicator
              if (message.isForwarded) _buildForwardedLabel(),

              // Reply preview
              if (message.replyToId != null) _buildReplyPreview(),

              // Star indicator
              if (message.isStarred) _buildStarIndicator(),

              Linkify(
                onOpen: (link) async {
                  final uri = Uri.parse(link.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                text: message.textContent ?? '',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
                linkStyle: const TextStyle(
                  color: AppColors.primaryBlue,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                  if (isSent) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _getStatusIcon(message.status),
                      size: 14,
                      color: _getStatusColor(message.status, isSent),
                    ),
                  ],
                  if (message.isStarred) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Color(0xFFFFC107),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble(bool isSent, String timeStr) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        constraints: const BoxConstraints(
          maxWidth: 280,
        ),
        decoration: BoxDecoration(
          color: isSent
              ? AppColors.whatsAppSentBubble
              : AppColors.whatsAppReceivedBubble,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 14, color: AppColors.textHint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'This message was deleted',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForwardedLabel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shortcut_rounded, size: 14, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            'Forwarded',
            style: AppTypography.caption.copyWith(
              color: AppColors.textHint,
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    final replyText = message.replyToText ?? '';
    final replySender = message.replyToSender ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: AppColors.primaryCyan, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replySender.isNotEmpty)
            Text(
              replySender,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryCyan,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          Text(
            replyText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Icon(
          Icons.star_rounded,
          size: 14,
          color: const Color(0xFFFFC107).withValues(alpha: 0.8),
        ),
      ),
    );
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
      default:
        return Icons.access_time;
    }
  }

  Color _getStatusColor(MessageStatus status, bool isSent) {
    if (status == MessageStatus.read) {
      return const Color(0xFF34B7F1); // WhatsApp Blue tick
    }
    return isSent ? Colors.white.withValues(alpha: 0.7) : AppColors.textHint;
  }
}
