import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../models/story_model.dart';

/// Full-screen story viewer — WhatsApp/Instagram style.
/// PageView for horizontal swipe, animated progress bars at top,
/// tap left/right to navigate, long-press to pause.
/// Video items use VideoPlayerController loaded from FILE path (no RAM holding).
class StoryViewerScreen extends StatefulWidget {
  final StoryGroup group;
  final int initialIndex;
  final void Function(String itemId)? onSeen;

  const StoryViewerScreen({
    super.key,
    required this.group,
    this.initialIndex = 0,
    this.onSeen,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  VideoPlayerController? _videoController;

  List<StoryItem> get _items => widget.group.activeItems;
  int _currentIndex = 0;
  bool _isPaused = false;

  static const Duration _imageDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(vsync: this);
    _loadItem(_currentIndex);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─── Navigation ───────────────────────────────────────────

  void _goNext() {
    if (_currentIndex < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _loadItem(index);
  }

  // ─── Item Loading ─────────────────────────────────────────

  Future<void> _loadItem(int index) async {
    _progressController.stop();
    _progressController.reset();
    await _videoController?.dispose();
    _videoController = null;

    final item = _items[index];
    widget.onSeen?.call(item.id);

    if (item.mediaType == StoryMediaType.video) {
      await _loadVideo(item.cachedFilePath);
    } else {
      _startImageTimer();
    }
  }

  Future<void> _loadVideo(String path) async {
    final controller = VideoPlayerController.file(File(path));
    await controller.initialize();
    if (!mounted) return;
    setState(() => _videoController = controller);
    controller.play();

    _progressController.duration = controller.value.duration;
    _progressController.forward();
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goNext();
    });
  }

  void _startImageTimer() {
    _progressController.duration = _imageDuration;
    _progressController.forward();
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goNext();
    });
  }

  // ─── Pause / Resume ───────────────────────────────────────

  void _pause() {
    if (_isPaused) return;
    _isPaused = true;
    _progressController.stop();
    _videoController?.pause();
  }

  void _resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _progressController.forward();
    _videoController?.play();
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Story PageView ──────────────────────────────
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _items.length,
              itemBuilder: (_, index) => _buildStoryPage(_items[index]),
            ),

            // ── Tap areas ───────────────────────────────────
            _buildTapAreas(),

            // ── Top progress bars + header ──────────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBars(),
                  _buildHeader(),
                ],
              ),
            ),

            // ── Caption ─────────────────────────────────────
            if (_items[_currentIndex].caption?.isNotEmpty == true)
              _buildCaption(),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPage(StoryItem item) {
    if (item.mediaType == StoryMediaType.video && _videoController != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      );
    }
    // Image — loaded from file path, NOT held in RAM
    return Image.file(
      File(item.cachedFilePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );
  }

  Widget _buildTapAreas() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(onTap: _goPrev, behavior: HitTestBehavior.opaque),
        ),
        Expanded(
          child: GestureDetector(onTap: _goNext, behavior: HitTestBehavior.opaque),
        ),
      ],
    );
  }

  Widget _buildProgressBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: List.generate(_items.length, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: i < _currentIndex
                  ? _ProgressSegment(value: 1.0)
                  : i == _currentIndex
                      ? AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) =>
                              _ProgressSegment(value: _progressController.value),
                        )
                      : _ProgressSegment(value: 0.0),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryCyan.withValues(alpha: 0.2),
            child: Text(
              widget.group.displayName.isNotEmpty
                  ? widget.group.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primaryCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _timeAgo(_items[_currentIndex].createdAt),
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          _items[_currentIndex].caption ?? '',
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─── Progress Segment ─────────────────────────────────────────────

class _ProgressSegment extends StatelessWidget {
  final double value;
  const _ProgressSegment({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.white30,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 3,
      ),
    );
  }
}
