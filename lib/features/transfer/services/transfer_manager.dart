import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'nearby_service.dart';
import 'webrtc_service.dart';
import 'signaling_service.dart';
import '../../../core/utils/encryption_util.dart';

/// Orchestrates file transfers across both Nearby (Wi-Fi) and 
/// Long-Distance (WebRTC) modes. Provides a unified API for the UI.
class TransferManager {
  final NearbyService nearbyService = NearbyService();
  final WebRTCService webrtcService = WebRTCService();
  final SignalingService signalingService = SignalingService();

  // ─── Transfer State ──────────────────────────────────────
  TransferMode _mode = TransferMode.nearby;
  TransferState _state = TransferState.idle;
  double _progress = 0.0;
  String _statusMessage = 'Ready';
  String? _roomCode;
  String? _errorMessage;
  
  // File info
  List<File> _pendingFiles = [];
  String? _currentFileName;
  int _filesSent = 0;
  int _totalFiles = 0;

  // Encryption
  bool _encryptionEnabled = false;
  String? _encryptionPin;

  // ─── Getters ─────────────────────────────────────────────
  TransferMode get mode => _mode;
  TransferState get state => _state;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get roomCode => _roomCode;
  String? get errorMessage => _errorMessage;
  String? get currentFileName => _currentFileName;
  int get filesSent => _filesSent;
  int get totalFiles => _totalFiles;
  bool get encryptionEnabled => _encryptionEnabled;

  // ─── Callbacks ───────────────────────────────────────────
  VoidCallback? onStateChanged;

  void _updateState(TransferState newState, {String? message}) {
    _state = newState;
    if (message != null) _statusMessage = message;
    onStateChanged?.call();
  }

  // ─── Mode Selection ──────────────────────────────────────

  void setMode(TransferMode mode) {
    _mode = mode;
    onStateChanged?.call();
  }

  void setEncryption({required bool enabled, String? pin}) {
    _encryptionEnabled = enabled;
    _encryptionPin = pin;
    onStateChanged?.call();
  }

  // ─── SENDER FLOW ─────────────────────────────────────────

