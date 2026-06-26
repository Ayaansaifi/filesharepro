import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/story_model.dart';

class StoryService {
  static const String _keyStories = 'stories_data';
  static const String _keyViewed = 'stories_viewed_up_to';
  static const int _maxStoriesPerUser = 10;

  /// Exposed for provider access (profile reading).
  SharedPreferences get prefs => _prefs;

  final SharedPreferences _prefs;

  StoryService(this._prefs);

  /// Load all story groups, pruning expired items and deleting orphan files.
  Future<List<StoryGroup>> loadStories() async {
    final jsonStr = _prefs.getString(_keyStories);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = json.decode(jsonStr);
      final groups = list
          .map((e) => StoryGroup.fromJson(e as Map<String, dynamic>))
          .toList();

      bool needsSave = false;
      for (final group in groups) {
        final before = group.items.length;
        // Remove expired items
        group.items.removeWhere((item) {
          if (item.isExpired) {
            _deleteStoryFile(item);
            return true;
          }
          return false;
        });
        if (group.items.length != before) needsSave = true;
      }

      // Remove empty groups
      groups.removeWhere((g) => g.items.isEmpty);
      if (needsSave) await _saveGroups(groups);

      // Sort: groups with most recent items first
      groups.sort((a, b) {
        final aTime = a.activeItems.isNotEmpty
            ? a.activeItems.first.createdAt
            : DateTime(2000);
        final bTime = b.activeItems.isNotEmpty
            ? b.activeItems.first.createdAt
            : DateTime(2000);
        return bTime.compareTo(aTime);
      });

      return groups;
    } catch (e) {
      debugPrint('StoryService: Error loading stories: $e');
      return [];
    }
  }

  /// Add a story item for the given user.
  Future<void> addStory(String userId, String displayName, StoryItem story) async {
    final groups = await loadStories();

    var group = groups.firstWhere(
      (g) => g.userId == userId,
      orElse: () => StoryGroup(userId: userId, displayName: displayName, items: []),
    );

    // If user group doesn't exist, add it
    final idx = groups.indexWhere((g) => g.userId == userId);
    if (idx < 0) {
      groups.insert(0, group);
    } else {
      group = groups[idx];
    }

    // Enforce max stories per user
    if (group.items.length >= _maxStoriesPerUser) {
      final removed = group.items.removeAt(0);
      _deleteStoryFile(removed);
    }

    group.items.add(story);
    // Update display name in case it changed
    final updatedGroups = groups
        .map((g) => g.userId == userId
            ? StoryGroup(userId: userId, displayName: displayName, items: g.items)
            : g)
        .toList();

    await _saveGroups(updatedGroups);
  }

  /// Delete a specific story item.
  Future<void> deleteStory(String userId, String storyId) async {
    final groups = await loadStories();
    final idx = groups.indexWhere((g) => g.userId == userId);
    if (idx < 0) return;

    final group = groups[idx];
    final storyIdx = group.items.indexWhere((s) => s.id == storyId);
    if (storyIdx < 0) return;

    _deleteStoryFile(group.items[storyIdx]);
    group.items.removeAt(storyIdx);

    if (group.items.isEmpty) {
      groups.removeAt(idx);
    }

    await _saveGroups(groups);
  }

  /// Delete all stories for a user.
  Future<void> deleteUserStories(String userId) async {
    final groups = await loadStories();
    final group = groups.firstWhere(
      (g) => g.userId == userId,
      orElse: () => StoryGroup(userId: '', displayName: '', items: []),
    );
    for (final item in group.items) {
      _deleteStoryFile(item);
    }
    groups.removeWhere((g) => g.userId == userId);
    await _saveGroups(groups);
  }

  // ─── View tracking (which story index each user was viewed up to) ───

  /// Get how far the user has viewed stories for a given group.
  int getViewedUpTo(String userId) {
    final map = _getViewedMap();
    return map[userId] ?? 0;
  }

  /// Mark stories as viewed up to a certain index.
  Future<void> setViewedUpTo(String userId, int index) async {
    final map = _getViewedMap();
    map[userId] = index;
    await _prefs.setString(_keyViewed, json.encode(map));
  }

  Map<String, dynamic> _getViewedMap() {
    final raw = _prefs.getString(_keyViewed);
    if (raw == null) return {};
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ─── Media file helpers ────────────────────────────────────

  Future<Directory> getStoryMediaDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Documents/FileSharePro/Stories');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/story_media');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copy a picked file into the story media directory and return the new path.
  ///
  /// On Flutter Web there is no local file system, so the picked bytes are
  /// read into memory and returned as a base64 data string (prefixed with
  /// a sentinel) that the viewer decodes for display.
  Future<String> copyMediaToStoryDir(String sourcePath) async {
    // Web path — embed the bytes as base64 so the story can be displayed
    // without a real file on disk.
    if (kIsWeb) {
      final bytes = await File(sourcePath).readAsBytes();
      return base64Encode(bytes);
    }

    final dir = await getStoryMediaDir();
    final fileName = 'story_${DateTime.now().millisecondsSinceEpoch}_${sourcePath.split('/').last}';
    final targetPath = '${dir.path}/$fileName';
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  void _deleteStoryFile(StoryItem story) {
    // On web there are no files to delete (media lives as base64 in prefs).
    if (kIsWeb) return;
    if (story.filePath != null) {
      try {
        final f = File(story.filePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    if (story.thumbnailPath != null) {
      try {
        final f = File(story.thumbnailPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _saveGroups(List<StoryGroup> groups) async {
    final jsonStr = json.encode(groups.map((g) => g.toJson()).toList());
    await _prefs.setString(_keyStories, jsonStr);
  }
}
