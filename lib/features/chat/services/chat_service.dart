import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/services/local_network_service.dart';
import '../models/chat_message.dart';
import 'chat_encryption_service.dart';
import '../../../core/services/webrtc_service.dart';
import '../../../core/services/signaling_service.dart';

class ChatService {
  static const String _chatRoomsKey = 'chat_rooms';
  static const int _maxMessagesPerRoom = 500;

  final LocalNetworkService _networkService;
  final WebRtcService _webRtcService;
  final ChatEncryptionService _encryption;
  final SignalingService _signalingService;

  ChatService(this._networkService, this._webRtcService, this._encryption, this._signalingService) {
    _networkService.onIncomingConnection = _handleIncomingConnection;
    _webRtcService.onTextMessage = _handleWebRtcText;
    _webRtcService.onBinaryMessage = _handleWebRtcBinary;
    _webRtcService.onConnectionStateChanged = _handleWebRtcState;
  }

  void _handleWebRtcState(WebRtcConnectionState state) {
    if (state == WebRtcConnectionState.connected) {
      _isConnected = true;

      // For a passive (callee) connection we never set _activeRoomCode in
      // connectTo(), so incoming messages would be dropped. Recover the peer's
      // id from the WebRTC layer and treat it as the active room.
      final remoteId = _webRtcService.remotePeerId;
      if ((_activeRoomCode == null || _activeRoomCode!.isEmpty) &&
          remoteId != null &&
          remoteId.isNotEmpty) {
        _activeRoomCode = remoteId;
        // Use the symmetric peer-pair key so caller and callee agree.
        _setSessionKeyForPeerPair(remoteId);
        // Ensure a room exists for this peer so messages can be persisted.
        _ensureRoomForPeer(remoteId);
      }

      onConnectionChange?.call(true);
      onStatusChange?.call('Connected globally');
      // A successful internet connection means the peer is reachable by their
      // phone number. Record the pairing so they show up in the contacts list
      // next time. The active room code IS the peer's phone-number peerId.
      _maybeNotifyPaired();
    } else if (state == WebRtcConnectionState.disconnected || state == WebRtcConnectionState.failed) {
      _isConnected = false;
      onConnectionChange?.call(false);
      onStatusChange?.call('Disconnected globally');
    }
  }

  /// Make sure a chat room row exists for an incoming peer so that messages
  /// received on a passive connection can be stored.
  Future<void> _ensureRoomForPeer(String peerId) async {
    try {
      final rooms = await getChatRooms();
      final exists = rooms.any((r) => r.roomCode == peerId);
      if (!exists) {
        await saveChatRoom(ChatRoom(
          roomCode: peerId,
          peerName: peerId,
          createdAt: DateTime.now(),
          lastActivity: DateTime.now(),
          messages: const [],
          isActive: true,
        ));
      }
    } catch (_) {}
  }

  /// Notify listeners that the currently connected peer (identified by their
  /// phone-number peerId) is now a reachable contact. Only fires for
  /// phone-number-based rooms (all digits) so local/TCP sessions are ignored.
  void _maybeNotifyPaired() {
    final peerId = _activeRoomCode;
    if (peerId == null || peerId.isEmpty) return;
    final isPhoneId = RegExp(r'^\d{7,}$').hasMatch(peerId);
    if (isPhoneId) {
      onPeerPaired?.call(peerId);
    }
  }