  /// Start sending files
  Future<void> startSending(List<File> files) async {
    if (files.isEmpty) {
      _updateState(TransferState.error, message: 'No files selected');
      return;
    }
    
    _pendingFiles = files;
    _totalFiles = files.length;
    _filesSent = 0;
    _errorMessage = null;

    try {
      if (_mode == TransferMode.nearby) {
        await _startNearbySend();
      } else {
        await _startWebRTCSend();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _updateState(TransferState.error, message: 'Transfer failed: $e');
    }
  }

  Future<void> _startNearbySend() async {
    _updateState(TransferState.waiting, message: 'Starting nearby transfer...');
    
    nearbyService.onTransferProgress = (p) {
      _progress = p;
      onStateChanged?.call();
    };
    
    nearbyService.onTransferComplete = (name) {
      _filesSent++;
      _currentFileName = name;
      _statusMessage = 'Sent: $name ($_filesSent/$_totalFiles)';
      
      // Check if all files sent
      if (_filesSent >= _totalFiles) {
        _updateState(TransferState.completed, 
            message: 'All $_totalFiles files sent!');
      } else {
        onStateChanged?.call();
      }
    };
    
    nearbyService.onError = (err) {
      _errorMessage = err;
      _updateState(TransferState.error, message: err);
    };
    
    nearbyService.onStatusChange = (status) {
      _statusMessage = status;
      onStateChanged?.call();
    };

    // Start hosting and wait for connection
    final hostName = await nearbyService.startHosting(
      onDeviceConnected: (deviceInfo) async {
        _updateState(TransferState.connected, 
            message: 'Connected to ${deviceInfo['name']}');
        
        // Small delay to ensure connection is stable
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Send all files sequentially
        await _sendAllFiles(isNearby: true);
      },
      onError: (err) {
        _errorMessage = err;
        _updateState(TransferState.error, message: err);
      },
    );
    
    if (hostName != null) {
      _roomCode = hostName;
      _updateState(TransferState.waiting, 
          message: 'Waiting for receiver to connect...');
    } else {
      _updateState(TransferState.error, 
          message: 'Failed to start hosting. Check permissions.');
    }
  }

  Future<void> _startWebRTCSend() async {
    _updateState(TransferState.waiting, message: 'Initializing WebRTC...');
    
    webrtcService.onTransferProgress = (p) {
      _progress = p;
      onStateChanged?.call();
    };
    
    webrtcService.onTransferComplete = (name) {
      _filesSent++;
      _currentFileName = name;
      _statusMessage = 'Sent: $name ($_filesSent/$_totalFiles)';
      
      if (_filesSent >= _totalFiles) {
        _updateState(TransferState.completed, 
            message: 'All $_totalFiles files sent!');
      } else {
        onStateChanged?.call();
      }
    };
    
    webrtcService.onError = (err) {
      _errorMessage = err;
      _updateState(TransferState.error, message: err);
    };
    
    webrtcService.onStatusChange = (status) {
      _statusMessage = status;
      onStateChanged?.call();
    };
    
    webrtcService.onConnectionStateChange = (connected) {
      if (connected) {
        _updateState(TransferState.connected, message: 'P2P Connected!');
        // Start sending files
        _sendAllFiles(isNearby: false);
      }
    };

    // Generate room code and create offer
    _roomCode = signalingService.generateRoomCode();
    final offer = await webrtcService.createOffer();
    
    if (offer != null) {
      // Package offer for QR code / sharing
      final signalData = signalingService.packageSignalData(
        type: 'offer',
        sdp: offer,
      );
      
      await signalingService.storeSignalData(_roomCode!, signalData);
      _updateState(TransferState.waiting, 
          message: 'Share code: $_roomCode with receiver');
    } else {
      _updateState(TransferState.error, 
          message: 'Failed to create WebRTC offer');
    }
  }

  Future<void> _sendAllFiles({required bool isNearby}) async {
    _updateState(TransferState.transferring, message: 'Sending files...');
    
    for (int i = 0; i < _pendingFiles.length; i++) {
      _progress = 0;
      _currentFileName = _pendingFiles[i].path.split(Platform.pathSeparator).last;
      _statusMessage = 'Sending ${i + 1}/$_totalFiles: $_currentFileName';
      onStateChanged?.call();
      
      File fileToSend = _pendingFiles[i];
      
      // Validate file exists and is readable
      if (!await fileToSend.exists()) {
        debugPrint('File not found: ${fileToSend.path}');
        continue; // Skip missing files
      }
      
      // Encrypt if needed
      if (_encryptionEnabled && _encryptionPin != null) {
        _statusMessage = 'Encrypting: $_currentFileName';
        onStateChanged?.call();
        
        try {
          final encryptedFile = await EncryptionUtil.encryptFile(
            fileToSend,
            _encryptionPin!,
          );
          if (encryptedFile != null) {
            fileToSend = encryptedFile;
          }
        } catch (e) {
          debugPrint('Encryption failed for $_currentFileName: $e');
          // Continue sending unencrypted
        }
      }
      
      int retryCount = 0;
      bool success = false;
      
      while (retryCount < 3 && !success) {
        if (isNearby) {
          success = await nearbyService.sendFile(fileToSend);
        } else {
          success = await webrtcService.sendFile(fileToSend);
        }
        
        if (!success) {
          retryCount++;
          if (retryCount < 3) {
            _statusMessage = 'Retrying $_currentFileName ($retryCount/3)';
            onStateChanged?.call();
            await Future.delayed(Duration(seconds: retryCount)); // Exponential backoff
          }
        }
      }
      
      if (!success) {
        _updateState(TransferState.error, 
            message: 'Failed to send: $_currentFileName after 3 attempts');
        return;
      }
      
      // Small delay between files to prevent buffer overflow
      if (i < _pendingFiles.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    
    _updateState(TransferState.completed, 
        message: 'All $_totalFiles files sent!');
  }

  // ─── RECEIVER FLOW ───────────────────────────────────────

  /// Start receiving files in nearby mode
  Future<void> startNearbyReceive(String address) async {
    _updateState(TransferState.connecting, message: 'Connecting to sender...');
    
    nearbyService.onTransferProgress = (p) {
      _progress = p;
      onStateChanged?.call();
    };
    
    nearbyService.onTransferComplete = (name) {
      _filesSent++;
      _currentFileName = name;
      _updateState(TransferState.completed, message: 'Received: $name');
    };
    
    nearbyService.onError = (err) {
      _errorMessage = err;
      _updateState(TransferState.error, message: err);
    };
    
    nearbyService.onStatusChange = (status) {
      _statusMessage = status;
      onStateChanged?.call();
    };
    
    try {
      final connected = await nearbyService.connectToHost(address);
      if (connected) {
        _updateState(TransferState.transferring, message: 'Receiving files...');
        await nearbyService.receiveFile();
      } else {
        _updateState(TransferState.error, 
            message: 'Could not connect to sender');
      }
    } catch (e) {
      _updateState(TransferState.error, 
          message: 'Connection error: $e');
    }
  }

  /// Start receiving files in WebRTC mode using a room code
  Future<void> startWebRTCReceive(String roomCode) async {
    _roomCode = roomCode;
    _updateState(TransferState.connecting, message: 'Connecting via code...');
    
    webrtcService.onTransferProgress = (p) {
      _progress = p;
      onStateChanged?.call();
    };
    
    webrtcService.onTransferComplete = (name) {
      _filesSent++;
      _currentFileName = name;
      _updateState(TransferState.completed, message: 'Received: $name');
    };
    
    webrtcService.onError = (err) {
      _errorMessage = err;
      _updateState(TransferState.error, message: err);
    };
    
    webrtcService.onStatusChange = (status) {
      _statusMessage = status;
      onStateChanged?.call();
    };
    
    webrtcService.onConnectionStateChange = (connected) {
      if (connected) {
        _updateState(TransferState.transferring, message: 'Connected! Waiting for files...');
      }
    };

    try {
      // Retrieve stored signal data
      final signalData = await signalingService.getSignalData(roomCode);
      if (signalData != null) {
        final unpacked = signalingService.unpackageSignalData(signalData);
        if (unpacked != null) {
          // Create answer from offer
          final answer = await webrtcService.createAnswer(unpacked['sdp']);
          if (answer != null) {
            final answerData = signalingService.packageSignalData(
              type: 'answer',
              sdp: answer,
            );
            await signalingService.storeSignalData('${roomCode}_answer', answerData);
            
            // Wait for file
            await webrtcService.waitForFile();
          } else {
            _updateState(TransferState.error, 
                message: 'Failed to create connection answer');
          }
        } else {
          _updateState(TransferState.error, 
              message: 'Invalid signal data from sender');
        }
      } else {
        _updateState(TransferState.error, 
            message: 'No sender found with code: $roomCode');
      }
    } catch (e) {
      _updateState(TransferState.error, 
          message: 'Connection error: $e');
    }
  }

  // ─── Cancel / Reset ──────────────────────────────────────

  Future<void> cancel() async {
    _updateState(TransferState.idle, message: 'Cancelled');
    _progress = 0;
    _pendingFiles = [];
    _filesSent = 0;
    _totalFiles = 0;
    _errorMessage = null;
    
    if (_roomCode != null) {
      await signalingService.clearSignalData(_roomCode!);
    }
    
    await nearbyService.dispose();
    await webrtcService.dispose();
  }

  /// Full cleanup
  Future<void> dispose() async {
    await cancel();
    await signalingService.cleanupExpiredSignals();
  }
}

// ─── Enums ─────────────────────────────────────────────────

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
