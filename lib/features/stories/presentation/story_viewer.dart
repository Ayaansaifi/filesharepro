import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_animated_builder.dart';
import '../models/story_model.dart';
import '../providers/story_provider.dart';

/// Opens a fullscreen story viewer for all groups (or a specific group).
///
/// WhatsApp-style: progress bars at top, tap left/right to navigate,
/// hold to pause, auto-advance after each story completes.
Future<void> openStoryViewer(
  BuildContext context,
  WidgetRef ref, {
  StoryGroup? initialGroup,
  int? initialIndex,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (_, _, _) => _StoryViewerScreen(
        initialGroup: initialGroup,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    ),
  );
}

class _StoryViewerScreen extends ConsumerStatefulWidget {
  final StoryGroup? initialGroup;
  final int? initialIndex;

  const _StoryViewerScreen({
    this.initialGroup,
    this.initialIndex,
  });

  @override
  ConsumerState<_StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<_StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  // Which group & story item are we showing
  int _groupIndex = 0;
  int _storyIndex = 0;

  // Timer for auto-advance (text/image = 5s, video = video duration)
  Timer? _advanceTimer;
  double _progress = 0.0;
  Duration _storyDuration = const Duration(seconds: 5);

  // Video controller (null for text/image)
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  // Hold-to-pause
  bool _isPaused = false;

  // Animation for fade-in
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();

    // Lock to portrait & immersive
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _disposeVideoController();
    _animController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  /// All active groups from the provider
  List<StoryGroup> get _groups => ref.read(storyGroupsProvider);

  /// Current group
  StoryGroup get _currentGroup {
    final groups = _groups;
    if (groups.isEmpty) {
      return widget.initialGroup ??
          StoryGroup(userId: '', displayName: '', items: []);
    }
    _groupIndex = _groupIndex.clamp(0, groups.length - 1);
    return groups[_groupIndex];
  }

  /// Current story item
  StoryItem? get _currentStory {
    final items = _currentGroup.activeItems;
    if (items.isEmpty) return null;
    _storyIndex = _storyIndex.clamp(0, items.length - 1);
    return items[_storyIndex];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initCurrentStory();
  }

  /// Set up the current story — load video if needed, start timer.
  void _initCurrentStory() {
    _advanceTimer?.cancel();
    _progress = 0.0;
    _videoInitialized = false;

    final story = _currentStory;
    if (story == null) return;

    // Video stories require local files and are only supported on mobile.
    if (story.type == StoryType.video &&
        story.filePath != null &&
        !kIsWeb) {
      _initVideo(story);
    } else {
      // Text or image — 5 second display
      _storyDuration = const Duration(seconds: 5);
      _disposeVideoController();
      _startTimer();
    }
  }

  void _initVideo(StoryItem story) {
    _disposeVideoController();

    final file = File(story.filePath!);
    if (!file.existsSync()) {
      // Video file missing — show briefly then skip
      _storyDuration = const Duration(seconds: 1);
      _startTimer();
      return;
    }

    _videoController = VideoPlayerController.file(file);
    _videoController!.initialize().then((_) {
      if (!mounted) return;
      setState(() => _videoInitialized = true);

      final dur = _videoController!.value.duration;
      _storyDuration = dur > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : dur;

      _videoController!.setLooping(false);
      _videoController!.play();
      _startTimer();
    }).catchError((e) {
      debugPrint('StoryViewer: Video init error: $e');
      if (mounted) {
        _storyDuration = const Duration(seconds: 2);
        _startTimer();
      }
    });
  }

