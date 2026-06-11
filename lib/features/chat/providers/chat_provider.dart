import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/contact_model.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/contacts_service.dart';
import '../services/chat_encryption_service.dart';

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

/// Provider for ChatService singleton
final chatServiceProvider = Provider<ChatService>((ref) {
  final encryption = ref.watch(chatEncryptionServiceProvider);
  final service = ChatService(encryption);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for chat rooms list
final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsNotifier, ChatRoomsState>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ChatRoomsNotifier(service);
});

/// Provider for active chat room messages
final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ActiveChatState>((ref) {
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

  Future<String?> createRoom(String deviceName) async {
    final code = await _service.createRoom(deviceName);
    if (code != null) await loadRooms();
    return code;
  }

  Future<bool> joinRoom(String roomCode, String deviceName) async {
    final success = await _service.joinRoom(roomCode, deviceName);
    if (success) await loadRooms();
    return success;
  }

  Future<void> deleteRoom(String roomCode) async {
    await _service.deleteChatRoom(roomCode);
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
  }

  void _handleIncomingMessage(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      sendProgress: 0,
      isTyping: false,
    );
  }

  Future<void> loadChat(String roomCode) async {
    final messages = await _service.getRoomMessages(roomCode);
    state = state.copyWith(
      roomCode: roomCode,
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

  Future<void> sendTextMessage(String text) async {
    final message = await _service.sendTextMessage(text);
    if (message != null) {
      state = state.copyWith(
        messages: [...state.messages, message],
      );
    }
  }

  void setTyping(bool typing) {
    state = state.copyWith(isTyping: typing);
  }

  void sendTypingStatus(bool isTyping) {
    _service.sendTypingStatus(isTyping);
  }

  void clearChat() {
    state = ActiveChatState.initial();
  }
}

class ActiveChatState {
  final String? roomCode;
  final List<ChatMessage> messages;
  final bool isConnected;
  final bool isSending;
  final double sendProgress;
  final String? statusMessage;
  final String? error;
  final bool isTyping;

  const ActiveChatState({
    this.roomCode,
    required this.messages,
    required this.isConnected,
    required this.isSending,
    required this.sendProgress,
    this.statusMessage,
    this.error,
    this.isTyping = false,
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
    List<ChatMessage>? messages,
    bool? isConnected,
    bool? isSending,
    double? sendProgress,
    String? statusMessage,
    String? error,
    bool? isTyping,
  }) {
    return ActiveChatState(
      roomCode: roomCode ?? this.roomCode,
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isSending: isSending ?? this.isSending,
      sendProgress: sendProgress ?? this.sendProgress,
      statusMessage: statusMessage ?? this.statusMessage,
      error: error ?? this.error,
      isTyping: isTyping ?? this.isTyping,
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
