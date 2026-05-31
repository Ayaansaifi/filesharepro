enum MessageType { text, file, image, video, voice, system }
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
  });

  ChatMessage copyWith({
    MessageStatus? status,
    String? filePath,
    String? thumbnailPath,
  }) {
    return ChatMessage(
      id: id,
      type: type,
      direction: direction,
      status: status ?? this.status,
      timestamp: timestamp,
      textContent: textContent,
      fileName: fileName,
      fileExtension: fileExtension,
      fileSize: fileSize,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      voiceDurationMs: voiceDurationMs,
      replyToId: replyToId,
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

  ChatRoom({
    required this.roomCode,
    required this.peerName,
    required this.createdAt,
    required this.lastActivity,
    required this.messages,
    this.isActive = false,
  });

  ChatRoom copyWith({
    String? peerName,
    DateTime? lastActivity,
    List<ChatMessage>? messages,
    bool? isActive,
  }) {
    return ChatRoom(
      roomCode: roomCode,
      peerName: peerName ?? this.peerName,
      createdAt: createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'peerName': peerName,
        'createdAt': createdAt.toIso8601String(),
        'lastActivity': lastActivity.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'isActive': isActive,
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
      );

  int get unreadCount => messages
      .where((m) =>
          m.direction == MessageDirection.received &&
          m.status == MessageStatus.delivered)
      .length;

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;

  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages yet';
    final last = messages.last;
    final prefix =
        last.direction == MessageDirection.sent ? 'You: ' : '';
    
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
    }
  }
}
