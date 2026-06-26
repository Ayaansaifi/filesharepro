import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/story_model.dart';
import '../providers/story_provider.dart';
import 'create_story_sheet.dart';
import 'story_viewer.dart';

/// WhatsApp-style horizontal stories row — shown at the top of the chat list.
///
/// First item is always "My Status" (create story).
/// Following items are other users' story rings with gradient indicators
/// (vibrant for unviewed, grey for all-viewed).
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(storyGroupsProvider);

    // Filter to only groups with active (non-expired) stories
    final activeGroups = groups.where((g) => g.hasActive).toList();

    // Avatar (60) + gap (6) + label (~16) + vertical padding (8+8) needs ~98px.
    // Use a SizedBox tall enough so the avatar + caption never overflow.
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // "My Status" — always first
          _buildMyStatusCard(context, ref),
          // Other users' story rings
          ...activeGroups.map((group) => _buildStoryRing(context, ref, group)),
        ],
      ),
    );
  }

  /// "My Status" card — tap to create a new story.
  Widget _buildMyStatusCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showCreateStorySheet(context, ref);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with "+" indicator
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                ),
                // "+" button at bottom-right
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Label
            SizedBox(
              width: 64,
              child: Text(
                'My Status',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A single user's story ring — gradient border + first-letter avatar.
  Widget _buildStoryRing(BuildContext context, WidgetRef ref, StoryGroup group) {
    final hasUnviewed = ref
        .read(storyGroupsProvider.notifier)
        .hasUnviewed(group);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        openStoryViewer(context, ref, initialGroup: group);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ring avatar
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewed
                    ? const LinearGradient(
                        colors: [
                          AppColors.primaryCyan,
                          AppColors.accentPink,
                          AppColors.accentOrange,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppColors.textHint, AppColors.textHint],
                      ),
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    group.displayName.isNotEmpty
                        ? group.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Name label
            SizedBox(
              width: 64,
              child: Text(
                group.displayName,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
