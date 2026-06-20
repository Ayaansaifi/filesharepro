import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/story_provider.dart';

/// Story creation screen — lets user pick/capture media, add caption, then post.
/// Media is picked via image_picker and immediately written to cache on "Post".
class StoryCameraScreen extends ConsumerStatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  ConsumerState<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends ConsumerState<StoryCameraScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  File? _selectedFile;
  bool _isVideo = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // ─── Pick Media ───────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 80, // compress to reduce cache size
      maxWidth: 1080,
    );
    if (xFile != null) {
      setState(() {
        _selectedFile = File(xFile.path);
        _isVideo = false;
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final xFile = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30), // WhatsApp-style 30s limit
    );
    if (xFile != null) {
      setState(() {
        _selectedFile = File(xFile.path);
        _isVideo = true;
      });
    }
  }

  // ─── Post Story ───────────────────────────────────────────

  Future<void> _postStory() async {
    if (_selectedFile == null) return;
    final caption = _captionController.text.trim();
    final success = await ref.read(storiesProvider.notifier).postStory(
          _selectedFile!,
          caption: caption.isNotEmpty ? caption : null,
        );
    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Story posted! It will disappear in 24 hours.'),
            backgroundColor: AppColors.primaryCyan,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to post story. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPosting = ref.watch(storiesProvider).isPosting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('New Story'),
        leading: const BackButton(),
        actions: [
          if (_selectedFile != null)
            TextButton(
              onPressed: isPosting ? null : _postStory,
              child: isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _selectedFile == null ? _buildPickerUI() : _buildPreviewUI(),
    );
  }

  // ─── Picker UI (no media selected) ───────────────────────

  Widget _buildPickerUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryCyan.withValues(alpha: 0.4),
                    blurRadius: 24,
                  )
                ],
              ),
              child: const Icon(Icons.add_a_photo_rounded,
                  size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create a Story',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share a photo or video that disappears after 24 hours',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.videocam_rounded,
                    label: 'Record Video',
                    onTap: () => _pickVideo(ImageSource.camera),
                    color: AppColors.accentPink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.video_library_rounded,
                    label: 'Video Gallery',
                    onTap: () => _pickVideo(ImageSource.gallery),
                    color: AppColors.accentPink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Preview UI (media selected) ─────────────────────────

  Widget _buildPreviewUI() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_isVideo)
                Image.file(_selectedFile!, fit: BoxFit.cover)
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded,
                          size: 64, color: AppColors.primaryCyan),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFile!.path.split('/').last,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              // Re-pick button
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFile = null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Caption input
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle:
                        const TextStyle(color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  maxLines: 2,
                  maxLength: 150,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Source Button ────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primaryCyan;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
