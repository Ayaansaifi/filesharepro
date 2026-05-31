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
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── App Bar ────────────────────────────
              _buildChatHeader(chatState),

              // ─── Messages ──────────────────────────
              Expanded(child: _buildMessageList(chatState)),

              // ─── Sending Progress ───────────────────
              if (chatState.isSending) _buildSendingProgress(chatState),

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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        border: const Border(
          bottom: BorderSide(color: AppColors.surfaceLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Room: ${widget.roomCode}',
                    style: AppTypography.labelLarge),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: chatState.isConnected
                            ? AppColors.success
                            : AppColors.textHint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      chatState.isConnected ? 'Connected' : 'Offline',
                      style: AppTypography.caption.copyWith(
                        color: chatState.isConnected
                            ? AppColors.success
                            : AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textHint.withValues(alpha: 0.3), size: 64),
            const SizedBox(height: 16),
            Text('No messages yet',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textHint)),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
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
            !_isSameDay(message.timestamp,
                chatState.messages[index - 1].timestamp);

        Widget bubble;
        switch (message.type) {
          case MessageType.text:
            bubble = TextBubble(message: message);
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: AppTypography.caption.copyWith(fontSize: 11)),
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

  Widget _buildBottomBar(BuildContext context, ActiveChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        border: const Border(
          top: BorderSide(color: AppColors.surfaceLight, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment Button
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.primaryCyan, size: 28),
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
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isRecording ? 'Recording audio...' : 'Type a message',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: _isRecording ? AppColors.error : AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (text) {
                    setState(() {}); // Trigger rebuild to swap mic/send icon
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
                // Short tap on mic doesn't do anything or shows hint
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hold to record voice note')),
                );
              }
            },
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                gradient: chatState.isSending
                    ? LinearGradient(colors: [
                        AppColors.textHint,
                        AppColors.textHint.withValues(alpha: 0.7)
                      ])
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: chatState.isSending
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryCyan.withValues(alpha: 0.4),
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
                      : (_isRecording ? Icons.mic_rounded : Icons.mic_none_rounded),
                  key: ValueKey(_textController.text.trim().isNotEmpty || _isRecording),
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
    
    ref.read(activeChatProvider.notifier).sendTextMessage(text);
    _textController.clear();
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      setState(() => _isRecording = true);
      HapticFeedback.lightImpact();
      final dir = await Directory.systemTemp.createTemp('voice_notes');
      _recordingPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = File(result.files.first.path!);
      ref.read(activeChatProvider.notifier).sendFile(file);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
