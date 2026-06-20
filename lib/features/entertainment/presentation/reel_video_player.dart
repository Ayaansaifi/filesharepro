import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelVideoPlayer extends StatefulWidget {
  const ReelVideoPlayer({super.key, required this.url, this.autoPlay = true});

  final String url;
  final bool autoPlay;

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _muted = false;
  bool _showControls = false;
  late AnimationController _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _init();
  }

  bool _hasError = false;

  Future<void> _init() async {
    // Add CORS proxy for web if it's a reddit video
    String finalUrl = widget.url;
    if (kIsWeb && finalUrl.contains('v.redd.it')) {
      finalUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(finalUrl)}';
    }

    final c = VideoPlayerController.networkUrl(
      Uri.parse(finalUrl),
      httpHeaders: {'User-Agent': 'FileSharePro/1.1'},
    );
    _controller = c;
    try {
      await c.initialize();
      c.setLooping(true);
      if (widget.autoPlay) await c.play();
      if (mounted) {
        setState(() {
          _ready = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Video player error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _fadeAnim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _showControls = true;
    });
    _fadeAnim.forward(from: 0);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _fadeAnim.reverse();
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              const Text('Failed to load reel', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _ready = false;
                  });
                  _init();
                },
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00A884), size: 18),
                label: const Text('Retry', style: TextStyle(color: Color(0xFF00A884))),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF00A884), strokeWidth: 2),
              SizedBox(height: 12),
              Text('Loading reel...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final duration = _controller!.value.duration;
    final position = _controller!.value.position;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

            // Gradient overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // Play/Pause overlay icon (fades in/out)
            if (_showControls)
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),

            // Progress bar at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF00A884),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),

            // Duration label
            Positioned(
              bottom: 10,
              left: 16,
              child: Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Mute button (top right)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _muted = !_muted;
                    _controller!.setVolume(_muted ? 0 : 1);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

            // "REEL" badge top left
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE040FB), Color(0xFFFF6B6B)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_filled, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('REEL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
