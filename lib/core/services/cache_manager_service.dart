import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';

/// Central cache manager — handles ephemeral story files + temp transfer files.
/// Uses getTemporaryDirectory() for all ephemeral data: auto-purged on low storage,
/// guaranteed cleanup on app lifecycle events. Zero RAM holding of heavy objects.
class CacheManagerService with WidgetsBindingObserver {
  static final CacheManagerService _instance = CacheManagerService._();
  factory CacheManagerService() => _instance;
  CacheManagerService._();

  Timer? _cleanupTimer;

  /// Call once in main.dart after WidgetsFlutterBinding.ensureInitialized()
  Future<void> init() async {
    if (kIsWeb) return;
    // Register for lifecycle events
    WidgetsBinding.instance.addObserver(this);
    // Run cleanup immediately on launch
    await cleanStoryCache();
    await cleanTransferCache();
    // Schedule periodic cleanup
    _cleanupTimer = Timer.periodic(
      Duration(minutes: AppConstants.storyCleanupIntervalMin),
      (_) async {
        await cleanStoryCache();
        await cleanTransferCache();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Fire-and-forget cleanup when app goes background/closes
      cleanStoryCache();
      cleanTransferCache();
    }
  }

  // ─── Story Cache ─────────────────────────────────────────

  /// Delete story media files older than [storyExpiryHours].
  /// Called on launch + every 30 min + app lifecycle pause.
  Future<void> cleanStoryCache() async {
    if (kIsWeb) return;
    try {
      final dir = await _getStoryCacheDir();
      if (!await dir.exists()) return;

      final now = DateTime.now();
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        try {
          final stat = await file.stat();
          final age = now.difference(stat.modified);
          if (age.inHours >= AppConstants.storyExpiryHours) {
            await file.delete();
            debugPrint('[CacheManager] Deleted expired story: ${file.path}');
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CacheManager] Story cache clean error: $e');
    }
  }

  /// Delete all story media files immediately (e.g., user taps "Clear Stories").
  Future<void> clearAllStories() async {
    if (kIsWeb) return;
    try {
      final dir = await _getStoryCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[CacheManager] Clear stories error: $e');
    }
  }

  // ─── Transfer Cache ──────────────────────────────────────

  /// Delete transfer temp files older than 24hrs.
  Future<void> cleanTransferCache() async {
    if (kIsWeb) return;
    try {
      final tmpDir = await getTemporaryDirectory();
      final transferDir = Directory('${tmpDir.path}/filesharepro_transfers');
      if (!await transferDir.exists()) return;

      final now = DateTime.now();
      final files = transferDir.listSync().whereType<File>();
      for (final file in files) {
        try {
          final stat = await file.stat();
          if (now.difference(stat.modified).inHours >= 24) {
            await file.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CacheManager] Transfer cache clean error: $e');
    }
  }

  // ─── Cache Size ──────────────────────────────────────────

  /// Returns total cache directory size in bytes.
  Future<int> getCacheSizeBytes() async {
    if (kIsWeb) return 0;
    try {
      final tmpDir = await getTemporaryDirectory();
      return await _dirSize(tmpDir);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }

  /// Human-readable cache size string (e.g., "12.4 MB")
  Future<String> getCacheSizeString() async {
    final bytes = await getCacheSizeBytes();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Nuke everything (for user-initiated "Clear Cache" in Settings).
  Future<void> clearAllCache() async {
    if (kIsWeb) return;
    try {
      final tmpDir = await getTemporaryDirectory();
      final entities = tmpDir.listSync();
      for (final e in entities) {
        try {
          if (e is Directory && e.path.contains('filesharepro')) {
            await e.delete(recursive: true);
          } else if (e is File && e.path.contains('filesharepro')) {
            await e.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CacheManager] Clear all cache error: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────

  Future<Directory> _getStoryCacheDir() async {
    final tmpDir = await getTemporaryDirectory();
    final dir = Directory('${tmpDir.path}/${AppConstants.storyCacheDir}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> getStoryCacheDirectory() => _getStoryCacheDir();

  void dispose() {
    _cleanupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