  void _handleWebRtcText(String text) {
    // The prefix (TEXT:/TYPING:/...) lives INSIDE the encrypted payload — see
    // _sendString, which encrypts the entire 'TEXT:...' string. So we must
    // decrypt the whole frame first, exactly like the TCP path (_handleFrame),
    // before any prefix matching can succeed. Without this every encrypted
    // WebRTC message silently failed prefix checks and was dropped.
    if (_encryption.isReady && text.contains(':')) {
      try {
        text = _encryption.decryptMessage(text);
      } catch (_) {
        // Decryption failed — leave text as-is so unencrypted control frames
        // (if any) still route correctly.
      }
    }

    // Basic text routing, similar to local socket routing
    if (text.startsWith('TYPING:')) {
      final isTyping = text.split(':')[1] == 'true';
      onTypingChange?.call(isTyping);
    } else if (text.startsWith('TEXT:')) {
      // Already decrypted above — the payload is plain text now.
      final content = text.substring(5);
      _handleText(content);
    } else if (text.startsWith('READ:')) {
      final msgId = text.substring(5);
      _markMessageRead(msgId);
    } else if (text.startsWith('DELIVERED:')) {
      final msgId = text.substring(10);
      _markMessageDelivered(msgId);
    } else if (text.startsWith('DELETE:')) {
      // Delete for everyone signal from peer
      final msgId = text.substring(7);
      _markMessageDeleted(msgId);
    } else if (text.startsWith('REPLY:')) {
      // REPLY:originalMsgId:originalSender:originalText:::replyText
      final remaining = text.substring(6);
      final sepIdx = remaining.indexOf(':::');
      if (sepIdx > 0) {
        final meta = remaining.substring(0, sepIdx).split(':');
        final replyText = remaining.substring(sepIdx + 3);
        if (meta.length >= 3) {
          _handleText(replyText, replyToId: meta[0], replyToText: meta[2], replyToSender: meta[1]);
          return;
        }
      }
      _handleText(text);
    } else if (text.startsWith('FILE:')) {
      // Header: FILE:filename:size
      final parts = text.split(':');
      if (parts.length >= 3) {
        _isReceivingFile = true;
        _receivingFileName = parts[1];
        _receivingFileSize = int.tryParse(parts[2]) ?? 0;
        _receivedBytes = 0;
        onStatusChange?.call('Receiving file...');
        _setupWebRtcReceiveFile();
      }
    } else if (text.startsWith('PRESENCE:')) {
      final status = text.substring(9);
      onPresenceChange?.call(status == 'online');
    }
  }

  Future<void> _setupWebRtcReceiveFile() async {
    final chatDir = await _getChatFilesDir();
    _receiveTempFile = File('${chatDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.tmp');
    _receiveSink = _receiveTempFile!.openWrite();
  }

  void _handleWebRtcBinary(Uint8List data) {
    if (_isReceivingFile) {
      _handleFileChunk(data);
      if (_receivedBytes >= _receivingFileSize) {
        _finishReceiving();
      }
    }
  }

  ValueChanged<ChatMessage>? onMessageReceived;
  ValueChanged<String>? onStatusChange;
  ValueChanged<String>? onError;
  ValueChanged<bool>? onConnectionChange;
  ValueChanged<bool>? onPresenceChange;
  ValueChanged<double>? onTransferProgress;
  ValueChanged<bool>? onTypingChange;
  // Notify when a message is updated (deleted/starred/delivered)
  ValueChanged<ChatMessage>? onMessageUpdated;
  // Notify when a peer has been reached over the internet — so the caller can
  // persist the contact as "paired" for quick access later. Carries the peer's
  // phone-number peerId.
  ValueChanged<String>? onPeerPaired;

  String? _activeRoomCode; // Now acts as the device ID or IP we are connected to
  bool _isConnected = false;
  Socket? _socket;
  StreamSubscription? _socketSubscription;

  /// Our own signaling identity (normalized phone number, or uniqueId for
  /// legacy/local-only profiles). Used so we subscribe to OUR topic when
  /// ensuring signaling is connected — never the peer's.
  String? _ownPeerId;

  /// Set our own peer identity. Called once the profile is loaded.
  /// `peerId` should be `profile.peerId` (phone number if available).
  void setOwnPeerId(String peerId) {
    _ownPeerId = peerId;
  }

  // Receiving state
  bool _isReceivingFile = false;
  String? _receivingFileName;
  int _receivingFileSize = 0;
  int _receivedBytes = 0;
  IOSink? _receiveSink;
  File? _receiveTempFile;

  bool get isConnected => _isConnected;
  String? get activeRoomCode => _activeRoomCode;

  void _setSessionKeyForRoom(String roomCode) {
    _encryption.setSessionKey(
      ChatEncryptionService.deriveSessionKeyFromRoom(roomCode),
    );
  }

