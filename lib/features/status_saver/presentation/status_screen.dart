import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/utils/file_utils.dart';
import '../services/status_saver_service.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StatusSaverService _statusService = StatusSaverService();
  List<File> _imageStatuses = [];
  List<File> _videoStatuses = [];
  bool _hasPermission = false;
  bool _isLoading = true;
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoad() async {
    final hasPerm = await _statusService.hasPermission();
    setState(() {
      _hasPermission = hasPerm;
      _isLoading = false;
    });
    if (hasPerm) _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);
    final statuses = await _statusService.getStatuses();
    setState(() {
      _imageStatuses =
          statuses.where((f) => FileUtils.isImage(f.path)).toList();
      _videoStatuses =
          statuses.where((f) => FileUtils.isVideo(f.path)).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Header ────────────────────────────────
            _buildHeader(),
            const SizedBox(height: 16),

            // ─── Content ───────────────────────────────
            Expanded(
              child: !_hasPermission
                  ? _buildPermissionRequest()
                  : _isLoading
                      ? _buildLoading()
                      : _buildStatusContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.successGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Saver', style: AppTypography.heading3),
                Text(
                  'Save WhatsApp statuses easily',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (_hasPermission)
            GlassCard(
              padding: const EdgeInsets.all(10),
              borderRadius: 14,
              onTap: _loadStatuses,
              child: const Icon(Icons.refresh_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.successGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 24),
          Text(
            'Grant Access to WhatsApp',
            style: AppTypography.heading3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'To view and save statuses, we need access to WhatsApp\'s media folder. '
            'Your files are never uploaded anywhere.',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GradientButton(
            label: 'Grant Permission',
            icon: Icons.folder_open_rounded,
            gradient: AppColors.successGradient,
            onPressed: () async {
              final granted = await _statusService.requestPermission();
              if (granted) {
                setState(() => _hasPermission = true);
                _loadStatuses();
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            '📌 You will be asked to select the WhatsApp status folder',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryCyan),
    );
  }

  Widget _buildStatusContent() {
    return Column(
      children: [
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textHint,
            labelStyle: AppTypography.labelLarge,
            tabs: [
              Tab(text: 'Images (${_imageStatuses.length})'),
              Tab(text: 'Videos (${_videoStatuses.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Grid
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGrid(_imageStatuses, isVideo: false),
              _buildGrid(_videoStatuses, isVideo: true),
            ],
          ),
        ),

        // Save selected button
        if (_isSelectionMode && _selectedIndices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: GradientButton(
              label: 'Save ${_selectedIndices.length} Selected',
              icon: Icons.save_alt_rounded,
              onPressed: _saveSelected,
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(List<File> files, {required bool isVideo}) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam_off_rounded : Icons.image_not_supported_rounded,
              color: AppColors.textHint,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              isVideo ? 'No video statuses found' : 'No image statuses found',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isSelected = _selectedIndices.contains(index);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedIndices.remove(index);
                  if (_selectedIndices.isEmpty) _isSelectionMode = false;
                } else {
                  _selectedIndices.add(index);
                }
              });
            } else {
              // Preview
              _previewFile(file, isVideo);
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _isSelectionMode = true;
              _selectedIndices.add(index);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryCyan
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail
                  isVideo
                      ? Container(
                          color: AppColors.surfaceLight,
                          child: const Center(
                            child: Icon(Icons.play_circle_filled,
                                color: AppColors.textHint, size: 36),
                          ),
                        )
                      : Image.file(file, fit: BoxFit.cover,
                          errorBuilder: (_, e, st) => Container(
                            color: AppColors.surfaceLight,
                            child: const Icon(Icons.broken_image,
                                color: AppColors.textHint),
                          ),
                        ),

                  // Video badge
                  if (isVideo)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('Video',
                                style: AppTypography.caption
                                    .copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  // Selection check
                  if (isSelected)
                    Container(
                      color: AppColors.primaryCyan.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(Icons.check_circle_rounded,
                            color: AppColors.primaryCyan, size: 32),
                      ),
                    ),

                  // Save button (non-selection mode)
                  if (!_isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _saveFile(file),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.save_alt_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _previewFile(File file, bool isVideo) {
    // TODO: Implement full-screen preview
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: isVideo
              ? Container(
                  height: 300,
                  color: AppColors.surface,
                  child: const Center(
                    child: Icon(Icons.play_circle_outline,
                        color: AppColors.primaryCyan, size: 64),
                  ),
                )
              : Image.file(file, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Future<void> _saveFile(File file) async {
    final saved = await _statusService.saveStatus(file);
    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? '✅ Saved to gallery!' : '❌ Failed to save'),
          backgroundColor: saved ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _saveSelected() async {
    final files = _tabController.index == 0 ? _imageStatuses : _videoStatuses;
    int saved = 0;
    for (final index in _selectedIndices) {
      if (index < files.length) {
        final success = await _statusService.saveStatus(files[index]);
        if (success) saved++;
      }
    }
    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedIndices.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $saved files saved to gallery!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
