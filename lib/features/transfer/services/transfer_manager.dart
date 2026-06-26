import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/utils/encryption_util.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_network_service.dart';
import '../../chat/models/user_profile.dart';

class TransferManager {
  /// Accepts an external LocalNetworkService to avoid port conflicts.
  /// If null, creates its own instance (legacy fallback).
  final LocalNetworkService? _sharedNetworkService;
  late final LocalNetworkService _networkService;

  TransferMode _mode = TransferMode.nearby;
  TransferState _state = TransferState.idle;
  double _progress = 0.0;
  String _statusMessage = 'Ready';
  String? _errorMessage;

  List<File> _pendingFiles = [];
  String? _currentFileName;
  int _filesTransferred = 0;
  int _totalFiles = 0;

  bool _encryptionEnabled = false;
  String? _encryptionPin;
  String? _receiverDecryptPin;

  List<LocalDevice> _discoveredDevices = [];

  Socket? _activeSocket;
  StreamSubscription? _socketSubscription;

  // ─── WebRTC (long-distance) state ────────────────────────
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  String? _connectionLink; // offer link the sender shares
  String? _answerLink; // answer link the receiver sends back
  String? _roomCode;
  bool _isWebRtcCaller = false;

  TransferMode get mode => _mode;
  TransferState get state => _state;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get currentFileName => _currentFileName;
  int get filesSent => _filesTransferred;
  int get totalFiles => _totalFiles;
  bool get encryptionEnabled => _encryptionEnabled;
  List<LocalDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  String? get roomCode => _roomCode;
  String? get connectionLink => _connectionLink;
  String? get answerLink => _answerLink;

  VoidCallback? onStateChanged;

  /// Creates TransferManager with optional shared network service.
  /// Pass the same instance used by ChatService to avoid port conflicts.
  TransferManager({LocalNetworkService? sharedNetworkService})
      : _sharedNetworkService = sharedNetworkService {
    _networkService = _sharedNetworkService ?? LocalNetworkService();
    _networkService.onDevicesChanged = (devices) {
      _discoveredDevices = devices;
      onStateChanged?.call();
    };
  }

  void _updateState(TransferState newState, {String? message}) {
    _state = newState;
    if (message != null) _statusMessage = message;
    onStateChanged?.call();
  }

  void setMode(TransferMode mode) {
    _mode = mode;
    onStateChanged?.call();
  }

  void setEncryption({required bool enabled, String? pin}) {
    _encryptionEnabled = enabled;
    _encryptionPin = pin;
    onStateChanged?.call();
  }

  void setReceiverDecryptPin(String? pin) {
    _receiverDecryptPin = pin;
  }

  // ─── SENDER FLOW ─────────────────────────────────────────

  Future<void> startSending(List<File> files) async {
    if (files.isEmpty) {
      _updateState(TransferState.error, message: 'No files selected');
      return;
    }

    _pendingFiles = files;
    _totalFiles = files.length;
    _filesTransferred = 0;
    _errorMessage = null;

    _updateState(TransferState.waiting, message: 'Select a nearby device to send files');

    // SHAREit-style: auto-start discovery so nearby receivers populate
    // the list. The sender then picks one from the UI.
    // NOTE: we only broadcast/listen for discovery — we do NOT claim the
    // shared service's onIncomingConnection (that's the receiver's job),
    // so this won't clobber ChatService's incoming-connection handler.
    if (_mode == TransferMode.nearby) {
      await startSenderDiscovery();
    } else if (_mode == TransferMode.longDistance) {
      // Internet mode: build the shareable connection link (WebRTC offer).
      await createConnectionLink();
    }
  }

  Future<void> connectAndSend(LocalDevice device) async {
    _updateState(TransferState.connecting, message: 'Connecting to ${device.name}...');
    final socket = await _networkService.connectTo(device.ip);
    if (socket == null) {
      _updateState(TransferState.error, message: 'Failed to connect. Make sure receiver is ready and on same network.');
      return;
    }

    _activeSocket = socket;
    _updateState(TransferState.connected, message: 'Connected to ${device.name}');
    await Future.delayed(const Duration(milliseconds: 500));
    await _sendAllFiles();
  }