  /// Derive the E2E session key from BOTH peer ids so the caller and callee
  /// land on the same key. `myId` is our own peer id (phone number); `peerId`
  /// is the room code we're connected to. Falls back to the legacy single-id
  /// derivation if our own id isn't known yet (e.g. very early boot).
  void _setSessionKeyForPeerPair(String peerId) {
    final myId = _ownPeerId;
    if (myId != null && myId.isNotEmpty) {
      _encryption.setSessionKey(
        ChatEncryptionService.deriveSessionKeyForPeers(myId, peerId),
      );
    } else {
      _setSessionKeyForRoom(peerId);
    }
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
        ..sort((a, b) {
          // Pinned first, then by lastActivity
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.lastActivity.compareTo(a.lastActivity);
        });
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

  /// Clear all messages in a room but keep the room itself
  Future<void> clearRoomMessages(String roomCode) async {
    final rooms = await getChatRooms();
    final index = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (index < 0) return;

    // Add a system message indicating chat was cleared
    final systemMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MessageType.system,
      direction: MessageDirection.received,
      status: MessageStatus.delivered,
      timestamp: DateTime.now(),
      textContent: '🔒 Messages and calls are end-to-end encrypted. No one outside this chat can ever read them.',
    );

    rooms[index] = rooms[index].copyWith(
      messages: [systemMessage],
      lastActivity: DateTime.now(),
    );
    await _saveAllRooms(rooms);
  }

  /// Toggle mute on a room
  Future<void> toggleMuteRoom(String roomCode, bool mute) async {
    final rooms = await getChatRooms();
    final index = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (index < 0) return;
    rooms[index] = rooms[index].copyWith(isMuted: mute);
    await _saveAllRooms(rooms);
  }

  /// Toggle pin on a room
  Future<void> togglePinRoom(String roomCode, bool pin) async {
    final rooms = await getChatRooms();
    final index = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (index < 0) return;
    rooms[index] = rooms[index].copyWith(isPinned: pin);
    await _saveAllRooms(rooms);
  }

  Future<void> _saveAllRooms(List<ChatRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(rooms.map((r) => r.toJson()).toList());
    await prefs.setString(_chatRoomsKey, jsonStr);
  }

  // ─── Connection Methods ─────────────────────────────────────

  /// Connect to a discovered device (IP address) or a contact (global WebRTC).
  Future<bool> connectTo(String ip, String deviceId, String deviceName) async {
    _activeRoomCode = deviceId;
    // Use the symmetric peer-pair key so caller and callee agree.
    _setSessionKeyForPeerPair(deviceId);

    onStatusChange?.call('Connecting...');

    if (ip.isEmpty || ip == 'global') {
      // Global Internet Connection via WebRTC + MQTT Signaling
      try {
        // Ensure signaling is connected to OUR OWN topic (so we can receive
        // offers/answers from the peer). Never subscribe to the peer's topic.
        if (!_webRtcIsCaller) {
          final myId = _ownPeerId ?? deviceId;
          final signalingConnected = await _ensureSignalingConnected(myId);
          if (!signalingConnected) {
            onStatusChange?.call('Waiting for signaling server…');
            // Don't return false — signaling may still be connecting;
            // proceed with WebRTC and let callbacks handle state.
          }
        }
        _webRtcIsCaller = true;
        // Target the peer: deviceId is the contact's normalized phone number.
        await _webRtcService.connectTo(deviceId);
        // Connection completes asynchronously via _handleWebRtcState.
      } catch (e) {
        onError?.call('Failed to initiate global connection: $e');
        return false;
      }
    } else {
      // Local Network Connection via TCP
      final socket = await _networkService.connectTo(ip);
      if (socket == null) {
        onError?.call('Failed to connect locally.');
        return false;
      }
      await _setupSocket(socket);
    }

    await saveChatRoom(ChatRoom(
      roomCode: deviceId,
      peerName: deviceName,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
      messages: [],
      isActive: true,
    ));

    return true;
  }

  bool _webRtcIsCaller = false;

