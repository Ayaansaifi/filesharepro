import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/constants/app_constants.dart';

/// Gemini AI service — wraps Google Generative AI SDK.
///
/// RAM protection:
/// - Rolling context capped at [AppConstants.aiRollingContextMax] items.
/// - No caching of images/files in RAM — only lightweight metadata strings passed.
/// - All heavy object references are local, not stored in class fields.
class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chatSession;

  // Rolling context — max 5 items (FIFO), lightweight List<Content> only
  final List<Content> _rollingContext = [];

  bool get isAvailable => AppConstants.geminiApiKey.isNotEmpty;

  // ─── Init ─────────────────────────────────────────────────

  void _ensureModel() {
    if (!isAvailable) return;
    _model ??= GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 512, // keep responses short to reduce latency
        topP: 0.9,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
    _chatSession ??= _model!.startChat(history: _rollingContext);
  }

  // ─── Smart Reply Suggestions ──────────────────────────────

  /// Given the last received message, returns 3 short reply suggestions.
  /// Returns empty list on failure/no API key (graceful degradation).
  Future<List<String>> getSuggestedReplies(String lastMessage) async {
    if (!isAvailable) return [];
    try {
      _ensureModel();
      final prompt = '''You are a helpful assistant in a file-sharing P2P chat app.
The user received this message: "$lastMessage"
Suggest 3 very short, natural reply options (max 8 words each).
Return ONLY a JSON array of 3 strings. Example: ["Got it!", "Thanks!", "Send me more details"]
No markdown, no explanation, only the JSON array.''';

      final response = await _model!
          .generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 10),
      );

      final text = response.text?.trim() ?? '';
      // Parse JSON array
      final jsonStart = text.indexOf('[');
      final jsonEnd = text.lastIndexOf(']');
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = text.substring(jsonStart, jsonEnd + 1);
        final list = jsonDecode(jsonStr) as List;
        return list.map((e) => e.toString()).take(3).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[GeminiService] getSuggestedReplies error: $e');
      return [];
    }
  }

  // ─── File Insight (Contextual Preview Summary) ────────────

  /// Given file metadata, returns a 2-line human-readable insight summary.
  /// Never accesses the actual file bytes — only metadata strings.
  Future<String?> getFileInsight({
    required String fileName,
    required int fileSizeBytes,
    required String mimeType,
  }) async {
    if (!isAvailable) return null;
    try {
      _ensureModel();
      final sizeStr = _formatBytes(fileSizeBytes);
      final prompt = '''You are a smart preview assistant in a file sharing app.
File received: "$fileName", Size: $sizeStr, Type: $mimeType
Write a SHORT 1-2 line preview description of what this file likely is/contains.
Be specific and informative. No emojis at start. Start directly with the description.
Max 30 words total.''';

      final response = await _model!
          .generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 8),
      );

      return response.text?.trim();
    } catch (e) {
      debugPrint('[GeminiService] getFileInsight error: $e');
      return null;
    }
  }

  // ─── Smart Chat with Rolling Context ─────────────────────

  /// Send a message to AI, maintaining a rolling 5-message context window.
  Future<String?> chatWithAI(String userMessage) async {
    if (!isAvailable) return null;
    try {
      _ensureModel();

      // Add to rolling context
      _rollingContext.add(Content.text(userMessage));
      // FIFO: trim to max
      while (_rollingContext.length > AppConstants.aiRollingContextMax) {
        _rollingContext.removeAt(0);
      }

      // Restart chat session with updated context to keep history in sync
      final session = _model!.startChat(history: _rollingContext);
      final response = await session
          .sendMessage(Content.text(userMessage))
          .timeout(const Duration(seconds: 15));

      final reply = response.text?.trim();
      if (reply != null) {
        _rollingContext.add(Content.model([TextPart(reply)]));
        // Trim again after adding response
        while (_rollingContext.length > AppConstants.aiRollingContextMax) {
          _rollingContext.removeAt(0);
        }
      }
      return reply;
    } catch (e) {
      debugPrint('[GeminiService] chatWithAI error: $e');
      return null;
    }
  }

  // ─── Translation ──────────────────────────────────────────

  /// Detect language and translate to target (e.g., 'English', 'Hindi').
  Future<String?> translateText(String text, String targetLanguage) async {
    if (!isAvailable) return null;
    try {
      _ensureModel();
      final prompt =
          'Translate the following text to $targetLanguage. Return only the translated text, nothing else:\n\n"$text"';
      final response = await _model!
          .generateContent([Content.text(prompt)]).timeout(
        const Duration(seconds: 10),
      );
      return response.text?.trim();
    } catch (e) {
      debugPrint('[GeminiService] translateText error: $e');
      return null;
    }
  }

  // ─── Context Management ───────────────────────────────────

  /// Clear rolling context (e.g., when switching chat rooms).
  void clearContext() {
    _rollingContext.clear();
    _chatSession = null;
    if (_model != null) {
      _chatSession = _model!.startChat(history: []);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void dispose() {
    _rollingContext.clear();
    _chatSession = null;
    _model = null;
  }
}
