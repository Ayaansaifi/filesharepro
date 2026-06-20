import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/file_utils.dart';
import '../models/chat_message.dart';
import '../../transfer/services/webrtc_service.dart';
import '../../transfer/services/signaling_service.dart';
import 'chat_encryption_service.dart';

/// P2P WhatsApp-style chat — SharedPreferences + disk files only (zero database).
class ChatService {
  static const String _chatRoomsKey = 'chat_rooms';
  static const int _maxMessagesPerRoom = 500;

  final WebRTCService _webrtc = WebRTCService();
  final SignalingService _signaling = SignalingService();
  final ChatEncryptionService _encryption;

  ChatService(this._encryption) {
    _webrtc.setEncryptionService(_encryption);
  }

  ValueChanged<ChatMessage>? onMessageReceived;
  ValueChanged<String>? onStatusChange;
  ValueChanged<String>? onError;
  ValueChanged<bool>? onConnectionChange;
  ValueChanged<double>? onTransferProgress;
  ValueChanged<bool>? onTypingChange;

  String? _activeRoomCode;
  bool _isConnected = false;
  String? _lastAnswerLink;
  DateTime? _lastTypingSent;

  bool get isConnected => _isConnected;
  String? get activeRoomCode => _activeRoomCode;
  String? get lastAnswerLink => _lastAnswerLink;
  SignalingService get signaling => _signaling;

  void _setSessionKeyForRoom(String roomCode) {
    _encryption.setSessionKey(
      ChatEncryptionService.deriveSessionKeyFromRoom(roomCode),
    );
  }

  Future<List<ChatRoom>> getChatRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_chatRoomsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveChatRoom(ChatRoom room) async {
    final rooms = await getChatRooms();
    final index = rooms.indexWhere((r) => r.roomCode == room.roomCode);
    if (index >= 0) {
      rooms[index] = room;
    } else {
      rooms.insert(0, room);
    }
    await _saveAllRooms(rooms);
  }

  Future<void> deleteChatRoom(String roomCode) async {
    final rooms = await getChatRooms();
    rooms.removeWhere((r) => r.roomCode == roomCode);
    await _saveAllRooms(rooms);
  }

  Future<void> _saveAllRooms(List<ChatRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(rooms.map((r) => r.toJson()).toList());
    await prefs.setString(_chatRoomsKey, jsonStr);
  }

  /// Host creates room — share link, then paste joiner's answer link back.
  Future<String?> createRoom(String deviceName) async {
    final roomCode = _signaling.generateRoomCode();
    _activeRoomCode = roomCode;
    _lastAnswerLink = null;
    _setSessionKeyForRoom(roomCode);
    _setupWebRTCCallbacks();

    final offer = await _webrtc.createOffer();
    if (offer == null) return null;

    final signalData = _signaling.packageSignalData(type: 'offer', sdp: offer);
    await _signaling.storeSignalData(roomCode, signalData);

    await saveChatRoom(ChatRoom(
      roomCode: roomCode,
      peerName: deviceName,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      messages: [],
      isActive: true,
    ));

    onStatusChange?.call('Room created — share link with friend');
    return roomCode;
  }

  /// Joiner pastes host link — returns answer link to send back to host.
  Future<bool> joinRoom(String roomCode, String deviceName) async {
    _activeRoomCode = roomCode;
    _lastAnswerLink = null;
    _setSessionKeyForRoom(roomCode);
    _setupWebRTCCallbacks();

    final signalData = await _signaling.getSignalData(roomCode);
    if (signalData == null) {
      onError?.call('Connection data missing — paste full host link');
      return false;
    }

    final unpacked = _signaling.unpackageSignalData(signalData);
    if (unpacked == null || unpacked['type'] != 'offer') {
      onError?.call('Invalid host connection data');
      return false;
    }

    final answer = await _webrtc.createAnswer(unpacked['sdp']);
    if (answer == null) return false;

    final answerData = _signaling.packageSignalData(type: 'answer', sdp: answer);
    _lastAnswerLink = _signaling.generateQrContent(
      roomCode: roomCode,
      signalData: answerData,
    );

    await saveChatRoom(ChatRoom(
      roomCode: roomCode,
      peerName: deviceName,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      messages: [],
      isActive: true,
    ));

    onStatusChange?.call('Connected — share answer link with host if needed');
    return true;
  }

