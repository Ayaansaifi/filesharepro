import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dioProvider = Provider((ref) => Dio());

final blockedMemeAuthorsProvider =
    StateNotifierProvider<BlockedMemeAuthorsNotifier, Set<String>>((ref) {
  return BlockedMemeAuthorsNotifier();
});

class BlockedMemeAuthorsNotifier extends StateNotifier<Set<String>> {
  BlockedMemeAuthorsNotifier() : super({}) {
    _load();
  }

  static const _key = 'blocked_meme_authors';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    state = list.toSet();
  }

  Future<void> blockAuthor(String author) async {
    state = {...state, author};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }
}

final likedMemesProvider =
    StateNotifierProvider<LikedMemesNotifier, Set<String>>((ref) {
  return LikedMemesNotifier();
});

class LikedMemesNotifier extends StateNotifier<Set<String>> {
  LikedMemesNotifier() : super({}) {
    _load();
  }

  static const _key = 'liked_memes';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? []).toSet();
  }

  Future<void> toggle(String postLink) async {
    if (state.contains(postLink)) {
      state = Set.from(state)..remove(postLink);
    } else {
      state = {...state, postLink};
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  bool isLiked(String postLink) => state.contains(postLink);
}

enum FeedMediaType { image, gif, video, reel }

final memeFeedProvider =
    StateNotifierProvider<MemeFeedNotifier, AsyncValue<List<MemeModel>>>((ref) {
  return MemeFeedNotifier(ref);
});

class MemeFeedNotifier extends StateNotifier<AsyncValue<List<MemeModel>>> {
  MemeFeedNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadMore();
  }

  final Ref ref;
  final List<MemeModel> _all = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    if (_all.isEmpty) state = const AsyncValue.loading();

    try {
      final dio = ref.read(dioProvider);
      // Alternate: memes API + Reddit trending funny/reels videos
      if (_page % 2 == 0) {
        await _loadMemeApi(dio);
      } else {
        await _loadRedditReels(dio);
      }
      _page++;
      if (_all.isEmpty) _hasMore = false;
      state = AsyncValue.data(List.from(_all));
    } catch (e, st) {
      if (_all.isEmpty) state = AsyncValue.error(e, st);
    } finally {
      _loading = false;
    }
  }

  Future<void> _loadMemeApi(Dio dio) async {
    final sub = _memeSubs[_page % _memeSubs.length];
    final response = await dio.get(
      'https://meme-api.com/gimme/$sub/20',
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    if (response.statusCode == 200 && response.data is Map) {
      final memes = (response.data['memes'] as List? ?? [])
          .map((m) => MemeModel.fromMemeApi(m as Map<String, dynamic>))
          .where(_isSafeContent)
          .toList();
      _all.addAll(memes);
      if (memes.isEmpty) _hasMore = false;
    }
  }

  Future<void> _loadRedditReels(Dio dio) async {
    final sub = _reelSubs[_page % _reelSubs.length];
    String redditUrl = 'https://www.reddit.com/r/$sub/hot.json?limit=25&raw_json=1';
    if (kIsWeb) {
      // Use a more stable proxy than corsproxy.io
      redditUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(redditUrl)}';
    }

    try {
      final response = await dio.get(
        redditUrl,
        options: Options(
          headers: {'User-Agent': 'FileSharePro/1.1 (Android; entertainment feed)'},
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode != 200 || response.data is! Map) return;
      final children = (response.data['data']?['children'] as List?) ?? [];

      for (final child in children) {
        try {
          if (child is! Map) continue;
          final post = child['data'] as Map<String, dynamic>?;
          if (post == null) continue;
          final model = MemeModel.fromRedditPost(post);
          if (model != null && _isSafeContent(model)) {
            _all.add(model);
          }
        } catch (e) {
          debugPrint('Error parsing reel post: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading Reddit reels: $e');
    }
  }

  Future<void> refresh() async {
    _all.clear();
    _page = 0;
    _hasMore = true;
    _loading = false;
    await loadMore();
  }

  static const _memeSubs = [
    'memes', 'dankmemes', 'wholesomememes', 'me_irl', 'ProgrammerHumor',
  ];

  static const _reelSubs = [
    'funny', 'ContagiousLaughter', 'TikTokCringe', 'PerfectlyCutScreams',
    'Unexpected', 'WatchPeopleDieInside', 'MadeMeSmile',
  ];
}

bool _isSafeContent(MemeModel meme) {
  if (meme.nsfw || meme.spoiler) return false;

  final unsafeKeywords = [
    'nsfw', 'porn', 'xxx', 'nude', 'naked', 'sex', 'hentai',
    'onlyfans', 'gore', 'suicide', 'cocaine', 'heroin',
  ];

  final titleLower = meme.title.toLowerCase();
  final subredditLower = meme.subreddit.toLowerCase();

  for (final keyword in unsafeKeywords) {
    if (_containsWord(titleLower, keyword) ||
        _containsWord(subredditLower, keyword)) {
      return false;
    }
  }

  const blockedSubreddits = {
    'gonewild', 'nsfw_gifs', 'rule34', 'hentai', 'realgirls', 'holdthemoan',
  };
  if (blockedSubreddits.contains(subredditLower)) return false;

  if (meme.mediaType == FeedMediaType.video || meme.mediaType == FeedMediaType.reel) {
    return meme.videoUrl != null && meme.videoUrl!.isNotEmpty;
  }

  final lowerUrl = meme.url.toLowerCase();
  return lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg') ||
      lowerUrl.endsWith('.png') ||
      lowerUrl.endsWith('.gif') ||
      lowerUrl.endsWith('.webp') ||
      lowerUrl.contains('i.redd.it') ||
      lowerUrl.contains('preview.redd.it');
}

bool _containsWord(String text, String word) {
  return RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(text);
}

class MemeModel {
  final String postLink;
  final String subreddit;
  final String title;
  final String url;
  final String? videoUrl;
  final FeedMediaType mediaType;
  final bool nsfw;
  final bool spoiler;
  final String author;
  final int ups;

  MemeModel({
    required this.postLink,
    required this.subreddit,
    required this.title,
    required this.url,
    this.videoUrl,
    this.mediaType = FeedMediaType.image,
    required this.nsfw,
    required this.spoiler,
    required this.author,
    required this.ups,
  });

  bool get isGif => mediaType == FeedMediaType.gif;
  bool get isVideo =>
      mediaType == FeedMediaType.video || mediaType == FeedMediaType.reel;

  factory MemeModel.fromMemeApi(Map<String, dynamic> json) {
    final url = json['url'] ?? '';
    return MemeModel(
      postLink: json['postLink'] ?? '',
      subreddit: json['subreddit'] ?? '',
      title: json['title'] ?? '',
      url: url,
      mediaType: url.toLowerCase().endsWith('.gif')
          ? FeedMediaType.gif
          : FeedMediaType.image,
      nsfw: json['nsfw'] ?? false,
      spoiler: json['spoiler'] ?? false,
      author: json['author'] ?? 'unknown',
      ups: json['ups'] ?? 0,
    );
  }

  static MemeModel? fromRedditPost(Map<String, dynamic> post) {
    if (post['over_18'] == true || post['spoiler'] == true) return null;

    final permalink = post['permalink'] as String? ?? '';
    final subreddit = post['subreddit'] as String? ?? '';
    final title = post['title'] as String? ?? '';
    final author = post['author'] as String? ?? 'unknown';
    final ups = post['ups'] as int? ?? 0;
    final postLink = 'https://reddit.com$permalink';

    // Reddit hosted video / reel
    if (post['is_video'] == true) {
      final media = post['media'] as Map<String, dynamic>?;
      final redditVideo = media?['reddit_video'] as Map<String, dynamic>?;
      final fallback = redditVideo?['fallback_url'] as String?;
      if (fallback == null || fallback.isEmpty) return null;
      final cleanUrl = fallback.split('?').first;
      return MemeModel(
        postLink: postLink,
        subreddit: subreddit,
        title: title,
        url: post['thumbnail'] as String? ?? cleanUrl,
        videoUrl: cleanUrl,
        mediaType: FeedMediaType.reel,
        nsfw: false,
        spoiler: false,
        author: author,
        ups: ups,
      );
    }

    final url = post['url'] as String? ?? '';
    if (url.contains('v.redd.it') || url.contains('.mp4')) {
      return MemeModel(
        postLink: postLink,
        subreddit: subreddit,
        title: title,
        url: post['preview']?['images']?[0]?['source']?['url']
                ?.toString()
                .replaceAll('&amp;', '&') ??
            url,
        videoUrl: url,
        mediaType: FeedMediaType.video,
        nsfw: false,
        spoiler: false,
        author: author,
        ups: ups,
      );
    }

    if (url.contains('i.redd.it') || url.contains('imgur.com')) {
      return MemeModel(
        postLink: postLink,
        subreddit: subreddit,
        title: title,
        url: url,
        mediaType: url.endsWith('.gif') ? FeedMediaType.gif : FeedMediaType.image,
        nsfw: false,
        spoiler: false,
        author: author,
        ups: ups,
      );
    }

    return null;
  }
}
