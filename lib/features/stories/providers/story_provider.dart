import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../chat/models/user_profile.dart';
import '../../chat/providers/chat_provider.dart';
import '../models/story_model.dart';
import '../services/story_service.dart';

/// Story service provider
final storyServiceProvider = Provider<StoryService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StoryService(prefs);
});

/// Story groups state — all users with stories, sorted by recency.
final storyGroupsProvider =
    StateNotifierProvider<StoryGroupsNotifier, List<StoryGroup>>((ref) {
  final service = ref.watch(storyServiceProvider);
  return StoryGroupsNotifier(service);
});

class StoryGroupsNotifier extends StateNotifier<List<StoryGroup>> {
  final StoryService _service;

  StoryGroupsNotifier(this._service) : super([]) {
    loadStories();
  }

  Future<void> loadStories() async {
    state = await _service.loadStories();
  }

  /// Add a new story for the current user.
  Future<void> addMyStory(StoryItem story) async {
    final profile = _getMyProfileFromPrefs(_service.prefs);
    if (profile == null) return;

    await _service.addStory(profile.peerId, profile.displayName, story);
    await loadStories();
  }

  /// Delete a specific story.
  Future<void> deleteStory(String userId, String storyId) async {
    await _service.deleteStory(userId, storyId);
    await loadStories();
  }

  /// Mark stories viewed for a group up to given index.
  Future<void> markViewed(String userId, int index) async {
    await _service.setViewedUpTo(userId, index);
    await loadStories();
  }

  /// Get view progress for a story group (0.0 = none viewed, 1.0 = all viewed).
  double viewProgress(StoryGroup group) {
    final viewedUpTo = _service.getViewedUpTo(group.userId);
    if (group.activeItems.isEmpty) return 1.0;
    return (viewedUpTo + 1) / group.activeItems.length;
  }

  /// Whether a group has any unviewed stories.
  bool hasUnviewed(StoryGroup group) {
    final viewedUpTo = _service.getViewedUpTo(group.userId);
    return viewedUpTo < group.activeItems.length - 1;
  }
}

// ─── Helper to read profile from SharedPreferences ───
UserProfile? _getMyProfileFromPrefs(SharedPreferences prefs) {
  final jsonStr = prefs.getString('my_profile');
  if (jsonStr == null) return null;
  try {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return UserProfile.fromJson(map);
  } catch (_) {
    return null;
  }
}

/// Convenience provider to get my user info for story creation.
final myStoryProfileProvider = Provider<(String, String)>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final profile = _getMyProfileFromPrefs(prefs);
  if (profile == null) return ('me', 'My Status');
  return (profile.peerId, profile.displayName);
});
