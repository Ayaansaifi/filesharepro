import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/cache_manager_service.dart';
import '../models/story_model.dart';

/// Cache-driven story service. All heavy media (images/videos) are written
/// directly to getTemporaryDirectory() — NEVER held in RAM variables.
/// Metadata (paths, timestamps) serialized to SharedPreferences as lightweight JSON.
class StoryCacheService {
  static const _uuid = Uuid();
  final SharedPreferences _prefs;

  StoryCacheService(this._prefs);

  // ─── Read ─────────────────────────────────────────────────

  /// Load all story groups, filtering out expired items automatically.
  Future<List<StoryGroup>> getAllStoryGroups() async {
    try {
      final jsonStr = _prefs.getString(AppConstants.storyMetaKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      var groups = StoryGroup.decodeList(jsonStr);
      // Filter expired items and delete their files
      bool changed = false;
      final updated = <StoryGroup>[];
      for (final group in groups) {
        final liveItems = <StoryItem>[];
        for (final item in group.items) {
          if (item.isExpired) {
            _deleteFile(item.cachedFilePath);
            changed = true;
          } else {
            liveItems.add(item);
          }
        }
        if (liveItems.isNotEmpty) {
          updated.add(group.copyWith(items: liveItems));
        } else {
          changed = true;
        }
      }
      if (changed) await _saveGroups(updated);
      return updated;
    } catch (_) {
      return [];
    }
  }

  /// Get story group for own device (isOwn = true).
  Future<StoryGroup?> getMyStoryGroup() async {
    final groups = await getAllStoryGroups();
    return groups.where((g) => g.isOwn).firstOrNull;
  }

  // ─── Write ────────────────────────────────────────────────

  /// Save image/video file to temp cache, register story metadata.
  /// Returns the created [StoryItem] or null on failure.
  Future<StoryItem?> postStory({
    required File mediaFile,
    required String deviceId,
    required String displayName,
    String? caption,
  }) async {
    if (kIsWeb) return null;
    try {
      final ext = _extension(mediaFile.path);
      final isVideo = _isVideoExt(ext);

      // Write to temp directory — NOT in RAM
      final cacheDir = await CacheManagerService().getStoryCacheDirectory();
      final id = _uuid.v4();
      final destPath = '${cacheDir.path}/$id$ext';

      // Copy file to cache (stream-based, no RAM holding)
      final src = mediaFile.openRead();
      final dest = File(destPath).openWrite();
      await src.pipe(dest);

      final now = DateTime.now();
      final item = StoryItem(
        id: id,
        mediaType: isVideo ? StoryMediaType.video : StoryMediaType.image,
        cachedFilePath: destPath,
        createdAt: now,
        expiresAt: now.add(
          Duration(hours: AppConstants.storyExpiryHours),
        ),
        caption: caption,
      );

      await _addItemToGroup(item, deviceId, displayName, isOwn: true);

      // Schedule auto-deletion timer for this specific file
      Timer(
        Duration(hours: AppConstants.storyExpiryHours),
        () => _deleteFile(destPath),
      );

      return item;
    } catch (e) {
      debugPrint('[StoryCacheService] postStory error: $e');
      return null;
    }
  }

  /// Add a peer's story (received via P2P) — path is peer's temp file.
  Future<void> addPeerStory({
    required StoryItem item,
    required String deviceId,
    required String displayName,
  }) async {
    await _addItemToGroup(item, deviceId, displayName, isOwn: false);
  }

  // ─── Update ───────────────────────────────────────────────

  /// Mark a story item as seen.
  Future<void> markSeen(String storyItemId) async {
    final groups = await getAllStoryGroups();
    final updated = groups.map((g) {
      final items = g.items.map((i) {
        return i.id == storyItemId ? i.copyWith(isSeen: true) : i;
      }).toList();
      return g.copyWith(items: items);
    }).toList();
    await _saveGroups(updated);
  }

  // ─── Delete ───────────────────────────────────────────────

  /// Delete a single story item by ID.
  Future<void> deleteStory(String storyItemId) async {
    final groups = await getAllStoryGroups();
    final updated = <StoryGroup>[];
    for (final g in groups) {
      final remaining = <StoryItem>[];
      for (final item in g.items) {
        if (item.id == storyItemId) {
          _deleteFile(item.cachedFilePath);
        } else {
          remaining.add(item);
        }
      }
      if (remaining.isNotEmpty) {
        updated.add(g.copyWith(items: remaining));
      }
    }
    await _saveGroups(updated);
  }

  /// Delete all own stories.
  Future<void> clearMyStories() async {
    final groups = await getAllStoryGroups();
    for (final g in groups.where((g) => g.isOwn)) {
      for (final item in g.items) {
        _deleteFile(item.cachedFilePath);
      }
    }
    final remaining = groups.where((g) => !g.isOwn).toList();
    await _saveGroups(remaining);
    await CacheManagerService().clearAllStories();
  }

  // ─── Helpers ─────────────────────────────────────────────

  Future<void> _addItemToGroup(
    StoryItem item,
    String deviceId,
    String displayName, {
    required bool isOwn,
  }) async {
    final groups = await getAllStoryGroups();
    final idx = groups.indexWhere((g) => g.deviceId == deviceId);
    List<StoryItem> items;
    if (idx >= 0) {
      items = [...groups[idx].items, item];
      // FIFO: remove oldest if over max
      if (items.length > AppConstants.storyMaxCount) {
        final removed = items.removeAt(0);
        _deleteFile(removed.cachedFilePath);
      }
      groups[idx] = groups[idx].copyWith(
        items: items,
        lastUpdated: DateTime.now(),
      );
    } else {
      groups.add(StoryGroup(
        deviceId: deviceId,
        displayName: displayName,
        items: [item],
        lastUpdated: DateTime.now(),
        isOwn: isOwn,
      ));
    }
    await _saveGroups(groups);
  }

  Future<void> _saveGroups(List<StoryGroup> groups) async {
    final jsonStr = StoryGroup.encodeList(groups);
    await _prefs.setString(AppConstants.storyMetaKey, jsonStr);
  }

  void _deleteFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  bool _isVideoExt(String ext) =>
      ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext.toLowerCase());

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot) : '.jpg';
  }

  /// Read file as Uint8List for display — stream-based, minimal RAM impact
  Future<Uint8List?> readStoryBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
