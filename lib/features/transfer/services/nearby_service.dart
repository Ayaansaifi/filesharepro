import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';

/// Nearby file transfer service using Google's Nearby Connections API.
/// Uses P2P_STAR strategy for high-bandwidth file transfers.
/// NO external server or database — purely local P2P.
class NearbyService {
  static const String _serviceId = 'com.filesharepro.filesharepro';

  final Strategy _strategy = Strategy.P2P_STAR;
  final Nearby _nearby = Nearby();

  // ─── State Callbacks ─────────────────────────────────────
  ValueChanged<NearbyDevice>? onDeviceFound;
  ValueChanged<double>? onTransferProgress;
  ValueChanged<String>? onTransferComplete;
  ValueChanged<String>? onError;
  ValueChanged<String>? onStatusChange;
  VoidCallback? onDisconnected;

  bool _isDiscovering = false;
  bool _isAdvertising = false;
  bool _isTransferring = false;
  String? _connectedEndpointId;

  // Transfer state
  int? _currentPayloadId;
  String? _currentFileName;
  int _currentFileSize = 0;

  bool get isDiscovering => _isDiscovering;
  bool get isAdvertising => _isAdvertising;
  bool get isTransferring => _isTransferring;
  bool get isConnected => _connectedEndpointId != null;

  Completer<bool>? _connectionCompleter;

  // ─── Permissions ────────────────────────────────────────

