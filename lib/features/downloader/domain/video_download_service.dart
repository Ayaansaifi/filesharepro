import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

/// Video Download Service — downloads videos from social media URLs.
/// Uses cobalt.tools API (v10+ format) as primary,
/// with HTML scraping as fallback.
/// NO DATABASE — uses local file system only.
class VideoDownloadService {
  // Callbacks
  ValueChanged<double>? onProgress;
  ValueChanged<String>? onStatusChange;
  ValueChanged<String>? onError;
  ValueChanged<String>? onComplete;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;
  
  // Track active task for cancellation
  DownloadTask? _activeTask;

  /// Validate if string is a proper URL
  static bool isValidUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Detect platform from URL
  static String detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
      return 'Instagram';
    } else if (lower.contains('tiktok.com') || lower.contains('vm.tiktok')) {
      return 'TikTok';
    } else if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'YouTube';
    } else if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return 'Facebook';
    } else if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'Twitter/X';
    } else if (lower.contains('pinterest.com') || lower.contains('pin.it')) {
      return 'Pinterest';
    }
    return 'Video';
  }

  /// Start downloading a video from a social media URL
  Future<void> startDownload(String url) async {
    if (_isDownloading) {
      onError?.call('A download is already in progress');
      return;
    }

    final trimmedUrl = url.trim();
    if (!isValidUrl(trimmedUrl)) {
      onError?.call('Invalid URL. Please enter a valid video link.');
      return;
    }

    final lowerUrl = trimmedUrl.toLowerCase();
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      onError?.call('Downloading from YouTube is not supported due to Google Play Policies.');
      return;
    }

    _isDownloading = true;
    final platform = detectPlatform(trimmedUrl);
    onStatusChange?.call('Processing $platform link...');
    onProgress?.call(0.05);

    try {
      // Step 1: Try to resolve the direct video URL
      String? directUrl = await _resolveVideoUrl(trimmedUrl);

      if (directUrl == null || directUrl.isEmpty) {
        // Fallback: try direct download if URL looks like a direct media link
        if (_isDirectMediaUrl(trimmedUrl)) {
          directUrl = trimmedUrl;
        } else {
          onError?.call('Could not extract video URL. The platform may have changed their format. Please try a different link.');
          _isDownloading = false;
          return;
        }
      }

      onStatusChange?.call('Downloading $platform video...');
      onProgress?.call(0.15);

      // Step 2: Download the video file
      await _downloadFile(directUrl, platform);
    } catch (e) {
      debugPrint('Download error: $e');
      onError?.call('Download failed: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}');
      _isDownloading = false;
    }
  }

  /// Resolve video URL using cobalt.tools v10+ API format
  Future<String?> _resolveVideoUrl(String socialUrl) async {
    // Cobalt API v10+ instances — updated format
    final instances = [
      'https://api.cobalt.tools',
      'https://cobalt-api.kwiatekmiki.com',
    ];

    for (final instance in instances) {
      try {
        final uri = Uri.parse('$instance/');
        final response = await http.post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'url': socialUrl,
            'videoQuality': '720',
            'filenameStyle': 'basic',
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final status = data['status'];

          // Cobalt v10+ response format
          if (status == 'redirect' || status == 'tunnel') {
            return data['url'] as String?;
          } else if (status == 'stream') {
            return data['url'] as String?;
          } else if (status == 'picker') {
            // Multiple options available, pick first video
            final picker = data['picker'] as List?;
            if (picker != null && picker.isNotEmpty) {
              for (final item in picker) {
                if (item['type'] == 'video') {
                  return item['url'] as String?;
                }
              }
              // If no video type found, use first item
              return picker.first['url'] as String?;
            }
          } else if (status == 'error') {
            debugPrint('Cobalt API error on $instance: ${data['error']?['code']}');
          }
        }
      } catch (e) {
        debugPrint('Cobalt API failed on $instance: $e');
      }
    }

    // Fallback: Try HTML scraping approach
    return await _scrapeVideoUrl(socialUrl);
  }

  /// Try to extract video URL from page HTML (fallback)
  Future<String?> _scrapeVideoUrl(String socialUrl) async {
    try {
      final response = await http.get(
        Uri.parse(socialUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;
        
        // Try to find video URL in page source
        final videoUrlMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(body);
        if (videoUrlMatch != null) {
          return videoUrlMatch.group(1)?.replaceAll(r'\u0025', '%').replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
        }

        // Try og:video meta tag
        final ogVideo = RegExp(r'<meta[^>]*property="og:video"[^>]*content="([^"]+)"').firstMatch(body);
        if (ogVideo != null) {
          return ogVideo.group(1);
        }

        // Try og:video:secure_url
        final ogSecure = RegExp(r'<meta[^>]*property="og:video:secure_url"[^>]*content="([^"]+)"').firstMatch(body);
        if (ogSecure != null) {
          return ogSecure.group(1);
        }
        
        // Try video src tag
        final videoSrc = RegExp(r'<video[^>]*src="([^"]+)"').firstMatch(body);
        if (videoSrc != null) {
          return videoSrc.group(1);
        }
        
        // Try content_url in JSON-LD
        final contentUrl = RegExp(r'"contentUrl"\s*:\s*"([^"]+)"').firstMatch(body);
        if (contentUrl != null) {
          return contentUrl.group(1);
        }
      }
    } catch (e) {
      debugPrint('HTML scrape fallback failed: $e');
    }

    return null;
  }

  /// Check if URL directly points to a media file
  bool _isDirectMediaUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.contains('.mp4?') ||
        lower.contains('.webm?');
  }

  /// Download a file from direct URL and save to gallery
  Future<void> _downloadFile(String directUrl, String platform) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${platform}_$timestamp.mp4';

    final task = DownloadTask(
      url: directUrl,
      filename: fileName,
      directory: 'FileSharePro/Downloads',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      requiresWiFi: false,
      retries: 2,
    );
    
    _activeTask = task;

    try {
      final result = await FileDownloader().download(
        task,
        onProgress: (progress) {
          final displayProgress = 0.15 + (progress * 0.80);
          onProgress?.call(displayProgress.clamp(0.0, 0.95));
          
          final percent = (progress * 100).toStringAsFixed(0);
          onStatusChange?.call('Downloading: $percent%');
        },
        onStatus: (status) {
          debugPrint('Download status: $status');
        },
      );

      if (result.status == TaskStatus.complete) {
        onProgress?.call(0.95);
        onStatusChange?.call('Saving to gallery...');

        // Save to gallery
        final filePath = await task.filePath();
        try {
          await Gal.putVideo(filePath);
          onProgress?.call(1.0);
          onStatusChange?.call('Saved to gallery!');
          onComplete?.call(filePath);
        } catch (e) {
          // Gallery save failed but file is downloaded
          onProgress?.call(1.0);
          onStatusChange?.call('Downloaded (gallery save failed)');
          onComplete?.call(filePath);
        }
      } else if (result.status == TaskStatus.canceled) {
        onError?.call('Download was cancelled');
      } else if (result.status == TaskStatus.notFound) {
        onError?.call('Video not found at the resolved URL');
      } else {
        onError?.call('Download failed: ${result.status}');
      }
    } catch (e) {
      onError?.call('Download error: $e');
    } finally {
      _isDownloading = false;
      _activeTask = null;
    }
  }

  /// Cancel ongoing download
  Future<void> cancelDownload() async {
    if (_activeTask != null) {
      await FileDownloader().cancelTaskWithId(_activeTask!.taskId);
    }
    _isDownloading = false;
    _activeTask = null;
    onStatusChange?.call('Download cancelled');
  }
}
