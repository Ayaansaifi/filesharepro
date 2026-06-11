import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';

/// Nearby file transfer service using local Wi-Fi sockets.
/// Works by creating a TCP server on sender and connecting from receiver.
/// NO external server or database — purely local P2P.
class NearbyService {
  static const int _port = 43210;
  
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  
  // ─── State Callbacks ─────────────────────────────────────
  ValueChanged<NearbyDevice>? onDeviceFound;
  ValueChanged<double>? onTransferProgress;
  ValueChanged<String>? onTransferComplete;
  ValueChanged<String>? onError;
  ValueChanged<String>? onStatusChange;

  bool _isDiscovering = false;
  bool _isTransferring = false;
  
  bool get isDiscovering => _isDiscovering;
  bool get isTransferring => _isTransferring;

  // ─── SENDER: Start hosting ───────────────────────────────

  /// Convenience method with callbacks for UI integration
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
    return _startHostingInternal();
  }

  /// Start TCP server to accept incoming file transfer connections.
  /// Returns the IP address and port for the receiver to connect to.
  Future<String?> _startHostingInternal() async {
    try {
      // Get device IP
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      
      String? localIp;
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            localIp = addr.address;
            break;
          }
        }
        if (localIp != null) break;
      }
      
      if (localIp == null) {
        onError?.call('Could not find local IP address. Make sure Wi-Fi is on.');
        return null;
      }

      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      onStatusChange?.call('Hosting on $localIp:$_port');
      
      _serverSocket!.listen(
        (Socket client) {
          onStatusChange?.call('Device connected: ${client.remoteAddress.address}');
          _clientSocket = client;
          onDeviceFound?.call(NearbyDevice(
            name: 'Device',
            address: client.remoteAddress.address,
            port: client.remotePort,
          ));
        },
        onError: (e) => onError?.call('Server error: $e'),
      );

      return '$localIp:$_port';
    } catch (e) {
      onError?.call('Failed to start hosting: $e');
      return null;
    }
  }

  // ─── RECEIVER: Connect to host ───────────────────────────

  /// Connect to the sender's TCP server
  Future<bool> connectToHost(String address) async {
    try {
      final parts = address.split(':');
      if (parts.length != 2) {
        onError?.call('Invalid address format. Use IP:PORT');
        return false;
      }
      
      final ip = parts[0];
      final port = int.tryParse(parts[1]) ?? _port;
      
      onStatusChange?.call('Connecting to $ip:$port...');
      
      _clientSocket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 10),
      );
      
      onStatusChange?.call('Connected to sender!');
      return true;
    } catch (e) {
      onError?.call('Connection failed: $e');
      return false;
    }
  }

  // ─── SENDER: Send file ───────────────────────────────────

  /// Send a file over the connected socket.
  /// Protocol: [4-byte name length][name bytes][8-byte file size][file bytes]
  Future<bool> sendFile(File file) async {
    if (_clientSocket == null) {
      onError?.call('No connected device');
      return false;
    }

    try {
      _isTransferring = true;
      onStatusChange?.call('Sending: ${file.path.split(Platform.pathSeparator).last}');
      
      final fileName = file.path.split(Platform.pathSeparator).last;
      final nameBytes = utf8.encode(fileName);
      final fileSize = await file.length();
      
      // Send header: name length (4 bytes) + name + file size (8 bytes)
      final header = ByteData(4);
      header.setUint32(0, nameBytes.length);
      _clientSocket!.add(header.buffer.asUint8List());
      _clientSocket!.add(nameBytes);
      
      final sizeHeader = ByteData(8);
      sizeHeader.setUint64(0, fileSize);
      _clientSocket!.add(sizeHeader.buffer.asUint8List());
      
      // Stream file data in chunks
      int sent = 0;
      final stream = file.openRead();
      await for (final chunk in stream) {
        _clientSocket!.add(chunk);
        sent += chunk.length;
        onTransferProgress?.call(sent / fileSize);
      }
      
      await _clientSocket!.flush();
      
      _isTransferring = false;
      onTransferComplete?.call(fileName);
      onStatusChange?.call('File sent successfully!');
      return true;
    } catch (e) {
      _isTransferring = false;
      onError?.call('Send failed: $e');
      return false;
    }
  }

  // ─── RECEIVER: Receive file ──────────────────────────────

  /// Listen for incoming file on the connected socket.
  Future<File?> receiveFile() async {
    if (_clientSocket == null) {
      onError?.call('No connected device');
      return null;
    }

    try {
      _isTransferring = true;
      onStatusChange?.call('Waiting for file...');
      
      final completer = Completer<File?>();
      final buffer = <int>[];
      String? fileName;
      int? fileSize;
      int headerPhase = 0; // 0=name_len, 1=name, 2=size, 3=data
      int? nameLength;
      int dataReceived = 0;
      IOSink? fileSink;
      File? outputFile;

      _clientSocket!.listen(
        (data) async {
          buffer.addAll(data);
          
          // Phase 0: Read name length (4 bytes)
          if (headerPhase == 0 && buffer.length >= 4) {
            final bd = ByteData.view(Uint8List.fromList(buffer.sublist(0, 4)).buffer);
            nameLength = bd.getUint32(0);
            buffer.removeRange(0, 4);
            headerPhase = 1;
          }
          
          // Phase 1: Read file name
          if (headerPhase == 1 && nameLength != null && buffer.length >= nameLength!) {
            fileName = utf8.decode(buffer.sublist(0, nameLength!));
            buffer.removeRange(0, nameLength!);
            headerPhase = 2;
          }
          
          // Phase 2: Read file size (8 bytes)
          if (headerPhase == 2 && buffer.length >= 8) {
            final bd = ByteData.view(Uint8List.fromList(buffer.sublist(0, 8)).buffer);
            fileSize = bd.getUint64(0);
            buffer.removeRange(0, 8);
            headerPhase = 3;
            
            // Create output file
            final downloadDir = await FileUtils.getReceivedDir();
            outputFile = File('${downloadDir.path}/$fileName');
            fileSink = outputFile!.openWrite();
            
            onStatusChange?.call('Receiving: $fileName (${FileUtils.formatFileSize(fileSize!)})');
          }
          
          // Phase 3: Receive file data
          if (headerPhase == 3 && fileSink != null && fileSize != null) {
            fileSink!.add(buffer);
            dataReceived += buffer.length;
            buffer.clear();
            
            onTransferProgress?.call(dataReceived / fileSize!);
            
            if (dataReceived >= fileSize!) {
              await fileSink!.flush();
              await fileSink!.close();
              _isTransferring = false;
              onTransferComplete?.call(fileName ?? 'file');
              onStatusChange?.call('File received successfully!');
              completer.complete(outputFile);
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            _isTransferring = false;
            if (dataReceived > 0 && fileSize != null && dataReceived >= fileSize!) {
              completer.complete(outputFile);
            } else {
              completer.complete(null);
            }
          }
        },
        onError: (e) {
          _isTransferring = false;
          onError?.call('Receive error: $e');
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      return await completer.future;
    } catch (e) {
      _isTransferring = false;
      onError?.call('Receive failed: $e');
      return null;
    }
  }

  // ─── Discovery (UDP Broadcast) ───────────────────────────

  /// Convenience method with callbacks for UI integration  
  Future<void> startDiscovery({
    ValueChanged<Map<String, dynamic>>? onDeviceFound,
    ValueChanged<String>? onError,
  }) async {
    this.onError = onError;
    this.onDeviceFound = (device) {
      onDeviceFound?.call({
        'name': device.name,
        'address': device.address,
        'port': device.port,
      });
    };
    await _startDiscoveryInternal(deviceName: 'FileShare Pro');
  }

  /// Broadcast presence on LAN using UDP for device discovery
  Future<void> _startDiscoveryInternal({
    required String deviceName,
  }) async {
    _isDiscovering = true;
    onStatusChange?.call('Searching for nearby devices...');
    
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;
      
      // Broadcast our presence
      final message = json.encode({
        'type': 'fileshare_discovery',
        'name': deviceName,
        'port': _port,
        'version': AppConstants.appVersion,
      });
      
      // Send broadcast every 2 seconds, auto-stop after 30 seconds
      int elapsed = 0;
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!_isDiscovering || elapsed >= 30) {
          timer.cancel();
          socket.close();
          if (elapsed >= 30) {
            onStatusChange?.call('Discovery timed out');
          }
          return;
        }
        elapsed += 2;
        
        socket.send(
          utf8.encode(message),
          InternetAddress('255.255.255.255'),
          _port + 1,
        );
      });
      
      // Listen for responses
      final listener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port + 1,
      );
      listener.broadcastEnabled = true;
      
      listener.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = listener.receive();
          if (datagram != null) {
            try {
              final data = json.decode(utf8.decode(datagram.data));
              if (data['type'] == 'fileshare_discovery') {
                onDeviceFound?.call(NearbyDevice(
                  name: data['name'] ?? 'Unknown',
                  address: datagram.address.address,
                  port: data['port'] ?? _port,
                ));
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      onError?.call('Discovery error: $e');
    }
  }

  /// Stop discovering nearby devices
  void stopDiscovery() {
    _isDiscovering = false;
    onStatusChange?.call('Discovery stopped');
  }

  // ─── Cleanup ─────────────────────────────────────────────

  Future<void> dispose() async {
    _isDiscovering = false;
    _isTransferring = false;
    
    try {
      _clientSocket?.destroy();
      _clientSocket = null;
    } catch (_) {}
    
    try {
      await _serverSocket?.close();
      _serverSocket = null;
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