  /// Host pastes joiner's answer link (completes WebRTC handshake).
  Future<bool> applyReceiverAnswer(String link) async {
    final parsed = _signaling.parseQrContent(link.trim());
    if (parsed == null || parsed['signalData']?.isEmpty != false) {
      onError?.call('Invalid answer link');
      return false;
    }

    final unpacked = _signaling.unpackageSignalData(parsed['signalData']!);
    if (unpacked == null || unpacked['type'] != 'answer') {
      onError?.call('Answer data invalid');
      return false;
    }

    await _webrtc.setRemoteAnswer(unpacked['sdp']);
    onStatusChange?.call('Peer connected!');
    return true;
  }

  void _setupWebRTCCallbacks() {
    _webrtc.onConnectionStateChange = (connected) {
      _isConnected = connected;
      onConnectionChange?.call(connected);
      onStatusChange?.call(connected ? 'Online' : 'Offline');
    };

    _webrtc.onError = onError;
    _webrtc.onStatusChange = onStatusChange;
    _webrtc.onTransferProgress = onTransferProgress;

    _webrtc.onTransferComplete = (fileName) async {
      final receivedDir = await FileUtils.getReceivedDir();
      File? sourceFile;
      final direct = File('${receivedDir.path}/$fileName');
      if (await direct.exists()) {
        sourceFile = direct;
      } else {
        if (await receivedDir.exists()) {
          for (final f in receivedDir.listSync().whereType<File>()) {
            if (f.path.split(Platform.pathSeparator).last == fileName) {
              sourceFile = f;
              break;
            }
          }
        }
      }

      final chatDir = await _getChatFilesDir();
      String finalPath = '${chatDir.path}/$fileName';
      int fileSize = 0;

      if (sourceFile != null && await sourceFile.exists()) {
        finalPath = await FileUtils.uniqueFilePath(chatDir.path, fileName);
        await sourceFile.copy(finalPath);
        fileSize = await File(finalPath).length();
      }

      final msgType = _messageTypeForFile(fileName);
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: msgType,
        fileName: fileName,
        fileExtension: FileUtils.getExtension(fileName),
        fileSize: fileSize,
        filePath: finalPath,
        direction: MessageDirection.received,
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
      );

      onMessageReceived?.call(message);
      if (_activeRoomCode != null) {
        await _addMessageToRoom(_activeRoomCode!, message);
      }
    };

