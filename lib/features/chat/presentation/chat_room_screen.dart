import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/app_animated_builder.dart';

import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import 'widgets/file_bubble.dart';
import 'widgets/text_bubble.dart';
import 'widgets/voice_bubble.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const ChatRoomScreen({super.key, required this.roomCode});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  late AnimationController _typingController;

  // Voice note state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  bool _showEmojiPanel = false;

  // Quick emoji reactions
  static const _quickEmojis = ['😂', '❤️', '👍', '🔥', '😍', '😮'];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    // Load chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeChatProvider.notifier).loadChat(widget.roomCode);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _typingController.dispose();
    _textController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(activeChatProvider);

    // Auto-scroll on new messages
    ref.listen(activeChatProvider, (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        Future.delayed(
            const Duration(milliseconds: 100), () => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: AppColors.whatsAppChatBg,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.whatsAppChatBg),
        child: SafeArea(
          child: Column(
            children: [
              // ─── App Bar ────────────────────────────
              _buildChatHeader(chatState),

              // ─── Messages ──────────────────────────
              Expanded(child: _buildMessageList(chatState)),

              // ─── Sending Progress ───────────────────
              if (chatState.isSending) _buildSendingProgress(chatState),

              // ─── Reply Preview Bar ──────────────────
              if (chatState.replyToMessage != null)
                _buildReplyPreviewBar(chatState.replyToMessage!),

              // ─── Emoji Panel ────────────────────────
              if (_showEmojiPanel) _buildEmojiPanel(),

              // ─── Bottom Bar ─────────────────────────
              _buildBottomBar(context, chatState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatHeader(ActiveChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () {
              ref.read(activeChatProvider.notifier).clearSelection();
              Navigator.pop(context);
            },
          ),
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 22),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: chatState.isConnected
                        ? AppColors.success
                        : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (chatState.peerName != null && chatState.peerName!.isNotEmpty)
                      ? chatState.peerName!
                      : widget.roomCode,
                    style: AppTypography.labelLarge.copyWith(fontSize: 15)),
                Row(
                  children: [
                    if (chatState.isTyping)
                      Row(
                        children: List.generate(3, (i) {
                          return AppAnimatedBuilder(
                            listenable: _typingController,
                            builder: (ctx, child) {
                              final delay = i * 0.3;
                              final value = (((_typingController.value - delay)
                                          .clamp(0.0, 1.0)) *
                                      2)
                                  .clamp(0.0, 1.0);
                              return Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.whatsAppGreen.withValues(
                                      alpha: 0.3 + value * 0.7),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                            child: const SizedBox(),
                          );
                        }),
                      )
                    else
                      Text(
                        _getStatusText(chatState),
                        style: AppTypography.caption.copyWith(
                          color: chatState.isPeerOnline
                              ? AppColors.success
                              : AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    if (chatState.isTyping) ...[
                      const SizedBox(width: 6),
                      Text(
                        'typing...',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.whatsAppGreen,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Copy room code
          GlassCard(
            padding: const EdgeInsets.all(8),
            borderRadius: 12,
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Room code copied!'),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Icon(Icons.copy_rounded,
                color: AppColors.primaryCyan, size: 18),
          ),
          const SizedBox(width: 4),
          // More menu
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: AppColors.surfaceLight,
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textPrimary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (context) => [
                _popMenuItem('clear_chat', Icons.delete_sweep_rounded,
                    'Clear Chat', AppColors.textSecondary),
                _popMenuItem('starred', Icons.star_rounded,
                    'Starred Messages', const Color(0xFFFFC107)),
                _popMenuItem('encryption', Icons.lock_rounded,
                    'Encryption: On', AppColors.success),
                _popMenuItem('report', Icons.report_problem_rounded,
                    'Report User', AppColors.error),
                _popMenuItem('block', Icons.block_rounded,
                    'Block User', AppColors.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(ActiveChatState chatState) {
    if (chatState.isPeerOnline) return 'Online';
    if (chatState.isConnected) return 'Online';
    return 'Offline';
  }

  PopupMenuEntry<String> _popMenuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    final notifier = ref.read(activeChatProvider.notifier);
    switch (action) {
      case 'clear_chat':
        final confirm = await _showConfirmDialog(
          'Clear Chat?',
          'All messages will be deleted locally. This cannot be undone.',
        );
        if (confirm == true && mounted) {
          notifier.clearChat();
          _showSnackBar('Chat cleared');
        }
        break;

      case 'starred':
        _showSnackBar('Starred messages feature — tap ⭐ on any message to star it');
        break;

      case 'encryption':
        _showSnackBar('End-to-end encrypted with AES-256 ✅');
        break;

      case 'report':
      case 'block':
        final title = action == 'report' ? 'Report User?' : 'Block User?';
        final content = action == 'report'
            ? 'Report this user for abusive behavior? They will also be blocked.'
            : 'Block this user? You will no longer receive messages from them.';

        final confirm = await _showConfirmDialog(title, content,
            confirmLabel: action == 'report' ? 'Report & Block' : 'Block');

        if (confirm == true) {
          await ref
              .read(blockedUsersProvider.notifier)
              .blockUser(widget.roomCode);
          if (mounted) {
            _showSnackBar(action == 'report' ? 'User reported & blocked.' : 'User blocked.');
            Navigator.pop(context);
          }
        }
        break;
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content,
      {String confirmLabel = 'Confirm'}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ActiveChatState chatState) {
    if (chatState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded,
                  color: AppColors.primaryCyan.withValues(alpha: 0.6),
                  size: 40),
            ),
            const SizedBox(height: 16),
            Text('Messages are end-to-end encrypted',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textHint)),
            const SizedBox(height: 8),
            Text(
              'Send a message to start chatting',
              style: AppTypography.caption,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        final showDate = index == 0 ||
            !_isSameDay(
                message.timestamp, chatState.messages[index - 1].timestamp);

        Widget bubble;
        final isSelected = chatState.selectedMessageId == message.id;
        switch (message.type) {
          case MessageType.text:
          case MessageType.deleted:
            bubble = TextBubble(
              message: message,
              isSelected: isSelected,
              onLongPress: () => _showMessageOptions(context, message),
            );
            break;
          case MessageType.voice:
            bubble = VoiceBubble(message: message);
            break;
          default:
            bubble = FileBubble(message: message);
        }

        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.timestamp),
            bubble,
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(label, style: AppTypography.caption.copyWith(fontSize: 11)),
        ),
      ),
    );
  }

  /// WhatsApp-style bottom sheet with message actions
  void _showMessageOptions(BuildContext context, ChatMessage message) {
    final notifier = ref.read(activeChatProvider.notifier);
    notifier.setSelectedMessage(message.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Message preview
              if (message.textContent != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.textContent!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppColors.primaryCyan),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.setReplyTo(message);
                },
              ),
              ListTile(
                leading: Icon(
                  message.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFFFC107),
                ),
                title: Text(message.isStarred ? 'Unstar' : 'Star'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.toggleStarMessage(message.id);
                },
              ),
              if (message.textContent != null)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: message.textContent!));
                    _showSnackBar('Message copied');
                    notifier.clearSelection();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.shortcut_rounded, color: AppColors.textSecondary),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(ctx);
                  notifier.forwardMessage(message);
                  _showSnackBar('Message forwarded');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Delete for Me'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.deleteMessageForMe(message.id);
                  _showSnackBar('Message deleted for you');
                },
              ),
              if (message.direction == MessageDirection.sent && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                  title: const Text('Delete for Everyone'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await notifier.deleteMessageForEveryone(message.id);
                    _showSnackBar('Message deleted for everyone');
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).then((_) {
      // Clear selection when sheet closes
      if (mounted) notifier.clearSelection();
    });
  }

  Widget _buildReplyPreviewBar(ChatMessage repliedTo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryCyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repliedTo.replyToSender ?? 'Replying to message',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  repliedTo.textContent ??
                      repliedTo.fileName ??
                      'Message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textHint),
            onPressed: () {
              ref.read(activeChatProvider.notifier).setReplyTo(null);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSendingProgress(ActiveChatState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              AppAnimatedBuilder(
                listenable: _typingController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.5 + (_typingController.value * 0.5),
                    child: child,
                  );
                },
                child: const Icon(Icons.upload_rounded,
                    color: AppColors.primaryCyan, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Sending... ${(state.sendProgress * 100).toStringAsFixed(0)}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.sendProgress,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryCyan),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _quickEmojis.map((emoji) {
          return GestureDetector(
            onTap: () {
              _textController.text += emoji;
              setState(() => _showEmojiPanel = false);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ActiveChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji button
          IconButton(
            icon: Icon(
              _showEmojiPanel
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
              color: AppColors.textHint,
              size: 26,
            ),
            onPressed: () =>
                setState(() => _showEmojiPanel = !_showEmojiPanel),
          ),

          // Attachment Button
          IconButton(
            icon: const Icon(Icons.attach_file_rounded,
                color: AppColors.textHint, size: 26),
            onPressed: chatState.isSending ? null : () => _pickAndSendFile(),
          ),

          // Text Input Field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.surfaceLight,
                  width: 0.5,
                ),
              ),
              child: Scrollbar(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isRecording ? '🔴 Recording...' : 'Message',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: _isRecording ? AppColors.error : AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (text) {
                    final notifier = ref.read(activeChatProvider.notifier);
                    if (text.isNotEmpty && !_isRecording) {
                      notifier.sendTypingStatus(true);
                    } else if (text.isEmpty) {
                      notifier.sendTypingStatus(false);
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send / Mic Button
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            onTap: () {
              if (_textController.text.trim().isNotEmpty) {
                _sendMessage();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Hold mic to record a voice note')),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: _isRecording
                    ? const LinearGradient(
                        colors: [AppColors.error, Color(0xFFFF6B6B)])
                    : chatState.isSending
                        ? LinearGradient(colors: [
                            AppColors.textHint,
                            AppColors.textHint.withValues(alpha: 0.7)
                          ])
                        : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? AppColors.error
                            : AppColors.primaryCyan)
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _textController.text.trim().isNotEmpty
                      ? Icons.send_rounded
                      : (_isRecording
                          ? Icons.stop_rounded
                          : Icons.mic_rounded),
                  key: ValueKey(_textController.text.trim().isNotEmpty ||
                      _isRecording),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final notifier = ref.read(activeChatProvider.notifier);
    final replyTo = ref.read(activeChatProvider).replyToMessage;

    if (replyTo != null) {
      notifier.sendTextMessage(
        text,
        replyToId: replyTo.id,
        replyToText: replyTo.textContent ?? replyTo.fileName ?? 'Message',
        replyToSender: 'You',
      );
      notifier.setReplyTo(null);
    } else {
      notifier.sendTextMessage(text);
    }
    notifier.sendTypingStatus(false);
    _textController.clear();
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      setState(() => _isRecording = true);
      HapticFeedback.mediumImpact();
      final dir = await Directory.systemTemp.createTemp('voice_notes');
      _recordingPath =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      final path = await _audioRecorder.stop();
      if (path != null && File(path).existsSync()) {
        ref.read(activeChatProvider.notifier).sendFile(File(path));
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    HapticFeedback.lightImpact();
    // Show bottom sheet for file type selection
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(ctx, Icons.image_rounded, 'Photo/Video',
                    AppColors.primaryCyan, FileType.media),
                _attachOption(ctx, Icons.insert_drive_file_rounded, 'Document',
                    AppColors.warning, FileType.custom),
                _attachOption(ctx, Icons.audiotrack_rounded, 'Audio',
                    AppColors.accentPink, FileType.audio),
                _attachOption(ctx, Icons.folder_open_rounded, 'Any File',
                    AppColors.primaryPurple, FileType.any),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(BuildContext ctx, IconData icon, String label,
      Color color, FileType type) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(ctx);
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: type == FileType.custom
              ? FileType.any
              : type,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = File(result.files.first.path!);
          ref.read(activeChatProvider.notifier).sendFile(file);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
