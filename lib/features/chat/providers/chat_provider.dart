import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/contact_model.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/contacts_service.dart';
import '../services/chat_encryption_service.dart';
import '../../../core/services/local_network_service.dart';
import '../../../core/services/signaling_service.dart';
import '../../../core/services/webrtc_service.dart';

/// SharedPreferences provider (must be overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// Contacts Service provider
final contactsServiceProvider = Provider<ContactsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ContactsService(prefs);
});

/// Encryption Service provider
final chatEncryptionServiceProvider = Provider<ChatEncryptionService>((ref) {
  final service = ChatEncryptionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Local Network Service provider — SINGLE shared instance across app
final localNetworkServiceProvider = Provider<LocalNetworkService>((ref) {
  final service = LocalNetworkService();
  service.startTcpServer();
  ref.onDispose(() => service.dispose());
  return service;
});

final signalingServiceProvider = Provider<SignalingService>((ref) {
  final service = SignalingService();
  ref.onDispose(() => service.disconnect());
  return service;
});

final webrtcServiceProvider = Provider<WebRtcService>((ref) {
  final signaling = ref.watch(signalingServiceProvider);
  final service = WebRtcService(signaling);
  ref.onDispose(() => service.disconnect());
  return service;
});

/// Provider for ChatService singleton
final chatServiceProvider = Provider<ChatService>((ref) {
  final encryption = ref.watch(chatEncryptionServiceProvider);
  final network = ref.watch(localNetworkServiceProvider);
  final signaling = ref.watch(signalingServiceProvider);
  final webrtc = ref.watch(webrtcServiceProvider);
  final service = ChatService(network, webrtc, encryption, signaling);

  // Push our own peer identity (phone number) into the chat service so it
  // subscribes to the correct signaling topic. Kept in sync with myProfileProvider.
  ref.listen(myProfileProvider, (previous, next) {
    if (next != null) {
      service.setOwnPeerId(next.peerId);
    }
  }, fireImmediately: true);

  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for chat rooms list
final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsNotifier, ChatRoomsState>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ChatRoomsNotifier(service);
});

/// Listens for successful peer connections and persists them as paired
/// contacts so they appear under "FileShare Pro Users" in the contacts list.
/// This makes contacts-based chat feel like WhatsApp: once you reach someone,
/// they stay reachable.
final pairingSyncProvider = Provider<void>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  final contactsService = ref.watch(contactsServiceProvider);

  chatService.onPeerPaired = (peerId) async {
    // Recover the human-readable name from the chat room we created.
    final rooms = await chatService.getChatRooms();
    final room = rooms.firstWhere(
      (r) => r.roomCode == peerId,
      orElse: () => ChatRoom(
        roomCode: peerId,
        peerName: peerId,
        createdAt: DateTime.now(),
        lastActivity: DateTime.now(),
        messages: const [],
      ),
    );

    final paired = AppContact(
      id: peerId,
      displayName: room.peerName.isNotEmpty ? room.peerName : peerId,
      phoneNumber: peerId,
      deviceId: peerId,
      roomCode: peerId,
    );

    await contactsService.savePairedContact(paired);
    // Refresh the paired-contacts list so the UI updates immediately.
    ref.read(pairedContactsProvider.notifier).state =
        contactsService.getPairedContacts();
  };
});

/// Provider for active chat room messages
final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ActiveChatState>((ref) {
  // Touch the pairing sync provider so it stays alive alongside active chats.
  ref.watch(pairingSyncProvider);
  final service = ref.watch(chatServiceProvider);
  return ActiveChatNotifier(service);
});

// ─── Contacts State ──────────────────────────────────────────

final pairedContactsProvider = StateProvider<List<AppContact>>((ref) {
  final service = ref.watch(contactsServiceProvider);
  return service.getPairedContacts();
});

final myProfileProvider = StateProvider<UserProfile?>((ref) {
  final service = ref.watch(contactsServiceProvider);
  return service.getMyProfile();
});

// ─── Chat Rooms List ────────────────────────────────────────

class ChatRoomsNotifier extends StateNotifier<ChatRoomsState> {
  final ChatService _service;

  ChatRoomsNotifier(this._service) : super(ChatRoomsState.initial()) {
    loadRooms();
  }

  Future<void> loadRooms() async {
    state = state.copyWith(isLoading: true);
    final rooms = await _service.getChatRooms();
    state = state.copyWith(rooms: rooms, isLoading: false);
  }