  /// Make sure the MQTT signaling broker is connected before we try WebRTC.
  /// Returns true if already connected or successfully connected.
  Future<bool> _ensureSignalingConnected(String myDeviceId) async {
    try {
      if (!_signalingService.isConnected) {
        await _signalingService.connect(myDeviceId);
        // Wait briefly for the broker handshake to complete.
        await Future.delayed(const Duration(seconds: 2));
      }
      return _signalingService.isConnected;
    } catch (e) {
      debugPrint('Signaling connect failed: $e');
      return false;
    }
  }

  void _handleIncomingConnection(Socket socket) {
    // If we accept incoming, we just set it up.
    _setupSocket(socket);
  }

  Future<void> _setupSocket(Socket socket) async {
    _socket = socket;
    _isConnected = true;
    onConnectionChange?.call(true);
    onStatusChange?.call('Online');

    _socketSubscription = LocalNetworkService.frameStream(socket).listen(
      _handleFrame,
      onError: (err) {
        _handleDisconnect();
      },
      onDone: () {
        _handleDisconnect();
      },
    );
  }

  void _handleDisconnect() {
    _isConnected = false;
    _socket = null;
    _socketSubscription?.cancel();
    onConnectionChange?.call(false);
    onStatusChange?.call('Offline');
  }

  // ─── Frame Handling ─────────────────────────────────────────

  void _handleFrame(Uint8List frame) async {
    if (_isReceivingFile) {
      _handleFileChunk(frame);
      return;
    }

    try {
      String text = utf8.decode(frame);
      if (_encryption.isReady && text.contains(':')) {
        try {
          text = _encryption.decryptMessage(text);
        } catch (_) {}
      }

      if (text.startsWith('HEADER:')) {
        final parts = text.split(':');
        if (parts.length >= 3) {
          _receivingFileName = parts.sublist(1, parts.length - 1).join(':');
          _receivingFileSize = int.tryParse(parts.last) ?? 0;
          _receivedBytes = 0;
          _isReceivingFile = true;
          await _startReceiveToDisk();
          onStatusChange?.call('Receiving: $_receivingFileName');
        }
      } else if (text.startsWith('DONE:')) {
        await _finishReceiving();
      } else if (text.startsWith('TEXT:')) {
        _handleText(text.substring(5));
      } else if (text.startsWith('REPLY:')) {
        // REPLY:originalMsgId:originalSender:originalText:::replyText
        final remaining = text.substring(6);
        final sepIdx = remaining.indexOf(':::');
        if (sepIdx > 0) {
          final meta = remaining.substring(0, sepIdx).split(':');
          final replyText = remaining.substring(sepIdx + 3);
          if (meta.length >= 3) {
            _handleText(replyText, replyToId: meta[0], replyToText: meta[2], replyToSender: meta[1]);
            return;
          }
        }
        _handleText(text);
      } else if (text.startsWith('READ:')) {
        _markMessageRead(text.substring(5));
      } else if (text.startsWith('DELIVERED:')) {
        _markMessageDelivered(text.substring(10));
      } else if (text.startsWith('DELETE:')) {
        _markMessageDeleted(text.substring(7));
      } else if (text.startsWith('TYPING:')) {
        onTypingChange?.call(text.substring(7) == 'true');
      } else if (text.startsWith('PRESENCE:')) {
        final status = text.substring(9);
        onPresenceChange?.call(status == 'online');
      }
    } catch (_) {
      // Might be binary data that we didn't expect, ignore.
    }
  }

  Future<void> _startReceiveToDisk() async {
    final downloadDir = await FileUtils.getReceivedDir();
    final safeName = FileUtils.sanitizeFileName(_receivingFileName ?? 'file');
    final path = await FileUtils.uniqueFilePath(downloadDir.path, safeName);
    _receiveTempFile = File(path);
    _receiveSink = _receiveTempFile!.openWrite();
  }

  void _handleFileChunk(Uint8List chunk) {
    _receiveSink?.add(chunk);
    _receivedBytes += chunk.length;
    onTransferProgress?.call(_receivedBytes / (_receivingFileSize == 0 ? 1 : _receivingFileSize));
  }