  Future<void> _sendAllFiles() async {
    _updateState(TransferState.transferring, message: 'Sending files...');

    for (int i = 0; i < _pendingFiles.length; i++) {
      _progress = 0;
      _currentFileName = _pendingFiles[i].path.split(Platform.pathSeparator).last;
      _statusMessage = 'Sending ${i + 1}/$_totalFiles: $_currentFileName';
      onStateChanged?.call();

      File fileToSend = _pendingFiles[i];

      if (!await fileToSend.exists()) {
        continue;
      }

      if (_encryptionEnabled && _encryptionPin != null) {
        _statusMessage = 'Encrypting: $_currentFileName';
        onStateChanged?.call();

        final encryptedFile = await EncryptionUtil.encryptFile(fileToSend, _encryptionPin!);
        if (encryptedFile == null) {
          _updateState(TransferState.error, message: 'Encryption failed for $_currentFileName');
          return;
        }
        fileToSend = encryptedFile;
      }

      final fileName = FileUtils.getFileName(fileToSend.path);
      final fileSize = await fileToSend.length();

      try {
        LocalNetworkService.sendFrame(_activeSocket!, Uint8List.fromList(utf8.encode('HEADER:$fileName:$fileSize')));

        int sent = 0;
        final raf = await fileToSend.open();
        const chunkSize = 65536;

        while (sent < fileSize) {
          final remaining = fileSize - sent;
          final readSize = remaining < chunkSize ? remaining : chunkSize;
          final chunk = await raf.read(readSize);
          LocalNetworkService.sendFrame(_activeSocket!, chunk);
          sent += chunk.length;
          _progress = sent / fileSize;
          onStateChanged?.call();
          await Future.delayed(const Duration(microseconds: 100));
        }
        await raf.close();

        LocalNetworkService.sendFrame(_activeSocket!, Uint8List.fromList(utf8.encode('DONE:$fileName')));
      } catch (e) {
        _updateState(TransferState.error, message: 'Failed to send: $_currentFileName');
        return;
      }

      _filesTransferred++;
      if (i < _pendingFiles.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    for (final f in _pendingFiles) {
      final name = f.path.split(Platform.pathSeparator).last;
      await _logTransfer(name, 'sent', 'nearby', size: await f.length());
    }

    _updateState(TransferState.completed, message: 'All $_totalFiles files sent!');
    _activeSocket?.destroy();
    _activeSocket = null;
  }

  // ─── SENDER DISCOVERY (SHAREit-style) ─────────────────────
  //
  // Lightweight discovery for the SENDER side: it only needs to see nearby
  // receivers, not accept incoming TCP connections. It deliberately does
  // NOT touch onIncomingConnection so it never overrides the receiver's
  // (or ChatService's) incoming-connection handler on the shared service.
  Future<void> startSenderDiscovery() async {
    _discoveredDevices.clear();
    _updateState(TransferState.waiting,
        message: 'Searching for nearby receivers…');

    final senderProfile = UserProfile(
      uniqueId: 'sender_${DateTime.now().millisecondsSinceEpoch}',
      displayName: 'Sender',
      createdAt: DateTime.now(),
    );
    await _networkService.startDiscovery(senderProfile);
  }

  // ─── RECEIVER FLOW ───────────────────────────────────────

  Future<void> startNearbyDiscovery() async {
    _discoveredDevices.clear();
    _updateState(TransferState.waiting, message: 'Ready to receive. Waiting for sender...');

    _networkService.onIncomingConnection = (socket) {
      _handleIncomingConnection(socket);
    };
    await _networkService.startTcpServer();

    // Also broadcast our presence for senders to find us
    final dummyProfile = UserProfile(uniqueId: 'receiver', displayName: 'Ready to Receive', createdAt: DateTime.now());
    await _networkService.startDiscovery(dummyProfile);
  }

  void startAdvertisingPresence(dynamic profile) {
    _networkService.startDiscovery(profile);
  }

  Future<void> _handleIncomingConnection(Socket socket) async {
    _activeSocket = socket;
    _filesTransferred = 0;
    _updateState(TransferState.transferring, message: 'Sender connected. Receiving files...');

    bool isReceivingFile = false;
    String? receivingFileName;
    int receivingFileSize = 0;
    int receivedBytes = 0;
    IOSink? receiveSink;
    File? receiveTempFile;

    _socketSubscription = LocalNetworkService.frameStream(socket).listen((frame) async {
      if (isReceivingFile) {
        receiveSink?.add(frame);
        receivedBytes += frame.length;
        _progress = receivedBytes / (receivingFileSize == 0 ? 1 : receivingFileSize);
        onStateChanged?.call();
        return;
      }

      try {
        final text = utf8.decode(frame);
        if (text.startsWith('HEADER:')) {
          final parts = text.split(':');
          if (parts.length >= 3) {
            receivingFileName = parts.sublist(1, parts.length - 1).join(':');
            receivingFileSize = int.tryParse(parts.last) ?? 0;
            receivedBytes = 0;
            isReceivingFile = true;

            final downloadDir = await FileUtils.getReceivedDir();
            final safeName = FileUtils.sanitizeFileName(receivingFileName ?? 'file');
            final path = await FileUtils.uniqueFilePath(downloadDir.path, safeName);
            receiveTempFile = File(path);
            receiveSink = receiveTempFile!.openWrite();

            _statusMessage = 'Receiving: $receivingFileName';
            onStateChanged?.call();
          }
        } else if (text.startsWith('DONE:')) {
          isReceivingFile = false;
          await receiveSink?.flush();
          await receiveSink?.close();
          receiveSink = null;

          _filesTransferred++;

          if (receiveTempFile != null && await receiveTempFile!.exists()) {
            await _handleReceivedFile(receiveTempFile!, receivingFileName ?? 'file');
          }

          _statusMessage = 'Received $_filesTransferred file(s)';
          onStateChanged?.call();
        }
      } catch (_) {}
    }, onDone: () {
      if (_filesTransferred > 0 && _state != TransferState.error) {
        _updateState(TransferState.completed, message: 'Received $_filesTransferred file(s)');
      } else if (_filesTransferred == 0) {
        _updateState(TransferState.error, message: 'Sender disconnected unexpectedly');
      }
    });
  }

  Future<void> _handleReceivedFile(File file, String originalName) async {
    _currentFileName = originalName;
    if (await _isEncryptedPayload(file)) {
      final pin = _receiverDecryptPin ?? _encryptionPin;
      if (pin != null) {
        final decrypted = await _decryptReceivedFile(file, pin);
        if (decrypted != null) {
          _currentFileName = FileUtils.getFileName(decrypted.path);
          await _logTransfer(_currentFileName!, 'received', 'nearby', size: await decrypted.length());
        }
      }
    } else {
      await _logTransfer(_currentFileName!, 'received', 'nearby', size: await file.length());
    }
  }

  Future<bool> _isEncryptedPayload(File file) async {
    if (file.path.contains(AppConstants.encryptedExtension)) return true;
    try {
      final raf = await file.open();
      final header = await raf.read(AppConstants.magicBytes.length);
      await raf.close();
      if (header.length < 4) return false;
      for (var i = 0; i < 4; i++) {
        if (header[i] != AppConstants.magicBytes[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<File?> _decryptReceivedFile(File encrypted, String pin) async {
    try {
      final bytes = await EncryptionUtil.decryptFile(encrypted, pin);
      if (bytes == null) return null;
      final dir = await FileUtils.getReceivedDir();
      var name = _currentFileName ?? 'file';
      if (name.endsWith(AppConstants.encryptedExtension)) {
        name = name.substring(0, name.length - AppConstants.encryptedExtension.length);
      }
      final outPath = await FileUtils.uniqueFilePath(dir.path, FileUtils.sanitizeFileName(name));
      final out = File(outPath);
      await out.writeAsBytes(bytes);
      try {
        await encrypted.delete();
      } catch (_) {}
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> _logTransfer(String fileName, String direction, String mode, {int size = 0}) async {
    // History logging disabled as service is missing
  }

  Future<void> cancel() async {
    _updateState(TransferState.idle, message: 'Cancelled');
    _progress = 0;
    _pendingFiles = [];
    _filesTransferred = 0;
    _totalFiles = 0;
    _errorMessage = null;
    _discoveredDevices.clear();

    _socketSubscription?.cancel();
    _activeSocket?.destroy();
    _activeSocket = null;

    await _disposeWebRtc();

    // Reset link state
    _connectionLink = null;
    _answerLink = null;
    _roomCode = null;

    // Only stop discovery if we own the network service
    if (_sharedNetworkService == null) {
      _networkService.stopDiscovery();
      _networkService.stopTcpServer();
    }
  }

  Future<void> dispose() async {
    await cancel();
    // Only dispose if we own the network service
    if (_sharedNetworkService == null) {
      _networkService.dispose();
    }
  }

  // ─── WEBRTC (LONG-DISTANCE) FLOW ─────────────────────────
  //
  // No signaling server needed: the full SDP offer (with gathered ICE
  // candidates) is packed into a base64 "connection link" that the sender
  // shares out-of-band (WhatsApp/SMS/QR). The receiver pastes it, creates
  // an answer (also fully packed) and shares it back. The sender pastes
  // the answer — the P2P data channel opens and files stream over it.
  // Works across any distance, anywhere on the internet, behind NAT,
  // using Google STUN + a public TURN relay for symmetric-NAT cases.

  Future<void> _disposeWebRtc() async {
    try {
      await _dataChannel?.close();
    } catch (_) {}
    try {
      await _peerConnection?.close();
    } catch (_) {}
    _dataChannel = null;
    _peerConnection = null;
    _isWebRtcCaller = false;
  }

  Map<String, dynamic> get _rtcConfig => {
        'iceServers': AppConstants.iceServers,
        'sdpSemantics': 'unified-plan',
      };

  /// SENDER (caller): create offer, gather ICE, pack into a shareable link.
  /// Call this after startSending() when mode == longDistance.
  Future<void> createConnectionLink() async {
    if (_pendingFiles.isEmpty) {
      _updateState(TransferState.error, message: 'No files to send');
      return;
    }
    _isWebRtcCaller = true;
    _updateState(TransferState.connecting,
        message: 'Creating connection link…');

    try {
      await _disposeWebRtc();
      _peerConnection = await createPeerConnection(_rtcConfig);

      // Reliable ordered data channel for file transfer.
      final dcInit = RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30;
      _dataChannel = await _peerConnection!
          .createDataChannel('file_transfer', dcInit);
      _setupDataChannel(_dataChannel!);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Wait until ICE gathering completes so all candidates are in the SDP.
      await _waitForIceGathering(_peerConnection!);

      final finalOffer = await _peerConnection!.getLocalDescription();
      _roomCode = _generateRoomCode();
      _connectionLink = _encodeSdp(
        sdp: finalOffer!.sdp ?? '',
        type: finalOffer.type ?? 'offer',
        roomCode: _roomCode!,
      );

      _updateState(TransferState.waiting,
          message: 'Share this link with the receiver, then paste their answer');
    } catch (e) {
      _updateState(TransferState.error,
          message: 'Failed to create link: $e');
    }
  }

  /// SENDER: paste the receiver's answer link to complete the handshake.
  Future<bool> applyReceiverAnswer(String link) async {
    if (_peerConnection == null) {
      _errorMessage = 'No active offer. Create the link first.';
      onStateChanged?.call();
      return false;
    }
    final decoded = _decodeSdp(link);
    if (decoded == null) {
      _errorMessage = 'Invalid answer link';
      onStateChanged?.call();
      return false;
    }
    try {
      _updateState(TransferState.connecting,
          message: 'Applying receiver answer…');
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(decoded['sdp'], decoded['type']),
      );
      _updateState(TransferState.connected,
          message: 'Connected! Starting transfer…');
      // The data channel opens via onOpen; _sendAllFiles triggers there.
      return true;
    } catch (e) {
      _updateState(TransferState.error,
          message: 'Failed to apply answer: $e');
      return false;
    }
  }

  /// RECEIVER: paste the sender's offer link, create answer link to send back.
  Future<void> startWebRTCReceiveFromLink(String link) async {
    final decoded = _decodeSdp(link);
    if (decoded == null) {
      _updateState(TransferState.error, message: 'Invalid connection link');
      return;
    }
    _isWebRtcCaller = false;
    _updateState(TransferState.connecting,
        message: 'Connecting to sender…');

    try {
      await _disposeWebRtc();
      _peerConnection = await createPeerConnection(_rtcConfig);

      // Receiver gets the data channel via onDataChannel callback.
      _peerConnection!.onDataChannel = (channel) {
        _setupDataChannel(channel);
      };

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(decoded['sdp'], decoded['type']),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      await _waitForIceGathering(_peerConnection!);

      final finalAnswer = await _peerConnection!.getLocalDescription();
      _roomCode = decoded['roomCode'];
      _answerLink = _encodeSdp(
        sdp: finalAnswer!.sdp ?? '',
        type: finalAnswer.type ?? 'answer',
        roomCode: _roomCode!,
      );

      _updateState(TransferState.waiting,
          message: 'Send this answer back to the sender');
    } catch (e) {
      _updateState(TransferState.error,
          message: 'Failed to create answer: $e');
    }
  }

  Future<void> startWebRTCReceive(String roomCode) async {
    // Legacy stub — link-based flow is preferred.
    await startWebRTCReceiveFromLink(roomCode);
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _updateState(TransferState.connected, message: 'Channel open');
        if (_isWebRtcCaller) {
          // Sender: start pushing files once the channel is open.
          _sendAllFilesWebRtc();
        }
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        if (_filesTransferred > 0 && _state != TransferState.error) {
          _updateState(TransferState.completed,
              message: 'Transfer complete');
        }
      }
    };
    channel.onMessage = (RTCDataChannelMessage msg) {
      if (_isWebRtcCaller) {
        // Sender only sends; ignore incoming (could handle acks later).
        return;
      }
      _handleWebRtcIncoming(msg);
    };
  }

  // ─── WebRTC sender: stream files over the data channel ────
  Future<void> _sendAllFilesWebRtc() async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      _updateState(TransferState.error,
          message: 'Channel closed before transfer');
      return;
    }
    _updateState(TransferState.transferring,
        message: 'Sending files over internet…');

    for (int i = 0; i < _pendingFiles.length; i++) {
      _progress = 0;
      File fileToSend = _pendingFiles[i];
      _currentFileName =
          fileToSend.path.split(Platform.pathSeparator).last;
      _statusMessage = 'Sending ${i + 1}/$_totalFiles: $_currentFileName';
      onStateChanged?.call();

      if (!await fileToSend.exists()) continue;

      if (_encryptionEnabled && _encryptionPin != null) {
        _statusMessage = 'Encrypting: $_currentFileName';
        onStateChanged?.call();
        final encrypted =
            await EncryptionUtil.encryptFile(fileToSend, _encryptionPin!);
        if (encrypted == null) {
          _updateState(TransferState.error,
              message: 'Encryption failed for $_currentFileName');
          return;
        }
        fileToSend = encrypted;
      }

      final fileName = FileUtils.getFileName(fileToSend.path);
      final fileSize = await fileToSend.length();

      // Header frame
      _sendWebRtcText('HEADER:$fileName:$fileSize');

      int sent = 0;
      final raf = await fileToSend.open();
      const chunkSize = AppConstants.webrtcChunkSize;
      try {
        while (sent < fileSize) {
          final remaining = fileSize - sent;
          final readSize =
              remaining < chunkSize ? remaining : chunkSize;
          final chunk = await raf.read(readSize);

          // Backpressure: wait if the send buffer is too full.
          while (_dataChannel != null &&
              (_dataChannel!.bufferedAmount ?? 0) >
                  AppConstants.webrtcMaxBufferedAmount) {
            await Future.delayed(const Duration(milliseconds: 20));
          }
          _dataChannel?.send(RTCDataChannelMessage.fromBinary(chunk));
          sent += chunk.length;
          _progress = sent / fileSize;
          onStateChanged?.call();
          // Yield occasionally so the UI stays responsive.
          if ((sent ~/ chunkSize) % AppConstants.webrtcChunkDelayEvery ==
              0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }
      } finally {
        await raf.close();
      }

      _sendWebRtcText('DONE:$fileName');
      _filesTransferred++;
      if (i < _pendingFiles.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    _updateState(TransferState.completed,
        message: 'All $_totalFiles files sent!');
    await Future.delayed(const Duration(milliseconds: 800));
    await _disposeWebRtc();
  }

  void _sendWebRtcText(String text) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel?.send(RTCDataChannelMessage(text));
    }
  }

  // ─── WebRTC receiver: assemble files from incoming frames ──
  bool _wrtcReceiving = false;
  String? _wrtcFileName;
  int _wrtcFileSize = 0;
  int _wrtcReceived = 0;
  IOSink? _wrtcSink;
  File? _wrtcTempFile;

  void _handleWebRtcIncoming(RTCDataChannelMessage msg) {
    if (_wrtcReceiving) {
      if (msg.isBinary) {
        _wrtcSink?.add(msg.binary);
        _wrtcReceived += msg.binary.length;
        _progress = _wrtcFileSize == 0
            ? 0
            : _wrtcReceived / _wrtcFileSize;
        onStateChanged?.call();
      }
      return;
    }
    if (msg.isBinary) return;
    final text = msg.text;
    try {
      if (text.startsWith('HEADER:')) {
        final parts = text.split(':');
        if (parts.length >= 3) {
          _wrtcFileName = parts.sublist(1, parts.length - 1).join(':');
          _wrtcFileSize = int.tryParse(parts.last) ?? 0;
          _wrtcReceived = 0;
          _wrtcReceiving = true;
          _currentFileName = _wrtcFileName;
          _statusMessage = 'Receiving: $_wrtcFileName';
          _beginWrtcFileWrite();
        }
      } else if (text.startsWith('DONE:')) {
        _finalizeWrtcFile();
      }
    } catch (_) {}
  }

  Future<void> _beginWrtcFileWrite() async {
    try {
      final downloadDir = await FileUtils.getReceivedDir();
      final safeName =
          FileUtils.sanitizeFileName(_wrtcFileName ?? 'file');
      final path =
          await FileUtils.uniqueFilePath(downloadDir.path, safeName);
      _wrtcTempFile = File(path);
      _wrtcSink = _wrtcTempFile!.openWrite();
      _updateState(TransferState.transferring,
          message: 'Receiving $_wrtcFileName…');
    } catch (e) {
      _updateState(TransferState.error,
          message: 'Cannot write received file: $e');
    }
  }

  Future<void> _finalizeWrtcFile() async {
    _wrtcReceiving = false;
    try {
      await _wrtcSink?.flush();
      await _wrtcSink?.close();
    } catch (_) {}
    _wrtcSink = null;

    if (_wrtcTempFile != null && await _wrtcTempFile!.exists()) {
      await _handleReceivedFile(_wrtcTempFile!, _wrtcFileName ?? 'file');
    }
    _filesTransferred++;
    _statusMessage = 'Received $_filesTransferred file(s)';
    onStateChanged?.call();
  }

  // ─── SDP link encoding/decoding ───────────────────────────
  String _encodeSdp(
      {required String sdp,
      required String type,
      required String roomCode}) {
    final payload = jsonEncode({
      'sdp': sdp,
      'type': type,
      'roomCode': roomCode,
      'app': 'filesharepro',
      'v': 1,
    });
    // URL-safe base64 so the link survives WhatsApp/SMS untouched.
    final b64 = base64Url.encode(utf8.encode(payload));
    return 'filesharepro://$b64';
  }

  Map<String, dynamic>? _decodeSdp(String link) {
    var raw = link.trim();
    final prefix = 'filesharepro://';
    if (raw.startsWith(prefix)) {
      raw = raw.substring(prefix.length);
    }
    // Tolerate surrounding text (user may paste the whole message).
    final match = RegExp(r'filesharepro://([A-Za-z0-9_\-]+)').firstMatch(link);
    if (match != null) {
      raw = match.group(1)!;
    }
    try {
      final padded = base64Url.normalize(raw);
      final payload = utf8.decode(base64Url.decode(padded));
      final json = jsonDecode(payload) as Map<String, dynamic>;
      if (json['app'] != 'filesharepro') return null;
      return json;
    } catch (_) {
      return null;
    }
  }

  String _generateRoomCode() {
    const chars = AppConstants.roomCodeChars;
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final code = StringBuffer();
    for (int i = 0; i < AppConstants.roomCodeLength; i++) {
      code.write(chars[(rnd + i * 7) % chars.length]);
    }
    return code.toString();
  }

  /// Wait until ICE gathering finishes (or times out), so the local SDP
  /// contains all candidates. Falls back after a timeout so the user isn't
  /// stuck forever on flaky networks.
  Future<void> _waitForIceGathering(RTCPeerConnection pc) async {
    try {
      final completer = Completer<void>();
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) completer.complete();
      });
      pc.onIceGatheringState = (RTCIceGatheringState state) {
        if (state ==
                RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !completer.isCompleted) {
          completer.complete();
        }
      };
      await completer.future;
    } catch (_) {}
  }
}

enum TransferMode { nearby, longDistance }

enum TransferState {
  idle,
  waiting,
  connecting,
  connected,
  transferring,
  completed,
  error,
}
