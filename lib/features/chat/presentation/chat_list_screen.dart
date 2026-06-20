import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../../../features/stories/presentation/story_ring_widget.dart';

import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'chat_room_screen.dart';
import 'contacts_screen.dart';
import 'widgets/connect_dialog.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatRoomsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Header ───────────────────────────────
              _buildHeader(context),

              // ─── Ephemeral Stories Row ────────────────
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const StoriesRow(),
              ),
              Container(
                height: 1,
                color: AppColors.glassBorder,
              ),

              // ─── Chat List ───────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: chatState.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primaryCyan))
                      : chatState.rooms.isEmpty
                          ? _buildEmptyState()
                          : _buildChatList(chatState.rooms),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: _buildFab(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryCyan.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File Chat', style: AppTypography.heading3),
                Text(
                  'Encrypted P2P • End-to-End',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.primaryCyan),
                ),
              ],
            ),
          ),
          // Search icon
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () {},
          ),
          // More menu
          Theme(
            data: Theme.of(context)
                .copyWith(cardColor: AppColors.surfaceLight),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textSecondary, size: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'new_room') {
                  _showConnectDialog(context, isJoin: false);
                } else if (val == 'join') {
                  _showConnectDialog(context, isJoin: true);
                } else if (val == 'contacts') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContactsScreen()),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'new_room',
                  child: Row(children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.primaryCyan, size: 18),
                    SizedBox(width: 10),
                    Text('New Room'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'join',
                  child: Row(children: [
                    Icon(Icons.link_rounded,
                        color: AppColors.primaryCyan, size: 18),
                    SizedBox(width: 10),
                    Text('Join with Code'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'contacts',
                  child: Row(children: [
                    Icon(Icons.contacts_rounded,
                        color: AppColors.primaryCyan, size: 18),
                    SizedBox(width: 10),
                    Text('Contacts'),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryCyan.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.chat_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text('No Chats Yet', style: AppTypography.heading3),
            const SizedBox(height: 8),
            Text(
              'Start a new file chat to share\nfiles securely with friends',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionChip(
                  icon: Icons.add_rounded,
                  label: 'Create Room',
                  color: AppColors.primaryCyan,
                  onTap: () => _showConnectDialog(context, isJoin: false),
                ),
                const SizedBox(width: 12),
                _buildActionChip(
                  icon: Icons.login_rounded,
                  label: 'Join Room',
                  color: AppColors.primaryPurple,
                  onTap: () => _showConnectDialog(context, isJoin: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildChatList(List<ChatRoom> rooms) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _buildChatTile(room, index);
      },
    );
  }

  Widget _buildChatTile(ChatRoom room, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(room.roomCode),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: AppColors.error),
        ),
        onDismissed: (_) {
          ref.read(chatRoomsProvider.notifier).deleteRoom(room.roomCode);
        },
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ChatRoomScreen(roomCode: room.roomCode),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(0),
                ),
                child: Row(
                  children: [
                    // WhatsApp-style circular avatar
                    Stack(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: index.isEven
                                ? AppColors.primaryGradient
                                : AppColors.receiveGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              room.peerName.isNotEmpty
                                  ? room.peerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (room.isActive)
                          Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.surface,
                                    width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.peerName,
                                  style: AppTypography.labelLarge
                                      .copyWith(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                _formatTime(room.lastActivity),
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                  color: room.unreadCount > 0
                                      ? AppColors.primaryCyan
                                      : AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              // Checkmarks for sent/read status
                              if (room.lastMessage?.direction ==
                                  MessageDirection.sent) ...
                                [
                                  Icon(
                                    room.lastMessage?.status ==
                                            MessageStatus.read
                                        ? Icons.done_all_rounded
                                        : Icons.done_rounded,
                                    size: 14,
                                    color: room.lastMessage?.status ==
                                            MessageStatus.read
                                        ? AppColors.primaryCyan
                                        : AppColors.textHint,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              Expanded(
                                child: Text(
                                  room.lastMessagePreview,
                                  style: AppTypography.bodySmall
                                      .copyWith(
                                    color: room.unreadCount > 0
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: room.unreadCount > 0
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (room.unreadCount > 0)
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryCyan,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      room.unreadCount > 9
                                          ? '9+'
                                          : '${room.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

  Widget _buildFab(BuildContext context) {
    return AppAnimatedBuilder(
      listenable: _fabController,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabController.value,
          child: child,
        );
      },
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen()));
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryCyan.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('New Chat',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectDialog(BuildContext context, {required bool isJoin}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConnectDialog(isJoin: isJoin),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