  Future<void> _finishReceiving() async {
    _isReceivingFile = false;
    await _receiveSink?.flush();
    await _receiveSink?.close();
    _receiveSink = null;

    if (_receiveTempFile != null && await _receiveTempFile!.exists()) {
      final fileName = _receivingFileName ?? 'file';
      final fileSize = await _receiveTempFile!.length();

      final chatDir = await _getChatFilesDir();
      final finalPath = await FileUtils.uniqueFilePath(chatDir.path, fileName);
      await _receiveTempFile!.copy(finalPath);

      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      final message = ChatMessage(
        id: msgId,
        type: _messageTypeForFile(fileName),
        fileName: fileName,
        fileExtension: FileUtils.getExtension(fileName),
        fileSize: fileSize,
        filePath: finalPath,
        direction: MessageDirection.received,
        status: MessageStatus.delivered,
        timestamp: DateTime.now(),
      );

      onMessageReceived?.call(message);
      // Persist to the active room, falling back to the connected WebRTC peer
      // id for passive receivers (see _handleText).
      final room = _activeRoomCode ?? _webRtcService.remotePeerId;
      if (room != null) {
        await _addMessageToRoom(room, message);
      }
      // Send back a delivered receipt
      _sendString('DELIVERED:$msgId');
      onStatusChange?.call('File received');
    }
  }

  void _handleText(String content, {String? replyToId, String? replyToText, String? replyToSender}) {
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = ChatMessage(
      id: msgId,
      type: MessageType.text,
      direction: MessageDirection.received,
      status: MessageStatus.delivered,
      timestamp: DateTime.now(),
      textContent: content,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
    );
    onMessageReceived?.call(message);
    // Persist to the active room. Fall back to the connected WebRTC peer id in
    // case this is a passive receiver where _activeRoomCode isn't set yet.
    final room = _activeRoomCode ?? _webRtcService.remotePeerId;
    if (room != null) {
      _addMessageToRoom(room, message);
    }
    // Send back a delivered receipt
    _sendString('DELIVERED:$msgId');
  }

  // ─── Sending ────────────────────────────────────────────────

  bool _sendString(String message) {
    if (!_isConnected) return false;
    try {
      final textToSend = _encryption.isReady ? _encryption.encryptMessage(message) : message;
      if (_socket != null) {
        LocalNetworkService.sendFrame(_socket!, Uint8List.fromList(utf8.encode(textToSend)));
      } else {
        _webRtcService.sendText(textToSend);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ChatMessage?> sendTextMessage(String text, {String? replyToId, String? replyToText, String? replyToSender}) async {
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
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
    );

    bool success = false;
    if (replyToId != null && replyToText != null) {
      // Send reply format: REPLY:originalMsgId:originalSender:originalText:::replyText
      final sender = replyToSender ?? '';
      success = _sendString('REPLY:$replyToId:$sender:$replyToText:::$text');
    } else {
      success = _sendString('TEXT:$text');
    }

    final updated = message.copyWith(
      status: success ? MessageStatus.sent : MessageStatus.failed,
    );

    if (_activeRoomCode != null) {
      await _addMessageToRoom(_activeRoomCode!, updated);
    }
    return updated;
  }

  Future<ChatMessage?> sendFile(File file) async {
    if (!_isConnected) {
      onError?.call('Not connected');
      return null;
    }

    final fileName = FileUtils.getFileName(file.path);
    final fileSize = await file.length();

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _messageTypeForFile(fileName),
      fileName: fileName,
      fileExtension: FileUtils.getExtension(fileName),
      fileSize: fileSize,
      filePath: file.path,
      direction: MessageDirection.sent,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
    );

    try {
      _sendString('HEADER:$fileName:$fileSize');

      int sent = 0;
      final raf = await file.open();
      const chunkSize = 65536;

      while (sent < fileSize) {
        final remaining = fileSize - sent;
        final readSize = remaining < chunkSize ? remaining : chunkSize;
        final chunk = await raf.read(readSize);
        if (_socket != null) {
          LocalNetworkService.sendFrame(_socket!, chunk);
        } else {
          _webRtcService.sendBinary(Uint8List.fromList(chunk));
        }
        sent += chunk.length;
        onTransferProgress?.call(sent / fileSize);
        await Future.delayed(const Duration(milliseconds: 1)); // Small delay to prevent overwhelming
      }
      await raf.close();

      _sendString('DONE:$fileName');

      final updated = message.copyWith(status: MessageStatus.sent);
      if (_activeRoomCode != null) {
        await _addMessageToRoom(_activeRoomCode!, updated);
      }
      return updated;
    } catch (e) {
      final updated = message.copyWith(status: MessageStatus.failed);
      if (_activeRoomCode != null) {
        await _addMessageToRoom(_activeRoomCode!, updated);
      }
      return updated;
    }
  }

  /// Forward a message to the active room
  Future<ChatMessage?> forwardMessage(ChatMessage original) async {
    if (!_isConnected) {
      onError?.call('Not connected');
      return null;
    }

    if (original.type == MessageType.text && original.textContent != null) {
      // For text, resend as forwarded text
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: MessageType.text,
        direction: MessageDirection.sent,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        textContent: original.textContent,
        isForwarded: true,
      );
      final success = _sendString('TEXT:${original.textContent}');
      final updated = message.copyWith(status: success ? MessageStatus.sent : MessageStatus.failed);
      if (_activeRoomCode != null) {
        await _addMessageToRoom(_activeRoomCode!, updated);
      }
      return updated;
    } else if (original.filePath != null && File(original.filePath!).existsSync()) {
      // For files, mark as forwarded and send the file
      final fileMessage = await sendFile(File(original.filePath!));
      // Could update isForwarded flag if needed
      return fileMessage;
    }
    return null;
  }

