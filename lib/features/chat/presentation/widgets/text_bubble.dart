import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../models/chat_message.dart';

class TextBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onLongPress;

  const TextBubble({
    super.key,
    required this.message,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSent = message.direction == MessageDirection.sent;
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isSent ? AppColors.primaryCyan : AppColors.surfaceLight,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSent ? 16 : 4),
              bottomRight: Radius.circular(isSent ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment:
                isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Linkify(
                onOpen: (link) async {
                  final uri = Uri.parse(link.url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                text: message.textContent ?? '',
                style: AppTypography.bodyMedium.copyWith(
                  color: isSent ? Colors.white : AppColors.textPrimary,
                  height: 1.3,
                ),
                linkStyle: TextStyle(
                  color: isSent ? Colors.white : AppColors.primaryCyan,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: isSent
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textHint,
                      fontSize: 10,
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
                ],
              ),
            ],
          ),
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
    return isSent ? Colors.white.withOpacity(0.7) : AppColors.textHint;
  }
}