  Future<bool> connectTo(String ip, String deviceId, String deviceName) async {
    final success = await _service.connectTo(ip, deviceId, deviceName);
    if (success) await loadRooms();
    return success;
  }

  Future<void> deleteRoom(String roomCode) async {
    await _service.deleteChatRoom(roomCode);
    await loadRooms();
  }

  Future<void> clearRoom(String roomCode) async {
    await _service.clearRoomMessages(roomCode);
    await loadRooms();
  }

  Future<void> toggleMute(String roomCode, bool mute) async {
    await _service.toggleMuteRoom(roomCode, mute);
    await loadRooms();
  }

  Future<void> togglePin(String roomCode, bool pin) async {
    await _service.togglePinRoom(roomCode, pin);
    await loadRooms();
  }
}

class ChatRoomsState {
  final List<ChatRoom> rooms;
  final bool isLoading;

  const ChatRoomsState({required this.rooms, required this.isLoading});

  factory ChatRoomsState.initial() =>
      const ChatRoomsState(rooms: [], isLoading: true);

  ChatRoomsState copyWith({List<ChatRoom>? rooms, bool? isLoading}) {
    return ChatRoomsState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ─── Active Chat Room ───────────────────────────────────────

class ActiveChatNotifier extends StateNotifier<ActiveChatState> {
  final ChatService _service;

  ActiveChatNotifier(this._service) : super(ActiveChatState.initial()) {
    _service.onMessageReceived = _handleIncomingMessage;
    _service.onMessageUpdated = _handleUpdatedMessage;
    _service.onConnectionChange = (connected) {
      state = state.copyWith(isConnected: connected);
    };
    _service.onTransferProgress = (progress) {
      state = state.copyWith(sendProgress: progress);
    };
    _service.onStatusChange = (status) {
      state = state.copyWith(statusMessage: status);
    };
    _service.onError = (err) {
      state = state.copyWith(error: err);
    };
    _service.onTypingChange = (typing) {
      state = state.copyWith(isTyping: typing);
    };
    _service.onPresenceChange = (online) {
      state = state.copyWith(isPeerOnline: online);
    };
  }

  void _handleIncomingMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      sendProgress: 0,
      isTyping: false,
    );
  }

  void _handleUpdatedMessage(ChatMessage updated) {
    final messages = state.messages.map((m) {
      return m.id == updated.id ? updated : m;
    }).toList();
    state = state.copyWith(messages: messages);
  }

  Future<void> loadChat(String roomCode) async {
    await _service.reconnectRoom(roomCode);
    final messages = await _service.getRoomMessages(roomCode);
    // Resolve a friendly peer name for the header (falls back to the raw
    // room code, which may be a phone number for internet chats).
    final rooms = await _service.getChatRooms();
    final room = rooms.firstWhere(
      (r) => r.roomCode == roomCode,
      orElse: () => ChatRoom(
        roomCode: roomCode,
        peerName: roomCode,
        createdAt: DateTime.now(),
        lastActivity: DateTime.now(),
        messages: const [],
      ),
    );
    await _service.markRoomAsRead(roomCode);
    state = state.copyWith(
      roomCode: roomCode,
      peerName: room.peerName,
      messages: messages,
      isConnected: _service.isConnected,
    );
  }

  Future<void> sendFile(File file) async {
    state = state.copyWith(isSending: true, sendProgress: 0);
    final message = await _service.sendFile(file);
    if (message != null) {
      state = state.copyWith(
        messages: [...state.messages, message],
        isSending: false,
        sendProgress: 0,
      );
    } else {
      state = state.copyWith(isSending: false);
    }
  }

  Future<void> sendTextMessage(String text, {String? replyToId, String? replyToText, String? replyToSender}) async {
    final message = await _service.sendTextMessage(
      text,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
    );
    if (message != null) {
      state = state.copyWith(
        messages: [...state.messages, message],
      );
    }
  }

