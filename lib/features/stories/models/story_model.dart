import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';

/// Story content types — text, image, or video.
enum StoryType { text, image, video }

/// A single story item (one slide in a user's story ring).
///
/// Stories are local-only and stored in SharedPreferences (metadata) +
/// app documents directory (media files on mobile). They auto-expire
/// after 24 hours.
///
/// Media storage:
/// - Mobile (Android/iOS): local file via [filePath].
/// - Web: base64-encoded image bytes via [mediaData] (Flutter web has no
///   dart:io file system, so images are embedded directly).
class StoryItem {
  final String id;
  final StoryType type;
  final DateTime createdAt;

  // Text story
  final String? textContent;
  final Color? bgColor;

  // Image / Video story
  final String? filePath; // local file path (mobile only)
  final String? thumbnailPath;

  /// Base64-encoded media bytes — used for image stories on Flutter Web
  /// where there is no local file system. Null on mobile.
  final String? mediaData;

  StoryItem({
    required this.id,
    required this.type,
    required this.createdAt,
    this.textContent,
    this.bgColor,
    this.filePath,
    this.thumbnailPath,
    this.mediaData,
  });

  /// Stories older than this are expired and should be deleted.
  static const Duration expiryDuration = Duration(hours: 24);

  bool get isExpired => DateTime.now().difference(createdAt) > expiryDuration;

  bool get hasMedia => type == StoryType.image || type == StoryType.video;

  /// Whether the media payload is available to render.
  /// On web we use [mediaData] (base64); on mobile we stat the file.
  /// existsSync() is a dart:io call that throws on web, so it is guarded.
  bool get hasFile {
    if (mediaData != null && mediaData!.isNotEmpty) return true;
    if (filePath == null || filePath!.isEmpty) return false;
    if (kIsWeb) return true;
    return File(filePath!).existsSync();
  }

  StoryItem copyWith({
    String? textContent,
    Color? bgColor,
    String? filePath,
    String? thumbnailPath,
    String? mediaData,
  }) {
    return StoryItem(
      id: id,
      type: type,
      createdAt: createdAt,
      textContent: textContent ?? this.textContent,
      bgColor: bgColor ?? this.bgColor,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      mediaData: mediaData ?? this.mediaData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'createdAt': createdAt.toIso8601String(),
        'textContent': textContent,
        'bgColor': bgColor?.toARGB32(),
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'mediaData': mediaData,
      };

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as String,
        type: StoryType.values[json['type'] as int? ?? 0],
        createdAt: DateTime.parse(json['createdAt'] as String),
        textContent: json['textContent'] as String?,
        bgColor: json['bgColor'] != null
            ? Color(json['bgColor'] as int)
            : null,
        filePath: json['filePath'] as String?,
        thumbnailPath: json['thumbnailPath'] as String?,
        mediaData: json['mediaData'] as String?,
      );
}

/// A user's story ring — all of their story items grouped together.
class StoryGroup {
  final String userId; // profile.peerId or profile.uniqueId
  final String displayName;
  final List<StoryItem> items;

  StoryGroup({
    required this.userId,
    required this.displayName,
    required this.items,
  });

  /// Only non-expired items count.
  List<StoryItem> get activeItems => items.where((s) => !s.isExpired).toList();

  bool get hasActive => activeItems.isNotEmpty;

  /// Index of the first un-viewed item (for the ring progress indicator).
  /// Returns 0 if none have been viewed.
  int firstUnviewedIndex(int viewedUpTo) {
    if (viewedUpTo >= activeItems.length) return 0;
    return viewedUpTo.clamp(0, activeItems.length - 1);
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'items': items.map((s) => s.toJson()).toList(),
      };

  factory StoryGroup.fromJson(Map<String, dynamic> json) => StoryGroup(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Unknown',
        items: (json['items'] as List)
            .map((s) => StoryItem.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
