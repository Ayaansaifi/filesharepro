import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_service.dart';

// ─── Service Provider ─────────────────────────────────────────────

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final service = GeminiService();
  ref.onDispose(service.dispose);
  return service;
});

// ─── AI Enabled State ─────────────────────────────────────────────

/// Whether AI features are currently visible/active in the chat.
final aiEnabledProvider = StateProvider<bool>((ref) => true);

// ─── Suggested Replies ────────────────────────────────────────────

/// Fetch suggested replies for the last received message text.
/// Auto-disposes when not watched. Returns [] if AI unavailable.
final suggestedRepliesProvider =
    FutureProvider.family<List<String>, String>((ref, lastMessage) async {
  final service = ref.watch(geminiServiceProvider);
  if (lastMessage.isEmpty) return [];
  return service.getSuggestedReplies(lastMessage);
});

// ─── File Insight ─────────────────────────────────────────────────

class FileInsightRequest {
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;

  const FileInsightRequest({
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileInsightRequest &&
          fileName == other.fileName &&
          fileSizeBytes == other.fileSizeBytes &&
          mimeType == other.mimeType;

  @override
  int get hashCode => Object.hash(fileName, fileSizeBytes, mimeType);
}

/// Fetch 2-line file insight summary from metadata only.
final fileInsightProvider =
    FutureProvider.family<String?, FileInsightRequest>((ref, request) async {
  final service = ref.watch(geminiServiceProvider);
  return service.getFileInsight(
    fileName: request.fileName,
    fileSizeBytes: request.fileSizeBytes,
    mimeType: request.mimeType,
  );
});

// ─── AI Chat State ────────────────────────────────────────────────

class AiChatState {
  final List<AiMessage> messages;
  final bool isLoading;
  final String? error;

  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? isLoading,
    String? error,
  }) =>
      AiChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  AiMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final GeminiService _service;

  AiChatNotifier(this._service) : super(const AiChatState());

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = AiMessage(text: text, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    final reply = await _service.chatWithAI(text);
    if (reply != null) {
      final aiMsg = AiMessage(text: reply, isUser: false);
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: _service.isAvailable
            ? 'AI response failed. Try again.'
            : 'Add Gemini API key in Settings to enable AI.',
      );
    }
  }

  void clearContext() {
    _service.clearContext();
    state = const AiChatState();
  }
}

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, AiChatState>((ref) {
  final service = ref.watch(geminiServiceProvider);
  return AiChatNotifier(service);
});
