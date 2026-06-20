import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'nearby_service.dart';
import 'webrtc_service.dart';
import 'signaling_service.dart';
import '../../../core/utils/encryption_util.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/transfer_history_service.dart';

/// Orchestrates file transfers across both Nearby (Wi-Fi) and 
/// Long-Distance (WebRTC) modes. Provides a unified API for the UI.
class TransferManager {
  final NearbyService nearbyService = NearbyService();
  final WebRTCService webrtcService = WebRTCService();
  final SignalingService signalingService = SignalingService();
  final TransferHistoryService _history = TransferHistoryService();

  TransferMode _mode = TransferMode.nearby;
  TransferState _state = TransferState.idle;
  double _progress = 0.0;
  String _statusMessage = 'Ready';
  String? _roomCode;
  String? _errorMessage;
  String? _connectionLink;
  String? _answerLink;

  List<File> _pendingFiles = [];
  String? _currentFileName;
  int _filesTransferred = 0;
  int _totalFiles = 0;

  bool _encryptionEnabled = false;
  String? _encryptionPin;
  String? _receiverDecryptPin;

  final List<NearbyDevice> _discoveredDevices = [];

  TransferMode get mode => _mode;
  TransferState get state => _state;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  String? get roomCode => _roomCode;
  String? get errorMessage => _errorMessage;
  String? get connectionLink => _connectionLink;
  String? get answerLink => _answerLink;
  String? get currentFileName => _currentFileName;
  int get filesSent => _filesTransferred;
  int get totalFiles => _totalFiles;
  bool get encryptionEnabled => _encryptionEnabled;
  List<NearbyDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  VoidCallback? onStateChanged;

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
    _connectionLink = null;
    _answerLink = null;

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
    _bindNearbyCallbacks(isReceiver: false);

    final hostName = await nearbyService.startHosting(
      deviceName: 'FileShare Pro',
      onDeviceConnected: (deviceInfo) async {
        _updateState(
          TransferState.connected,
          message: 'Connected to ${deviceInfo['name']}',
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await _sendAllFiles(isNearby: true);
      },
      onError: (err) {
        _errorMessage = err;
        _updateState(TransferState.error, message: err);
      },
    );

    if (hostName != null) {
      _roomCode = hostName;
      _updateState(
        TransferState.waiting,
        message: 'Waiting for receiver to connect...',
      );
    } else {
      _updateState(
        TransferState.error,
        message: 'Failed to start hosting. Check permissions.',
      );
    }
  }

  Future<void> _startWebRTCSend() async {
    _updateState(TransferState.waiting, message: 'Initializing WebRTC...');
    _bindWebRTCCallbacks(isReceiver: false);

    _roomCode = signalingService.generateRoomCode();
    final offer = await webrtcService.createOffer();

    if (offer == null) {
      _updateState(TransferState.error, message: 'Failed to create WebRTC offer');
      return;
    }

    final signalData = signalingService.packageSignalData(
      type: 'offer',
      sdp: offer,
    );
    await signalingService.storeSignalData(_roomCode!, signalData);

    _connectionLink = signalingService.generateQrContent(
      roomCode: _roomCode!,
      signalData: signalData,
    );
    _updateState(
      TransferState.waiting,
      message: 'Share connection link with receiver',
    );
  }

  /// Sender pastes the answer link shared by receiver (completes WebRTC handshake).
  Future<bool> applyReceiverAnswer(String link) async {
    final parsed = signalingService.parseQrContent(link.trim());
    if (parsed == null || parsed['signalData']?.isEmpty != false) {
      _errorMessage = 'Invalid answer link';
      _updateState(TransferState.error, message: _errorMessage!);
      return false;
    }

    final unpacked = signalingService.unpackageSignalData(parsed['signalData']!);
    if (unpacked == null || unpacked['type'] != 'answer') {
      _errorMessage = 'Answer data is invalid';
      _updateState(TransferState.error, message: _errorMessage!);
      return false;
    }

    _updateState(TransferState.connecting, message: 'Applying receiver answer...');
    await webrtcService.setRemoteAnswer(unpacked['sdp']);
    return true;
  }