  /// Delete message for me only
  Future<void> deleteMessageForMe(String messageId) async {
    if (state.roomCode == null) return;
    await _service.deleteMessageForMe(state.roomCode!, messageId);
    final messages = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: messages);
  }

  /// Delete message for everyone
  Future<void> deleteMessageForEveryone(String messageId) async {
    if (state.roomCode == null) return;
    await _service.deleteMessageForEveryone(state.roomCode!, messageId);
    final messages = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isDeleted: true, type: MessageType.deleted, textContent: 'This message was deleted');
      }
      return m;
    }).toList();
    state = state.copyWith(messages: messages);
  }

  /// Toggle star on a message
  Future<void> toggleStarMessage(String messageId) async {
    if (state.roomCode == null) return;
    await _service.toggleStarMessage(state.roomCode!, messageId);
    final messages = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isStarred: !m.isStarred);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: messages, selectedMessageId: null);
  }

  /// Forward a message to this room
  Future<void> forwardMessage(ChatMessage original) async {
    final message = await _service.forwardMessage(original);
    if (message != null) {
      state = state.copyWith(messages: [...state.messages, message]);
    }
  }

  void setTyping(bool typing) {
    state = state.copyWith(isTyping: typing);
  }

  void sendTypingStatus(bool isTyping) {
    _service.sendTypingStatus(isTyping);
  }

  void setSelectedMessage(String? messageId) {
    state = state.copyWith(selectedMessageId: messageId);
  }

  void setReplyTo(ChatMessage? message) {
    state = state.copyWith(replyToMessage: message, selectedMessageId: null);
  }

  void clearSelection() {
    state = state.copyWith(selectedMessageId: null, replyToMessage: null);
  }

  void clearChat() {
    if (state.roomCode != null) {
      _service.clearRoomMessages(state.roomCode!);
    }
    state = ActiveChatState.initial();
  }
}

class ActiveChatState {
  final String? roomCode;
  final String? peerName;
  final List<ChatMessage> messages;
  final bool isConnected;
  final bool isSending;
  final double sendProgress;
  final String? statusMessage;
  final String? error;
  final bool isTyping;
  final bool isPeerOnline;

  // Selection / context menu state
  final String? selectedMessageId; // Message being acted on
  final ChatMessage? replyToMessage; // Message being replied to

  const ActiveChatState({
    this.roomCode,
    this.peerName,
    required this.messages,
    required this.isConnected,
    required this.isSending,
    required this.sendProgress,
    this.statusMessage,
    this.error,
    this.isTyping = false,
    this.isPeerOnline = false,
    this.selectedMessageId,
    this.replyToMessage,
  });

  factory ActiveChatState.initial() => const ActiveChatState(
        messages: [],
        isConnected: false,
        isSending: false,
        sendProgress: 0,
        isTyping: false,
      );

  ActiveChatState copyWith({
    String? roomCode,
    String? peerName,
    List<ChatMessage>? messages,
    bool? isConnected,
    bool? isSending,
    double? sendProgress,
    String? statusMessage,
    String? error,
    bool? isTyping,
    bool? isPeerOnline,
    String? selectedMessageId,
    ChatMessage? replyToMessage,
    bool clearSelection = false,
    bool clearReply = false,
  }) {
    return ActiveChatState(
      roomCode: roomCode ?? this.roomCode,
      peerName: peerName ?? this.peerName,
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isSending: isSending ?? this.isSending,
      sendProgress: sendProgress ?? this.sendProgress,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error ?? this.error,
      isTyping: isTyping ?? this.isTyping,
      isPeerOnline: isPeerOnline ?? this.isPeerOnline,
      selectedMessageId: clearSelection ? null : (selectedMessageId ?? this.selectedMessageId),
      replyToMessage: clearReply ? null : (replyToMessage ?? this.replyToMessage),
    );
  }
}

// ─── Blocked Users Logic ────────────────────────────────────

final blockedUsersProvider = StateNotifierProvider<BlockedUsersNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BlockedUsersNotifier(prefs);
});

class BlockedUsersNotifier extends StateNotifier<List<String>> {
  final SharedPreferences _prefs;
  static const _key = 'blocked_users';

  BlockedUsersNotifier(this._prefs) : super([]) {
    _loadBlockedUsers();
  }

  void _loadBlockedUsers() {
    final blocked = _prefs.getStringList(_key) ?? [];
    state = blocked;
  }

  Future<void> blockUser(String userId) async {
    if (!state.contains(userId)) {
      final updated = [...state, userId];
      await _prefs.setStringList(_key, updated);
      state = updated;
    }
  }

  Future<void> unblockUser(String userId) async {
    final updated = state.where((id) => id != userId).toList();
    await _prefs.setStringList(_key, updated);
    state = updated;
  }
}