  /// Request all necessary permissions for Nearby Connections
  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    // Location is critical; others are best-effort
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;
    return locationGranted;
  }

  // ─── SENDER: Start hosting ───────────────────────────────

  /// Start advertising this device so receivers can discover it.
  /// Returns the device name or null on failure.
  Future<String?> startHosting({
    String? deviceName,
    ValueChanged<Map<String, dynamic>>? onDeviceConnected,
    ValueChanged<String>? onError,
  }) async {
    this.onError = onError;
    onDeviceFound = (device) {
      onDeviceConnected?.call({
        'name': device.name,
        'address': device.address,
        'port': device.port,
      });
    };

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) {
      onError?.call('Location permission is required for Nearby Sharing');
      return null;
    }

    final name = deviceName ?? 'FileShare Pro';

    try {
      final success = await _nearby.startAdvertising(
        name,
        _strategy,
        onConnectionInitiated: (id, info) {
          onStatusChange?.call('Connection request from ${info.endpointName}');
          // Auto-accept connections
          _nearby.acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              _handlePayloadReceived(endpointId, payload);
            },
            onPayloadTransferUpdate: (endpointId, update) {
              _handlePayloadTransferUpdate(endpointId, update);
            },
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            onStatusChange?.call('Device connected!');
            onDeviceFound?.call(NearbyDevice(
              name: name,
              address: id,
              port: 0,
            ));
          } else {
            onStatusChange?.call('Connection failed');
          }
        },
        onDisconnected: (id) {
          _connectedEndpointId = null;
          onStatusChange?.call('Device disconnected');
          onDisconnected?.call();
        },
      );

      if (success) {
        _isAdvertising = true;
        onStatusChange?.call('Broadcasting as "$name"...');
        return name;
      }
      return null;
    } catch (e) {
      this.onError?.call('Failed to start hosting: $e');
      return null;
    }
  }

  // ─── RECEIVER: Discover and Connect ──────────────────────

  /// Start scanning for nearby senders
  Future<void> startDiscovery({
    ValueChanged<Map<String, dynamic>>? onDeviceFound,
    ValueChanged<String>? onError,
  }) async {
    this.onError = onError;

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) {
      onError?.call('Location permission is required for Nearby Sharing');
      return;
    }

    try {
      final success = await _nearby.startDiscovery(
        'filesharepro_receiver',
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          onStatusChange?.call('Found: $name');
          onDeviceFound?.call({
            'name': name,
            'address': id,
            'port': 0,
          });

          // Notify our internal callback too
          this.onDeviceFound?.call(NearbyDevice(
            name: name,
            address: id,
            port: 0,
          ));
        },
        onEndpointLost: (id) {
          onStatusChange?.call('Device lost');
        },
      );

      if (success) {
        _isDiscovering = true;
        onStatusChange?.call('Searching for nearby devices...');
      }
    } catch (e) {
      this.onError?.call('Discovery error: $e');
    }
  }

  /// Connect to a discovered endpoint by its ID
  Future<bool> connectToHost(String endpointId) async {
    try {
      onStatusChange?.call('Connecting...');

      _connectionCompleter = Completer<bool>();

      await _nearby.requestConnection(
        'filesharepro_receiver',
        endpointId,
        onConnectionInitiated: (id, info) {
          onStatusChange?.call('Authenticating with ${info.endpointName}...');
          _nearby.acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              _handlePayloadReceived(endpointId, payload);
            },
            onPayloadTransferUpdate: (endpointId, update) {
              _handlePayloadTransferUpdate(endpointId, update);
            },
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            onStatusChange?.call('Connected!');
            if (_connectionCompleter != null &&
                !_connectionCompleter!.isCompleted) {
              _connectionCompleter!.complete(true);
            }
          } else {
            onStatusChange?.call('Connection rejected');
            if (_connectionCompleter != null &&
                !_connectionCompleter!.isCompleted) {
              _connectionCompleter!.complete(false);
            }
          }
        },
        onDisconnected: (id) {
          _connectedEndpointId = null;
          onStatusChange?.call('Disconnected');
          onDisconnected?.call();
        },
      );

      return await _connectionCompleter!.future.timeout(
        const Duration(seconds: AppConstants.connectionTimeoutSec),
        onTimeout: () {
          onError?.call('Connection timed out');
          return false;
        },
      );
    } catch (e) {
      onError?.call('Connection failed: $e');
      return false;
    } finally {
      _connectionCompleter = null;
    }
  }

  // ─── SENDER: Send file ───────────────────────────────────

  /// Send a file to the connected endpoint using Nearby Connections FILE payload.
  Future<bool> sendFile(File file) async {
    if (_connectedEndpointId == null) {
      onError?.call('No connected device');
      return false;
    }

    try {
      _isTransferring = true;
      final fileName = file.path.split(Platform.pathSeparator).last;
      _currentFileName = fileName;
      _currentFileSize = await file.length();

      onStatusChange?.call('Sending: $fileName');

      // First send the filename as BYTES payload so receiver knows what it is
      final metaJson = json.encode({
        'fileName': fileName,
        'fileSize': _currentFileSize,
      });
      await _nearby.sendBytesPayload(
        _connectedEndpointId!,
        Uint8List.fromList(utf8.encode('META:$metaJson')),
      );

      // Small delay to ensure metadata arrives first
      await Future.delayed(const Duration(milliseconds: 200));

      // Send the actual file payload
      final payloadId = await _nearby.sendFilePayload(
        _connectedEndpointId!,
        file.path,
      );

      _currentPayloadId = payloadId;
      onStatusChange?.call('Sending $fileName...');

      return true;
    } catch (e) {
      _isTransferring = false;
      onError?.call('Send failed: $e');
      return false;
    }
  }

  // ─── RECEIVER: Receive file ──────────────────────────────

  /// Listen for incoming file on the connected endpoint.
  /// Files are received automatically via the payload callbacks.
  Future<File?> receiveFile() async {
    // Nearby Connections handles receiving automatically through callbacks
    // set up during acceptConnection. This method exists for API compatibility.
    onStatusChange?.call('Waiting for file...');
    
    // Return null — actual file handling is done in payload callbacks
    return null;
  }

  // ─── Payload Handling ────────────────────────────────────

  void _handlePayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final message = utf8.decode(payload.bytes!);
      if (message.startsWith('META:')) {
        try {
          final metaJson = json.decode(message.substring(5));
          _currentFileName = metaJson['fileName'] as String?;
          _currentFileSize = metaJson['fileSize'] as int? ?? 0;
          onStatusChange?.call('Receiving: $_currentFileName');
        } catch (e) {
          debugPrint('Failed to parse file metadata: $e');
        }
      }
    } else if (payload.type == PayloadType.FILE) {
      _currentPayloadId = payload.id;
      _isTransferring = true;
      onStatusChange?.call('Receiving file data...');
    }
  }

  void _handlePayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    if (update.id == _currentPayloadId) {
      final progress = update.bytesTransferred / (update.totalBytes > 0 ? update.totalBytes : 1);
      onTransferProgress?.call(progress);

      if (update.status == PayloadStatus.SUCCESS) {
        _isTransferring = false;

        // Nearby Connections saves FILE payloads to a temp location
        // We need to rename and move it to our received directory
        _finalizeReceivedFile(update).then((success) {
          if (success) {
            onTransferComplete?.call(_currentFileName ?? 'file');
            onStatusChange?.call('File received successfully!');
          }
        });
      } else if (update.status == PayloadStatus.FAILURE) {
        _isTransferring = false;
        onError?.call('Transfer failed');
      }
    }
  }

  /// Move the received file from Nearby Connections temp directory to our app's directory
  Future<bool> _finalizeReceivedFile(PayloadTransferUpdate update) async {
    try {
      final downloadDir = await FileUtils.getReceivedDir();
      final targetName = FileUtils.sanitizeFileName(
        _currentFileName ?? 'received_${DateTime.now().millisecondsSinceEpoch}',
      );
      final targetPath = await FileUtils.uniqueFilePath(
        downloadDir.path,
        targetName,
      );

      // Nearby Connections saves the file with the payload ID as the filename
      // in the Downloads directory or app cache
      final possiblePaths = [
        '/storage/emulated/0/Download/${update.id}',
        '/storage/emulated/0/Android/data/$_serviceId/files/${update.id}',
      ];

      for (final path in possiblePaths) {
        final tempFile = File(path);
        if (await tempFile.exists()) {
          await tempFile.rename(targetPath);
          onStatusChange?.call('Saved: $targetName');
          return true;
        }
      }

      onError?.call('Received file could not be located on device');
      return false;
    } catch (e) {
      debugPrint('Failed to finalize received file: $e');
      onError?.call('File saved but could not be moved: $e');
      return false;
    }
  }

  // ─── Stop ────────────────────────────────────────────────

  /// Stop discovering nearby devices
  void stopDiscovery() {
    _isDiscovering = false;
    _nearby.stopDiscovery();
    onStatusChange?.call('Discovery stopped');
  }

  /// Stop advertising
  void stopAdvertising() {
    _isAdvertising = false;
    _nearby.stopAdvertising();
    onStatusChange?.call('Advertising stopped');
  }

  // ─── Cleanup ─────────────────────────────────────────────

  Future<void> dispose() async {
    _isDiscovering = false;
    _isAdvertising = false;
    _isTransferring = false;
    _connectedEndpointId = null;

    try {
      await _nearby.stopAllEndpoints();
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
    } catch (_) {}
  }
}

/// Represents a discovered nearby device
class NearbyDevice {
  final String name;
  final String address;
  final int port;

  const NearbyDevice({
    required this.name,
    required this.address,
    required this.port,
  });

  String get connectionString => '$address:$port';

  @override
  String toString() => 'NearbyDevice($name @ $address:$port)';
}
