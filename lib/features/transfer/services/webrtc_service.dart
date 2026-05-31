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
  List<Uint8List> _receivedChunks = [];
  int _receivedBytes = 0;
  Completer<File?>? _receiveCompleter;

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

  /// Create an SDP offer and data channel (sender side)
  Future<String?> createOffer() async {
    if (_peerConnection == null) await initialize();

    try {
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
      onStatusChange?.call('Offer created. Share with receiver.');

      // Encode offer as compact JSON
      return json.encode({
        'type': offer.type,
        'sdp': offer.sdp,
      });
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
      final offerData = json.decode(offerJson);
      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': false,
        'offerToReceiveVideo': false,
      });

      await _peerConnection!.setLocalDescription(answer);
      onStatusChange?.call('Answer created. Connecting...');

      return json.encode({
        'type': answer.type,
        'sdp': answer.sdp,
      });
    } catch (e) {
      onError?.call('Failed to create answer: $e');
      return null;
    }
  }

  /// Set remote answer (sender side)
  Future<void> setRemoteAnswer(String answerJson) async {
    try {
      final answerData = json.decode(answerJson);
      final answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );

      await _peerConnection!.setRemoteDescription(answer);
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
      // File data chunk
      if (_receivingFileName != null && _receivingFileSize != null) {
        _receivedChunks.add(message.binary);
        _receivedBytes += message.binary.length;
        onTransferProgress?.call(_receivedBytes / _receivingFileSize!);
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
        // Parse header: "HEADER:filename:filesize"
        final parts = text.split(':');
        if (parts.length >= 3) {
          _receivingFileName = parts.sublist(1, parts.length - 1).join(':'); // Handle colons in filename
          _receivingFileSize = int.tryParse(parts.last) ?? 0;
          _receivedChunks = [];
          _receivedBytes = 0;
          _isTransferring = true;
          onStatusChange?.call('Receiving: $_receivingFileName (${FileUtils.formatFileSize(_receivingFileSize!)})');
        }
      } else if (text.startsWith('DONE:')) {
        _finishReceiving();
      } else {
        // Pass plain/decrypted text to callback (could be TEXT, TYPING, READ, etc.)
        onTextMessageReceived?.call(text);
      }
    }
  }

  Future<void> _finishReceiving() async {
    if (_receivingFileName == null) return;

    try {
      final downloadDir = await FileUtils.getReceivedDir();
      final file = File('${downloadDir.path}/$_receivingFileName');
      
      // Merge all chunks into file
      final sink = file.openWrite();
      for (final chunk in _receivedChunks) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      _isTransferring = false;
      onTransferComplete?.call(_receivingFileName!);
      onStatusChange?.call('File received: $_receivingFileName');
      
      _receiveCompleter?.complete(file);
      
      // Reset state
      _receivingFileName = null;
      _receivingFileSize = null;
      _receivedChunks = [];
      _receivedBytes = 0;
    } catch (e) {
      onError?.call('Failed to save received file: $e');
      _receiveCompleter?.complete(null);
    }
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

      // Send file in chunks (16KB chunks for WebRTC data channel)
      const chunkSize = 16384; // 16KB
      int sent = 0;
      
      final bytes = await file.readAsBytes();
      for (int offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize > bytes.length)
            ? bytes.length
            : offset + chunkSize;
            
        final chunk = bytes.sublist(offset, end);
        _dataChannel!.send(RTCDataChannelMessage.fromBinary(chunk));
        
        sent += chunk.length;
        onTransferProgress?.call(sent / fileSize);
        
        // Small delay to prevent buffer overflow
        if (sent % (chunkSize * 10) == 0) {
           await Future.delayed(const Duration(milliseconds: 10));
        }
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

  /// Wait for an incoming file transfer
  Future<File?> waitForFile() async {
    _receiveCompleter = Completer<File?>();
    return await _receiveCompleter!.future;
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
