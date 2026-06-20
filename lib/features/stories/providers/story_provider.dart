import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/story_model.dart';
import '../services/story_cache_service.dart';
import '../../chat/providers/chat_provider.dart';

// ─── Service Provider ─────────────────────────────────────────────

final storyCacheServiceProvider = Provider<StoryCacheService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StoryCacheService(prefs);
});

// ─── Device Identity (for stories) ───────────────────────────────

final storyDeviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  const key = 'story_device_id';
  var id = prefs.getString(key);
  if (id == null) {
    id = const Uuid().v4();
    prefs.setString(key, id);
  }
  return id;
});

final storyDisplayNameProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString('user_display_name') ?? 'Me';
});

// ─── Stories State ────────────────────────────────────────────────

class StoriesState {
  final List<StoryGroup> groups;
  final bool isLoading;
  final bool isPosting;
  final String? error;

  const StoriesState({
    this.groups = const [],
    this.isLoading = false,
    this.isPosting = false,
    this.error,
  });

  StoriesState copyWith({
    List<StoryGroup>? groups,
    bool? isLoading,
    bool? isPosting,
    String? error,
  }) =>
      StoriesState(
        groups: groups ?? this.groups,
        isLoading: isLoading ?? this.isLoading,
        isPosting: isPosting ?? this.isPosting,
        error: error,
      );

  /// Own story group (isOwn = true)
  StoryGroup? get myGroup => groups.where((g) => g.isOwn).firstOrNull;

  /// Peer story groups (others)
  List<StoryGroup> get peerGroups => groups.where((g) => !g.isOwn).toList();
}

// ─── Notifier ─────────────────────────────────────────────────────

class StoriesNotifier extends StateNotifier<StoriesState> {
  final StoryCacheService _service;
  final String _deviceId;
  final String _displayName;

  StoriesNotifier(this._service, this._deviceId, this._displayName)
      : super(const StoriesState()) {
    loadStories();
  }

  Future<void> loadStories() async {
    state = state.copyWith(isLoading: true);
    final groups = await _service.getAllStoryGroups();
    state = state.copyWith(groups: groups, isLoading: false);
  }

  /// Pick and post a new story from a File (already picked by image_picker).
  Future<bool> postStory(File mediaFile, {String? caption}) async {
    state = state.copyWith(isPosting: true, error: null);
    final item = await _service.postStory(
      mediaFile: mediaFile,
      deviceId: _deviceId,
      displayName: _displayName,
      caption: caption,
    );
    if (item != null) {
      await loadStories();
      state = state.copyWith(isPosting: false);
      return true;
    } else {
      state = state.copyWith(isPosting: false, error: 'Failed to post story');
      return false;
    }
  }

  Future<void> markSeen(String itemId) async {
    await _service.markSeen(itemId);
    await loadStories();
  }

  Future<void> deleteStory(String itemId) async {
    await _service.deleteStory(itemId);
    await loadStories();
  }

  Future<void> clearMyStories() async {
    await _service.clearMyStories();
    await loadStories();
  }
}

// ─── Main Provider ────────────────────────────────────────────────

final storiesProvider =
    StateNotifierProvider<StoriesNotifier, StoriesState>((ref) {
  final service = ref.watch(storyCacheServiceProvider);
  final deviceId = ref.watch(storyDeviceIdProvider);
  final displayName = ref.watch(storyDisplayNameProvider);
  return StoriesNotifier(service, deviceId, displayName);
});
