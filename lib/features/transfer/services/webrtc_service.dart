import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';

import '../../chat/services/chat_encryption_service.dart';

/// WebRTC P2P file transfer service for long-distance transfers.
/// Uses DataChannel for direct phone-to-phone file streaming.
/// NO server needed for data transfer — only for initial signaling.
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  ChatEncryptionService? _encryption;
  
  void setEncryptionService(ChatEncryptionService encryption) {
    _encryption = encryption;
  }
  
  // ─── State Callbacks ─────────────────────────────────────
  ValueChanged<RTCIceCandidate>? onIceCandidate;
  ValueChanged<RTCSessionDescription>? onLocalDescription;
  ValueChanged<double>? onTransferProgress;
  ValueChanged<String>? onTransferComplete;
  ValueChanged<String>? onTextMessageReceived; // For encrypted text/control msgs
  ValueChanged<String>? onError;
  ValueChanged<String>? onStatusChange;
  ValueChanged<bool>? onConnectionStateChange;
  
  bool _isConnected = false;
  bool _isTransferring = false;
  
  bool get isConnected => _isConnected;
  bool get isTransferring => _isTransferring;

  // ─── Receiving state ──────────────────────────────────────
  String? _receivingFileName;
  int? _receivingFileSize;
  int _receivedBytes = 0;
  IOSink? _receiveSink;
  File? _receiveTempFile;
  int _chunksSincePause = 0;
  Completer<File?>? _receiveCompleter;
  bool _sessionEnded = false;
  final List<Map<String, dynamic>> _localIceCandidates = [];
  final List<Map<String, dynamic>> _pendingRemoteCandidates = [];

  // ─── ICE Configuration ───────────────────────────────────
  
  Map<String, dynamic> get _iceConfig => {
    'iceServers': AppConstants.iceServers,
    'sdpSemantics': 'unified-plan',
  };

  // ─── Initialize Connection ───────────────────────────────

  Future<void> initialize() async {
    try {
      _peerConnection = await createPeerConnection(_iceConfig, {
        'optional': [{'DtlsSrtpKeyAgreement': true}],
      });

      _peerConnection!.onIceCandidate = (candidate) {
        _localIceCandidates.add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
        onIceCandidate?.call(candidate);
      };

      _peerConnection!.onIceConnectionState = (state) {
        final connected = state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
                          state == RTCIceConnectionState.RTCIceConnectionStateCompleted;
        _isConnected = connected;
        onConnectionStateChange?.call(connected);
        
        if (connected) {
          onStatusChange?.call('P2P Connection established!');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          onError?.call('Connection failed. Check your internet.');
          _isConnected = false;
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          onStatusChange?.call('Connection lost. Reconnecting...');
          _isConnected = false;
        }
      };

      _peerConnection!.onDataChannel = (channel) {
        _setupDataChannel(channel);
      };

      onStatusChange?.call('WebRTC initialized');
    } catch (e) {
      onError?.call('WebRTC init failed: $e');
    }
  }

  // ─── SENDER: Create Offer ────────────────────────────────

  /// Wait until ICE gathering completes (or times out).
  Future<void> _waitForIceGathering() async {
    if (_peerConnection == null) return;
    final completer = Completer<void>();
    void listener(RTCIceGatheringState state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    }

    _peerConnection!.onIceGatheringState = listener;
    if (_peerConnection!.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    await completer.future.timeout(
      const Duration(seconds: AppConstants.connectionTimeoutSec),
      onTimeout: () {},
    );
  }

  Map<String, dynamic> _encodeSessionDescription(RTCSessionDescription desc) {
    return {
      'type': desc.type,
      'sdp': desc.sdp,
      'candidates': List<Map<String, dynamic>>.from(_localIceCandidates),
    };
  }

  Future<void> _applyRemoteCandidates(List<dynamic>? candidates) async {
    if (candidates == null || _peerConnection == null) return;
    for (final raw in candidates) {
      if (raw is! Map) continue;
      final candidate = RTCIceCandidate(
        raw['candidate'] as String?,
        raw['sdpMid'] as String?,
        raw['sdpMLineIndex'] as int?,
      );
      await addIceCandidate(candidate);
    }
  }

  /// Create an SDP offer and data channel (sender side)
  Future<String?> createOffer() async {
    if (_peerConnection == null) await initialize();

    try {
      _localIceCandidates.clear();
      _pendingRemoteCandidates.clear();
      // Create data channel for file transfer
      final channelInit = RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30;
      
      _dataChannel = await _peerConnection!.createDataChannel(
        'fileTransfer',
        channelInit,
      );
      _setupDataChannel(_dataChannel!);

      // Create offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(offer);
      await _waitForIceGathering();
      onStatusChange?.call('Offer created. Share with receiver.');

      return json.encode(_encodeSessionDescription(offer));
    } catch (e) {
      onError?.call('Failed to create offer: $e');
      return null;
    }
  }

  // ─── RECEIVER: Create Answer ─────────────────────────────

  /// Set remote offer and create answer (receiver side)
  Future<String?> createAnswer(String offerJson) async {
    if (_peerConnection == null) await initialize();

    try {
      _localIceCandidates.clear();
      _pendingRemoteCandidates.clear();
      final offerData = json.decode(offerJson) as Map<String, dynamic>;
      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);
      await _applyRemoteCandidates(offerData['candidates'] as List<dynamic>?);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(answer);
      await _waitForIceGathering();
      onStatusChange?.call('Answer created. Share back with sender.');

      return json.encode(_encodeSessionDescription(answer));
    } catch (e) {
      onError?.call('Failed to create answer: $e');
      return null;
    }
  }

  /// Set remote answer (sender side)
  Future<void> setRemoteAnswer(String answerJson) async {
    try {
      final answerData = json.decode(answerJson) as Map<String, dynamic>;
      final answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );

      await _peerConnection!.setRemoteDescription(answer);
      await _applyRemoteCandidates(answerData['candidates'] as List<dynamic>?);
      onStatusChange?.call('Remote answer set. Finalizing connection...');
    } catch (e) {
      onError?.call('Failed to set answer: $e');
    }
  }

  /// Add ICE candidate from remote peer
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      debugPrint('ICE candidate error: $e');
    }
  }

  // ─── Data Channel Setup ──────────────────────────────────

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    
    channel.onMessage = (message) {
      _handleDataChannelMessage(message);
    };

    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        onStatusChange?.call('Data channel open — ready to transfer!');
        _isConnected = true;
        onConnectionStateChange?.call(true);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        onStatusChange?.call('Data channel closed');
        _isConnected = false;
        onConnectionStateChange?.call(false);
      }
    };
  }

  // ─── File Transfer Protocol ──────────────────────────────
  // Message format:
  //   "HEADER:<filename>:<filesize>"  -> File metadata
  //   Binary data chunks             -> File content  
  //   "DONE:<filename>"              -> Transfer complete

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    if (message.isBinary) {
      if (_receivingFileName != null && _receiveSink != null) {
        _receiveSink!.add(message.binary);
        _receivedBytes += message.binary.length;
        _chunksSincePause++;
        onTransferProgress?.call(_receivedBytes / (_receivingFileSize ?? 1));

        if (_chunksSincePause >= AppConstants.webrtcChunkDelayEvery) {
          _chunksSincePause = 0;
          final buffered = _dataChannel?.bufferedAmount ?? 0;
          if (buffered > AppConstants.webrtcMaxBufferedAmount) {
            Future.delayed(const Duration(milliseconds: 12));
          }
        }
      }
    } else {
      // Control/Text message
      String text = message.text;
      
      // Decrypt if encryption is configured and it looks like encrypted text
      if (_encryption != null && _encryption!.isReady && text.contains(':')) {
        try {
          text = _encryption!.decryptMessage(text);
        } catch (e) {
          debugPrint('Failed to decrypt incoming message: $e');
        }
      }
      
      if (text.startsWith('HEADER:')) {
        final parts = text.split(':');
        if (parts.length >= 3) {
          _receivingFileName =
              parts.sublist(1, parts.length - 1).join(':');
          _receivingFileSize = int.tryParse(parts.last) ?? 0;
          _receivedBytes = 0;
          _chunksSincePause = 0;
          _isTransferring = true;
          _startReceiveToDisk();
          onStatusChange?.call(
            'Receiving: $_receivingFileName (${FileUtils.formatFileSize(_receivingFileSize!)})',
          );
        }
      } else if (text.startsWith('DONE:')) {
        _finishReceiving();
      } else if (text == 'ALL_DONE') {
        _sessionEnded = true;
        _receiveCompleter?.complete(null);
      } else {
        // Pass plain/decrypted text to callback (could be TEXT, TYPING, READ, etc.)
        onTextMessageReceived?.call(text);
      }
    }
  }

  Future<void> _startReceiveToDisk() async {
    await _closeReceiveSink();
    try {
      final downloadDir = await FileUtils.getReceivedDir();
      final safeName = FileUtils.sanitizeFileName(_receivingFileName ?? 'file');
      final path = await FileUtils.uniqueFilePath(downloadDir.path, safeName);
      _receiveTempFile = File(path);
      _receiveSink = _receiveTempFile!.openWrite();
    } catch (e) {
      onError?.call('Cannot write received file: $e');
    }
  }

  Future<void> _closeReceiveSink() async {
    try {
      await _receiveSink?.flush();
      await _receiveSink?.close();
    } catch (_) {}
    _receiveSink = null;
  }

  Future<void> _finishReceiving() async {
    if (_receivingFileName == null) return;

    if (_receivingFileSize != null && _receivingFileSize! > 0 &&
        _receivedBytes != _receivingFileSize) {
      onError?.call(
        'Incomplete file received ($_receivedBytes / $_receivingFileSize bytes)',
      );
      _receiveCompleter?.complete(null);
      _resetReceiveState();
      return;
    }

    try {
      await _closeReceiveSink();
      final file = _receiveTempFile;
      if (file == null || !await file.exists()) {
        onError?.call('Received file missing on disk');
        _receiveCompleter?.complete(null);
        _resetReceiveState();
        return;
      }

      final safeName = FileUtils.sanitizeFileName(_receivingFileName!);
      onTransferComplete?.call(safeName);
      onStatusChange?.call('File received: $safeName');
      
      _receiveCompleter?.complete(file);
      
      _resetReceiveState();
    } catch (e) {
      onError?.call('Failed to save received file: $e');
      _receiveCompleter?.complete(null);
      _resetReceiveState();
    }
  }

  void _resetReceiveState() {
    _receivingFileName = null;
    _receivingFileSize = null;
    _receivedBytes = 0;
    _chunksSincePause = 0;
    _receiveTempFile = null;
    _receiveSink = null;
    _isTransferring = false;
  }

  // ─── SENDER: Send File ───────────────────────────────────

  /// Send an encrypted text or control message over WebRTC data channel
  bool sendTextMessage(String message) {
    if (_dataChannel == null || !_isConnected) return false;
    try {
      final textToSend = (_encryption != null && _encryption!.isReady) 
          ? _encryption!.encryptMessage(message) 
          : message;
      _dataChannel!.send(RTCDataChannelMessage(textToSend));
      return true;
    } catch (e) {
      debugPrint('Failed to send text message: $e');
      return false;
    }
  }

  /// Send a file over WebRTC data channel
  Future<bool> sendFile(File file) async {
    if (_dataChannel == null || !_isConnected) {
      onError?.call('Not connected. Establish connection first.');
      return false;
    }

    try {
      _isTransferring = true;
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();
      
      onStatusChange?.call('Sending: $fileName (${FileUtils.formatFileSize(fileSize)})');

      // Send header
      sendTextMessage('HEADER:$fileName:$fileSize');

      // Send file in chunks — stream from disk (ShareIt-style, low memory)
      const chunkSize = AppConstants.webrtcChunkSize;
      int sent = 0;

      final raf = await file.open();
      try {
      while (sent < fileSize) {
        final remaining = fileSize - sent;
        final readSize = remaining < chunkSize ? remaining : chunkSize;
        final chunk = await raf.read(readSize);

        var waitLoops = 0;
        while ((_dataChannel!.bufferedAmount ?? 0) > AppConstants.webrtcMaxBufferedAmount &&
            waitLoops < 200) {
          await Future.delayed(const Duration(milliseconds: 10));
          waitLoops++;
        }

        _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunk));
        sent += chunk.length;
        onTransferProgress?.call(sent / fileSize);

        if (sent % (chunkSize * AppConstants.webrtcChunkDelayEvery) == 0) {
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }
      } finally {
        await raf.close();
      }

      // Send done
      sendTextMessage('DONE:$fileName');

      _isTransferring = false;
      onTransferComplete?.call(fileName);
      onStatusChange?.call('File sent: $fileName');
      return true;
    } catch (e) {
      onError?.call('Failed to send file: $e');
      _isTransferring = false;
      return false;
    }
  }

  /// Wait for an incoming file transfer (supports multiple files per session)
  Future<File?> waitForFile() async {
    _receiveCompleter = Completer<File?>();
    return _receiveCompleter!.future;
  }

  bool get sessionEnded => _sessionEnded;

  void resetSessionEnd() => _sessionEnded = false;

  /// Prepare for the next incoming file in the same session
  void prepareForNextFile() {
    if (_receiveCompleter != null && !_receiveCompleter!.isCompleted) {
      _receiveCompleter!.complete(null);
    }
    _receiveCompleter = Completer<File?>();
  }

  /// Tell receiver that all files in this session were sent.
  void signalAllDone() {
    sendTextMessage('ALL_DONE');
  }

  // ─── Cleanup ─────────────────────────────────────────────

  Future<void> dispose() async {
    _isConnected = false;
    _isTransferring = false;
    
    try {
      _dataChannel?.close();
      _dataChannel = null;
    } catch (_) {}
    
    try {
      await _peerConnection?.close();
      _peerConnection = null;
    } catch (_) {}
  }
}