  Future<void> _sendAllFiles({required bool isNearby}) async {
    _updateState(TransferState.transferring, message: 'Sending files...');

    for (int i = 0; i < _pendingFiles.length; i++) {
      _progress = 0;
      _currentFileName =
          _pendingFiles[i].path.split(Platform.pathSeparator).last;
      _statusMessage = 'Sending ${i + 1}/$_totalFiles: $_currentFileName';
      onStateChanged?.call();

      File fileToSend = _pendingFiles[i];

      if (!await fileToSend.exists()) {
        debugPrint('File not found: ${fileToSend.path}');
        continue;
      }

      if (_encryptionEnabled && _encryptionPin != null) {
        _statusMessage = 'Encrypting: $_currentFileName';
        onStateChanged?.call();

        final encryptedFile = await EncryptionUtil.encryptFile(
          fileToSend,
          _encryptionPin!,
        );
        if (encryptedFile == null) {
          _updateState(
            TransferState.error,
            message: 'Encryption failed for $_currentFileName',
          );
          return;
        }
        fileToSend = encryptedFile;
      }

      int retryCount = 0;
      bool success = false;

      while (retryCount < 3 && !success) {
        success = isNearby
            ? await nearbyService.sendFile(fileToSend)
            : await webrtcService.sendFile(fileToSend);

        if (!success) {
          retryCount++;
          if (retryCount < 3) {
            _statusMessage = 'Retrying $_currentFileName ($retryCount/3)';
            onStateChanged?.call();
            await Future.delayed(Duration(seconds: retryCount));
          }
        }
      }

      if (!success) {
        _updateState(
          TransferState.error,
          message: 'Failed to send: $_currentFileName after 3 attempts',
        );
        return;
      }

      _filesTransferred++;
      if (i < _pendingFiles.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    for (final f in _pendingFiles) {
      final name = f.path.split(Platform.pathSeparator).last;
      await _logTransfer(name, 'sent', isNearby ? 'nearby' : 'webrtc', size: await f.length());
    }

    if (!isNearby) {
      webrtcService.signalAllDone();
    }

    _updateState(
      TransferState.completed,
      message: 'All $_totalFiles files sent!',
    );
  }

  // ─── RECEIVER FLOW ───────────────────────────────────────

  /// Discover nearby senders (ShareIt-style device list).
  Future<void> startNearbyDiscovery() async {
    _discoveredDevices.clear();
    _updateState(TransferState.waiting, message: 'Searching nearby devices...');
    _bindNearbyCallbacks(isReceiver: true);

    await nearbyService.startDiscovery(
      onDeviceFound: (deviceInfo) {
        final device = NearbyDevice(
          name: deviceInfo['name'] as String? ?? 'Unknown',
          address: deviceInfo['address'] as String? ?? '',
          port: deviceInfo['port'] as int? ?? 0,
        );
        if (!_discoveredDevices.any((d) => d.address == device.address)) {
          _discoveredDevices.add(device);
          _statusMessage = 'Found: ${device.name}';
          onStateChanged?.call();
        }
      },
      onError: (err) {
        _errorMessage = err;
        _updateState(TransferState.error, message: err);
      },
    );
  }

  Future<void> startNearbyReceive(String endpointId) async {
    _filesTransferred = 0;
    _totalFiles = 0;
    _updateState(TransferState.connecting, message: 'Connecting to sender...');
    _bindNearbyCallbacks(isReceiver: true);

    try {
      final connected = await nearbyService.connectToHost(endpointId);
      if (connected) {
        _updateState(TransferState.transferring, message: 'Receiving files...');
        await nearbyService.receiveFile();
      } else {
        _updateState(TransferState.error, message: 'Could not connect to sender');
      }
    } catch (e) {
      _updateState(TransferState.error, message: 'Connection error: $e');
    }
  }

  /// Connect using full link: filesharepro://CODE#signalData
  Future<void> startWebRTCReceiveFromLink(String link) async {
    _filesTransferred = 0;
    _totalFiles = 0;
    _errorMessage = null;
    _answerLink = null;

    final parsed = signalingService.parseQrContent(link.trim());
    if (parsed == null || parsed['signalData']?.isEmpty != false) {
      _updateState(
        TransferState.error,
        message: 'Invalid connection link. Ask sender to reshare.',
      );
      return;
    }

    _roomCode = parsed['roomCode'];
    await signalingService.storeSignalData(_roomCode!, parsed['signalData']!);
    await _completeWebRTCReceive();
  }

  /// Legacy: room code only (works only if offer stored on same device).
  Future<void> startWebRTCReceive(String roomCode) async {
    _roomCode = roomCode;
    await _completeWebRTCReceive();
  }

  Future<void> _completeWebRTCReceive() async {
    _updateState(TransferState.connecting, message: 'Connecting via link...');
    _bindWebRTCCallbacks(isReceiver: true);

    try {
      final signalData = await signalingService.getSignalData(_roomCode!);
      if (signalData == null) {
        _updateState(
          TransferState.error,
          message: 'Connection data missing. Paste the full sender link.',
        );
        return;
      }

      final unpacked = signalingService.unpackageSignalData(signalData);
      if (unpacked == null || unpacked['type'] != 'offer') {
        _updateState(TransferState.error, message: 'Invalid sender connection data');
        return;
      }

      final answer = await webrtcService.createAnswer(unpacked['sdp']);
      if (answer == null) {
        _updateState(TransferState.error, message: 'Failed to create connection answer');
        return;
      }

      final answerData = signalingService.packageSignalData(
        type: 'answer',
        sdp: answer,
      );
      _answerLink = signalingService.generateQrContent(
        roomCode: _roomCode!,
        signalData: answerData,
      );
      _updateState(
        TransferState.waiting,
        message: 'Share answer link back with sender',
      );

      await _receiveAllWebRTCFiles();
    } catch (e) {
      _updateState(TransferState.error, message: 'Connection error: $e');
    }
  }

  Future<void> _receiveAllWebRTCFiles() async {
    _updateState(TransferState.transferring, message: 'Waiting for files...');
    webrtcService.resetSessionEnd();

    while (_state != TransferState.error) {
      webrtcService.prepareForNextFile();
      final file = await webrtcService.waitForFile().timeout(
        const Duration(minutes: 15),
        onTimeout: () => null,
      );

      if (webrtcService.sessionEnded) break;

      if (file == null) {
        if (_filesTransferred == 0) {
          _updateState(TransferState.error, message: 'No file received');
        }
        break;
      }

      _filesTransferred++;
      _currentFileName = file.path.split(Platform.pathSeparator).last;
      _progress = 1.0;

      if (await _isEncryptedPayload(file)) {
        final pin = _receiverDecryptPin ?? _encryptionPin;
        if (pin != null) {
          final decrypted = await _decryptReceivedFile(file, pin);
          if (decrypted != null) {
            _currentFileName = FileUtils.getFileName(decrypted.path);
            await _logTransfer(
              _currentFileName!,
              'received',
              'webrtc',
              size: await decrypted.length(),
            );
          } else {
            _statusMessage = 'Decrypt failed — check PIN';
          }
        } else {
          _statusMessage = 'Encrypted file — enter PIN in Receive screen';
        }
      } else {
        await _logTransfer(
          _currentFileName!,
          'received',
          'webrtc',
          size: await file.length(),
        );
      }

      _statusMessage = 'Received $_filesTransferred: $_currentFileName';
      onStateChanged?.call();
    }

    if (_filesTransferred > 0 && _state != TransferState.error) {
      _updateState(
        TransferState.completed,
        message: 'Received $_filesTransferred file(s)',
      );
    }
  }

  void _bindNearbyCallbacks({required bool isReceiver}) {
    nearbyService.onTransferProgress = (p) {
      _progress = p;
      onStateChanged?.call();
    };

    nearbyService.onTransferComplete = (name) {
      _filesTransferred++;
      _currentFileName = name;
      _logTransfer(name, 'received', 'nearby');
      if (isReceiver) {
        _statusMessage = 'Received: $name ($_filesTransferred)';
        onStateChanged?.call();
      } else {
        // Sender progress handled in _sendAllFiles
      }
    };

    nearbyService.onDisconnected = () {
      if (isReceiver && _filesTransferred > 0) {
        _updateState(
          TransferState.completed,
          message: 'Received $_filesTransferred file(s)',
        );
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
  }

  void _bindWebRTCCallbacks({required bool isReceiver}) {
    webrtcService.onTransferProgress = (p) {
      _progress = p;
      onStateChanged?.call();
    };

    webrtcService.onTransferComplete = (name) {
      _currentFileName = name;
      _statusMessage = isReceiver ? 'Received: $name' : 'Sent: $name';
      if (isReceiver) {
        _logTransfer(name, 'received', 'webrtc');
      }
      onStateChanged?.call();
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
        if (isReceiver) {
          _updateState(TransferState.transferring, message: 'Connected! Receiving...');
        } else {
          _updateState(TransferState.connected, message: 'P2P Connected!');
          _sendAllFiles(isNearby: false);
        }
      }
    };
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
      final outPath = await FileUtils.uniqueFilePath(
        dir.path,
        FileUtils.sanitizeFileName(name),
      );
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

  Future<void> _logTransfer(
    String fileName,
    String direction,
    String mode, {
    int size = 0,
  }) async {
    await _history.addRecord(TransferRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: size,
      direction: direction,
      mode: mode,
      at: DateTime.now(),
    ));
  }

  Future<void> cancel() async {
    _updateState(TransferState.idle, message: 'Cancelled');
    _progress = 0;
    _pendingFiles = [];
    _filesTransferred = 0;
    _totalFiles = 0;
    _errorMessage = null;
    _connectionLink = null;
    _answerLink = null;
    _discoveredDevices.clear();

    if (_roomCode != null) {
      await signalingService.clearSignalData(_roomCode!);
    }

    nearbyService.stopDiscovery();
    nearbyService.stopAdvertising();
    await nearbyService.dispose();
    await webrtcService.dispose();
  }

  Future<void> dispose() async {
    await cancel();
    await signalingService.cleanupExpiredSignals();
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
