import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/story_model.dart';
import '../providers/story_provider.dart';

/// WhatsApp-style bottom sheet for creating a story.
/// Shows options: Text, Photo, Video.
Future<void> showCreateStorySheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _CreateStorySheet(),
  );
}

class _CreateStorySheet extends ConsumerStatefulWidget {
  const _CreateStorySheet();

  @override
  ConsumerState<_CreateStorySheet> createState() => _CreateStorySheetState();
}

class _CreateStorySheetState extends ConsumerState<_CreateStorySheet> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Create Story', style: AppTypography.heading3),
            const SizedBox(height: 8),
            Text(
              'Stories disappear after 24 hours',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _createOption(
                  ctx: context,
                  icon: Icons.text_fields_rounded,
                  label: 'Text',
                  color: AppColors.primaryCyan,
                  onTap: () => _createTextStory(context),
                ),
                _createOption(
                  ctx: context,
                  icon: Icons.image_rounded,
                  label: 'Photo',
                  color: AppColors.accentPink,
                  onTap: () => _pickAndCreateImageStory(context),
                ),
                _createOption(
                  ctx: context,
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: AppColors.accentOrange,
                  onTap: () => _pickAndCreateVideoStory(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _createOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isCreating ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTextStory(BuildContext context) async {
    Navigator.pop(context); // Close bottom sheet

    final text = await _showTextInput(context);
    if (text == null || text.trim().isEmpty) return;
    if (!context.mounted) return;

    setState(() => _isCreating = true);

    // Pick background color
    final bgColor = await _showColorPicker(context);
    if (!context.mounted) return;

    final story = StoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: StoryType.text,
      createdAt: DateTime.now(),
      textContent: text.trim(),
      bgColor: bgColor ?? AppColors.primaryCyan,
    );

    await ref.read(storyGroupsProvider.notifier).addMyStory(story);

    if (!context.mounted) return;
    setState(() => _isCreating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Story posted! 🎉'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndCreateImageStory(BuildContext context) async {
    Navigator.pop(context);

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked == null) return;
    if (!context.mounted) return;

    setState(() => _isCreating = true);

    try {
      final service = ref.read(storyServiceProvider);
      final savedPath = await service.copyMediaToStoryDir(picked.path);

      // On web, savedPath is base64 bytes — store it in mediaData so the
      // viewer can render via Image.memory instead of dart:io File.
      final isWeb = kIsWeb;
      final story = StoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: StoryType.image,
        createdAt: DateTime.now(),
        filePath: isWeb ? null : savedPath,
        mediaData: isWeb ? savedPath : null,
      );

      await ref.read(storyGroupsProvider.notifier).addMyStory(story);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save story: $e')),
      );
    }

    if (!context.mounted) return;
    setState(() => _isCreating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Story posted! 🎉'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndCreateVideoStory(BuildContext context) async {
    // Video stories rely on dart:io files + local video playback which
    // isn't available on Flutter Web. Show a friendly message instead.
    if (kIsWeb) {
      Navigator.pop(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video stories are available on the Android app.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context);

    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30), // Story videos max 30s
    );
    if (picked == null) return;
    if (!context.mounted) return;

    setState(() => _isCreating = true);

    try {
      final service = ref.read(storyServiceProvider);
      final savedPath = await service.copyMediaToStoryDir(picked.path);

      final story = StoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: StoryType.video,
        createdAt: DateTime.now(),
        filePath: savedPath,
      );

      await ref.read(storyGroupsProvider.notifier).addMyStory(story);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save story: $e')),
      );
    }

    if (!context.mounted) return;
    setState(() => _isCreating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Story posted! 🎉'),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _showTextInput(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Type your story', style: AppTypography.heading4),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: 'What\'s on your mind?',
            hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.bodySmall),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<Color?> _showColorPicker(BuildContext context) {
    final colors = [
      AppColors.primaryCyan,
      AppColors.primaryPurple,
      AppColors.accentPink,
      AppColors.accentOrange,
      AppColors.accentYellow,
      Colors.blue,
      Colors.teal,
      Colors.red,
    ];
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Background color', style: AppTypography.heading4),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
