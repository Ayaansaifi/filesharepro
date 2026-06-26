import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/app_animated_builder.dart';


import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'chat_room_screen.dart';
import 'contacts_screen.dart';
import 'discovery_screen.dart';
import '../../stories/presentation/stories_row.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(myProfileProvider);
      if (profile != null) {
        // Connect to the signaling broker using our phone-number identity so
        // that contacts can reach us globally. Falls back to uniqueId for
        // legacy/local-only profiles.
        ref.read(signalingServiceProvider).connect(profile.peerId);
      }
    });
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen()));
                } else if (val == 'join') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen()));
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
                    Text('Scan Network'),
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
        child: SingleChildScrollView(
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
                  label: 'Scan Network',
                  color: AppColors.primaryCyan,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiscoveryScreen())),
                ),
                const SizedBox(width: 12),
                _buildActionChip(
                  icon: Icons.contacts_rounded,
                  label: 'Contacts',
                  color: AppColors.primaryPurple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())),
                ),
              ],
            ),
          ],
        ),
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
        // Swipe right → Pin / Unpin
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryCyan.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            room.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: AppColors.primaryCyan,
          ),
        ),
        // Swipe left → Mute / Unmute
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            room.isMuted ? Icons.notifications_rounded : Icons.notifications_off_rounded,
            color: AppColors.warning,
          ),
        ),
        confirmDismiss: (direction) async {
          final notifier = ref.read(chatRoomsProvider.notifier);
          if (direction == DismissDirection.startToEnd) {
            // Pin toggle
            await notifier.togglePin(room.roomCode, !room.isPinned);
            _showSnackBar(room.isPinned ? 'Unpinned' : 'Pinned');
            return false; // Don't actually dismiss
          } else {
            // Long swipe left → show options (mute, delete)
            final action = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(
                        room.isMuted ? Icons.notifications_rounded : Icons.notifications_off_rounded,
                        color: AppColors.warning,
                      ),
                      title: Text(room.isMuted ? 'Unmute notifications' : 'Mute notifications'),
                      onTap: () => Navigator.pop(ctx, 'mute'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_rounded, color: AppColors.error),
                      title: const Text('Delete chat'),
                      onTap: () => Navigator.pop(ctx, 'delete'),
                    ),
                    ListTile(
                      leading: Icon(Icons.push_pin_rounded, color: AppColors.primaryCyan),
                      title: Text(room.isPinned ? 'Unpin chat' : 'Pin chat'),
                      onTap: () => Navigator.pop(ctx, 'pin'),
                    ),
                  ],
                ),
              ),
            );

            if (action == 'mute') {
              await notifier.toggleMute(room.roomCode, !room.isMuted);
              _showSnackBar(room.isMuted ? 'Unmuted' : 'Muted');
            } else if (action == 'pin') {
              await notifier.togglePin(room.roomCode, !room.isPinned);
              _showSnackBar(room.isPinned ? 'Unpinned' : 'Pinned');
            } else if (action == 'delete') {
              if (!mounted) return false;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Delete "${room.peerName}"?', style: const TextStyle(color: Colors.white)),
                  content: const Text('All messages will be permanently deleted.',
                      style: TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await notifier.deleteRoom(room.roomCode);
                _showSnackBar('Chat deleted');
              }
            }
            return false; // Don't dismiss — we handle it via provider
          }
        },
        child: Material(
            color: Colors.transparent,
            child: InkWell(
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
                  color: room.isPinned
                      ? AppColors.surface.withValues(alpha: 0.7)
                      : AppColors.surface,
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
                              if (room.isMuted)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.notifications_off_rounded,
                                      size: 14, color: AppColors.textHint),
                                ),
                              Expanded(
                                child: Text(
                                  room.peerName,
                                  style: AppTypography.labelLarge
                                      .copyWith(fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (room.isPinned)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.push_pin_rounded,
                                      size: 14, color: AppColors.textHint),
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
                                  MessageDirection.sent &&
                                  !room.lastMessage!.isDeleted) ...[
                                Icon(
                                  room.lastMessage?.status ==
                                          MessageStatus.read
                                      ? Icons.done_all_rounded
                                      : (room.lastMessage?.status ==
                                              MessageStatus.delivered
                                          ? Icons.done_all_rounded
                                          : Icons.done_rounded),
                                  size: 14,
                                  color: room.lastMessage?.status ==
                                          MessageStatus.read
                                      ? const Color(0xFF34B7F1)
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