  Future<void> sendTypingStatus(bool isTyping) async {
    _sendString('TYPING:$isTyping');
  }

  /// Send our presence status (online/offline)
  void sendPresence(bool isOnline) {
    _sendString('PRESENCE:${isOnline ? 'online' : 'offline'}');
  }

  Future<void> markRoomAsRead(String roomCode) async {
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    final updated = room.messages.map((m) {
      if (m.direction == MessageDirection.received && m.status != MessageStatus.read) {
        if (_isConnected) {
          _sendString('READ:${m.id}');
        }
        return m.copyWith(status: MessageStatus.read);
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
  }

  Future<List<ChatMessage>> getRoomMessages(String roomCode) async {
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (idx < 0) return [];
    return rooms[idx].messages;
  }

  /// Mark a message as read (received a READ signal from peer)
  Future<void> _markMessageRead(String messageId) async {
    if (_activeRoomCode == null) return;
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == _activeRoomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    ChatMessage? updatedMsg;
    final updated = room.messages.map((m) {
      if (m.id == messageId) {
        updatedMsg = m.copyWith(status: MessageStatus.read);
        return updatedMsg!;
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
    if (updatedMsg != null) onMessageUpdated?.call(updatedMsg!);
  }

  /// Mark a message as delivered (received a DELIVERED signal from peer)
  Future<void> _markMessageDelivered(String messageId) async {
    if (_activeRoomCode == null) return;
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == _activeRoomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    ChatMessage? updatedMsg;
    final updated = room.messages.map((m) {
      if (m.id == messageId && m.status == MessageStatus.sent) {
        updatedMsg = m.copyWith(status: MessageStatus.delivered);
        return updatedMsg!;
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
    if (updatedMsg != null) onMessageUpdated?.call(updatedMsg!);
  }

  /// Mark a message as deleted (received a DELETE signal from peer — delete for everyone)
  Future<void> _markMessageDeleted(String messageId) async {
    if (_activeRoomCode == null) return;
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == _activeRoomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    ChatMessage? updatedMsg;
    final updated = room.messages.map((m) {
      if (m.id == messageId) {
        updatedMsg = m.copyWith(isDeleted: true, type: MessageType.deleted, textContent: 'This message was deleted');
        return updatedMsg!;
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
    if (updatedMsg != null) onMessageUpdated?.call(updatedMsg!);
  }

  // ─── WhatsApp-style actions ───────────────────────────────

  /// Delete a message for me only (local removal)
  Future<void> deleteMessageForMe(String roomCode, String messageId) async {
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    final updated = room.messages.where((m) => m.id != messageId).toList();
    rooms[idx] = room.copyWith(messages: updated, lastActivity: DateTime.now());
    await _saveAllRooms(rooms);
  }

  /// Delete a message for everyone (local + send signal to peer)
  Future<void> deleteMessageForEveryone(String roomCode, String messageId) async {
    // Send delete signal to peer
    if (_isConnected) {
      _sendString('DELETE:$messageId');
    }
    // Mark locally as deleted
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    final updated = room.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(isDeleted: true, type: MessageType.deleted, textContent: 'This message was deleted');
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated, lastActivity: DateTime.now());
    await _saveAllRooms(rooms);
  }

  /// Toggle starred status on a message
  Future<void> toggleStarMessage(String roomCode, String messageId) async {
    final rooms = await getChatRooms();
    final idx = rooms.indexWhere((r) => r.roomCode == roomCode);
    if (idx < 0) return;
    final room = rooms[idx];
    ChatMessage? updatedMsg;
    final updated = room.messages.map((m) {
      if (m.id == messageId) {
        updatedMsg = m.copyWith(isStarred: !m.isStarred);
        return updatedMsg!;
      }
      return m;
    }).toList();
    rooms[idx] = room.copyWith(messages: updated);
    await _saveAllRooms(rooms);
    if (updatedMsg != null) onMessageUpdated?.call(updatedMsg!);
  }

  /// Get all starred messages across all rooms
  Future<List<MapEntry<String, ChatMessage>>> getStarredMessages() async {
    final rooms = await getChatRooms();
    final starred = <MapEntry<String, ChatMessage>>[];
    for (final room in rooms) {
      for (final msg in room.messages) {
        if (msg.isStarred && !msg.isDeleted) {
          starred.add(MapEntry(room.peerName, msg));
        }
      }
    }
    return starred;
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

  MessageType _messageTypeForFile(String name) {
    if (FileUtils.isImage(name)) return MessageType.image;
    if (FileUtils.isVideo(name)) return MessageType.video;
    final ext = FileUtils.getExtension(name);
    if (['.mp3', '.wav', '.aac', '.m4a', '.ogg'].contains(ext)) {
      return MessageType.voice;
    }
    return MessageType.file;
  }

  Future<void> reconnectRoom(String roomCode) async {
    _activeRoomCode = roomCode;
    // Use the symmetric peer-pair key so caller and callee agree.
    _setSessionKeyForPeerPair(roomCode);

    // If we're already connected (e.g. active socket/WebRTC), nothing to do.
    if (_isConnected) return;

    // Internet-based chats use the room code (= peer's phone-number peerId) as
    // the WebRTC target, so we can re-establish the link automatically. Local
    // (TCP) chats require manual discovery and cannot be reconnected here.
    final isPhoneId = RegExp(r'^\d{7,}$').hasMatch(roomCode);
    if (!isPhoneId) return;

    onStatusChange?.call('Reconnecting...');

    try {
      // Reset the caller latch so signaling is ensured for a fresh connection.
      _webRtcIsCaller = false;
      final myId = _ownPeerId ?? roomCode;
      final signalingConnected = await _ensureSignalingConnected(myId);
      if (!signalingConnected) {
        onStatusChange?.call('Waiting for signaling server…');
        return;
      }
      _webRtcIsCaller = true;
      // Tear down any stale peer connection before opening a new one.
      _webRtcService.disconnect();
      await _webRtcService.connectTo(roomCode);
      // Connection state is reported asynchronously via _handleWebRtcState.
    } catch (e) {
      debugPrint('reconnectRoom failed: $e');
      onStatusChange?.call('Reconnect failed');
    }
  }

  Future<void> disconnect() async {
    sendPresence(false);
    _handleDisconnect();
    _activeRoomCode = null;
  }

  Future<void> dispose() async {
    await disconnect();
  }
}
