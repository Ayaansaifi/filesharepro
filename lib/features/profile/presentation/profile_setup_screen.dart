import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../chat/models/user_profile.dart';
import '../../chat/providers/chat_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final void Function(BuildContext context) onComplete;
  final UserProfile? existingProfile;

  const ProfileSetupScreen({super.key, required this.onComplete, this.existingProfile});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late TextEditingController _nameController;
  late TextEditingController _aboutController;
  File? _avatarFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingProfile?.displayName ?? '');
    _aboutController = TextEditingController(text: widget.existingProfile?.about ?? 'Available');
    if (widget.existingProfile?.avatarPath != null && !kIsWeb) {
      final file = File(widget.existingProfile!.avatarPath!);
      if (file.existsSync()) {
        _avatarFile = file;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    
    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
      });
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Profile Photo', style: AppTypography.heading3),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildPickerOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_avatarFile != null)
                  _buildPickerOption(
                    icon: Icons.delete_rounded,
                    label: 'Remove',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _avatarFile = null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primaryCyan,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? savedAvatarPath;
      if (_avatarFile != null && !kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final targetPath = '${dir.path}/profile_avatar.jpg';
        await _avatarFile!.copy(targetPath);
        savedAvatarPath = targetPath;
      }

      final profile = UserProfile(
        uniqueId: widget.existingProfile?.uniqueId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        displayName: name,
        about: _aboutController.text.trim(),
        avatarPath: savedAvatarPath,
        createdAt: widget.existingProfile?.createdAt ?? DateTime.now(),
      );

      final contactsService = ref.read(contactsServiceProvider);
      await contactsService.saveMyProfile(profile);

      if (!mounted) return;
      ref.invalidate(myProfileProvider); // Safely invalidate here using our own mounted ref
      setState(() => _isLoading = false);
      widget.onComplete(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text('Profile Info', style: AppTypography.heading1),
                const SizedBox(height: 8),
                Text(
                  'Please provide your name and an optional profile photo',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Avatar Picker
                GestureDetector(
                  onTap: _showImagePickerModal,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceLight,
                      image: _avatarFile != null && !kIsWeb
                          ? DecorationImage(
                              image: FileImage(_avatarFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: (_avatarFile == null || kIsWeb)
                        ? const Center(
                            child: Icon(Icons.add_a_photo_rounded,
                                color: AppColors.primaryCyan, size: 40),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 40),

                // Name Input
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  borderRadius: 16,
                  child: TextField(
                    controller: _nameController,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Type your name here',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textHint),
                      border: InputBorder.none,
                      icon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // About Input
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  borderRadius: 16,
                  child: TextField(
                    controller: _aboutController,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'About',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textHint),
                      border: InputBorder.none,
                      icon: const Icon(Icons.info_outline_rounded, color: AppColors.primaryCyan),
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // EULA / Terms of Service Agreement for UGC
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy, and agree not to share or upload objectionable content.',
                    style: AppTypography.caption.copyWith(color: AppColors.textHint, fontSize: 10, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      elevation: WidgetStateProperty.all(0),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryCyan.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Next',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
