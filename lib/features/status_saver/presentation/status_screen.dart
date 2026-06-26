import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final StatusSaverService _statusService = StatusSaverService();
  List<File> _imageStatuses = [];
  List<File> _videoStatuses = [];
  List<File> _savedStatuses = [];
  bool _hasPermission = false;
  bool _isLoading = true;
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  /// Re-check when app resumes (user might have granted SAF permission)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndLoad();
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    final hasPerm = await _statusService.hasPermission();
    setState(() {
      _hasPermission = hasPerm;
      _isLoading = false;
      _errorMessage = null;
    });
    if (hasPerm) _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final statuses = await _statusService.getStatuses();
      final saved = await _statusService.getSavedStatuses();
      setState(() {
        _imageStatuses =
            statuses.where((f) => FileUtils.isImage(f.path)).toList();
        _videoStatuses =
            statuses.where((f) => FileUtils.isVideo(f.path)).toList();
        _savedStatuses = saved;
        _isLoading = false;
        if (statuses.isEmpty && _hasPermission) {
          _errorMessage = 'No statuses found. Make sure you have viewed some WhatsApp statuses recently.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading statuses: $e';
      });
    }
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
                      : Column(
                          children: [
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTypography.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            Expanded(child: _buildStatusContent()),
                          ],
                        ),
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
                  '${_imageStatuses.length + _videoStatuses.length} statuses found',
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
                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('WhatsApp Status Access', style: AppTypography.heading3),
                    content: Text(
                      'FileShare Pro needs access to the WhatsApp ".Statuses" folder to display and save statuses.\n\n'
                      'This app only accesses this specific folder locally on your device. Your media is never uploaded to any server or shared with third parties.',
                      style: AppTypography.bodyMedium,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textHint)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Proceed', style: TextStyle(color: AppColors.primaryCyan, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (proceed == true) {
                  final granted = await _statusService.requestPermission();
                  if (granted) {
                    setState(() => _hasPermission = true);
                    _loadStatuses();
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Permission denied. Please select the WhatsApp .Statuses folder.'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              },
            ),
          const SizedBox(height: 20),
          GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 14,
            child: Column(
              children: [
                Text('📌 How to grant access:', style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                Text(
                  '1. Tap "Grant Permission" above\n'
                  '2. Navigate to: Android > media > com.whatsapp > WhatsApp > Media > .Statuses\n'
                  '3. Tap "Use this folder"\n'
                  '4. Tap "Allow"',
                  style: AppTypography.caption.copyWith(height: 1.6),
                ),
              ],
            ),
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
        // Tabs with 3 sections
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
            labelStyle: AppTypography.labelLarge.copyWith(fontSize: 12),
            tabs: [
              Tab(text: '📷 ${_imageStatuses.length}'),
              Tab(text: '🎬 ${_videoStatuses.length}'),
              Tab(text: '💾 ${_savedStatuses.length}'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Grid
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                onRefresh: _loadStatuses,
                color: AppColors.primaryCyan,
                child: _buildGrid(_imageStatuses, isVideo: false),
              ),
              RefreshIndicator(
                onRefresh: _loadStatuses,
                color: AppColors.primaryCyan,
                child: _buildGrid(_videoStatuses, isVideo: true),
              ),
              RefreshIndicator(
                onRefresh: _loadStatuses,
                color: AppColors.primaryCyan,
                child: _buildSavedGrid(),
              ),
            ],
          ),
        ),

        // Save selected button
        if (_isSelectionMode && _selectedIndices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: GradientButton(
              label: 'Save ${_selectedIndices.length} Selected',
              icon: Icons.save_alt_rounded,
              onPressed: _saveSelected,
            ),
          ),

        // Disclaimer
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Text(
            'Disclaimer: This app is not affiliated with, sponsored, or endorsed by WhatsApp Inc.',
            style: AppTypography.caption.copyWith(fontSize: 10, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<File> files, {required bool isVideo}) {
    if (files.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 300,
            child: Center(
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
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  // Thumbnail - use actual video frame or image
                  isVideo
                      ? _VideoThumbnail(file: file)
                      : kIsWeb 
                          ? Image.network(file.path, fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (_, e, st) => Container(
                                color: AppColors.surfaceLight,
                                child: const Icon(Icons.broken_image,
                                    color: AppColors.textHint),
                              ),
                            )
                          : Image.file(file, fit: BoxFit.cover,
                          cacheWidth: 200,
                          errorBuilder: (_, e, st) => Container(
                            color: AppColors.surfaceLight,
                            child: const Icon(Icons.broken_image,
                                color: AppColors.textHint),
                          ),
                        ),

                  // Video play icon overlay
                  if (isVideo)
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
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
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => _saveFile(file),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.save_alt_rounded,
                              color: Colors.white, size: 14),
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

  Widget _buildSavedGrid() {
    if (_savedStatuses.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border_rounded,
                      color: AppColors.textHint, size: 48),
                  const SizedBox(height: 12),
                  Text('No saved statuses', style: AppTypography.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Save statuses from Images/Videos tabs',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _savedStatuses.length,
      itemBuilder: (context, index) {
        final file = _savedStatuses[index];
        final isVideo = FileUtils.isVideo(file.path);

        return GestureDetector(
          onTap: () => _previewFile(file, isVideo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                isVideo
                    ? _VideoThumbnail(file: file)
                    : kIsWeb
                        ? Image.network(file.path, fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, e, st) => Container(
                              color: AppColors.surfaceLight,
                              child: const Icon(Icons.broken_image, color: AppColors.textHint),
                            ),
                          )
                        : Image.file(file, fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (_, e, st) => Container(
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.broken_image, color: AppColors.textHint),
                        ),
                      ),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Saved',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _previewFile(File file, bool isVideo) {
    if (isVideo) {
      // Full-screen video player
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VideoPreviewScreen(file: file),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: kIsWeb ? Image.network(file.path, fit: BoxFit.contain) : Image.file(file, fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _saveFile(file);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.save_alt_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
      if (saved) _loadStatuses(); // Refresh saved tab
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
      _loadStatuses(); // Refresh saved tab
    }
  }
}

/// Lightweight video thumbnail widget — uses static icon instead of
/// VideoPlayerController to prevent OOM crashes in grids with many videos.
class _VideoThumbnail extends StatelessWidget {
  final File file;

  const _VideoThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    // Get file size for display
    String sizeLabel = '';
    try {
      final bytes = file.lengthSync();
      if (bytes > 1024 * 1024) {
        sizeLabel = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else if (bytes > 1024) {
        sizeLabel = '${(bytes / 1024).toStringAsFixed(0)} KB';
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight,
            AppColors.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8A50)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
            ),
            if (sizeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                sizeLabel,
                style: const TextStyle(color: AppColors.textHint, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen video preview with playback
class _VideoPreviewScreen extends StatefulWidget {
  final File file;

  const _VideoPreviewScreen({required this.file});

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = kIsWeb ? VideoPlayerController.networkUrl(Uri.parse(widget.file.path)) : VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, color: AppColors.success),
            onPressed: () async {
              final service = StatusSaverService();
              final saved = await service.saveStatus(widget.file);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(saved ? '✅ Saved!' : '❌ Failed'),
                  backgroundColor: saved ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 36),
                      ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: AppColors.primaryCyan),
      ),
      bottomNavigationBar: _initialized
          ? Container(
              padding: const EdgeInsets.all(16),
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primaryCyan,
                  bufferedColor: AppColors.surfaceLight,
                  backgroundColor: AppColors.surface,
                ),
              ),
            )
          : null,
    );
  }
}
