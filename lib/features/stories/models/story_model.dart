import 'dart:convert';

/// Represents a single story media item (image or video).
/// Media stored on disk; only lightweight metadata held in RAM.
class StoryItem {
  final String id;
  final StoryMediaType mediaType;
  final String cachedFilePath; // path in getTemporaryDirectory()
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? caption;
  bool isSeen;

  StoryItem({
    required this.id,
    required this.mediaType,
    required this.cachedFilePath,
    required this.createdAt,
    required this.expiresAt,
    this.caption,
    this.isSeen = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaType': mediaType.index,
        'cachedFilePath': cachedFilePath,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'caption': caption,
        'isSeen': isSeen,
      };

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as String,
        mediaType: StoryMediaType.values[json['mediaType'] as int],
        cachedFilePath: json['cachedFilePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        caption: json['caption'] as String?,
        isSeen: json['isSeen'] as bool? ?? false,
      );

  StoryItem copyWith({bool? isSeen, String? caption}) => StoryItem(
        id: id,
        mediaType: mediaType,
        cachedFilePath: cachedFilePath,
        createdAt: createdAt,
        expiresAt: expiresAt,
        caption: caption ?? this.caption,
        isSeen: isSeen ?? this.isSeen,
      );
}

enum StoryMediaType { image, video }

/// A group of stories belonging to one device/user.
class StoryGroup {
  final String deviceId;   // unique device identifier
  final String displayName;
  final List<StoryItem> items;
  final DateTime lastUpdated;
  final bool isOwn;        // true = my stories, false = peer's stories

  const StoryGroup({
    required this.deviceId,
    required this.displayName,
    required this.items,
    required this.lastUpdated,
    this.isOwn = false,
  });

  /// Count of unseen story items
  int get unseenCount => items.where((i) => !i.isSeen && !i.isExpired).length;

  /// Live items (not expired)
  List<StoryItem> get activeItems =>
      items.where((i) => !i.isExpired).toList();

  bool get hasActiveStories => activeItems.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'displayName': displayName,
        'items': items.map((i) => i.toJson()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
        'isOwn': isOwn,
      };

  factory StoryGroup.fromJson(Map<String, dynamic> json) => StoryGroup(
        deviceId: json['deviceId'] as String,
        displayName: json['displayName'] as String,
        items: (json['items'] as List)
            .map((i) => StoryItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        isOwn: json['isOwn'] as bool? ?? false,
      );

  StoryGroup copyWith({List<StoryItem>? items, DateTime? lastUpdated}) =>
      StoryGroup(
        deviceId: deviceId,
        displayName: displayName,
        items: items ?? this.items,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        isOwn: isOwn,
      );

  static String encodeList(List<StoryGroup> groups) =>
      jsonEncode(groups.map((g) => g.toJson()).toList());

  static List<StoryGroup> decodeList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((g) => StoryGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }
}