    _webrtc.onTextMessageReceived = (text) {
      if (text.startsWith('TEXT:')) {
        final content = text.substring(5);
        final message = ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.text,
          direction: MessageDirection.received,
          status: MessageStatus.delivered,
          timestamp: DateTime.now(),
          textContent: content,
        );
        onMessageReceived?.call(message);
        if (_activeRoomCode != null) {
          _addMessageToRoom(_activeRoomCode!, message);
        }
      } else if (text.startsWith('READ:')) {
        final msgId = text.substring(5);
        _markMessageRead(msgId);
      } else if (text.startsWith('TYPING:')) {
        onTypingChange?.call(text.substring(7) == 'true');
      }
    };
  }

  MessageType _messageTypeForFile(String name) {
    if (FileUtils.isImage(name)) return MessageType.image;
    if (FileUtils.isVideo(name)) return MessageType.video;
    final ext = FileUtils.getExtension(name);
    if (['.mp3', '.wav', '.aac', '.m4a', '.ogg'].contains(ext)) {
      return MessageType.voice;
    }
    return MessageType.file;
  }

  Future<void> _markMessageRead(String messageId) async {
    if (_activeRoomCode == null) return;
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == _activeRoomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    final updated = room.messages.map((m) {
      if (m.id == messageId) return m.copyWith(status: MessageStatus.read);
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
  }

  Future<void> markRoomAsRead(String roomCode) async {
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    final updated = room.messages.map((m) {
      if (m.direction == MessageDirection.received &&
          m.status != MessageStatus.read) {
        if (_isConnected) {
          _webrtc.sendTextMessage('READ:${m.id}');
        }
        return m.copyWith(status: MessageStatus.read);
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
  }

  Future<ChatMessage?> sendFile(File file) async {
    if (!_isConnected) {
      onError?.call('Not connected — share answer link if host');
      return null;
    }

    final fileName = FileUtils.getFileName(file.path);
    final fileSize = await file.length();
    final msgType = _messageTypeForFile(fileName);

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: msgType,
      fileName: fileName,
      fileExtension: FileUtils.getExtension(fileName),
      fileSize: fileSize,
      filePath: file.path,
      direction: MessageDirection.sent,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
    );

    final chatDir = await _getChatFilesDir();
    final chatFile = await file.copy(
      await FileUtils.uniqueFilePath(chatDir.path, fileName),
    );

    final success = await _webrtc.sendFile(chatFile);
    final updated = message.copyWith(
      status: success ? MessageStatus.sent : MessageStatus.failed,
      filePath: chatFile.path,
    );

    if (_activeRoomCode != null) {
      await _addMessageToRoom(_activeRoomCode!, updated);
    }
    return updated;
  }

  Future<ChatMessage?> sendTextMessage(String text) async {
    if (!_isConnected) {
      onError?.call('Not connected');
      return null;
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MessageType.text,
      direction: MessageDirection.sent,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      textContent: text,
    );

    final success = _webrtc.sendTextMessage('TEXT:$text');
    final updated = message.copyWith(
      status: success ? MessageStatus.sent : MessageStatus.failed,
    );

    if (_activeRoomCode != null) {
      await _addMessageToRoom(_activeRoomCode!, updated);
    }
    return updated;
  }

  Future<void> sendTypingStatus(bool isTyping) async {
    if (!_isConnected) return;
    final now = DateTime.now();
    if (_lastTypingSent != null &&
        now.difference(_lastTypingSent!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastTypingSent = now;
    _webrtc.sendTextMessage('TYPING:$isTyping');
  }

  Future<Directory> _getChatFilesDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Documents/FileSharePro/Chat');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final dir = await getApplicationDocumentsDirectory();
    final chatDir = Directory('${dir.path}/chat_files');
    if (!await chatDir.exists()) await chatDir.create(recursive: true);
    return chatDir;
  }

  Future<void> _addMessageToRoom(String roomCode, ChatMessage message) async {
    final rooms = await getChatRooms();
    final index = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (index < 0) return;

    final room = rooms[index];
    var messages = [...room.messages, message];
    if (messages.length > _maxMessagesPerRoom) {
      messages = messages.sublist(messages.length - _maxMessagesPerRoom);
    }

    rooms[index] = room.copyWith(
      messages: messages,
      lastActivity: DateTime.now(),
    );
    await _saveAllRooms(rooms);
  }

  Future<List<ChatMessage>> getRoomMessages(String roomCode) async {
    final rooms = await getChatRooms();
    return rooms.where((r) => r.roomCode == roomCode).firstOrNull?.messages ??
        [];
  }

  Future<void> reconnectRoom(String roomCode) async {
    _activeRoomCode = roomCode;
    _setSessionKeyForRoom(roomCode);
    _setupWebRTCCallbacks();
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _activeRoomCode = null;
    await _webrtc.dispose();
  }

  Future<void> dispose() async {
    await disconnect();
    await _signaling.cleanupExpiredSignals();
  }
}
