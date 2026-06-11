import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

final dioProvider = Provider((ref) => Dio());

final memeFeedProvider = FutureProvider.autoDispose<List<MemeModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  
  try {
    // Using a public meme API for demonstration
    final response = await dio.get(
      'https://meme-api.com/gimme/50',
      options: Options(
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final data = response.data;
      if (data is! Map || !data.containsKey('memes')) {
        throw Exception('Invalid API response format');
      }
      
      final memes = data['memes'] as List;
      return memes
          .map((m) => MemeModel.fromJson(m as Map<String, dynamic>))
          .where((m) => _isSafeContent(m))
          .toList();
    }
    return [];
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      throw Exception('Connection timed out. Please check your internet.');
    }
    throw Exception('Failed to load content: ${e.message}');
  } catch (e) {
    throw Exception('Failed to load memes: $e');
  }
});

/// Comprehensive content safety filter for Play Store compliance
bool _isSafeContent(MemeModel meme) {
  // Reject NSFW-flagged content
  if (meme.nsfw || meme.spoiler) return false;
  
  // Reject non-image URLs (videos, gifs from unsafe sources)
  final lowerUrl = meme.url.toLowerCase();
  if (!lowerUrl.endsWith('.jpg') && 
      !lowerUrl.endsWith('.jpeg') && 
      !lowerUrl.endsWith('.png') && 
      !lowerUrl.endsWith('.gif') &&
      !lowerUrl.endsWith('.webp') &&
      !lowerUrl.contains('i.redd.it') &&
      !lowerUrl.contains('i.imgur.com') &&
      !lowerUrl.contains('preview.redd.it')) {
    return false;
  }
  
  // Keyword-based NSFW filtering for titles and subreddit names
  final unsafeKeywords = [
    'nsfw', 'porn', 'xxx', 'nude', 'naked', 'sex', 'hentai',
    'boob', 'ass', 'dick', 'pussy', 'fuck', 'cock', 'cum',
    'onlyfans', 'gore', 'death', 'kill', 'suicide', 'drug',
    'weed', 'cocaine', 'heroin', 'meth',
  ];
  
  final titleLower = meme.title.toLowerCase();
  final subredditLower = meme.subreddit.toLowerCase();
  
  for (final keyword in unsafeKeywords) {
    if (titleLower.contains(keyword) || subredditLower.contains(keyword)) {
      return false;
    }
  }
  
  // Block known NSFW subreddits
  final blockedSubreddits = [
    'gonewild', 'nsfw_gifs', 'rule34', 'hentai', 'realgirls',
    'holdthemoan', 'nsfwfunny', 'trashy', 'trashyboners',
    'cursedcomments', 'makemesuffer', 'fiftyfifty',
  ];
  
  if (blockedSubreddits.contains(subredditLower)) {
    return false;
  }
  
  return true;
}

class MemeModel {
  final String postLink;
  final String subreddit;
  final String title;
  final String url;
  final bool nsfw;
  final bool spoiler;
  final String author;
  final int ups;
  
  MemeModel({
    required this.postLink,
    required this.subreddit,
    required this.title,
    required this.url,
    required this.nsfw,
    required this.spoiler,
    required this.author,
    required this.ups,
  });
  
  factory MemeModel.fromJson(Map<String, dynamic> json) {
    return MemeModel(
      postLink: json['postLink'] ?? '',
      subreddit: json['subreddit'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      nsfw: json['nsfw'] ?? false,
      spoiler: json['spoiler'] ?? false,
      author: json['author'] ?? 'unknown',
      ups: json['ups'] ?? 0,
    );
  }
}