  void _disposeVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;
  }

  void _startTimer() {
    _advanceTimer?.cancel();
    final totalMs = _storyDuration.inMilliseconds;
    if (totalMs <= 0) return;

    const intervalMs = 50; // smooth 20fps progress update

    _advanceTimer = Timer.periodic(
      const Duration(milliseconds: intervalMs),
      (_) {
        if (!mounted) {
          _advanceTimer?.cancel();
          return;
        }
        if (_isPaused) return;

        setState(() {
          _progress += intervalMs / totalMs;

          if (_progress >= 1.0) {
            _progress = 1.0;
            _advanceTimer?.cancel();
            _goToNextStory();
          }
        });
      },
    );
  }

  void _goToNextStory() {
    final items = _currentGroup.activeItems;

    if (_storyIndex < items.length - 1) {
      // Next story in same group
      setState(() {
        _storyIndex++;
        _initCurrentStory();
      });
    } else {
      // End of group — move to next group or close
      if (_groupIndex < _groups.length - 1) {
        final group = _currentGroup;
        ref
            .read(storyGroupsProvider.notifier)
            .markViewed(group.userId, group.activeItems.length - 1);

        setState(() {
          _groupIndex++;
          _storyIndex = 0;
          _initCurrentStory();
        });
      } else {
        // All done
        final group = _currentGroup;
        ref
            .read(storyGroupsProvider.notifier)
            .markViewed(group.userId, group.activeItems.length - 1);
        _disposeVideoController();
        Navigator.of(context).pop();
      }
    }
  }

  void _goToPreviousStory() {
    if (_storyIndex > 0) {
      setState(() {
        _storyIndex--;
        _initCurrentStory();
      });
    } else if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _storyIndex = 0;
        _initCurrentStory();
      });
    }
  }

  // ─── Gesture callbacks ───────────────────────────────────

  void _onTapDown(TapDownDetails details) {
    _isPaused = true;
    if (_videoController != null && _videoInitialized) {
      _videoController!.pause();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _isPaused = false;
    if (_videoController != null && _videoInitialized) {
      _videoController!.play();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < screenWidth * 0.35) {
      _goToPreviousStory();
    } else if (tapX > screenWidth * 0.65) {
      _goToNextStory();
    }
    // Middle 30% — just resume playback (handled above)
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _isPaused = true);
    if (_videoController != null && _videoInitialized) {
      _videoController!.pause();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() => _isPaused = false);
    if (_videoController != null && _videoInitialized) {
      _videoController!.play();
    }
  }

  // ─── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        onVerticalDragEnd: (details) {
          // Swipe down to dismiss
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            _disposeVideoController();
            Navigator.of(context).pop();
          }
        },
        child: AppAnimatedBuilder(
          listenable: _animController,
          builder: (context, child) {
            return Opacity(
              opacity: _animController.value,
              child: _buildStoryContent(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoryContent() {
    final story = _currentStory;
    if (story == null) {
      return const Center(
        child: Text('No stories', style: TextStyle(color: Colors.white)),
      );
    }

    final items = _currentGroup.activeItems;

    return Stack(
      children: [
        // Full-screen background / content
        Positioned.fill(child: _buildStoryBackground(story)),

        // Progress bars at top
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          child: _buildProgressBars(items.length),
        ),

        // Header: avatar + name + time + close
        Positioned(
          top: MediaQuery.of(context).padding.top + 32,
          left: 12,
          right: 12,
          child: _buildHeader(story),
        ),

        // Caption overlay at bottom (image/video with optional text)
        if (story.type == StoryType.image || story.type == StoryType.video)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildCaption(story),
          ),
      ],
    );
  }

  /// Story content — colored text, image, or video
  Widget _buildStoryBackground(StoryItem story) {
    switch (story.type) {
      case StoryType.text:
        return Container(
          color: story.bgColor ?? AppColors.primaryCyan,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                story.textContent ?? '',
                style: AppTypography.heading2.copyWith(
                  fontSize: 28,
                  color: Colors.white,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black45),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

      case StoryType.image:
        // Web stores the image as base64 bytes (no dart:io file system).
        if (story.mediaData != null && story.mediaData!.isNotEmpty) {
          try {
            return Image.memory(
              base64Decode(story.mediaData!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => _buildErrorBackground(),
            );
          } catch (_) {
            return _buildErrorBackground();
          }
        }
        // Mobile — render from the local file on disk.
        if (!kIsWeb &&
            story.filePath != null &&
            File(story.filePath!).existsSync()) {
          return Image.file(
            File(story.filePath!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _buildErrorBackground(),
          );
        }
        return _buildErrorBackground();

      case StoryType.video:
        if (_videoController != null && _videoInitialized) {
          return Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          );
        }
        return _buildVideoLoading();
    }
  }

  Widget _buildVideoLoading() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryCyan,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorBackground() {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: AppColors.textHint,
          size: 48,
        ),
      ),
    );
  }

  /// Progress bars row — one bar per story item in the current group.
  /// Filled = viewed, partially filled = current, empty = upcoming.
  Widget _buildProgressBars(int totalItems) {
    return Row(
      children: List.generate(totalItems, (i) {
        final isCurrent = (i == _storyIndex);
        final isPast = (i < _storyIndex);

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: i == 0 ? 0 : 3,
              right: i == totalItems - 1 ? 0 : 3,
            ),
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: isCurrent
                  ? _progress
                  : (isPast ? 1.0 : 0.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Header row — avatar, name, timestamp, and close button.
  Widget _buildHeader(StoryItem story) {
    final group = _currentGroup;
    final elapsed = DateTime.now().difference(story.createdAt);
    final timeStr = _formatStoryTime(elapsed);

    return Row(
      children: [
        // Avatar with ring
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              group.displayName.isNotEmpty
                  ? group.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Name + time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                timeStr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // Close button
        GestureDetector(
          onTap: () {
            _disposeVideoController();
            Navigator.of(context).pop();
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  /// Caption overlay at bottom for image/video stories.
  Widget _buildCaption(StoryItem story) {
    if (story.textContent == null || story.textContent!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        story.textContent!,
        style: AppTypography.bodyMedium.copyWith(
          color: Colors.white,
          fontSize: 15,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatStoryTime(Duration elapsed) {
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
  }
}
