import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/story_model.dart';
import '../providers/story_provider.dart';
import 'story_viewer_screen.dart';
import 'story_camera_screen.dart';

/// Horizontal scrollable row of story ring avatars.
/// Placed at the top of ChatListScreen.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storiesProvider);
    final myGroup = state.myGroup;
    final peers = state.peerGroups;

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 1 + peers.length, // My Story + peers
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MyStoryRing(
              group: myGroup,
              onAdd: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoryCameraScreen()),
              ),
              onView: myGroup != null && myGroup.hasActiveStories
                  ? () => _openViewer(context, ref, myGroup, 0)
                  : null,
            );
          }
          final peer = peers[index - 1];
          return _PeerStoryRing(
            group: peer,
            onTap: () => _openViewer(context, ref, peer, 0),
          );
        },
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    WidgetRef ref,
    StoryGroup group,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, anim1, anim2) => StoryViewerScreen(
          group: group,
          initialIndex: initialIndex,
          onSeen: (id) => ref.read(storiesProvider.notifier).markSeen(id),
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ─── My Story Ring ────────────────────────────────────────────────

class _MyStoryRing extends StatelessWidget {
  final StoryGroup? group;
  final VoidCallback onAdd;
  final VoidCallback? onView;

  const _MyStoryRing({
    required this.group,
    required this.onAdd,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final hasStory = group != null && group!.hasActiveStories;

    return GestureDetector(
      onTap: hasStory ? onView : onAdd,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _StoryRingBorder(
                  hasSeen: hasStory ? group!.unseenCount == 0 : true,
                  child: _AvatarCircle(
                    icon: Icons.person_rounded,
                    label: 'Me',
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'My Story',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Peer Story Ring ──────────────────────────────────────────────

class _PeerStoryRing extends StatelessWidget {
  final StoryGroup group;
  final VoidCallback onTap;

  const _PeerStoryRing({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StoryRingBorder(
              hasSeen: group.unseenCount == 0,
              child: _AvatarCircle(
                icon: Icons.person_rounded,
                label: group.displayName,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              group.displayName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gradient Ring Border ─────────────────────────────────────────

class _StoryRingBorder extends StatelessWidget {
  final bool hasSeen;
  final Widget child;

  const _StoryRingBorder({required this.hasSeen, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasSeen
            ? null
            : const LinearGradient(
                colors: [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFF00F2FE)],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasSeen ? AppColors.surfaceLight : null,
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background,
        ),
        padding: const EdgeInsets.all(2),
        child: child,
      ),
    );
  }
}

// ─── Avatar Circle ────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AvatarCircle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceLight,
      ),
      child: Center(
        child: Text(
          label.isNotEmpty ? label[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primaryCyan,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
