enum MessageType { text, file, image, video, voice, system, deleted }
enum MessageDirection { sent, received }
enum MessageStatus { sending, sent, delivered, read, failed, downloading }

/// Represents a message in a P2P chat session.
/// Stored as JSON in SharedPreferences — NO database.
class ChatMessage {
  final String id;
  final MessageType type;
  final MessageDirection direction;
  final MessageStatus status;
  final DateTime timestamp;

  // Text content
  final String? textContent;

  // File content
  final String? fileName;
  final String? fileExtension;
  final int? fileSize;
  final String? filePath;
  final String? thumbnailPath;

  // Voice content
  final int? voiceDurationMs;

  // Reply context
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;

  // WhatsApp-style flags
  final bool isStarred;
  final bool isForwarded;
  final bool isDeleted; // "This message was deleted"

  ChatMessage({
    required this.id,
    required this.type,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.textContent,
    this.fileName,
    this.fileExtension,
    this.fileSize,
    this.filePath,
    this.thumbnailPath,
    this.voiceDurationMs,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.isStarred = false,
    this.isForwarded = false,
    this.isDeleted = false,
  });

  ChatMessage copyWith({
    MessageStatus? status,
    String? filePath,
    String? thumbnailPath,
    bool? isStarred,
    bool? isDeleted,
    MessageType? type,
    String? textContent,
  }) {
    return ChatMessage(
      id: id,
      type: type ?? this.type,
      direction: direction,
      status: status ?? this.status,
      timestamp: timestamp,
      textContent: textContent ?? this.textContent,
      fileName: fileName,
      fileExtension: fileExtension,
      fileSize: fileSize,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      voiceDurationMs: voiceDurationMs,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
      isStarred: isStarred ?? this.isStarred,
      isForwarded: isForwarded,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'direction': direction.index,
        'status': status.index,
        'timestamp': timestamp.toIso8601String(),
        'textContent': textContent,
        'fileName': fileName,
        'fileExtension': fileExtension,
        'fileSize': fileSize,
        'filePath': filePath,
        'thumbnailPath': thumbnailPath,
        'voiceDurationMs': voiceDurationMs,
        'replyToId': replyToId,
        'replyToText': replyToText,
        'replyToSender': replyToSender,
        'isStarred': isStarred,
        'isForwarded': isForwarded,
        'isDeleted': isDeleted,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Handle migration from old file-only messages
    final typeIndex = json['type'] as int?;
    final msgType = typeIndex != null
        ? MessageType.values[typeIndex]
        : MessageType.file;

    // Map old status to new status if needed
    int statusIndex = json['status'] as int;
    if (statusIndex > MessageStatus.values.length - 1) {
      statusIndex = 2; // Default to delivered
    }

    return ChatMessage(
      id: json['id'] as String,
      type: msgType,
      direction: MessageDirection.values[json['direction'] as int],
      status: MessageStatus.values[statusIndex],
      timestamp: DateTime.parse(json['timestamp'] as String),
      textContent: json['textContent'] as String?,
      fileName: json['fileName'] as String?,
      fileExtension: json['fileExtension'] as String?,
      fileSize: json['fileSize'] as int?,
      filePath: json['filePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      voiceDurationMs: json['voiceDurationMs'] as int?,
      replyToId: json['replyToId'] as String?,
      replyToText: json['replyToText'] as String?,
      replyToSender: json['replyToSender'] as String?,
      isStarred: json['isStarred'] as bool? ?? false,
      isForwarded: json['isForwarded'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}

/// A chat room represents a P2P session between two devices
class ChatRoom {
  final String roomCode;
  final String peerName;
  final DateTime createdAt;
  final DateTime lastActivity;
  final List<ChatMessage> messages;
  final bool isActive;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;

  ChatRoom({
    required this.roomCode,
    required this.peerName,
    required this.createdAt,
    required this.lastActivity,
    required this.messages,
    this.isActive = false,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
  });

  ChatRoom copyWith({
    String? peerName,
    DateTime? lastActivity,
    List<ChatMessage>? messages,
    bool? isActive,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
  }) {
    return ChatRoom(
      roomCode: roomCode,
      peerName: peerName ?? this.peerName,
      createdAt: createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'peerName': peerName,
        'createdAt': createdAt.toIso8601String(),
        'lastActivity': lastActivity.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'isActive': isActive,
        'isMuted': isMuted,
        'isPinned': isPinned,
        'isArchived': isArchived,
      };

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
        roomCode: json['roomCode'] as String,
        peerName: json['peerName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastActivity: DateTime.parse(json['lastActivity'] as String),
        messages: (json['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        isActive: json['isActive'] as bool? ?? false,
        isMuted: json['isMuted'] as bool? ?? false,
        isPinned: json['isPinned'] as bool? ?? false,
        isArchived: json['isArchived'] as bool? ?? false,
      );

  int get unreadCount => messages
      .where((m) =>
          m.direction == MessageDirection.received &&
          m.status == MessageStatus.delivered &&
          !m.isDeleted)
      .length;

  ChatMessage? get lastMessage {
    // Skip deleted messages for preview
    final nonDeleted = messages.where((m) => !m.isDeleted).toList();
    return nonDeleted.isNotEmpty ? nonDeleted.last : (messages.isNotEmpty ? messages.last : null);
  }

  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages yet';
    final last = lastMessage;
    if (last == null) return 'No messages yet';

    if (last.isDeleted) return '🚫 Message deleted';

    final prefix = last.direction == MessageDirection.sent ? 'You: ' : '';

    switch (last.type) {
      case MessageType.text:
        return '$prefix${last.textContent ?? ''}';
      case MessageType.voice:
        return '$prefix🎤 Voice note';
      case MessageType.image:
        return '$prefix📷 Image';
      case MessageType.video:
        return '$prefix🎥 Video';
      case MessageType.file:
        return '$prefix📎 ${last.fileName ?? 'File'}';
      case MessageType.system:
        return last.textContent ?? 'System message';
      case MessageType.deleted:
        return '🚫 Message deleted';
    }
  }
}
